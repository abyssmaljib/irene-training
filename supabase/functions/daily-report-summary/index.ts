// daily-report-summary/index.ts
// รวม 3 bubble (เช็คลิสต์ + นัดหมาย + ยา) เป็น 1 carousel ต่อ 1 resident
// ส่งทีเดียวเป็น LINE Flex Carousel — ญาติ swipe ซ้าย-ขวาดูได้
// ⚠️ DEV MODE: ส่งไปห้อง dev เท่านั้น
//
// Bubble builders copy-paste จาก:
//   - checklist-shift-summary (buildBubble + categorizeTasks)
//   - calendar-upcoming-summary (buildAppointmentBubble + relativeDate)
//   - med-daily-summary (buildMedBubble + renderVerificationLines)

import { pushToLine } from '../_shared/line-flex.ts'

const LINE_TOKEN = Deno.env.get('LINE_CHANNEL_ACCESS_TOKEN') || ''
const DEV_LINE_GROUP_ID = 'C57c1c76d5500d7eb9d617e1590734290'

// ============================================
// Production Rollout — ส่งห้อง LINE จริงเฉพาะ residents ใน list นี้
// คนที่ไม่อยู่ใน list → ส่ง DEV group เหมือนเดิม
// เพิ่มคนใหม่: แค่เพิ่ม resident_id เข้า Set
// ============================================
const PRODUCTION_RESIDENTS = new Set([104, 159, 169, 173, 310]) // คุณสุริยะ เชิญศิริ, คุณสุชญา อักษรนิติ, คุณถเวช เก็งวินิจ, คุณยุทธศาสตร์ ธีรพิริยะ, คุณงามตา รักษาจิต

// ============================================
// Types (รวมจากทั้ง 3 functions)
// ============================================

// --- Checklist types ---
interface TaskRow {
  status: string | null
  expected_time: string
  title: string
  task_type: string
  done_by: string | null
  note: string | null
  problem_type: string | null
  resolution_status: string | null
  resolution_note: string | null
  resolved_by_name: string | null
  resident_id: number
  resident_name: string
  confirm_image: string | null  // URL รูปยืนยันการทำงาน
  completed_at: string | null   // เวลาที่ทำเสร็จจริง (datetime string)
  ticket_title: string | null   // ชื่อ ticket (ถ้าหัวหน้าเวรสร้างไว้)
  ticket_status: string | null  // สถานะ ticket
  task_log_id: number           // id ของ task log
}

interface CatItem {
  title: string; time: string; status: string | null; note: string | null
  problem_type?: string | null; resolution_status?: string | null
  resolution_note?: string | null; resolved_by?: string | null
  has_photo?: boolean; completed_at?: string | null
  confirm_image_url?: string | null  // URL รูปยืนยัน — ให้ญาติกดดูได้
  ticket_title?: string | null; ticket_status?: string | null
}

interface CatGroup { taskType: string; emoji: string; items: CatItem[] }

// --- Calendar types ---
interface AppointmentRow {
  calendar_id: number
  title: string
  description: string | null
  date_bkk: string          // 'YYYY-MM-DD HH24:MI:SS'
  resident_id: number
  resident_name: string
  is_npo: boolean | null
  is_require_na: boolean | null   // ต้องมี NA ไปด้วย
  is_document_prepared: boolean | null  // เตรียมเอกสารแล้ว (legacy)
  sbar_status: string | null           // สถานะเอกสาร SBAR: 'draft' | 'finalized' | null
  is_relative_paid: boolean | null      // ญาติจ่ายมัดจำแล้ว
  transport_status: string | null       // สถานะรถ: not_needed / pending / booked
  has_slip: boolean                     // มีใบนัด (url ไม่เป็น null)
  hospital: string | null
  staff_name: string | null  // พนักงานที่ assign จาก DD_Record_Clock
}

// --- Med types ---
interface MedLogRow {
  log_id: number
  meal: string
  resident_id: number
  resident_name: string
  has_2c_photo: boolean       // มีรูปจัดยา
  has_3c_photo: boolean       // มีรูปเสิร์ฟยา
  qc_2c_mark: string | null   // หัวหน้าเวรตรวจจัดยา: "รูปตรง" / "รูปไม่ตรง" / null
  qc_3c_mark: string | null   // หัวหน้าเวรตรวจเสิร์ฟ: "รูปตรง" / "รูปไม่ตรง" / null
  served_by: string | null     // ชื่อคนเสิร์ฟ
  med_count: number            // จำนวนรายการยา
}

interface AIVerRow {
  med_log_id: number
  photo_type: string           // '2C' | '3C'
  ai_status: string            // 'pass' | 'flag' | 'pending' | 'skipped'
  confidence_score: number | null
}

interface MedErrorRow {
  meal: string
  resident_id: number
  reason: string | null
  reply_nurse_mark: string | null
}

interface IncidentRow {
  source_id: number           // med_log_id
  title: string | null
  description: string | null  // เช่น "ให้��าฆ่าเชื้อซ้ำ"
  severity: string | null     // LEVEL_1..5
  status: string | null       // PENDING, RESOLVED, etc.
}

// --- PT (กายภาพบำบัด) types ---
interface PTRow {
  soap_id: number
  resident_id: number
  resident_name: string
  date_bkk: string           // 'YYYY-MM-DD'
  progression_2_times: string // AI comparison markdown
  share_token: string         // UUID for public link
}

// --- Vitals types ---
interface VitalRow {
  vital_id: number
  resident_id: number
  resident_name: string
  shift: string              // 'เวรเช้า' | 'เวรดึก'
  user_nickname: string | null
  temp: number | null
  pr: number | null
  rr: number | null
  sbp: number | null
  dbp: number | null
  o2: number | null
  dtx: number | null
  defecation: boolean
  constipation: number | null
  input_ml: number | null
  output_count: string | null
  napkin: number | null
  vital_signs_status: string | null
  general_report: string | null
  time_bkk: string           // 'HH:MI'
  date_bkk: string           // 'DD/MM'
  ai_comment: string | null  // จาก vitalsign_sent_queue
  queue_status: string | null // SENT, ผิดปกติ, etc.
  is_full_report: boolean
}

interface MealSummary {
  meal: string
  mealShort: string
  emoji: string
  medCount: number
  // จัดยา (2C)
  has2cPhoto: boolean
  ai2cStatus: string | null       // pass / flag / pending / skipped / null
  ai2cConfidence: number | null
  qc2cMark: string | null         // หัวหน้าเวร: "รูปตรง" / "รูปไม่ตรง" / null
  // เสิร์ฟ (3C)
  has3cPhoto: boolean
  ai3cStatus: string | null
  ai3cConfidence: number | null
  qc3cMark: string | null
  // Error
  hasError: boolean
  errorReason: string | null
  errorReply: string | null
  // Incident (จาก B_Incident — source_type = med_log)
  hasIncident: boolean
  incidentDesc: string | null   // เช่น "ให้ยาฆ่าเชื้อซ้ำ"
  incidentSeverity: string | null
  incidentStatus: string | null
  // Staff
  servedBy: string | null
}

// ============================================
// Constants — Checklist (exact copy จาก checklist-shift-summary)
// ============================================

// taskType หลัง refactor (2026-04-05)
const TASK_TYPE_ORDER = [
  'เสิร์ฟอาหาร', 'ทานอาหารเสร็จ', 'Feed', 'อาหารว่าง', 'น้ำ',
  'ดูแลร่างกาย', 'พลิกตะแคงตัว', 'หัตถการ', 'กายภาพ',
  'กิจกรรม', 'ยานอกมื้อหลัก', 'ขับถ่าย',
  'ชั่งน้ำหนัก', 'วัดส่วนสูง', 'DTX', 'Insulin', 'สัญญาณชีพ v/s',
  'ความปลอดภัย', 'งานในโซน', 'อื่นๆ',
]

const TASK_TYPE_EMOJI: Record<string, string> = {
  'เสิร์ฟอาหาร': '🍽️', 'ทานอาหารเสร็จ': '🥄', 'Feed': '🍶', 'อาหารว่าง': '🥛', 'น้ำ': '💧',
  'ดูแลร่างกาย': '🧹', 'พลิกตะแคงตัว': '🔁', 'หัตถการ': '💉', 'กายภาพ': '🦿',
  'กิจกรรม': '🎵', 'ยานอกมื้อหลัก': '💊', 'ขับถ่าย': '🚽',
  'ชั่งน้ำหนัก': '⚖️', 'วัดส่วนสูง': '📏', 'DTX': '🩸', 'Insulin': '💉', 'สัญญาณชีพ v/s': '🩺',
  'ความปลอดภัย': '🛡️', 'งานในโซน': '🏠', 'อื่นๆ': '📋',
}

const PROBLEM_LABEL: Record<string, string> = {
  'patient_refused': 'คนไข้ปฏิเสธ', 'busy_with_other': 'ติดภารกิจอื่น',
  'not_needed': 'ไม่จำเป็น', 'not_eating': 'ไม่ทานอาหาร',
  'behavior_issue': 'ปัญหาพฤติกรรม', 'out_of_supply': 'ของหมด', 'other': 'อื่นๆ',
}

// ตัด emoji ออกจาก title เพื่อจัดกลุ่ม/แสดงผลสะอาด
const stripEmoji = (s: string) => s.replace(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}\u{200D}]/gu, '').trim()

// ============================================
// Constants — Med (exact copy จาก med-daily-summary)
// ============================================

// ลำดับมื้อยาสำหรับแสดงผล
const MEAL_ORDER = [
  'ก่อนอาหารเช้า', 'หลังอาหารเช้า',
  'ก่อนอาหารกลางวัน', 'หลังอาหารกลางวัน',
  'ก่อนอาหารเย็น', 'หลังอาหารเย็น',
  'ก่อนนอน',
]

// Emoji สำหรับมื้อยา
const MEAL_EMOJI: Record<string, string> = {
  'ก่อนอาหารเช้า': '🌅', 'หลังอาหารเช้า': '🌅',
  'ก่อนอาหารกลางวัน': '🌤️', 'หลังอาหารกลางวัน': '🌤️',
  'ก่อนอาหารเย็น': '🌆', 'หลังอาหารเย็น': '🌆',
  'ก่อนนอน': '🌙',
}

// ชื่อย่อมื้อสำหรับ bubble (กระชับ)
const MEAL_SHORT: Record<string, string> = {
  'ก่อนอาหารเช้า': 'ก่อนเช้า',
  'หลังอาหารเช้า': 'หลังเช้า',
  'ก่อนอาหารกลางวัน': 'ก่อนเที่ยง',
  'หลังอาหารกลางวัน': 'หลังเที่ยง',
  'ก่อนอาหารเย็น': 'ก่อนเย็น',
  'หลังอาหารเย็น': 'หลังเย็น',
  'ก่อนนอน': 'ก่อนนอน',
}

// ============================================
// Constants — Vitals
// ============================================

// SUBJECT_MAP และ scaleBar ถูกลบแล้ว — scale assessment ย้ายไป checklist task completion

// ============================================
// Bubble: หน้าปก (Cover) — แสดงชื่อ วันที่ และสรุปว่ามีอะไรบ้าง
// ============================================

function buildCoverBubble(
  residentName: string,
  dateLabel: string,
  sections: string[],
  picUrl?: string | null,
  timeRangeLabel?: string,
): Record<string, unknown> {
  const c: Record<string, unknown>[] = []

  // หัวข้อ
  c.push({ type: 'text', text: '📋 สรุปประจำวัน', weight: 'bold', size: 'xxl', color: '#1a1a1a' })
  c.push({ type: 'text', text: dateLabel, size: 'lg', weight: 'bold', color: '#E67E22', margin: 'md', wrap: true })
  // ช่วงเวลาที่ครอบคลุม
  if (timeRangeLabel) {
    c.push({ type: 'text', text: timeRangeLabel, size: 'sm', color: '#888888', margin: 'sm', wrap: true })
  }

  // ชื่อผู้พักอาศัย
  c.push({ type: 'separator', margin: 'xl' })
  c.push({ type: 'text', text: `คุณ${residentName}`, weight: 'bold', size: 'xxl', color: '#3D58B8', margin: 'xl' })
  c.push({ type: 'separator', margin: 'xl' })

  // รายการ sections ที่มี
  for (const s of sections) {
    c.push({ type: 'text', text: s, size: 'lg', color: '#333333', margin: 'lg' })
  }

  // คำแนะนำ
  c.push({ type: 'text', text: '👉 เลื่อนไปทางขวาเพื่อดู', size: 'md', color: '#999999', margin: 'xxl' })

  const bubble: Record<string, unknown> = {
    type: 'bubble', size: 'mega',
    body: { type: 'box', layout: 'vertical', spacing: 'sm', paddingAll: '20px', contents: c },
    footer: IRENEOS_FOOTER,
  }

  // รูป profile ผู้พักอาศัย (ถ้ามี)
  if (picUrl) {
    bubble.hero = {
      type: 'image', url: picUrl,
      size: 'full', aspectMode: 'cover', aspectRatio: '1:1',
    }
  }

  return bubble
}

// ============================================
// Bubble: สัญญาณชีพประจำวัน (รวมทุก record ไล่ตาม timeline)
// ============================================

function buildVitalsBubble(
  residentName: string,
  dateLabel: string,
  vitals: VitalRow[],
): Record<string, unknown> | null {
  if (vitals.length === 0) return null

  const c: Record<string, unknown>[] = []

  // Header
  c.push({ type: 'text', text: '🩺 สัญญาณชีพประจำวัน', weight: 'bold', size: 'lg', color: '#1a1a1a' })
  c.push({ type: 'text', text: dateLabel, size: 'sm', color: '#999999', margin: 'xs' })
  c.push({ type: 'text', text: residentName, size: 'sm', color: '#666666', margin: 'xs' })
  c.push({ type: 'separator', margin: 'lg' })

  // สรุปจำนวนครั้ง
  const fullCount = vitals.filter(v => v.is_full_report).length
  const spotCount = vitals.filter(v => !v.is_full_report).length
  const anyAbnormal = vitals.some(v => v.vital_signs_status !== 'สัญญาณชีพล่าสุดปกติ')
  const summaryEmoji = anyAbnormal ? '⚠️' : '✅'
  const summaryColor = anyAbnormal ? '#F39C12' : '#27AE60'
  let summaryText = `${summaryEmoji} วัด ${vitals.length} ครั้ง`
  if (fullCount > 0) summaryText += ` (สรุปเวร ${fullCount}`
  if (spotCount > 0) summaryText += fullCount > 0 ? `, ระหว่างวัน ${spotCount})` : ` (ระหว่างวัน ${spotCount})`
  else if (fullCount > 0) summaryText += ')'
  if (anyAbnormal) summaryText += ' — พบค่าผิดปกติ'
  // Summary bar — พื้นหลังเขียวอ่อนถ้าปกติ, เหลืองอ่อนถ้ามีปัญหา
  c.push({
    type: 'box', layout: 'vertical', margin: 'lg', paddingAll: '10px',
    cornerRadius: '8px', backgroundColor: anyAbnormal ? '#FFF8E1' : '#F0FFF0',
    contents: [{ type: 'text', text: summaryText, size: 'sm', weight: 'bold', color: summaryColor, wrap: true }],
  })

  // ไล่แต่ละ record ตาม timeline — wrap ใน box ที่มีพื้นหลังสี
  for (const v of vitals) {
    const shiftIcon = v.shift === 'เวรเช้า' ? '☀️' : v.shift === 'เวรดึก' ? '🌙' : '🕐'
    const shiftText = v.shift !== '-' ? v.shift : 'ระหว่างวัน'
    const isNormal = v.vital_signs_status === 'สัญญาณชีพล่าสุดปกติ'
    const timeColor = isNormal ? '#333333' : '#E74C3C'
    // พื้นหลัง: ปกติ = เทาอ่อน, ผิดปกติ = ชมพูอ่อน
    const bgColor = isNormal ? '#F7F7F7' : '#FFF0F0'

    // สร้าง contents สำหรับ record นี้
    const rc: Record<string, unknown>[] = []

    rc.push({
      type: 'text',
      text: `${shiftIcon} ${v.date_bkk} ${v.time_bkk} น. — ${shiftText}`,
      size: 'sm', weight: 'bold', color: timeColor,
    })

    if (!isNormal) {
      rc.push({ type: 'text', text: `⚠️ ${v.vital_signs_status}`, size: 'sm', color: '#E74C3C', margin: 'sm' })
    }

    const vals: string[] = []
    if (v.temp) vals.push(`T${v.temp}`)
    if (v.pr) vals.push(`P${v.pr}`)
    if (v.rr) vals.push(`R${v.rr}`)
    if (v.sbp && v.dbp) vals.push(`BP${v.sbp}/${v.dbp}`)
    if (v.o2) vals.push(`O₂${v.o2}%`)
    if (v.dtx) vals.push(`DTX${v.dtx}`)
    if (vals.length > 0) {
      rc.push({ type: 'text', text: vals.join('  '), size: 'sm', color: '#555555', margin: 'sm', wrap: true })
    }

    if (v.is_full_report) {
      const io: string[] = []
      if (v.input_ml && v.input_ml > 0) io.push(`💧${v.input_ml}ml`)
      if (v.output_count && v.output_count !== '-') io.push(`🚽${v.output_count}ครั้ง`)
      if (v.defecation) io.push('💩ถ่ายแล้ว')
      if (v.constipation && v.constipation > 0) io.push(`⏳ท้องผูก${v.constipation}วัน`)
      if (v.napkin && v.napkin > 0) io.push(`🩲ผ้าอ้อม${v.napkin}`)
      if (io.length > 0) {
        rc.push({ type: 'text', text: io.join('  '), size: 'sm', color: '#777777', wrap: true, margin: 'sm' })
      }

      // Scale/rating assessment ย้ายไป checklist task completion แล้ว
      // ไม่แสดงใน vital sign bubble อีกต่อไป

      if (v.general_report && v.general_report !== '-' && v.general_report.trim()) {
        const report = v.general_report.trim().replace(/^-\s*(อื่นๆ\s*:\s*)?/, '').trim()
        rc.push({ type: 'text', text: `📝 ${report}`, size: 'sm', color: '#888888', wrap: true, margin: 'sm' })
      }
    }

    if (v.user_nickname) {
      rc.push({ type: 'text', text: `👤 ${v.user_nickname}`, size: 'sm', color: '#999999', margin: 'sm' })
    }

    // Wrap ใน box ที่มีพื้นหลังสี + มุมโค้ง
    c.push({
      type: 'box', layout: 'vertical', margin: 'lg', paddingAll: '12px',
      cornerRadius: '8px', backgroundColor: bgColor,
      contents: rc,
    })
  }

  return {
    type: 'bubble', size: 'mega',
    body: { type: 'box', layout: 'vertical', spacing: 'sm', paddingAll: '16px', contents: c },
    footer: IRENEOS_FOOTER,
  }
}

// ============================================
// Bubble 1: เช็คลิสต์ — EXACT copy จาก checklist-shift-summary
// (categorizeTasks + buildBubble — full category list, time grid, problem details)
// ============================================

function categorizeTasks(tasks: TaskRow[]) {
  const groups = new Map<string, CatGroup>()
  const staffSet = new Set<string>()
  let totalDone = 0, totalProblem = 0, totalPending = 0, totalRefer = 0, totalWithPhoto = 0

  for (const t of tasks) {
    const time = t.expected_time.substring(11, 16)
    if (t.done_by) staffSet.add(t.done_by)
    if (t.status === 'complete') {
      totalDone++
      // นับ task ที่มีรูปยืนยัน
      if (t.confirm_image) totalWithPhoto++
    }
    else if (t.status === 'problem') totalProblem++
    else if (t.status === 'refer') totalRefer++
    else totalPending++

    const type = t.task_type || 'อื่นๆ'
    if (!groups.has(type)) groups.set(type, { taskType: type, emoji: TASK_TYPE_EMOJI[type] || '📋', items: [] })
    // เวลาทำจริง (HH:MM) จาก completed_at
    const doneTime = t.completed_at ? t.completed_at.substring(11, 16) : null

    groups.get(type)!.items.push({
      title: t.title, time, status: t.status, note: t.note,
      problem_type: t.problem_type, resolution_status: t.resolution_status,
      resolution_note: t.resolution_note, resolved_by: t.resolved_by_name,
      has_photo: !!t.confirm_image, completed_at: doneTime,
      confirm_image_url: t.confirm_image || null,
      ticket_title: t.ticket_title || null, ticket_status: t.ticket_status || null,
    })
  }

  const sorted = [...groups.values()].sort((a, b) => {
    const ia = TASK_TYPE_ORDER.indexOf(a.taskType), ib = TASK_TYPE_ORDER.indexOf(b.taskType)
    return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib)
  })

  return { categories: sorted, totalDone, totalProblem, totalPending, totalRefer, totalWithPhoto, total: tasks.length, staffNames: [...staffSet] }
}

function buildChecklistBubble(
  name: string, shiftLabel: string, shiftEmoji: string,
  dateLabel: string, tasks: TaskRow[],
): Record<string, unknown> | null {
  if (tasks.length === 0) return null

  const data = categorizeTasks(tasks)

  // ข้าม resident ที่ทุก task เป็น refer (อยู่ รพ → ไม่ต้องส่ง)
  if (data.totalRefer === data.total) return null

  const c: Record<string, unknown>[] = []

  // Header
  c.push({ type: 'text', text: `${shiftEmoji} เช็คลิสต์${shiftLabel}`, weight: 'bold', size: 'lg', color: '#1a1a1a' })
  c.push({ type: 'text', text: dateLabel, size: 'sm', color: '#999999', margin: 'xs' })
  c.push({ type: 'text', text: name, size: 'sm', color: '#666666', margin: 'xs' })
  c.push({ type: 'separator', margin: 'lg' })

  // สรุป
  const act = data.total - data.totalRefer
  if (data.totalRefer === data.total) {
    c.push({ type: 'text', text: `🏠 ไม่อยู่ที่ศูนย์ — ${data.totalRefer} รายการ`, size: 'sm', weight: 'bold', color: '#3498DB', margin: 'lg' })
  } else {
    const ok = data.totalProblem === 0 && data.totalPending === 0
    const emoji = ok ? '✅' : data.totalProblem > 0 ? '⚠️' : '🔄'
    const color = ok ? '#27AE60' : data.totalProblem > 0 ? '#F39C12' : '#3498DB'
    let txt = `${emoji} สำเร็จ ${data.totalDone}/${act}`
    if (data.totalProblem > 0) txt += `  ❌ ติดปัญหา ${data.totalProblem}`
    if (data.totalPending > 0) txt += `  ⏳ รอ ${data.totalPending}`
    if (data.totalRefer > 0) txt += `  🏠 ไม่อยู่ ${data.totalRefer}`
    // Summary bar — พื้นหลังเขียวอ่อนถ้าปกติ, เหลืองอ่อนถ้ามีปัญหา
    const summaryContents: Record<string, unknown>[] = [
      { type: 'text', text: txt, size: 'sm', weight: 'bold', color, wrap: true },
    ]
    if (data.totalWithPhoto > 0) {
      summaryContents.push({ type: 'text', text: `📸 ยืนยันด้วยรูป ${data.totalWithPhoto}/${data.totalDone}`, size: 'sm', color: '#888888', margin: 'sm', wrap: true })
    }
    c.push({
      type: 'box', layout: 'vertical', margin: 'lg', paddingAll: '10px',
      cornerRadius: '8px', backgroundColor: ok ? '#F0FFF0' : data.totalProblem > 0 ? '#FFF8E1' : '#F0F4FF',
      contents: summaryContents,
    })
  }

  // หมวด
  for (const g of data.categories) {
    c.push({ type: 'separator', margin: 'lg' })
    const cnt = g.items.length > 1 ? ` (${g.items.length} ครั้ง)` : ''
    c.push({ type: 'text', text: `${g.emoji} ${g.taskType}${cnt}`, size: 'sm', weight: 'bold', color: '#333333', margin: 'lg' })

    const uniq = new Set(g.items.map(i => stripEmoji(i.title)))

    // ใช้ time grid เฉพาะเมื่อ title เหมือนกันทั้งหมด AND ไม่มี problem (เพราะ problem ต้องแสดงเหตุผล)
    const hasProblem = g.items.some(i => i.status === 'problem')
    if (uniq.size === 1 && g.items.length > 1 && !hasProblem) {
      c.push({ type: 'text', text: [...uniq][0], size: 'sm', color: '#777777', margin: 'sm' })
      // ถ้ามีรูป 📸 มาก → ลด chunk เหลือ 3 ต่อบรรทัดเพื่อไม่ให้ล้น
      const hasPhotos = g.items.some(it => it.has_photo)
      const chunkSize = hasPhotos ? 3 : 4
      for (let i = 0; i < g.items.length; i += chunkSize) {
        const line = g.items.slice(i, i + chunkSize).map(it => {
          const ic = it.status === 'complete' ? '☑' : it.status === 'problem' ? '✗' : it.status === 'refer' ? '🏠' : '○'
          const photo = it.has_photo ? '📸' : ''
          return `${ic} ${it.time}${photo}`
        }).join('  ')
        // ถ้า items ทั้ง chunk เป็น complete หมด → เขียว, มี pending → เทา
        const chunkItems = g.items.slice(i, i + chunkSize)
        const allComplete = chunkItems.every(it => it.status === 'complete')
        c.push({ type: 'text', text: line, size: 'sm', color: allComplete ? '#27AE60' : '#999999', margin: 'sm' })
      }
    } else {
      for (const it of g.items) {
        const ic = it.status === 'complete' ? '☑' : it.status === 'problem' ? '✗' : it.status === 'refer' ? '🏠' : '○'
        const col = it.status === 'problem' ? '#E74C3C' : it.status === 'refer' ? '#3498DB' : it.status === 'complete' ? '#27AE60' : '#999999'
        const photo = it.has_photo ? ' 📸' : ''

        if (it.status === 'problem') {
          // Task ที่ติดปัญหา → wrap ใน box พื้นหลังชมพูอ่อน
          const pc: Record<string, unknown>[] = []
          pc.push({ type: 'text', text: `${ic} ${stripEmoji(it.title)} ${it.time}${photo}`, size: 'sm', color: col, wrap: true })
          const rl = PROBLEM_LABEL[it.problem_type || ''] || ''
          const dt = it.note ? `: ${it.note}` : ''
          pc.push({ type: 'text', text: `เหตุผล: ${rl ? rl + dt : (it.note || 'ไม่ระบุ')}`, size: 'sm', color: '#E74C3C', wrap: true, margin: 'sm' })
          if (it.resolution_status && it.resolution_status !== 'dismiss') {
            let rd = it.resolution_status
            if (it.resolution_note) { const p = it.resolution_note.split('|'); rd = p.length > 1 ? p.slice(1).join('|') : p[0] }
            pc.push({ type: 'text', text: `จัดการ: ${rd}${it.resolved_by ? ` (${it.resolved_by})` : ''}`, size: 'sm', color: '#F39C12', wrap: true, margin: 'sm' })
          }
          if (it.ticket_title) {
            const tStatus = it.ticket_status === 'resolved' ? '✅ แก้ไขแล้ว' : it.ticket_status === 'in_progress' ? '🔄 กำลังดำเนินการ' : '📌 เปิดอยู่'
            pc.push({ type: 'text', text: `🎫 ตั๋วติดตาม: ${tStatus}`, size: 'sm', color: '#8E44AD', wrap: true, margin: 'sm' })
          }
          c.push({
            type: 'box', layout: 'vertical', margin: 'sm', paddingAll: '10px',
            cornerRadius: '8px', backgroundColor: '#FFF0F0',
            contents: pc,
          })
        } else {
          // Task ปกติ (complete, refer, pending)
          c.push({ type: 'text', text: `${ic} ${stripEmoji(it.title)} ${it.time}${photo}`, size: 'sm', color: col, wrap: true, margin: 'sm' })
          if (it.status === 'refer' && it.note) {
            c.push({ type: 'text', text: `    ${it.note}`, size: 'sm', color: '#3498DB', wrap: true, margin: 'none' })
          }
        }
      }
    }
  }

  c.push({ type: 'separator', margin: 'lg' })
  c.push({ type: 'text', text: `ผู้ดูแล: ${data.staffNames.join(', ') || '-'}`, size: 'sm', color: '#888888', margin: 'md', wrap: true })

  return {
    type: 'bubble', size: 'mega',
    body: { type: 'box', layout: 'vertical', spacing: 'sm', paddingAll: '16px', contents: c },
    footer: IRENEOS_FOOTER,
  }
}

// ============================================
// Bubble 2: นัดหมาย — EXACT copy จาก calendar-upcoming-summary
// (relativeDate + buildAppointmentBubble — full status checklist)
// ============================================

function relativeDate(dateStr: string, today: string): string {
  // dateStr = 'YYYY-MM-DD HH24:MI:SS', today = 'YYYY-MM-DD'
  const d = dateStr.substring(0, 10)
  const t = new Date(today + 'T00:00:00Z')
  const tomorrow = new Date(t.getTime() + 86400000).toISOString().substring(0, 10)
  const dayAfter = new Date(t.getTime() + 2 * 86400000).toISOString().substring(0, 10)

  // format วันที่ เช่น "25 มี.ค."
  const months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.']
  const day = parseInt(d.substring(8, 10))
  const month = months[parseInt(d.substring(5, 7)) - 1]
  const time = dateStr.substring(11, 16) // HH:MM
  const timeStr = time === '00:00' ? '' : ` ${time}` // ซ่อนเวลาถ้าเป็น 00:00 (ไม่ได้ระบ��เวลา)

  if (d === today) return `วันนี้ · ${day} ${month}${timeStr}`
  if (d === tomorrow) return `พรุ่งนี้ · ${day} ${month}${timeStr}`
  if (d === dayAfter) return `มะรืนนี้ · ${day} ${month}${timeStr}`
  return `${day} ${month}${timeStr}`
}

function buildAppointmentBubble(
  residentName: string,
  appointments: AppointmentRow[],
  today: string,
): Record<string, unknown> | null {
  if (appointments.length === 0) return null

  const c: Record<string, unknown>[] = []

  // Header
  c.push({
    type: 'text', text: '📅 นัดหมายที่กำลังจะถึง',
    weight: 'bold', size: 'lg', color: '#1a1a1a',
  })
  c.push({
    type: 'text', text: residentName,
    size: 'sm', color: '#666666', margin: 'xs',
  })
  c.push({ type: 'separator', margin: 'lg' })

  // แต่ละนัดหมาย (สูงสุด 3 ครั้ง)
  const circled = ['❶', '❷', '❸']

  for (let i = 0; i < appointments.length; i++) {
    const appt = appointments[i]
    const dateLabel = relativeDate(appt.date_bkk, today)

    // ถ้าเป็น "วันนี้" หรือ "พรุ่งนี้" ใช้สีเข้มกว่า
    const d = appt.date_bkk.substring(0, 10)
    const isUrgent = d === today
    const dateColor = isUrgent ? '#E74C3C' : '#333333'

    // ── วันที่ ──
    c.push({
      type: 'text',
      text: `${circled[i]} ${dateLabel}`,
      size: 'sm', weight: 'bold', color: dateColor, margin: i === 0 ? 'lg' : 'xl',
    })

    // ── ชื่อนัดหมาย ──
    // ตัดคำฟุ่มเฟือยออก เช่น **จ่ายมัดจำน้องแล้ว
    const cleanTitle = appt.title.replace(/\*+[^*]*$/g, '').trim() || appt.title
    c.push({
      type: 'text', text: `   ${cleanTitle}`,
      size: 'sm', color: '#555555', wrap: true, margin: 'sm',
    })

    // ── รายละเอียด (ถ้ามี) ──
    if (appt.description && appt.description.trim()) {
      // ตัดให้สั้น — แสดงแค่ 2 บรรทัดแรก ไม่เกิน 80 chars
      const desc = appt.description.trim().split('\n').slice(0, 2).join(' ').substring(0, 80)
      c.push({
        type: 'text', text: `   📝 ${desc}`,
        size: 'sm', color: '#888888', wrap: true, margin: 'sm',
      })
    }

    // ── โรงพยาบาล (ถ้ามีและไม่ซ้ำกับ title) ──
    if (appt.hospital && !cleanTitle.includes(appt.hospital)) {
      c.push({
        type: 'text', text: `   🏥 ${appt.hospital}`,
        size: 'sm', color: '#0277BD', margin: 'sm',
      })
    }

    // ── Checklist สถานะเตรียมตัว ──
    // รวมทุกสถานะเป็น 1 กล่อง — ✅ พร้อม / ⏳ รอ / ❌ ยังไม่ได้
    const checks: string[] = []

    // NPO
    checks.push(appt.is_npo ? '⚠️ งดน้ำงดอาหาร' : '✅ ไม่ต้อง NPO')

    // พนักงาน
    if (appt.staff_name) {
      checks.push(`👤 ${appt.staff_name}`)
    } else if (appt.is_require_na) {
      checks.push('👤 กำลังจัดหาพนักงาน')
    }

    // รถพยาบาล
    if (appt.transport_status === 'booked') checks.push('🚑 จองรถแล้ว')
    else if (appt.transport_status === 'pending') checks.push('🚑 รอจองรถ')

    // เอกสารพบแพทย์
    if (appt.sbar_status === 'finalized') checks.push('📄 เอกสารพร้อม')
    else if (appt.sbar_status === 'draft') checks.push('📄 เอกสารร่าง')
    else checks.push('📄 ยังไม่มีเอกสาร')

    // ใบนัด
    checks.push(appt.has_slip ? '📋 ได้ใบนัดแล้ว' : '📋 รอใบนัด')

    // มัดจำ
    if (appt.is_relative_paid) checks.push('💰 จ่ายมัดจำแล้ว')

    c.push({
      type: 'text',
      text: `   ${checks.join('  ')}`,
      size: 'sm', color: '#888888', wrap: true, margin: 'sm',
    })
  }

  return {
    type: 'bubble', size: 'mega',
    body: {
      type: 'box', layout: 'vertical', spacing: 'sm', paddingAll: '16px',
      contents: c,
    },
    footer: IRENEOS_FOOTER,
  }
}

// ============================================
// Bubble 3: ยา — EXACT copy จาก med-daily-summary
// (renderVerificationLines + buildMedBubble — full AI + head nurse, incident from B_Incident)
// ============================================

// สร้าง 1-2 บรรทัดแสดงผลการตรวจ (AI + หัวหน้าเวร)
function renderVerificationLines(
  label: string,
  hasPhoto: boolean,
  aiStatus: string | null,
  aiConf: number | null,
  qcMark: string | null,
  hasIncident = false,  // ถ้ามี incident → หน.เวร "แก้ปัญหาเรียบร้อย" แทน "ยืนยันว่าถูกต้อง"
): string[] {
  const lines: string[] = []

  // ไม่มีรูป → แสดงแค่บรรทัดเดียว
  if (!hasPhoto) {
    lines.push(`   ${label}: 📷 ยังไม่ได้ถ่ายรูป`)
    return lines
  }

  // AI ตรวจ (แสดงเสมอถ้ามี)
  if (aiStatus === 'pass') {
    lines.push(`   ${label} 🤖 AI มั่นใจ ${aiConf ?? '-'}% ✅`)
  } else if (aiStatus === 'flag') {
    lines.push(`   ${label} 🤖 AI ไม่มั่นใจ ${aiConf ?? '-'}% ⚠️`)
  } else if (aiStatus === 'pending') {
    lines.push(`   ${label} 🤖 AI กำลังตรวจ ⏳`)
  } else if (aiStatus === 'skipped') {
    // AI skip → ไม่ต้องแสดงบรรทัด AI
  } else {
    // ไม่มี AI record → รอตรวจ
    lines.push(`   ${label} 🤖 รอ AI ตรวจ ⏳`)
  }

  // หัวหน้าเวรตรวจ (แสดงเสม���ถ้ามี)
  if (qcMark) {
    const ok = ['รูปตรง', 'ถูกต้อง', 'ตำแหน่งสลับ'].includes(qcMark)
    if (hasIncident) {
      // มี incident → หน.เวร แก้ปัญหาเรียบร้อย
      lines.push(`   ${label} 👩‍⚕️ หน.เวร แก้ปัญหาเรียบร้อย ☑️`)
    } else {
      lines.push(`   ${label} 👩‍⚕️ หน.เวร ${ok ? 'ยืนยันว่าถูกต้อง ✅' : qcMark + ' ❌'}`)
    }
  }

  // มีรูปแต่ไม่มี AI ไม่มี QC
  if (lines.length === 0) {
    lines.push(`   ${label}: ⏳ รอตรวจ`)
  }

  return lines
}

function buildMedBubble(
  residentName: string,
  date: string,
  meals: MealSummary[],
  medShareToken?: string | null,
): Record<string, unknown> | null {
  if (meals.length === 0) return null

  const c: Record<string, unknown>[] = []

  // Header
  c.push({
    type: 'text', text: '💊 สรุปยาประจำวัน',
    weight: 'bold', size: 'lg', color: '#1a1a1a',
  })
  c.push({ type: 'text', text: date, size: 'sm', color: '#999999', margin: 'xs' })
  c.push({ type: 'text', text: residentName, size: 'sm', color: '#666666', margin: 'xs' })
  c.push({ type: 'separator', margin: 'lg' })

  // สรุปภาพรวม
  const totalMeals = meals.length
  const allOk = meals.every(m =>
    (m.qc2cMark === 'รูปตรง' || m.qc2cMark === 'ถูกต้อง' || m.qc2cMark === 'ตำแหน่งสลับ' || m.ai2cStatus === 'pass') &&
    (m.qc3cMark === 'รูปตรง' || m.qc3cMark === 'ถูกต้อง' || m.qc3cMark === 'ตำแหน่งสลับ' || m.ai3cStatus === 'pass')
    && !m.hasIncident  // ถ้ามี incident = ไม่ถือว่า allOk
  )
  const hasProblems = meals.some(m => m.hasError || m.hasIncident)
  const hasFlags = meals.some(m => m.ai2cStatus === 'flag' || m.ai3cStatus === 'flag')

  const statusEmoji = allOk ? '✅' : hasProblems ? '❌' : hasFlags ? '⚠️' : '🔄'
  const statusColor = allOk ? '#27AE60' : hasProblems ? '#E74C3C' : hasFlags ? '#F39C12' : '#3498DB'
  const statusText = allOk
    ? `${statusEmoji} ตรวจยาครบ ${totalMeals} มื้อ — ถูกต้องทั้งหมด`
    : hasProblems
      ? `${statusEmoji} ตรวจยา ${totalMeals} มื้อ — พบปัญหา`
      : hasFlags
        ? `${statusEmoji} ตรวจยา ${totalMeals} มื้อ — รอตรวจสอบเพิ่ม`
        : `${statusEmoji} ตรวจยา ${totalMeals} มื้อ`

  // Summary bar — พื้นหลังเขียวอ่อนถ้า OK, เหลืองอ่อนถ้ามีปัญหา
  c.push({
    type: 'box', layout: 'vertical', margin: 'lg', paddingAll: '10px',
    cornerRadius: '8px', backgroundColor: allOk ? '#F0FFF0' : hasProblems ? '#FFF0F0' : '#FFF8E1',
    contents: [{ type: 'text', text: statusText, size: 'sm', weight: 'bold', color: statusColor, wrap: true }],
  })

  // แต่ละมื้อ — wrap ใน box ที่มีพื้นหลังสี
  for (const m of meals) {
    // หัวหน้าเวรยืนยันถูกต้อง → เขียว (override AI flag), incident/error จริง → ชมพู, อื่นๆ → เทา
    const qcConfirmed = ['รูปตรง', 'ถูกต้อง', 'ตำแหน่งสลับ'].includes(m.qc2cMark || '') || ['รูปตรง', 'ถูกต้อง', 'ตำแหน่งสลับ'].includes(m.qc3cMark || '')
    const mealHasRealProblem = m.hasIncident || m.hasError || m.qc2cMark === 'รูปไม่ตรง' || m.qc3cMark === 'รูปไม่ตรง'
    const mealColor = mealHasRealProblem ? '#E74C3C' : '#333333'
    const bgColor = mealHasRealProblem ? '#FFF0F0' : qcConfirmed ? '#F0FFF0' : '#F7F7F7'

    const mc: Record<string, unknown>[] = []

    mc.push({
      type: 'text',
      text: `${m.emoji} ${m.mealShort}${m.medCount > 0 ? ` (${m.medCount} รายการ)` : ''}`,
      size: 'sm', weight: 'bold', color: mealColor,
    })

    for (const line of renderVerificationLines('จัด', m.has2cPhoto, m.ai2cStatus, m.ai2cConfidence, m.qc2cMark, m.hasIncident)) {
      const color = line.includes('✅') ? '#555555' : line.includes('❌') ? '#E74C3C' : line.includes('⚠️') ? '#F39C12' : '#888888'
      mc.push({ type: 'text', text: line, size: 'sm', color, wrap: true, margin: 'sm' })
    }

    for (const line of renderVerificationLines('เสิร์ฟ', m.has3cPhoto, m.ai3cStatus, m.ai3cConfidence, m.qc3cMark, m.hasIncident)) {
      const color = line.includes('✅') ? '#555555' : line.includes('❌') ? '#E74C3C' : line.includes('⚠️') ? '#F39C12' : '#888888'
      mc.push({ type: 'text', text: line, size: 'sm', color, wrap: true, margin: 'sm' })
    }

    if (m.hasError) {
      const reason = m.errorReason && m.errorReason !== '-' ? m.errorReason : ''
      const reply = m.errorReply || ''
      let errText = '🔔 พบปัญหา'
      if (reason) errText += `: ${reason}`
      if (reply) errText += ` → ${reply}`
      mc.push({ type: 'text', text: errText, size: 'sm', color: '#E74C3C', wrap: true, margin: 'sm' })
    }

    if (m.hasIncident) {
      mc.push({ type: 'text', text: `⚠️ ${m.incidentDesc || 'มีรายงานความผิดพลาด'}`, size: 'sm', color: '#C60031', wrap: true, margin: 'sm' })
    }

    if (m.servedBy) {
      mc.push({ type: 'text', text: `👤 ${m.servedBy}`, size: 'sm', color: '#999999', margin: 'sm' })
    }

    c.push({
      type: 'box', layout: 'vertical', margin: 'lg', paddingAll: '12px',
      cornerRadius: '8px', backgroundColor: bgColor,
      contents: mc,
    })
  }

  // Footer: ปุ่มดูรายการยา (ถ้ามี token) + IreneOS banner
  const medUrl = medShareToken ? `${ADMIN_BASE_URL}/reports/medicine/${medShareToken}` : null
  const medFooter = medUrl ? {
    type: 'box', layout: 'vertical', spacing: 'sm', paddingAll: '0px',
    contents: [
      {
        type: 'box', layout: 'vertical', paddingAll: '12px', contents: [{
          type: 'button', style: 'primary', color: '#3D58B8', height: 'sm',
          action: { type: 'uri', label: 'ดูรายการยาปัจจุบัน', uri: medUrl },
        }],
      },
      {
        type: 'image', url: 'https://amthgthvrxhlxpttioxu.supabase.co/storage/v1/object/public/testupload/outsideImage/ireneos-report-banner-v6.png',
        size: 'full', aspectMode: 'fit', aspectRatio: '8:3',
      },
    ],
  } : IRENEOS_FOOTER

  return {
    type: 'bubble', size: 'mega',
    body: { type: 'box', layout: 'vertical', spacing: 'sm', paddingAll: '16px', contents: c },
    footer: medFooter,
  }
}

// ============================================
// Bubble: กายภาพบำบัด — สรุปพัฒนาการจาก AI (progression_2_times)
// + ปุ่มลิงก์ไปดูรายงานฉบับเต็ม (ai_summary)
// ============================================

const ADMIN_BASE_URL = Deno.env.get('ADMIN_BASE_URL') || 'https://ireneos.vercel.app'

// ป้าย IreneOS — ใช้เป็น footer ทุก bubble
const IRENEOS_FOOTER = {
  type: 'box', layout: 'vertical', paddingAll: '0px',
  contents: [{
    type: 'image', url: 'https://amthgthvrxhlxpttioxu.supabase.co/storage/v1/object/public/testupload/outsideImage/ireneos-report-banner-v6.png',
    size: 'full', aspectMode: 'fit', aspectRatio: '8:3',
  }],
}

// แปลง markdown progression_2_times → LINE Flex text elements
function markdownToFlexContents(md: string): Record<string, unknown>[] {
  const lines = md.split('\n')
  const contents: Record<string, unknown>[] = []

  for (const line of lines) {
    const trimmed = line.trim()
    if (!trimmed) continue

    // ข้าม # หัวข้อหลัก (ใช้ header ของ bubble แทน)
    if (trimmed.startsWith('# ') && !trimmed.startsWith('## ')) continue

    // ข้าม ℹ️ บรรทัดแรก และ "- ผู้ป่วย:" (ซ้ำกับ header)
    if (trimmed.startsWith('ℹ️') || trimmed.startsWith('- ผู้ป่วย:')) continue

    // ## หัวข้อ → bold text สีเข้ม + separator
    if (trimmed.startsWith('## ')) {
      const heading = trimmed.replace(/^##\s*/, '')
      contents.push({ type: 'separator', margin: 'lg' })
      contents.push({ type: 'text', text: heading, size: 'sm', weight: 'bold', color: '#333333', margin: 'lg', wrap: true })
      continue
    }

    // - bullet → text ปกติ
    if (trimmed.startsWith('- ')) {
      const bullet = trimmed.replace(/^-\s*/, '')
      // ลบ bold markdown (**text**) ออก
      const clean = bullet.replace(/\*\*/g, '')
      contents.push({ type: 'text', text: `• ${clean}`, size: 'sm', color: '#555555', margin: 'sm', wrap: true })
      continue
    }
  }

  return contents
}

function buildPTBubble(
  residentName: string,
  dateLabel: string,
  pt: PTRow,
): Record<string, unknown> {
  const c: Record<string, unknown>[] = []

  // Header
  c.push({ type: 'text', text: '🏃‍♂️ สรุปกายภาพบำบัด', weight: 'bold', size: 'lg', color: '#1a1a1a' })
  c.push({ type: 'text', text: dateLabel, size: 'sm', color: '#999999', margin: 'xs' })
  c.push({ type: 'text', text: residentName, size: 'sm', color: '#666666', margin: 'xs' })

  // แปลง markdown → flex contents
  const bodyContents = markdownToFlexContents(pt.progression_2_times)
  c.push(...bodyContents)

  // ลิงก์ไปดูรายงานฉบับเต็ม (ai_summary)
  const reportUrl = `${ADMIN_BASE_URL}/reports/soap/${pt.share_token}?view=report`

  return {
    type: 'bubble', size: 'mega',
    body: { type: 'box', layout: 'vertical', spacing: 'sm', paddingAll: '16px', contents: c },
    footer: {
      type: 'box', layout: 'vertical', spacing: 'sm', paddingAll: '0px',
      contents: [
        {
          type: 'box', layout: 'vertical', paddingAll: '12px', contents: [{
            type: 'button', style: 'primary', color: '#3D58B8', height: 'sm',
            action: { type: 'uri', label: 'อ่านรายงานฉบับเต็ม', uri: reportUrl },
          }],
        },
        {
          type: 'image', url: 'https://amthgthvrxhlxpttioxu.supabase.co/storage/v1/object/public/testupload/outsideImage/ireneos-report-banner-v6.png',
          size: 'full', aspectMode: 'fit', aspectRatio: '8:3',
        },
      ],
    },
  }
}

// ============================================
// Main Handler (เหมือนเดิม — multi-query + carousel per resident)
// ============================================
// CORS headers สำหรับ preview mode (เรียกจาก admin dashboard)
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const dateOverride = url.searchParams.get('date')
    const previewMode = url.searchParams.get('preview') === 'true'
    // ต้องส่ง send_production=true ถึงจะส่งห้อง LINE จริง (cron job ส่ง param นี้)
    // ถ้าไม่มี → ทุกคนส่ง dev group หมด (ปลอดภัยสำหรับ manual test)
    const sendProduction = url.searchParams.get('send_production') === 'true'
    // ส่งเฉพาะ resident เดียว (สำหรับ debug/test)
    const residentFilter = url.searchParams.get('resident_id') ? Number(url.searchParams.get('resident_id')) : null

    // สรุปทั้งวัน: เที่ยงคืนเมื่อวาน – เที่ยงคืนที่ผ่านมา
    // cron เรียกตอน 08:00 → สรุปข้อมูลของเมื่อวาน
    const now = new Date()
    const bkk = new Date(now.getTime() + 7 * 3600000)
    const today = bkk.toISOString().substring(0, 10)
    // date ที่จะสรุป = เมื่อวาน (หรือ override ได้)
    const reportDate = dateOverride || new Date(new Date(today + 'T00:00:00Z').getTime() - 86400000).toISOString().substring(0, 10)

    // Time range: 00:00 – 24:00 ของ reportDate (เวลาไทย)
    const startTime = `${reportDate} 00:00:00+07`
    const endTime = `${reportDate} 23:59:59+07`
    const shiftLabel = 'ประจำวัน'
    const shiftEmoji = '📋'

    // format วันที่แบบไทย เช่น "26 มี.ค. 2026"
    const months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.']
    const d = parseInt(reportDate.substring(8, 10)), m = months[parseInt(reportDate.substring(5, 7)) - 1]
    // คำนวณ relative label เช่น "(เมื่อวานนี้)", "(วันนี้)"
    const diffDays = Math.round((new Date(today + 'T00:00:00Z').getTime() - new Date(reportDate + 'T00:00:00Z').getTime()) / 86400000)
    const relLabel = diffDays === 0 ? ' (วันนี้)' : diffDays === 1 ? ' (เมื่อวานนี้)' : diffDays > 1 ? ` (${diffDays} วันก่อน)` : ''
    const dateLabel = `ของวันที่ ${d} ${m} ${reportDate.substring(0, 4)}${relLabel}`
    // ช่วงเวลาที่ครอบคลุม: 00:00 ของ reportDate ถึง 00:00 ของวันถัดไป
    const nextDay = new Date(new Date(reportDate + 'T00:00:00Z').getTime() + 86400000)
    const nd = parseInt(nextDay.toISOString().substring(8, 10)), nm = months[parseInt(nextDay.toISOString().substring(5, 7)) - 1]
    const timeRangeLabel = `ข้อมูลตั้งแต่ 00:00 น. (${d} ${m}) ถึง 00:00 น. (${nd} ${nm})`
    const medDateLabel = dateLabel

    console.log(`Daily report: date=${reportDate} (00:00-24:00)`)

    const dbUrl = Deno.env.get('SUPABASE_DB_URL')
    if (!dbUrl) throw new Error('SUPABASE_DB_URL not set')
    const { Pool } = await import('https://deno.land/x/postgres@v0.19.3/mod.ts')
    const pool = new Pool(dbUrl, 3, true)
    const conn = await pool.connect()

    // ===== Query ทั้งหมด =====
    let taskRows: TaskRow[], apptRows: AppointmentRow[], medLogs: MedLogRow[], aiVers: AIVerRow[], medErrors: MedErrorRow[], incidents: IncidentRow[], vitalRows: VitalRow[], ptRows: PTRow[]

    try {
      // 1. Checklist tasks
      const taskResult = await conn.queryObject<TaskRow>(`
        SELECT tl.status, to_char(tl."ExpectedDateTime" AT TIME ZONE 'Asia/Bangkok', 'YYYY-MM-DD HH24:MI:SS') as expected_time,
          t.title, COALESCE(NULLIF(t."taskType", ''), 'อื่นๆ') as task_type,
          ui.nickname as done_by, tl."Descript" as note, tl.problem_type,
          tl.resolution_status, tl.resolution_note, ui_r.nickname as resolved_by_name,
          t.resident_id::int, r."i_Name_Surname" as resident_name,
          tl."confirmImage" as confirm_image,
          to_char(tl.completed_at AT TIME ZONE 'Asia/Bangkok', 'YYYY-MM-DD HH24:MI:SS') as completed_at,
          tk."ticket_Title" as ticket_title, tk.status as ticket_status,
          tl.id::int as task_log_id
        FROM "A_Task_logs_ver2" tl
        JOIN "A_Tasks" t ON tl.task_id = t.id
        JOIN residents r ON t.resident_id = r.id
        LEFT JOIN user_info ui ON tl.completed_by = ui.id
        LEFT JOIN user_info ui_r ON tl.resolved_by = ui_r.id
        LEFT JOIN "B_Ticket" tk ON tk.source_type = 'task_log' AND tk.source_id = tl.id
        WHERE r.s_status = 'Stay' AND r."i_Name_Surname" NOT LIKE 'งาน%'
          AND tl."ExpectedDateTime" >= $1::timestamptz AND tl."ExpectedDateTime" < $2::timestamptz
        ORDER BY r."i_Name_Surname", tl."ExpectedDateTime"
      `, [startTime, endTime])
      taskRows = taskResult.rows as TaskRow[]

      // 2. Appointments (upcoming)
      const apptResult = await conn.queryObject<AppointmentRow>(`
        SELECT c.id as calendar_id, c."Title" as title, c."Description" as description,
          to_char(c."dateTime" AT TIME ZONE 'Asia/Bangkok', 'YYYY-MM-DD HH24:MI:SS') as date_bkk,
          c.resident_id::int, r."i_Name_Surname" as resident_name,
          c."isNPO" as is_npo, c."isRequireNA" as is_require_na,
          c."isDocumentPrepared" as is_document_prepared, c."isRelativePaidIn" as is_relative_paid,
          COALESCE(c.transport_status, 'not_needed') as transport_status,
          (c.url IS NOT NULL AND c.url != '') as has_slip,
          c.hospital, ui.nickname as staff_name,
          dvs.status as sbar_status
        FROM "C_Calendar" c
        JOIN residents r ON c.resident_id = r.id
        LEFT JOIN "DD_Record_Clock" dd ON dd.calendar_appointment_id = c.id
        LEFT JOIN user_info ui ON dd.user_id = ui.id
        LEFT JOIN "B_Doctor_Visit_Summary" dvs ON dvs.calendar_id = c.id AND (dvs.is_deleted IS NULL OR dvs.is_deleted = false)
        WHERE c."Type" IN ('นัดหมาย', 'appointment') AND c."dateTime" >= $1::date AND r.s_status = 'Stay'
          AND r."i_Name_Surname" NOT LIKE 'งาน%'
        ORDER BY c.resident_id, c."dateTime"
      `, [today])  /* นัดหมาย ดึงจาก "วันนี้" เป็นต้นไป (ไม่ใช่ reportDate) เพราะเป็นข้อมูล upcoming */
      apptRows = apptResult.rows as AppointmentRow[]

      // 3. Med logs
      const mlResult = await conn.queryObject<MedLogRow>(`
        SELECT ml.id as log_id, ml.meal, ml.resident_id::int, r."i_Name_Surname" as resident_name,
          (ml."SecondCPictureUrl" IS NOT NULL AND ml."SecondCPictureUrl" != '') as has_2c_photo,
          (ml."ThirdCPictureUrl" IS NOT NULL AND ml."ThirdCPictureUrl" != '') as has_3c_photo,
          ml.qc_2c_mark, ml.qc_3c_mark, ui_3c.nickname as served_by,
          COALESCE(array_length(ml."medList_id_List", 1), 0) as med_count
        FROM "A_Med_logs" ml JOIN residents r ON ml.resident_id = r.id
        LEFT JOIN user_info ui_3c ON ml."3C_Compleated_by" = ui_3c.id
        WHERE ml."Created_Date" = $1 AND r.s_status = 'Stay' AND r."i_Name_Surname" NOT LIKE 'งาน%'
          AND ml.meal NOT IN ('test', 'จัดยาทั้งวัน', 'ให้เมื่อมีอาการ')
        ORDER BY r."i_Name_Surname", ml.meal
      `, [reportDate])
      medLogs = mlResult.rows as MedLogRow[]

      // 4. AI verifications
      const aiResult = await conn.queryObject<AIVerRow>(`
        SELECT med_log_id, photo_type, ai_status, confidence_score::float as confidence_score
        FROM "A_Med_AI_Verification" WHERE calendar_date = $1
      `, [reportDate])
      aiVers = aiResult.rows as AIVerRow[]

      // 5. Med errors
      const errResult = await conn.queryObject<MedErrorRow>(`
        SELECT meal, resident_id::int, reason, "reply_nurseMark" as reply_nurse_mark
        FROM "A_Med_Error_Log" WHERE "CalendarDate" = $1
      `, [reportDate])
      medErrors = errResult.rows as MedErrorRow[]

      // 6. Incidents
      const incResult = await conn.queryObject<IncidentRow>(`
        SELECT source_id::int, title, description, severity, status
        FROM "B_Incident" WHERE source_type = 'med_log'
          AND source_id IN (SELECT id FROM "A_Med_logs" WHERE "Created_Date" = $1)
      `, [reportDate])
      incidents = incResult.rows as IncidentRow[]

      // 7. Vitalsign (ทุก record ในวัน — ไล่ตาม timeline)
      const vitalResult = await conn.queryObject<VitalRow>(`
        SELECT v.id as vital_id, v.resident_id::int, v.resident_name, v.shift,
          v.user_nickname, v."Temp"::float as temp, v."PR"::int as pr, v."RR"::int as rr,
          v."sBP"::int as sbp, v."dBP"::int as dbp, v."O2"::int as o2, v."DTX"::int as dtx,
          v."Defecation" as defecation, v.constipation::float as constipation,
          v."Input"::int as input_ml, v.output as output_count, v.napkin::int as napkin,
          v.vital_signs_status,
          v."generalReport" as general_report,
          to_char(v.created_at AT TIME ZONE 'Asia/Bangkok', 'HH24:MI') as time_bkk,
          to_char(v.created_at AT TIME ZONE 'Asia/Bangkok', 'DD/MM') as date_bkk,
          q.comment as ai_comment, q.status as queue_status,
          v."isFullReport" as is_full_report
        FROM combined_vitalsign_details_view v
        LEFT JOIN vitalsign_sent_queue q ON q.vitalsign_id = v.id
        JOIN residents r ON v.resident_id = r.id
        WHERE v.created_at >= $1::timestamptz AND v.created_at < $2::timestamptz
          AND r.s_status = 'Stay' AND r."i_Name_Surname" NOT LIKE 'งาน%'
        ORDER BY v.resident_id, v.created_at
      `, [startTime, endTime])
      vitalRows = vitalResult.rows as VitalRow[]

      // 8. PT (กายภาพบำบัด) — SOAP note ล่าสุดของ reportDate ที่มี AI comparison
      const ptResult = await conn.queryObject<PTRow>(`
        SELECT s.id as soap_id, s.resident_id::int, r."i_Name_Surname" as resident_name,
          to_char(s.date AT TIME ZONE 'Asia/Bangkok', 'YYYY-MM-DD') as date_bkk,
          s.progression_2_times, s.share_token
        FROM "SOAPNote" s
        JOIN residents r ON s.resident_id = r.id
        WHERE s.type = 'กายภาพบำบัด'
          AND s.date >= $1::timestamptz AND s.date < $2::timestamptz
          AND s.progression_2_times IS NOT NULL AND s.progression_2_times != ''
          AND s.share_token IS NOT NULL
          AND r.s_status = 'Stay' AND r."i_Name_Surname" NOT LIKE 'งาน%'
        ORDER BY s.resident_id, s.date DESC
      `, [startTime, endTime])
      ptRows = ptResult.rows as PTRow[]

      // 9. Resident profile pictures + zone + LINE group (สำหรับ production send)
      var residentInfoResult = await conn.queryObject<{ resident_id: number; pic_url: string | null; zone_id: number | null; zone_name: string | null; zone_abbr: string | null; line_group_id: string | null; med_share_token: string | null; created_at: string }>(`
        SELECT r.id::int as resident_id, r.i_picture_url as pic_url,
          r.s_zone::int as zone_id, nz.zone as zone_name, nz.zone_abbr,
          rp.line_group_id, r.med_share_token::text,
          r.created_at::text as created_at
        FROM residents r
        LEFT JOIN nursinghome_zone nz ON r.s_zone = nz.id
        LEFT JOIN n8n_agent_resident_profile rp ON r.id = rp.resident_id
        WHERE r.s_status = 'Stay' AND r."i_Name_Surname" NOT LIKE 'งาน%'
      `)
      var residentInfoRows = residentInfoResult.rows
    } finally {
      conn.release()
      await pool.end()
    }

    console.log(`Data: ${taskRows.length} tasks, ${apptRows.length} appts, ${medLogs.length} meds, ${aiVers.length} AI, ${incidents.length} incidents, ${vitalRows.length} vitals, ${ptRows.length} PT`)

    // ===== Resident picture + zone + LINE group maps =====
    const residentPics = new Map<number, string>()
    const residentZones = new Map<number, { id: number | null; name: string | null; abbr: string | null }>()
    const residentLineGroups = new Map<number, string>()
    const residentMedTokens = new Map<number, string>()
    // ผู้พักเข้าใหม่ < 3 วัน → ยังไม่ส่งรายงาน (ข้อมูลยังไม่สมบูรณ์)
    const newResidentIds = new Set<number>()
    const THREE_DAYS_MS = 3 * 24 * 60 * 60 * 1000
    for (const ri of residentInfoRows) {
      const rid = Number(ri.resident_id)
      if (ri.pic_url) residentPics.set(rid, ri.pic_url)
      residentZones.set(rid, { id: ri.zone_id, name: ri.zone_name, abbr: ri.zone_abbr })
      if (ri.line_group_id) residentLineGroups.set(rid, ri.line_group_id)
      if (ri.med_share_token) residentMedTokens.set(rid, ri.med_share_token)
      // เช็คว่าเข้าพักไม่ถึง 3 วัน
      if (ri.created_at && (Date.now() - new Date(ri.created_at).getTime()) < THREE_DAYS_MS) {
        newResidentIds.add(rid)
      }
    }
    if (newResidentIds.size > 0) {
      console.log(`Skipping ${newResidentIds.size} new resident(s) (< 3 days): ${[...newResidentIds].join(', ')}`)
    }

    // ===== Group ทุกอย่าง by resident_id =====
    const allResidents = new Set<number>()
    const residentNames = new Map<number, string>()

    // Tasks by resident
    const tasksByRes = new Map<number, TaskRow[]>()
    for (const t of taskRows) {
      const rid = Number(t.resident_id)
      allResidents.add(rid); residentNames.set(rid, t.resident_name)
      if (!tasksByRes.has(rid)) tasksByRes.set(rid, [])
      tasksByRes.get(rid)!.push(t)
    }

    // Appointments by resident (max 3, merge DD staff)
    const apptsByRes = new Map<number, AppointmentRow[]>()
    for (const a of apptRows) {
      const rid = Number(a.resident_id)
      allResidents.add(rid); residentNames.set(rid, a.resident_name)
      if (!apptsByRes.has(rid)) apptsByRes.set(rid, [])
      const arr = apptsByRes.get(rid)!
      const existing = arr.find(x => x.calendar_id === a.calendar_id)
      if (existing) {
        if (a.staff_name && existing.staff_name && !existing.staff_name.includes(a.staff_name)) existing.staff_name += `, ${a.staff_name}`
        else if (a.staff_name && !existing.staff_name) existing.staff_name = a.staff_name
      } else if (arr.length < 3) arr.push({ ...a })
    }

    // Med by resident — index AI, errors, incidents
    const aiByLog = new Map<number, { '2C'?: AIVerRow; '3C'?: AIVerRow }>()
    for (const av of aiVers) {
      const mlId = Number(av.med_log_id)
      if (!aiByLog.has(mlId)) aiByLog.set(mlId, {})
      aiByLog.get(mlId)![av.photo_type as '2C' | '3C'] = av
    }

    const errByKey = new Map<string, MedErrorRow>()
    for (const err of medErrors) {
      errByKey.set(`${err.resident_id}_${err.meal}`, err)
    }

    const incByLog = new Map<number, IncidentRow>()
    for (const inc of incidents) incByLog.set(Number(inc.source_id), inc)

    const medsByRes = new Map<number, MealSummary[]>()
    for (const ml of medLogs) {
      const rid = Number(ml.resident_id)
      allResidents.add(rid); residentNames.set(rid, ml.resident_name)
      if (!medsByRes.has(rid)) medsByRes.set(rid, [])

      const logId = Number(ml.log_id)
      const ai = aiByLog.get(logId) || {}
      const err = errByKey.get(`${rid}_${ml.meal}`)
      const inc = incByLog.get(logId)

      medsByRes.get(rid)!.push({
        meal: ml.meal,
        mealShort: MEAL_SHORT[ml.meal] || ml.meal,
        emoji: MEAL_EMOJI[ml.meal] || '💊',
        medCount: Number(ml.med_count) || 0,
        has2cPhoto: ml.has_2c_photo,
        ai2cStatus: ai['2C']?.ai_status || null,
        ai2cConfidence: ai['2C']?.confidence_score || null,
        qc2cMark: ml.qc_2c_mark,
        has3cPhoto: ml.has_3c_photo,
        ai3cStatus: ai['3C']?.ai_status || null,
        ai3cConfidence: ai['3C']?.confidence_score || null,
        qc3cMark: ml.qc_3c_mark,
        // Med Error — filter เหมือน med-daily-summary ต้นฉบับ
        hasError: !!err
          && !['รูปตรง', 'ถูกต้อง', 'ตำแหน่งสลับ'].includes(err.reply_nurse_mark || '')
          && (err.reason !== '-' && err.reason !== null && err.reason !== ''),
        errorReason: err?.reason || null,
        errorReply: err?.reply_nurse_mark || null,
        // Incident จาก B_Incident (source_type = med_log)
        hasIncident: !!inc,
        incidentDesc: inc?.description || null,
        incidentSeverity: inc?.severity || null,
        incidentStatus: inc?.status || null,
        servedBy: ml.served_by,
      })
    }

    // Sort meals ตาม MEAL_ORDER
    for (const [, meals] of medsByRes) {
      meals.sort((a, b) => {
        const ia = MEAL_ORDER.indexOf(a.meal)
        const ib = MEAL_ORDER.indexOf(b.meal)
        return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib)
      })
    }

    // Vitals by resident (ทุก record ไล่ตาม timeline)
    const vitalsByRes = new Map<number, VitalRow[]>()
    for (const vr of vitalRows) {
      const rid = Number(vr.resident_id)
      allResidents.add(rid); residentNames.set(rid, vr.resident_name)
      if (!vitalsByRes.has(rid)) vitalsByRes.set(rid, [])
      vitalsByRes.get(rid)!.push(vr)
    }

    // PT by resident (เอาแค่ record ล่าสุดต่อคน)
    const ptByRes = new Map<number, PTRow>()
    for (const pt of ptRows) {
      const rid = Number(pt.resident_id)
      allResidents.add(rid); residentNames.set(rid, pt.resident_name)
      // เอาแค่ record แรก (ล่าสุด เพราะ ORDER BY date DESC)
      if (!ptByRes.has(rid)) ptByRes.set(rid, pt)
    }

    // ===== สร้าง carousel per resident =====
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const results: Record<string, any>[] = []

    const sortedResidents = [...allResidents]
      .filter(rid => !residentFilter || rid === residentFilter)
      .filter(rid => !newResidentIds.has(rid))  // ข้ามผู้พักเข้าใหม่ < 3 วัน
      .sort((a, b) => (residentNames.get(a) || '').localeCompare(residentNames.get(b) || ''))

    for (const rid of sortedResidents) {
      const name = residentNames.get(rid) || ''
      const bubbles: Record<string, unknown>[] = []

      // Bubble 1: สัญญาณชีพประจำวัน (รวมทุก record ไล่ตาม timeline)
      const vitalBubble = buildVitalsBubble(name, dateLabel, vitalsByRes.get(rid) || [])
      if (vitalBubble) bubbles.push(vitalBubble)

      // Bubble 3: เช็คลิสต์
      const checkBubble = buildChecklistBubble(name, shiftLabel, shiftEmoji, dateLabel, tasksByRes.get(rid) || [])
      if (checkBubble) bubbles.push(checkBubble)

      // Bubble 4: ยา
      const medBubble = buildMedBubble(name, medDateLabel, medsByRes.get(rid) || [], residentMedTokens.get(rid))
      if (medBubble) bubbles.push(medBubble)

      // Bubble 5: กายภาพบำบัด (สรุปพัฒนาการ AI)
      const ptData = ptByRes.get(rid)
      if (ptData) bubbles.push(buildPTBubble(name, dateLabel, ptData))

      // Bubble 6: นัดหมาย (ไว้สุดท้าย)
      const apptBubble = buildAppointmentBubble(name, apptsByRes.get(rid) || [], today)
      if (apptBubble) bubbles.push(apptBubble)

      if (bubbles.length === 0) continue

      // สร้าง Cover bubble — หน้าปกแสดงชื่อ วันที่ และสรุปว่ามีอะไรบ้าง
      const sections: string[] = []
      if (vitalBubble) sections.push('🩺 สัญญาณชีพ')
      if (checkBubble) sections.push('📋 เช็คลิสต์')
      if (medBubble) sections.push('💊 สรุปยา')
      if (ptData) sections.push('🏃‍♂️ กายภาพบำบัด')
      if (apptBubble) sections.push('📅 นัดหมาย')
      bubbles.unshift(buildCoverBubble(name, dateLabel, sections, residentPics.get(rid), timeRangeLabel))

      if (previewMode) {
        // Preview mode: เก็บข้อมูลดิบสำหรับ dashboard (ไม่ส่ง LINE)
        const taskData = tasksByRes.get(rid) ? categorizeTasks(tasksByRes.get(rid)!) : null
        results.push({
          id: rid, name, bubbles: bubbles.length, sent: false,
          production: PRODUCTION_RESIDENTS.has(rid),  // อยู่ใน production list หรือไม่
          picUrl: residentPics.get(rid) || null,
          zone: residentZones.get(rid) ?? null,  // { id, name, abbr }
          sections,
          medShareToken: residentMedTokens.get(rid) || null,  // token สำหรับลิงก์ดูรายการยา
          // ข้อมูลดิบแต่ละ section
          vitals: vitalsByRes.get(rid) || [],
          tasks: taskData,
          meds: medsByRes.get(rid) || [],
          pt: ptByRes.get(rid) || null,
          appointments: apptsByRes.get(rid) || [],
        })
      } else {
        // ปกติ: ส่ง LINE
        const flexMsg = {
          type: 'flex',
          altText: `📋 สรุปประจำวัน — ${name}`,
          contents: bubbles.length === 1 ? bubbles[0] : { type: 'carousel', contents: bubbles },
        }

        // ส่งห้องจริงเฉพาะ: send_production=true + อยู่ใน PRODUCTION_RESIDENTS + มี line_group_id
        const isProduction = sendProduction && PRODUCTION_RESIDENTS.has(rid)
        const targetGroup = isProduction ? (residentLineGroups.get(rid) || DEV_LINE_GROUP_ID) : DEV_LINE_GROUP_ID
        const res = await pushToLine(LINE_TOKEN, targetGroup, [flexMsg])
        results.push({ id: rid, name, bubbles: bubbles.length, sent: res.success, production: isProduction })
        await new Promise(r => setTimeout(r, 150))
      }
    }

    if (previewMode) {
      // Preview response: ข้อมูลดิบ + metadata
      // ใช้ replacer เพื่อแปลง BigInt → number (PostgreSQL bigint columns)
      const bigIntReplacer = (_k: string, v: unknown) => typeof v === 'bigint' ? Number(v) : v
      return new Response(JSON.stringify({
        success: true, reportDate, date: today,
        snapshotAt: new Date().toISOString(),
        dateLabel, timeRangeLabel,
        totalResidents: allResidents.size,
        residents: results,
      }, bigIntReplacer, 2), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const sentOk = results.filter(r => r.sent).length
    return new Response(JSON.stringify({
      success: true, reportDate, date: today,
      totalResidents: allResidents.size, sentSuccess: sentOk, sentFailed: results.length - sentOk,
      residents: results,
    }, null, 2), { headers: { 'Content-Type': 'application/json' } })
  } catch (err: unknown) {
    console.error('Error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { 'Content-Type': 'application/json' } })
  }
})
