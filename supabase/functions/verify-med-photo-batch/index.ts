// ============================================
// Edge Function: verify-med-photo-batch
// ============================================
// Batch processor สำหรับตรวจสอบรูปยาด้วย AI (Gemini Vision)
// ถูกเรียกโดย pg_cron ทุก 2 นาที เมื่อมี items อยู่ใน med_verification_queue
//
// Flow:
//   1. Claim items จาก queue ด้วย claim_verification_queue RPC (ใช้ FOR UPDATE SKIP LOCKED)
//   2. วน process ทีละ item (sequential — ลดปัญหา concurrency)
//   3. แต่ละ item: ดึงยา → กรอง shouldTakeOnDate → ดาวน์โหลดรูป → Gemini Vision → บันทึกผล
//   4. อัพเดท queue status เป็น 'done' หรือ 'error'
//
// เหตุผลที่ใช้ batch แทน trigger-per-row:
//   - ลดจำนวน cold starts (เดิม trigger ทุก row → boot 546 ครั้ง → error)
//   - pg_cron เรียกทุก 2 นาที → batch ละ 5 items → ประหยัด resources
//   - FOR UPDATE SKIP LOCKED ป้องกัน race condition ถ้ามี worker หลายตัว

import { createClient } from 'npm:@supabase/supabase-js@2'
import { GoogleGenerativeAI } from 'npm:@google/generative-ai'

// ============================================
// Supabase + Gemini clients
// ============================================
// สร้าง client ด้วย service role key เพราะ edge function ไม่มี user session
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// Gemini AI client สำหรับ Vision API
const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!)

// ============================================
// Types
// ============================================

// ข้อมูลจาก queue table (claim_verification_queue RPC ส่งกลับมา)
interface QueueItem {
  id: number           // queue item ID (ใช้อัพเดท status)
  med_log_id: number
  photo_type: '2C' | '3C'
  resident_id: number
  meal: string         // เช่น 'ก่อนอาหารเช้า'
  photo_url: string    // URL รูปที่ staff ถ่าย
  calendar_date: string // YYYY-MM-DD
  nursinghome_id: number
  status: string
  retry_count: number
  created_at: string
  started_at: string
}

// ข้อมูลยาจาก medicine_summary view (ครบทุก field สำหรับ shouldTakeOnDate)
interface MedicineSummary {
  medicine_list_id: number
  resident_id: number
  generic_name: string | null
  brand_name: string | null
  take_tab: number | null
  str: string | null
  unit: string | null
  front_foiled: string | null
  back_foiled: string | null
  front_nude: string | null
  back_nude: string | null
  // fields สำหรับ shouldTakeOnDate filtering
  status: string | null
  prn: boolean | null
  before_after: string[] | null
  bldb: string[] | null
  type_of_time: string | null      // 'วัน' | 'สัปดาห์' | 'เดือน' | 'ชั่วโมง'
  every_hr: number | null           // ความถี่ (ทุกกี่วัน/สัปดาห์/เดือน)
  days_of_week: string[] | null     // สำหรับ สัปดาห์ เช่น ['จันทร์', 'พุธ']
  first_med_history_on_date: string | null  // วันที่เริ่มใช้ยา
  last_med_history_off_date: string | null  // วันที่หยุดยา
}

// ผลจาก Gemini (structured JSON)
interface AIAnalysis {
  pill_count_match: boolean
  pill_appearance_match: boolean
  packaging_match: boolean
  expected_count: number | null
  detected_count: number | null
  concerns: string[]
  summary: string
  confidence_score: number
}

// ============================================
// Constants
// ============================================

// Map วันภาษาไทย → index (0=อาทิตย์, 1=จันทร์, ...)
// ใช้แปลง daysOfWeek จาก DB (ภาษาไทย) เป็น JS getDay() index
const THAI_DAY_TO_INDEX: Record<string, number> = {
  'อาทิตย์': 0,
  'จันทร์': 1,
  'อังคาร': 2,
  'พุธ': 3,
  'พฤหัส': 4,
  'พฤหัสบดี': 4,
  'ศุกร์': 5,
  'เสาร์': 6,
}

// แปลง meal name → BeforeAfter + BLDB สำหรับ filter ยา
// เช่น 'ก่อนอาหารเช้า' → beforeAfter='ก่อนอาหาร', bldb='เช้า'
const mealMappings: Record<string, { beforeAfter: string; bldb: string }> = {
  'ก่อนอาหารเช้า': { beforeAfter: 'ก่อนอาหาร', bldb: 'เช้า' },
  'หลังอาหารเช้า': { beforeAfter: 'หลังอาหาร', bldb: 'เช้า' },
  'ก่อนอาหารกลางวัน': { beforeAfter: 'ก่อนอาหาร', bldb: 'กลางวัน' },
  'หลังอาหารกลางวัน': { beforeAfter: 'หลังอาหาร', bldb: 'กลางวัน' },
  'ก่อนอาหารเย็น': { beforeAfter: 'ก่อนอาหาร', bldb: 'เย็น' },
  'หลังอาหารเย็น': { beforeAfter: 'หลังอาหาร', bldb: 'เย็น' },
  'ก่อนนอน': { beforeAfter: '', bldb: 'ก่อนนอน' },
}

// ============================================
// CORS headers
// ============================================

// Response สำหรับ CORS preflight
function corsResponse(): Response {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
    },
  })
}

// สร้าง JSON response พร้อม CORS headers
function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  })
}

// ============================================
// Prompt สำหรับ Gemini Vision
// ============================================
// สั่งให้ Gemini เปรียบเทียบรูป reference กับรูป staff
// lenient กับ lighting/มุม แต่ strict กับจำนวนและประเภทยา
// (เหมือนกับ verify-med-photo เป๊ะ — ห้ามแก้ logic)

function buildPrompt(medicines: MedicineSummary[], photoType: '2C' | '3C'): string {
  // สร้างรายการยาที่ต้องมีใน meal นี้
  const medList = medicines.map((med, i) => {
    const name = med.brand_name || med.generic_name || 'ไม่ระบุ'
    const count = med.take_tab ?? 1
    const strength = med.str || ''
    const unit = med.unit || 'เม็ด'
    return `  ${i + 1}. ${name} ${strength} — จำนวน ${count} ${unit}`
  }).join('\n')

  const photoTypeDesc = photoType === '2C'
    ? 'แผงยา (blister pack / foil)'
    : 'เม็ดยา (individual pills)'

  return `คุณเป็นระบบ AI ตรวจสอบความถูกต้องของยาใน Nursing Home
คุณจะได้รับ:
1. "รูปอ้างอิง" (Reference) — ภาพ${photoTypeDesc}ของยาแต่ละตัวจากฐานข้อมูล (อาจมีทั้งด้านหน้าและด้านหลัง)
2. "รูปจริง" (Staff Photo) — ภาพที่ staff ถ่ายตอน${photoType === '2C' ? 'จัดยา' : 'เสิร์ฟยา'}

ยาที่ต้องมีในมื้อนี้:
${medList}

## กฎการตรวจสอบ:
- ✅ LENIENT: อนุโลมเรื่องแสง (lighting), มุมกล้อง (angle), ความชัด (blur เล็กน้อย)
- ❌ STRICT: จำนวนเม็ดยา/แผงยาต้องตรง, ประเภทยา (สี/รูปร่าง/marking) ต้องตรง
- ⚠️ ถ้ารูปจริงมียาหลายตัวรวมกัน ให้พยายาม identify แต่ละตัวเทียบกับ reference
- 📷 ถ้ารูปเบลอมากจนไม่สามารถตรวจสอบได้ ให้ flag พร้อมระบุเหตุผล

## Output:
ตอบเป็น JSON เท่านั้น (ห้ามมี text อื่น):
{
  "pill_count_match": true/false,
  "pill_appearance_match": true/false,
  "packaging_match": true/false,
  "expected_count": <จำนวนรวมที่ต้องมี>,
  "detected_count": <จำนวนที่เห็นในรูปจริง หรือ null ถ้าไม่แน่ใจ>,
  "concerns": ["ข้อกังวล 1 (ภาษาไทย)", "ข้อกังวล 2"],
  "summary": "สรุปสั้นๆ ภาษาไทย",
  "confidence_score": 0-100
}

หมายเหตุ confidence_score:
- 90-100: มั่นใจมากว่ายาถูกต้อง
- 70-89: น่าจะถูกต้อง แต่มีจุดที่ไม่ชัด
- 50-69: ไม่แน่ใจ ควรให้คนตรวจซ้ำ
- 0-49: พบปัญหาชัดเจน (ยาผิด/ขาด/เกิน)`
}

// ============================================
// ดาวน์โหลดรูปเป็น base64 สำหรับส่ง Gemini
// ============================================
// Gemini Vision ต้องการรูปเป็น base64 inline data
// ดาวน์โหลดจาก URL → แปลง ArrayBuffer → base64 string

async function downloadImageAsBase64(url: string): Promise<{ base64: string; mimeType: string } | null> {
  try {
    const response = await fetch(url)
    if (!response.ok) {
      console.error(`Failed to download image: ${response.status} ${url}`)
      return null
    }

    const arrayBuffer = await response.arrayBuffer()
    const uint8Array = new Uint8Array(arrayBuffer)

    // แปลงเป็น base64 string ทีละ byte
    let binary = ''
    for (let i = 0; i < uint8Array.length; i++) {
      binary += String.fromCharCode(uint8Array[i])
    }
    const base64 = btoa(binary)

    // ดึง MIME type จาก response header (ปกติจะเป็น image/jpeg หรือ image/png)
    const contentType = response.headers.get('content-type') || 'image/jpeg'

    return { base64, mimeType: contentType }
  } catch (err) {
    console.error(`Error downloading image: ${err}`)
    return null
  }
}

// ============================================
// shouldTakeOnDate — Port จาก webapp types.ts
// ============================================
// ตรวจสอบว่ายาต้องกินในวันที่เลือกหรือไม่
// ใช้ logic เดียวกับ verify-med-photo เป๊ะ (ห้ามแก้)
// ดู logic เต็มใน: irene-training-admin/app/(dashboard)/medicine/review/types.ts

// Parse PostgreSQL array format "{val1,val2}" → string[]
// medicine_summary view อาจส่ง array มาเป็น string format นี้
function parseStringArray(value: unknown): string[] {
  if (Array.isArray(value)) return value as string[]
  if (typeof value === 'string') {
    // ลบ { } ออก แล้ว split ด้วย comma
    const trimmed = value.replace(/^\{|\}$/g, '')
    if (!trimmed) return []
    return trimmed.split(',').map(s => s.trim().replace(/^"|"$/g, ''))
  }
  return []
}

// คำนวณจำนวนวันระหว่าง 2 วัน (ปัดเศษลง)
function daysBetween(dateA: Date, dateB: Date): number {
  const msPerDay = 24 * 60 * 60 * 1000
  return Math.floor((dateB.getTime() - dateA.getTime()) / msPerDay)
}

// ตรวจสอบว่ายาต้องกินในวันที่เลือกหรือไม่
// ตรวจ: PRN, status, date range, BeforeAfter, BLDB, ความถี่ (วัน/สัปดาห์/เดือน)
function shouldTakeOnDate(
  med: MedicineSummary,
  selectedDate: Date,
  filterBeforeAfter?: string,
  filterBldb?: string,
): boolean {
  // 1. ข้าม PRN (ยาตามอาการ — ไม่ได้กินประจำ)
  if (med.prn) return false

  // 2. ต้อง status = 'on' (ยาที่ยัง active อยู่)
  if (med.status !== 'on') return false

  // 3. Normalize วันที่เป็น YYYY-MM-DD (ตัด timezone เพื่อเทียบเฉพาะวัน)
  const checkDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate())

  // 4. ตรวจ date range — ยาอาจมีวันเริ่มและวันหยุด
  if (med.first_med_history_on_date) {
    const startDate = new Date(med.first_med_history_on_date)
    const startNorm = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate())
    if (checkDate < startNorm) return false
  }
  if (med.last_med_history_off_date) {
    const endDate = new Date(med.last_med_history_off_date)
    const endNorm = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate())
    if (checkDate > endNorm) return false
  }

  // 5. ตรวจ BeforeAfter filter (ก่อนอาหาร/หลังอาหาร)
  const medBeforeAfter = parseStringArray(med.before_after)
  if (filterBeforeAfter && medBeforeAfter.length > 0) {
    if (!medBeforeAfter.includes(filterBeforeAfter)) return false
  }

  // 6. ตรวจ BLDB filter (เช้า/กลางวัน/เย็น/ก่อนนอน)
  const medBldb = parseStringArray(med.bldb)
  if (filterBldb && medBldb.length > 0) {
    if (!medBldb.includes(filterBldb)) return false
  }

  // 7. ตรวจความถี่ตาม typeOfTime
  const typeOfTime = med.type_of_time
  const everyHr = med.every_hr ?? 1

  // ไม่มี typeOfTime หรือ 'ชั่วโมง' → กินทุกวัน
  if (!typeOfTime || typeOfTime === 'ชั่วโมง') {
    return true
  }

  // ต้องมี start date สำหรับคำนวณ frequency
  let startNorm: Date
  if (med.first_med_history_on_date) {
    const s = new Date(med.first_med_history_on_date)
    startNorm = new Date(s.getFullYear(), s.getMonth(), s.getDate())
  } else {
    // ไม่มี start date → pass ทุกวัน (ไม่มีจุดอ้างอิงสำหรับคำนวณ)
    return true
  }

  if (typeOfTime === 'วัน') {
    // ทุก N วัน: จำนวนวันจาก start date หาร everyHr ต้องลงตัว
    const days = daysBetween(startNorm, checkDate)
    return days >= 0 && days % everyHr === 0
  }

  if (typeOfTime === 'สัปดาห์') {
    // ทุก N สัปดาห์ + เฉพาะวันที่กำหนดใน daysOfWeek
    const daysOfWeek = parseStringArray(med.days_of_week)
    const checkDayIndex = checkDate.getDay()

    // ตรวจว่าวันนี้อยู่ใน daysOfWeek ไหม
    const dayMatches = daysOfWeek.some(thaiDay => {
      const dayIndex = THAI_DAY_TO_INDEX[thaiDay]
      return dayIndex !== undefined && dayIndex === checkDayIndex
    })
    if (!dayMatches && daysOfWeek.length > 0) return false

    // ตรวจว่าอยู่ในสัปดาห์ที่ถูกต้อง (ทุก N สัปดาห์)
    const days = daysBetween(startNorm, checkDate)
    const weeks = Math.floor(days / 7)
    return weeks >= 0 && weeks % everyHr === 0
  }

  if (typeOfTime === 'เดือน') {
    // ทุก N เดือน: วันของเดือนตรงกับ start date
    return startNorm.getDate() === checkDate.getDate()
  }

  // fallback → กินทุกวัน
  return true
}

// ============================================
// Queue Management Functions
// ============================================

// Claim items จาก queue แบบ atomic ด้วย FOR UPDATE SKIP LOCKED
// ป้องกัน race condition — ถ้ามี worker หลายตัว แต่ละตัวจะได้ items คนละชุด
async function claimQueueItems(
  // deno-lint-ignore no-explicit-any
  client: any,
  limit = 2,
): Promise<{ data: QueueItem[] | null; error: Error | null }> {
  const { data, error } = await client.rpc('claim_verification_queue', { batch_limit: limit })
  return { data, error }
}

// อัพเดท queue item เป็น 'done' พร้อมเวลาที่เสร็จ
async function markDone(
  // deno-lint-ignore no-explicit-any
  client: any,
  queueId: number,
): Promise<void> {
  const { error } = await client
    .from('med_verification_queue')
    .update({ status: 'done', completed_at: new Date().toISOString() })
    .eq('id', queueId)

  if (error) {
    console.error(`[batch] Failed to mark item ${queueId} as done:`, error.message)
  }
}

// อัพเดท queue item เป็น 'error' พร้อม error message
async function markError(
  // deno-lint-ignore no-explicit-any
  client: any,
  queueId: number,
  errorMessage: string,
): Promise<void> {
  const { error } = await client
    .from('med_verification_queue')
    .update({
      status: 'error',
      error_message: errorMessage,
      completed_at: new Date().toISOString(),
    })
    .eq('id', queueId)

  if (error) {
    console.error(`[batch] Failed to mark item ${queueId} as error:`, error.message)
  }
}

// ============================================
// processOneItem — หัวใจของ batch processor
// ============================================
// ทำเหมือน verify-med-photo เป๊ะ แต่รับข้อมูลจาก queue item แทน request body
// Steps: ดึงยา → กรอง → ดาวน์โหลดรูป → Gemini Vision → บันทึกผล

async function processOneItem(
  // deno-lint-ignore no-explicit-any
  client: any,
  // deno-lint-ignore no-explicit-any
  ai: any,
  item: QueueItem,
): Promise<void> {
  const startTime = Date.now()
  const { med_log_id, resident_id, meal, photo_type, photo_url, calendar_date, nursinghome_id } = item

  console.log(`[batch] Processing item ${item.id}: resident=${resident_id}, meal=${meal}, type=${photo_type}, date=${calendar_date}`)

  // ============================================
  // Step 1: ดึง active meds ของ resident จาก medicine_summary
  // ============================================
  // Query เหมือน verify-med-photo เป๊ะ — ดึงทุก field ที่ shouldTakeOnDate ต้องใช้
  const { data: medsData, error: medsError } = await client
    .from('medicine_summary')
    .select(`
      medicine_list_id,
      resident_id,
      generic_name,
      brand_name,
      take_tab,
      str,
      unit,
      status,
      prn,
      "Front-Foiled",
      "Back-Foiled",
      "Front-Nude",
      "Back-Nude",
      "BeforeAfter",
      "BLDB",
      "typeOfTime",
      every_hr,
      "DaysOfWeek",
      first_med_history_on_date,
      last_med_history_off_date
    `)
    .eq('resident_id', resident_id)
    .eq('status', 'on')

  if (medsError) {
    throw new Error(`Failed to fetch medicines: ${medsError.message}`)
  }

  // ============================================
  // Step 2: กรองยาด้วย shouldTakeOnDate
  // ============================================
  // แปลง meal → beforeAfter + bldb สำหรับ filter
  const mealInfo = mealMappings[meal]
  if (!mealInfo) {
    console.warn(`[batch] Unknown meal: ${meal}, checking all medicines`)
  }

  // Parse วันที่สำหรับ shouldTakeOnDate (ใช้ T00:00:00 เพื่อ normalize timezone)
  const selectedDate = new Date(calendar_date + 'T00:00:00')

  // แปลง raw data → MedicineSummary (map field names จาก DB → interface)
  // DB ใช้ชื่อ field แบบ "Front-Foiled" แต่ interface ใช้ front_foiled
  const allMeds: MedicineSummary[] = ((medsData || []) as Record<string, unknown>[])
    .map(row => ({
      medicine_list_id: row.medicine_list_id as number,
      resident_id: row.resident_id as number,
      generic_name: row.generic_name as string | null,
      brand_name: row.brand_name as string | null,
      take_tab: row.take_tab as number | null,
      str: row.str as string | null,
      unit: row.unit as string | null,
      front_foiled: row['Front-Foiled'] as string | null,
      back_foiled: row['Back-Foiled'] as string | null,
      front_nude: row['Front-Nude'] as string | null,
      back_nude: row['Back-Nude'] as string | null,
      status: row.status as string | null,
      prn: row.prn as boolean | null,
      before_after: row.BeforeAfter as string[] | null,
      bldb: row.BLDB as string[] | null,
      type_of_time: row.typeOfTime as string | null,
      every_hr: row.every_hr as number | null,
      days_of_week: row.DaysOfWeek as string[] | null,
      first_med_history_on_date: row.first_med_history_on_date as string | null,
      last_med_history_off_date: row.last_med_history_off_date as string | null,
    }))

  // กรองด้วย shouldTakeOnDate — ตรวจ PRN, status, date range, meal match, ความถี่
  const filteredMeds = allMeds.filter(med =>
    shouldTakeOnDate(
      med,
      selectedDate,
      mealInfo?.beforeAfter || undefined,
      mealInfo?.bldb,
    )
  )

  console.log(`[batch] Item ${item.id}: Found ${filteredMeds.length} medicines for meal ${meal}`)

  // ============================================
  // Step 3: สร้าง reference image entries
  // ============================================
  // 2C → Front-Foiled + Back-Foiled (รูปแผงยา ด้านหน้า/หลัง)
  // 3C → Front-Nude + Back-Nude (รูปเม็ดยา ด้านหน้า/หลัง)
  const referenceEntries: { url: string; medIndex: number; side: 'หน้า' | 'หลัง' }[] = []
  filteredMeds.forEach((med, i) => {
    if (photo_type === '2C') {
      if (med.front_foiled) referenceEntries.push({ url: med.front_foiled, medIndex: i, side: 'หน้า' })
      if (med.back_foiled) referenceEntries.push({ url: med.back_foiled, medIndex: i, side: 'หลัง' })
    } else {
      if (med.front_nude) referenceEntries.push({ url: med.front_nude, medIndex: i, side: 'หน้า' })
      if (med.back_nude) referenceEntries.push({ url: med.back_nude, medIndex: i, side: 'หลัง' })
    }
  })

  const referenceUrls = referenceEntries.map(e => e.url)

  // ถ้าไม่มี reference image เลย → skip (ไม่ต้อง verify เพราะไม่มีอะไรเทียบ)
  if (referenceUrls.length === 0) {
    console.log(`[batch] Item ${item.id}: No reference images, skipping verification`)

    // กัน duplicate: ลบ record เก่าถ้ามี (กรณี retry)
    await client.from('A_Med_AI_Verification')
      .delete()
      .eq('med_log_id', med_log_id)
      .eq('photo_type', photo_type)

    const { error: skipInsertError } = await client.from('A_Med_AI_Verification').insert({
      med_log_id,
      photo_type,
      resident_id,
      calendar_date,
      meal,
      nursinghome_id,
      ai_status: 'skipped',
      staff_image_url: photo_url,
      ai_model: null,
      processing_time_ms: Date.now() - startTime,
      error_message: 'ไม่มีรูปอ้างอิง (reference image) ในฐานข้อมูล',
    })

    // ถ้า insert skipped record ไม่สำเร็จ → throw เพื่อให้ markError จับ
    if (skipInsertError) {
      throw new Error(`Failed to save skipped record: ${skipInsertError.message}`)
    }

    return // จบ — ถือว่า "สำเร็จ" (skipped)
  }

  // ============================================
  // Step 4: ดาวน์โหลดรูปทั้งหมดเป็น base64
  // ============================================
  console.log(`[batch] Item ${item.id}: Downloading ${referenceUrls.length} reference images + 1 staff photo`)

  // ดาวน์โหลด staff photo + reference images พร้อมกัน (parallel)
  const [staffImage, ...referenceImages] = await Promise.all([
    downloadImageAsBase64(photo_url),
    ...referenceUrls.map(url => downloadImageAsBase64(url)),
  ])

  if (!staffImage) {
    throw new Error('Failed to download staff photo')
  }

  // กรองเฉพาะ reference ที่ดาวน์โหลดสำเร็จ (เก็บ index เดิมเพื่อ map กลับไปหา entry)
  const validRefPairs: { img: { base64: string; mimeType: string }; entry: typeof referenceEntries[0] }[] = []
  referenceImages.forEach((img, i) => {
    if (img !== null) {
      validRefPairs.push({ img, entry: referenceEntries[i] })
    }
  })

  if (validRefPairs.length === 0) {
    throw new Error('Failed to download any reference images')
  }

  // ============================================
  // Step 5: ส่ง Gemini Vision เปรียบเทียบรูป
  // ============================================
  // ใช้ gemini-2.5-flash — เร็วและถูกกว่า pro แต่ accuracy ดีพอสำหรับ verification
  const model = ai.getGenerativeModel({
    model: 'gemini-2.5-flash',
    generationConfig: {
      responseMimeType: 'application/json', // บังคับให้ตอบเป็น JSON
      temperature: 0.2, // ต่ำเพื่อผลที่เสถียร (ไม่ creative เกินไป)
    },
  })

  // สร้าง prompt จาก medicines ที่กรองแล้ว
  const prompt = buildPrompt(filteredMeds, photo_type)

  // สร้าง content parts: prompt + reference images (พร้อม label) + staff photo
  // deno-lint-ignore no-explicit-any
  const parts: any[] = [
    { text: prompt },
  ]

  // เพิ่ม reference images พร้อม label (ระบุชื่อยา + ด้านหน้า/หลัง)
  validRefPairs.forEach(({ img, entry }) => {
    const med = filteredMeds[entry.medIndex]
    const medName = med?.brand_name || med?.generic_name || `ยาตัวที่ ${entry.medIndex + 1}`

    parts.push({ text: `\n--- รูปอ้างอิง (Reference) ยา: ${medName} — ด้าน${entry.side} ---` })
    parts.push({
      inlineData: {
        mimeType: img.mimeType,
        data: img.base64,
      },
    })
  })

  // เพิ่ม staff photo เป็น part สุดท้าย
  parts.push({ text: '\n--- รูปจริง (Staff Photo) ---' })
  parts.push({
    inlineData: {
      mimeType: staffImage.mimeType,
      data: staffImage.base64,
    },
  })

  console.log(`[batch] Item ${item.id}: Sending to Gemini (${validRefPairs.length} refs + 1 staff)...`)

  // เรียก Gemini Vision API
  const result = await model.generateContent(parts)
  const responseText = result.response.text()

  console.log(`[batch] Item ${item.id}: Gemini response: ${responseText.substring(0, 200)}...`)

  // ============================================
  // Step 6: Parse JSON response จาก Gemini
  // ============================================
  let analysis: AIAnalysis
  try {
    analysis = JSON.parse(responseText)
  } catch {
    // Gemini อาจตอบมี text อื่นปนมา → ลอง extract JSON ออกมา
    const jsonMatch = responseText.match(/\{[\s\S]*\}/)
    if (jsonMatch) {
      analysis = JSON.parse(jsonMatch[0])
    } else {
      throw new Error('Failed to parse AI response as JSON')
    }
  }

  // Validate + clamp confidence score ให้อยู่ในช่วง 0-100
  const confidenceScore = typeof analysis.confidence_score === 'number'
    ? Math.max(0, Math.min(100, analysis.confidence_score))
    : 50

  // กำหนด ai_status จาก confidence score
  // pass: มั่นใจ ≥80% + จำนวนตรง + หน้าตาตรง
  // flag: ต่ำกว่านั้น → ต้องให้คนตรวจซ้ำ
  let aiStatus: string
  if (confidenceScore >= 80 && analysis.pill_count_match && analysis.pill_appearance_match) {
    aiStatus = 'pass'
  } else {
    aiStatus = 'flag'
  }

  const processingTime = Date.now() - startTime

  // ============================================
  // Step 7: บันทึกผลลง A_Med_AI_Verification
  // ============================================
  // กัน duplicate: ถ้า retry แล้วรอบก่อนเคย insert สำเร็จ → ลบของเก่าก่อน
  // กรณี: item ถูก claim → insert สำเร็จ → crash ก่อน markDone → stale reset → retry → insert ซ้ำ
  await client.from('A_Med_AI_Verification')
    .delete()
    .eq('med_log_id', med_log_id)
    .eq('photo_type', photo_type)

  // Schema เหมือน verify-med-photo เป๊ะ
  const { error: insertError } = await client.from('A_Med_AI_Verification').insert({
    med_log_id,
    photo_type,
    resident_id,
    calendar_date,
    meal,
    nursinghome_id,
    ai_status: aiStatus,
    confidence_score: confidenceScore,
    ai_analysis: {
      pill_count_match: analysis.pill_count_match ?? true,
      pill_appearance_match: analysis.pill_appearance_match ?? true,
      packaging_match: analysis.packaging_match ?? true,
      expected_count: analysis.expected_count ?? null,
      detected_count: analysis.detected_count ?? null,
      concerns: Array.isArray(analysis.concerns) ? analysis.concerns : [],
      summary: analysis.summary || '',
    },
    reference_image_urls: referenceUrls,
    staff_image_url: photo_url,
    ai_model: 'gemini-2.5-flash',
    processing_time_ms: processingTime,
  })

  if (insertError) {
    throw new Error(`Failed to save result: ${insertError.message}`)
  }

  console.log(`[batch] Item ${item.id}: Done — status=${aiStatus}, confidence=${confidenceScore}, time=${processingTime}ms`)
}

// ============================================
// Main Handler — Batch Processor
// ============================================
// pg_cron เรียก endpoint นี้ทุก 2 นาที
// 1. Claim items จาก queue (atomic — ไม่มี race condition)
// 2. Process ทีละ item (sequential — ง่ายต่อ debug, ไม่ overload Gemini)
// 3. อัพเดท status แต่ละ item เป็น 'done' หรือ 'error'
// 4. Return สรุป batch result

Deno.serve(async (req) => {
  // CORS handling สำหรับ browser requests (admin dashboard อาจเรียกโดยตรง)
  if (req.method === 'OPTIONS') {
    return corsResponse()
  }

  const batchStart = Date.now()
  let processed = 0
  let success = 0
  let errors = 0

  try {
    // ============================================
    // 1. Claim items จาก queue
    // ============================================
    // claim_verification_queue RPC ใช้ FOR UPDATE SKIP LOCKED
    // → ถ้ามี worker อื่นกำลัง process items อยู่ จะข้ามไป (ไม่ซ้ำกัน)
    const { data: items, error: claimError } = await claimQueueItems(supabase, 5)

    if (claimError) {
      throw claimError
    }

    // ถ้าไม่มี items ใน queue → จบเลย (pg_cron จะเรียกใหม่ในอีก 2 นาที)
    if (!items || items.length === 0) {
      console.log('[batch] Queue empty, nothing to process')
      return jsonResponse({ message: 'Queue empty', processed: 0 })
    }

    console.log(`[batch] Claimed ${items.length} items from queue`)

    // ============================================
    // 2. Process ทีละ item (sequential)
    // ============================================
    // ทำไม sequential ไม่ parallel?
    // - Gemini API มี rate limit → parallel อาจโดน 429
    // - ง่ายต่อ debug (log ชัดเจนว่า item ไหน fail)
    // - ถ้า 1 item fail ไม่กระทบ items อื่น (try-catch แต่ละ item)
    for (const item of items) {
      try {
        // Process: ดึงยา → กรอง → ดาวน์โหลดรูป → Gemini → บันทึก
        await processOneItem(supabase, genAI, item)

        // สำเร็จ → อัพเดท queue status เป็น 'done'
        await markDone(supabase, item.id)
        success++
      } catch (err: unknown) {
        const errorMessage = err instanceof Error ? err.message : String(err)
        console.error(`[batch] Error processing item ${item.id}:`, errorMessage)

        // ล้มเหลว → อัพเดท queue status เป็น 'error' พร้อม error message
        // pg_cron จะ retry items ที่ error (ถ้า retry_count < 3)
        await markError(supabase, item.id, errorMessage)
        errors++
      }
      processed++
    }

    // ============================================
    // 3. สรุปผล batch
    // ============================================
    const duration = Date.now() - batchStart
    console.log(`[batch] Done: processed=${processed} success=${success} errors=${errors} duration=${duration}ms`)

    return jsonResponse({
      processed,
      success,
      errors,
      duration_ms: duration,
    })

  } catch (err: unknown) {
    // Critical error (เช่น claim RPC fail) → return 500
    const errorMessage = err instanceof Error ? err.message : String(err)
    console.error('[batch] Critical error:', errorMessage)

    return jsonResponse({ error: errorMessage }, 500)
  }
})
