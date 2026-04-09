// ============================================
// Edge Function: verify-med-photo
// ============================================
// ใช้ Gemini Vision เปรียบเทียบรูป reference จาก med_DB กับรูปที่ staff ถ่าย
// เรียกจาก Database Trigger (tr_verify_med_photo) อัตโนมัติเมื่อมีรูปใหม่ใน A_Med_logs
// ผลลัพธ์บันทึกลง A_Med_AI_Verification → แสดงบนหน้า Medicine Review (admin)
//
// Flow:
//   1. รับ med_log_id, resident_id, meal, photo_type, photo_url, date, nursinghome_id
//   2. ดึง active meds ของ resident + meal จาก medicine_summary view
//   3. กรองยาด้วย shouldTakeOnDate() (date range + frequency + วันในสัปดาห์)
//   4. ดึงรูป reference จาก med_DB (Front-Foiled สำหรับ 2C, Front-Nude สำหรับ 3C)
//   5. ส่งรูป reference + รูป staff → Gemini Flash Vision
//   6. บันทึกผลลง A_Med_AI_Verification

import { createClient } from 'npm:@supabase/supabase-js@2'
import { GoogleGenerativeAI } from 'npm:@google/generative-ai'

// ============================================
// Supabase + Gemini clients
// ============================================
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!)

// ============================================
// Types
// ============================================

interface RequestBody {
  med_log_id: number
  resident_id: number
  meal: string           // เช่น 'ก่อนอาหารเช้า'
  photo_type: '2C' | '3C'
  photo_url: string      // URL รูปที่ staff ถ่าย (จาก Supabase Storage)
  date: string           // YYYY-MM-DD
  nursinghome_id: number
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
// Prompt สำหรับ Gemini Vision
// ============================================
// สั่งให้ Gemini เปรียบเทียบรูป reference กับรูป staff
// lenient กับ lighting/มุม แต่ strict กับจำนวนและประเภทยา

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
async function downloadImageAsBase64(url: string): Promise<{ base64: string; mimeType: string } | null> {
  try {
    const response = await fetch(url)
    if (!response.ok) {
      console.error(`Failed to download image: ${response.status} ${url}`)
      return null
    }

    const arrayBuffer = await response.arrayBuffer()
    const uint8Array = new Uint8Array(arrayBuffer)

    // แปลงเป็น base64 string
    let binary = ''
    for (let i = 0; i < uint8Array.length; i++) {
      binary += String.fromCharCode(uint8Array[i])
    }
    const base64 = btoa(binary)

    // ดึง MIME type จาก response header
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
// ดู logic เต็มใน: irene-training-admin/app/(dashboard)/medicine/review/types.ts

// Map วันภาษาไทย → index (0=อาทิตย์, 1=จันทร์, ...)
const THAI_DAY_TO_INDEX: Record<string, number> = {
  // ชื่อเต็ม
  'อาทิตย์': 0,
  'จันทร์': 1,
  'อังคาร': 2,
  'พุธ': 3,
  'พฤหัส': 4,
  'พฤหัสบดี': 4,
  'ศุกร์': 5,
  'เสาร์': 6,
  // ชื่อย่อ (จาก Flutter add_medicine เก่า)
  'อา': 0, 'จ': 1, 'อ': 2, 'พ': 3, 'พฤ': 4, 'ศ': 5, 'ส': 6,
}

// Parse PostgreSQL array format "{val1,val2}" → string[]
// medicine_summary view อาจส่ง array มาเป็น string format นี้
function parseStringArray(value: unknown): string[] {
  if (Array.isArray(value)) return value as string[]
  if (typeof value === 'string') {
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
  // 1. ข้าม PRN (ยาตามอาการ)
  if (med.prn) return false

  // 2. ต้อง status = 'on'
  if (med.status !== 'on') return false

  // 3. Normalize วันที่เป็น YYYY-MM-DD (ตัด timezone)
  const checkDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate())

  // 4. ตรวจ date range
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

  // 5. ตรวจ BeforeAfter filter
  const medBeforeAfter = parseStringArray(med.before_after)
  if (filterBeforeAfter && medBeforeAfter.length > 0) {
    if (!medBeforeAfter.includes(filterBeforeAfter)) return false
  }

  // 6. ตรวจ BLDB filter
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
    // ไม่มี start date → pass ทุกวัน
    return true
  }

  if (typeOfTime === 'วัน') {
    // ทุก N วัน: จำนวนวันหาร everyHr ลงตัว
    const days = daysBetween(startNorm, checkDate)
    return days >= 0 && days % everyHr === 0
  }

  if (typeOfTime === 'สัปดาห์') {
    // ทุก N สัปดาห์ + เฉพาะวันที่กำหนด
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
// Main Handler
// ============================================

Deno.serve(async (req) => {
  // CORS handling
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
      },
    })
  }

  const startTime = Date.now()

  try {
    // ============================================
    // 1. Parse request body
    // ============================================
    const body: RequestBody = await req.json()
    const { med_log_id, resident_id, meal, photo_type, photo_url, date, nursinghome_id } = body

    console.log(`[verify-med-photo] Starting: resident=${resident_id}, meal=${meal}, type=${photo_type}, date=${date}`)

    // Validate required fields
    if (!med_log_id || !resident_id || !meal || !photo_type || !photo_url || !date || !nursinghome_id) {
      return new Response(JSON.stringify({
        error: 'Missing required fields: med_log_id, resident_id, meal, photo_type, photo_url, date, nursinghome_id'
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    // ============================================
    // 2. ดึง active meds ของ resident จาก medicine_summary
    // ============================================
    // ดึงยาทั้งหมดของ resident (ไม่ filter status ที่ DB เพราะ shouldTakeOnDate จะตรวจเอง)
    const { data: medsData, error: medsError } = await supabase
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
      console.error('[verify-med-photo] Error fetching medicines:', medsError)
      throw new Error(`Failed to fetch medicines: ${medsError.message}`)
    }

    // ============================================
    // 2b. กรองยาด้วย shouldTakeOnDate (ตรงกับ webapp logic เป๊ะ)
    // ============================================
    // แปลง meal → beforeAfter + bldb สำหรับ filter
    const mealMappings: Record<string, { beforeAfter: string; bldb: string }> = {
      'ก่อนอาหารเช้า': { beforeAfter: 'ก่อนอาหาร', bldb: 'เช้า' },
      'หลังอาหารเช้า': { beforeAfter: 'หลังอาหาร', bldb: 'เช้า' },
      'ก่อนอาหารกลางวัน': { beforeAfter: 'ก่อนอาหาร', bldb: 'กลางวัน' },
      'หลังอาหารกลางวัน': { beforeAfter: 'หลังอาหาร', bldb: 'กลางวัน' },
      'ก่อนอาหารเย็น': { beforeAfter: 'ก่อนอาหาร', bldb: 'เย็น' },
      'หลังอาหารเย็น': { beforeAfter: 'หลังอาหาร', bldb: 'เย็น' },
      'ก่อนนอน': { beforeAfter: '', bldb: 'ก่อนนอน' },
    }

    const mealInfo = mealMappings[meal]
    if (!mealInfo) {
      console.warn(`[verify-med-photo] Unknown meal: ${meal}, checking all medicines`)
    }

    // Parse วันที่สำหรับ shouldTakeOnDate
    const selectedDate = new Date(date + 'T00:00:00')

    // แปลง raw data → MedicineSummary แล้วกรองด้วย shouldTakeOnDate
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

    console.log(`[verify-med-photo] Found ${filteredMeds.length} medicines for meal ${meal}`)

    // ============================================
    // 3. ดึงรูป reference จาก med_DB (ทั้งหน้า + หลัง)
    // ============================================
    // 2C → Front-Foiled + Back-Foiled (แผงยา)
    // 3C → Front-Nude + Back-Nude (เม็ดยา)
    // สร้าง array ของ { url, medIndex, side } เพื่อ track ว่ารูปไหนเป็นของยาตัวไหน ด้านไหน
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

    // ถ้าไม่มี reference image เลย → skip (ไม่ต้อง verify)
    if (referenceUrls.length === 0) {
      console.log('[verify-med-photo] No reference images found, skipping verification')

      await supabase.from('A_Med_AI_Verification').insert({
        med_log_id,
        photo_type,
        resident_id,
        calendar_date: date,
        meal,
        nursinghome_id,
        ai_status: 'skipped',
        staff_image_url: photo_url,
        ai_model: null,
        processing_time_ms: Date.now() - startTime,
        error_message: 'ไม่มีรูปอ้างอิง (reference image) ในฐานข้อมูล',
      })

      return new Response(JSON.stringify({ ai_status: 'skipped', reason: 'No reference images' }), {
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    // ============================================
    // 4. ดาวน์โหลดรูปทั้งหมดเป็น base64
    // ============================================
    console.log(`[verify-med-photo] Downloading ${referenceUrls.length} reference images + 1 staff photo`)

    // ดาวน์โหลดรูป reference + staff พร้อมกัน
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
    // 5. ส่ง Gemini Vision เปรียบเทียบ
    // ============================================
    const model = genAI.getGenerativeModel({
      model: 'gemini-2.5-flash',
      generationConfig: {
        responseMimeType: 'application/json',
        temperature: 0.2, // ต่ำเพื่อผลที่เสถียร
      },
    })

    // สร้าง prompt
    const prompt = buildPrompt(filteredMeds, photo_type)

    // สร้าง content parts: prompt + reference images + staff photo
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

    // เพิ่ม staff photo
    parts.push({ text: '\n--- รูปจริง (Staff Photo) ---' })
    parts.push({
      inlineData: {
        mimeType: staffImage.mimeType,
        data: staffImage.base64,
      },
    })

    console.log(`[verify-med-photo] Sending to Gemini (${validRefPairs.length} refs + 1 staff)...`)

    // เรียก Gemini Vision
    const result = await model.generateContent(parts)
    const responseText = result.response.text()

    console.log(`[verify-med-photo] Gemini response: ${responseText.substring(0, 200)}...`)

    // ============================================
    // 6. Parse JSON response
    // ============================================
    let analysis: AIAnalysis
    try {
      analysis = JSON.parse(responseText)
    } catch {
      // ลอง extract JSON จาก response
      const jsonMatch = responseText.match(/\{[\s\S]*\}/)
      if (jsonMatch) {
        analysis = JSON.parse(jsonMatch[0])
      } else {
        throw new Error('Failed to parse AI response as JSON')
      }
    }

    // Validate + clamp confidence score
    const confidenceScore = typeof analysis.confidence_score === 'number'
      ? Math.max(0, Math.min(100, analysis.confidence_score))
      : 50

    // กำหนด ai_status จาก confidence score
    let aiStatus: string
    if (confidenceScore >= 80 && analysis.pill_count_match && analysis.pill_appearance_match) {
      aiStatus = 'pass'
    } else {
      aiStatus = 'flag'
    }

    const processingTime = Date.now() - startTime

    // ============================================
    // 7. บันทึกผลลง A_Med_AI_Verification
    // ============================================
    const { error: insertError } = await supabase.from('A_Med_AI_Verification').insert({
      med_log_id,
      photo_type,
      resident_id,
      calendar_date: date,
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
      console.error('[verify-med-photo] Error saving result:', insertError)
      throw new Error(`Failed to save result: ${insertError.message}`)
    }

    console.log(`[verify-med-photo] Done: status=${aiStatus}, confidence=${confidenceScore}, time=${processingTime}ms`)

    return new Response(JSON.stringify({
      ai_status: aiStatus,
      confidence_score: confidenceScore,
      concerns: analysis.concerns || [],
      summary: analysis.summary || '',
      processing_time_ms: processingTime,
    }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })

  } catch (err: unknown) {
    const errorMessage = err instanceof Error ? err.message : String(err)
    console.error('[verify-med-photo] Error:', errorMessage)

    // พยายามบันทึก error ลง DB (ถ้ามี med_log_id)
    try {
      const body = await req.clone().json().catch(() => null)
      if (body?.med_log_id) {
        await supabase.from('A_Med_AI_Verification').insert({
          med_log_id: body.med_log_id,
          photo_type: body.photo_type || '2C',
          resident_id: body.resident_id || 0,
          calendar_date: body.date || new Date().toISOString().slice(0, 10),
          meal: body.meal || '',
          nursinghome_id: body.nursinghome_id || 0,
          ai_status: 'error',
          staff_image_url: body.photo_url || '',
          ai_model: 'gemini-2.5-flash',
          processing_time_ms: Date.now() - startTime,
          error_message: errorMessage,
        })
      }
    } catch (saveErr) {
      console.error('[verify-med-photo] Failed to save error record:', saveErr)
    }

    return new Response(JSON.stringify({
      error: errorMessage,
      ai_status: 'error',
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
