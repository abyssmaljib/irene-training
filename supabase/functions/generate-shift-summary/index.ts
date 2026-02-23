// Edge Function: generate-shift-summary
// สรุปรายงานประจำเวรสำหรับ resident 1 คน โดยใช้ Google Gemini AI
// รวบรวมข้อมูลจากทุกตารางที่เกี่ยวข้อง (vital signs, tasks, meds, posts, etc.)
// แล้วส่งให้ AI สรุปเป็นรายงานภาษาไทย
//
// Input: { resident_id, resident_name, date, shift, nursinghome_id }
// Output: { content: string }

import { createClient } from 'npm:@supabase/supabase-js@2'
import { GoogleGenerativeAI } from 'npm:@google/generative-ai'

// Supabase client — ใช้ service role key เพื่อ bypass RLS
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// Google Gemini AI
const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!)

// =============================================
// Types
// =============================================

interface RequestBody {
  resident_id: number
  resident_name: string
  date: string          // 'YYYY-MM-DD' ในเวลาไทย
  shift: 'เวรเช้า' | 'เวรดึก'
  nursinghome_id: number
  current_form_data?: {  // ข้อมูลจากฟอร์มที่ user กรอกแล้วแต่ยังไม่ save
    vital_signs?: Record<string, string>  // เช่น { sBP: "120", dBP: "80", ... }
    ratings?: Array<{                      // Scale ประเมินสุขภาพ
      subject: string
      rating: number
      choice?: string
      note?: string
    }>
    report_template?: string  // บันทึกที่ NA เขียนไว้แล้วในช่องรายงาน (ส่งมาให้ AI รวมในสรุป)
  }
}

// Data sources ที่ admin เปิด/ปิดได้
interface DataSourceConfig {
  vital_signs: boolean
  task_logs: boolean
  med_logs: boolean
  posts: boolean
  soap_notes: boolean
  bowel_movements: boolean
  scale_reports: boolean
  med_errors: boolean
  calendars: boolean
  abnormal_values: boolean
}

// =============================================
// Default Config — ใช้เมื่อยังไม่มีใน B_AI_Config
// =============================================

const DEFAULT_DATA_SOURCES: DataSourceConfig = {
  vital_signs: true,
  task_logs: true,
  med_logs: true,
  posts: true,
  soap_notes: true,
  bowel_movements: true,
  scale_reports: true,
  med_errors: true,
  calendars: true,
  abnormal_values: true,
}

// Default prompt — admin สามารถแก้ไขได้จากหน้า Settings
const DEFAULT_PROMPT = `คุณเป็นพยาบาลหัวหน้าเวรใน Nursing Home ที่มีประสบการณ์สูงและใจดี
กรุณาสรุปรายงานประจำเวรสำหรับผู้พัก: {{RESIDENT_NAME}}
เวร: {{SHIFT}} วันที่ {{DATE}}

ข้อมูลในเวรนี้:
{{DATA}}

สรุปเป็นภาษาไทย กระชับ ชัดเจน ในรูปแบบรายงานประจำเวร

ถ้ามีส่วน "บันทึกจากผู้ดูแล (NA เขียนไว้แล้ว)" ในข้อมูล:
- ให้นำเนื้อหาที่ผู้ดูแลเขียนไว้มารวมเป็นส่วนหนึ่งของสรุปด้วย
- เนื้อหาเหล่านี้เป็นข้อสังเกตจากผู้ดูแลโดยตรง (เช่น อารมณ์ผู้พัก พฤติกรรม สิ่งที่สังเกตเห็น)
- รักษาเนื้อหาสำคัญไว้ แต่ปรับให้กลมกลืนกับสรุปรวม ไม่ต้องคัดลอกทั้งหมดตามตัวอักษร
- ถ้าข้อมูลซ้ำกับข้อมูลจากระบบ ให้รวมเป็นประโยคเดียวกัน

ใช้โครงสร้างนี้:
1. สรุปภาพรวมสั้นๆ 1 ประโยค (สถานะทั่วไปของผู้พัก)
2. รายงานสัญญาณชีพ (ถ้ามี) - เน้นค่าที่ผิดปกติ
3. รายงานยา (ถ้ามี) - สรุปว่าได้รับยาครบหรือไม่
4. รายงานงานที่ทำ (ถ้ามี) - สรุปงานที่เสร็จ/ไม่เสร็จ/มีปัญหา
5. รายงานอื่นๆ ที่สำคัญ (SOAP notes, การขับถ่าย, ค่าผิดปกติ, นัดหมาย)
6. ข้อสังเกตหรือสิ่งที่ต้องติดตาม (ถ้ามี)

น้ำเสียง:
- ญาติของผู้พักจะได้อ่านด้วย — สุภาพ ตรงไปตรงมา ไม่ทำให้ตกใจ
- อาการผิดปกติให้รายงานตามจริง แต่ใช้คำที่เหมาะสม เช่น "ความดันสูงกว่าปกติเล็กน้อย" แทน "ความดันสูงอันตราย"
- ห้ามเสแสร้ง ห้ามเติมคำว่า "อบอุ่น" "น่ารัก" "มีความสุข" ถ้าข้อมูลไม่ได้บอก
- ลงท้ายด้วย "ค่ะ" ได้ตามธรรมชาติ

ข้อกำหนด:
- เขียนสั้นกระชับที่สุด ตัดคำฟุ่มเฟือย เน้นแต่ข้อเท็จจริง
- plain text ไม่ใช้ markdown (ไม่ใช้ ** ## -)
- ภาษาไทยเข้าใจง่าย ข้ามหมวดที่ไม่มีข้อมูล
- ความยาวไม่เกิน 200 คำ
- ห้ามเพิ่มข้อมูลที่ไม่ได้ให้มา ห้ามใช้ emoji`

// =============================================
// Config Keys ใน B_AI_Config
// =============================================
const CONFIG_KEYS = {
  SHIFT_SUMMARY_PROMPT: 'shift_summary_prompt',
  SHIFT_SUMMARY_DATA_SOURCES: 'shift_summary_data_sources',
}

// =============================================
// Helper: คำนวณช่วงเวลาเวร (Asia/Bangkok = UTC+7)
// =============================================
// +07:00 คือ offset ของเวลาไทย → T07:00:00+07:00 = 07:00 น. ไทย = 00:00 UTC
// เวรเช้า: 07:00-19:00 BKK = 00:00-12:00 UTC
// เวรดึก: 19:00-07:00(+1) BKK = 12:00-00:00(+1) UTC
function getShiftRange(date: string, shift: string): { start: string; end: string } {
  // คำนวณวันถัดไปจาก date string โดยใช้ UTC methods
  // (ห้ามใช้ +07:00 ใน Date constructor เพราะ getDate()/setDate() ใช้ local time ของ server = UTC)
  const [year, month, day] = date.split('-').map(Number)
  const nextDate = new Date(Date.UTC(year, month - 1, day + 1))
  const nextDay = nextDate.toISOString().split('T')[0]

  // ตรวจว่าเป็น "เวรเช้า" — ใช้ includes เพื่อรองรับ encoding ที่อาจต่างกัน
  const isMorning = shift.includes('เช้า') || shift === 'เวรเช้า'

  if (isMorning) {
    // เวรเช้า: 07:00 → 19:00 เวลาไทย
    return {
      start: `${date}T07:00:00+07:00`, // 07:00 BKK = 00:00 UTC
      end: `${date}T19:00:00+07:00`,   // 19:00 BKK = 12:00 UTC
    }
  } else {
    // เวรดึก: 19:00 วันนี้ → 07:00 วันถัดไป
    return {
      start: `${date}T19:00:00+07:00`,   // 19:00 BKK = 12:00 UTC
      end: `${nextDay}T07:00:00+07:00`,  // 07:00 BKK วันถัดไป = 00:00 UTC
    }
  }
}

// =============================================
// Helper: อ่าน config จาก B_AI_Config
// =============================================
async function loadConfig(): Promise<{
  prompt: string
  dataSources: DataSourceConfig
}> {
  // ดึง config ทั้ง 2 keys พร้อมกัน
  const [promptResult, sourcesResult] = await Promise.all([
    (supabase.from('B_AI_Config') as any)
      .select('config_value')
      .eq('config_key', CONFIG_KEYS.SHIFT_SUMMARY_PROMPT)
      .eq('is_active', true)
      .maybeSingle(),
    (supabase.from('B_AI_Config') as any)
      .select('config_value')
      .eq('config_key', CONFIG_KEYS.SHIFT_SUMMARY_DATA_SOURCES)
      .eq('is_active', true)
      .maybeSingle(),
  ])

  // Prompt — ใช้ default ถ้าไม่มีใน DB
  const prompt = promptResult.data?.config_value || DEFAULT_PROMPT

  // Data sources — parse JSON หรือใช้ default
  let dataSources = { ...DEFAULT_DATA_SOURCES }
  if (sourcesResult.data?.config_value) {
    try {
      const parsed = JSON.parse(sourcesResult.data.config_value)
      dataSources = { ...DEFAULT_DATA_SOURCES, ...parsed }
    } catch {
      console.warn('Failed to parse data sources config, using defaults')
    }
  }

  return { prompt, dataSources }
}

// =============================================
// Data Queries — แต่ละตารางที่เกี่ยวกับ resident
// =============================================

// Collect query errors สำหรับ debug
const queryErrors: Record<string, string> = {}

// 1. สัญญาณชีพ
// หมายเหตุ: ไม่ดึง generalReport เพราะมันคือ "รายงานเวรเก่า" ที่เคยเขียนไว้
// ถ้าเอามาด้วย AI จะสับสนระหว่างข้อมูลเก่ากับข้อมูลเวรปัจจุบัน
async function queryVitalSigns(residentId: number, start: string, end: string) {
  const { data, error } = await supabase
    .from('vitalSign')
    .select('sBP, dBP, PR, RR, Temp, O2, DTX, Insulin, Input, output, napkin, Defecation, constipation, shift, created_at')
    .eq('resident_id', residentId)
    .gte('created_at', start)
    .lt('created_at', end)
    .order('created_at')
  if (error) { queryErrors.vital_signs = error.message; console.error('[vital_signs]', error) }
  return data || []
}

// 2. Task logs (ผ่าน A_Tasks.resident_id)
async function queryTaskLogs(residentId: number, start: string, end: string) {
  // A_Task_logs_ver2 ไม่มี FK ไป A_Tasks → ใช้ PostgREST join ไม่ได้
  // แก้: query A_Tasks ที่เป็นของ resident ก่อน → แล้ว query logs ที่มี task_id ตรง

  // Step 1: ดึง task IDs ของ resident นี้
  const { data: tasks, error: tasksError } = await (supabase
    .from('A_Tasks') as any)
    .select('id, title, description, resident_id, taskType')
    .eq('resident_id', residentId)

  if (tasksError) { queryErrors.task_logs_tasks = tasksError.message; console.error('[task_logs/A_Tasks]', tasksError) }
  if (!tasks || tasks.length === 0) return []

  const taskIds = tasks.map((t: any) => t.id)
  // สร้าง map สำหรับ lookup
  const taskMap = Object.fromEntries(tasks.map((t: any) => [t.id, t]))

  // Step 2: ดึง logs ที่มี ExpectedDateTime ในช่วงเวร + task_id อยู่ใน list
  const { data: logs, error: logsError } = await (supabase
    .from('A_Task_logs_ver2') as any)
    .select('id, status, Descript, completed_at, ExpectedDateTime, problem_type, task_id')
    .in('task_id', taskIds)
    .gte('ExpectedDateTime', start)
    .lt('ExpectedDateTime', end)

  if (logsError) { queryErrors.task_logs = logsError.message; console.error('[task_logs]', logsError) }
  if (!logs) return []

  // Step 3: Merge task info เข้ากับ logs
  return logs.map((log: any) => ({
    ...log,
    task: taskMap[log.task_id] || null,
  }))
}

// 3. การจัดยา
async function queryMedLogs(residentId: number, start: string, end: string) {
  const { data, error } = await supabase
    .from('A_Med_logs')
    .select('meal, Created_Date, ArrangeMed_by, created_at')
    .eq('resident_id', residentId)
    .gte('created_at', start)
    .lt('created_at', end)
    .order('created_at')
  if (error) { queryErrors.med_logs = error.message; console.error('[med_logs]', error) }
  return data || []
}

// 4. โพสต์/รายงาน — ทั้ง direct resident_id และ junction table
async function queryPosts(residentId: number, start: string, end: string) {
  // 4a. ดึง Post IDs จาก junction table
  const { data: junctionData, error: junctionError } = await (supabase
    .from('Post_Resident_id') as any)
    .select('Post_id')
    .eq('resident_id', residentId)
  if (junctionError) { queryErrors.posts_junction = junctionError.message; console.error('[posts_junction]', junctionError) }
  // กรอง null/empty ออก เพราะ junction table อาจมี Post_id ที่เป็น null หรือ ""
  const junctionPostIds = (junctionData || [])
    .map((p: any) => p.Post_id)
    .filter((id: any) => id != null && id !== '')
  console.log(`[posts] junction IDs for resident ${residentId}:`, junctionPostIds)

  // 4b. ดึง Posts — ทั้ง direct resident_id และจาก junction
  // สร้าง OR filter
  // Post table ใช้ "created_at" ไม่ใช่ "post_created_at"
  // (post_created_at เป็นชื่อที่ VIEW postwithuserinfo rename)
  let query = supabase
    .from('Post')
    .select('id, title, Text, created_at, is_handover')
    .gte('created_at', start)
    .lt('created_at', end)
    .order('created_at')

  if (junctionPostIds.length > 0) {
    // มีทั้ง direct และ junction
    query = query.or(`resident_id.eq.${residentId},id.in.(${junctionPostIds.join(',')})`)
  } else {
    // มีแค่ direct
    query = query.eq('resident_id', residentId)
  }

  const { data, error } = await query
  if (error) { queryErrors.posts = error.message; console.error('[posts]', error) }
  console.log(`[posts] found ${data?.length || 0} posts for resident ${residentId}`)
  return data || []
}

// 5. SOAP Notes
async function querySOAPNotes(residentId: number, start: string, end: string) {
  const { data } = await (supabase
    .from('SOAPNote') as any)
    .select('Subjective, Objective, Assessment, Plan, descriptive_Note, type, date')
    .eq('resident_id', residentId)
    .gte('date', start)
    .lt('date', end)
    .order('date')
  return data || []
}

// 6. การขับถ่าย
async function queryBowelMovements(residentId: number, start: string, end: string) {
  const { data } = await (supabase
    .from('Doc_Bowel_Movement') as any)
    .select('BristolScore, Amount, created_at')
    .eq('resident_id', residentId)
    .gte('created_at', start)
    .lt('created_at', end)
    .order('created_at')
  return data || []
}

// 7. ผลประเมินสุขภาพ
async function queryScaleReports(residentId: number, start: string, end: string) {
  const { data } = await (supabase
    .from('Scale_Report_Log') as any)
    .select('report_description, created_at')
    .eq('resident_id', residentId)
    .gte('created_at', start)
    .lt('created_at', end)
    .order('created_at')
  return data || []
}

// 8. ข้อผิดพลาดยา
async function queryMedErrors(residentId: number, start: string, end: string) {
  const { data } = await (supabase
    .from('A_Med_Error_Log') as any)
    .select('meal, list_of_med, reason, CalendarDate, created_at')
    .eq('resident_id', residentId)
    .gte('created_at', start)
    .lt('created_at', end)
  return data || []
}

// 9. นัดหมาย
async function queryCalendars(residentId: number, start: string, end: string) {
  const { data } = await (supabase
    .from('C_Calendar') as any)
    .select('Title, Description, Type, dateTime, hospital, isNPO')
    .eq('resident_id', residentId)
    .gte('dateTime', start)
    .lt('dateTime', end)
    .order('dateTime')
  return data || []
}

// 10. ค่าผิดปกติ
async function queryAbnormalValues(residentId: number, start: string, end: string) {
  const { data } = await (supabase
    .from('abnormal_value_Dashboard') as any)
    .select('abnormal_value, created_at')
    .eq('resident_id', residentId)
    .gte('created_at', start)
    .lt('created_at', end)
    .order('created_at')
  return data || []
}

// =============================================
// Formatters — แปลงข้อมูลเป็นข้อความสำหรับ AI
// =============================================

// แปลง UTC timestamp เป็นเวลาไทย HH:MM
function formatTime(isoString: string): string {
  try {
    const d = new Date(isoString)
    // เพิ่ม 7 ชม. สำหรับ UTC+7
    const thai = new Date(d.getTime() + 7 * 60 * 60 * 1000)
    const hh = thai.getUTCHours().toString().padStart(2, '0')
    const mm = thai.getUTCMinutes().toString().padStart(2, '0')
    return `${hh}:${mm}`
  } catch {
    return ''
  }
}

function formatVitalSigns(data: any[]): string {
  return data.map((v) => {
    const time = formatTime(v.created_at)
    const parts: string[] = []
    if (v.sBP && v.dBP) parts.push(`BP ${v.sBP}/${v.dBP}`)
    if (v.PR) parts.push(`PR ${v.PR}`)
    if (v.Temp) parts.push(`Temp ${v.Temp}`)
    if (v.RR) parts.push(`RR ${v.RR}`)
    if (v.O2) parts.push(`SpO2 ${v.O2}%`)
    if (v.DTX) parts.push(`DTX ${v.DTX}`)
    if (v.Insulin) parts.push(`Insulin ${v.Insulin}`)
    // I/O ข้อมูลสำคัญ
    if (v.Input) parts.push(`Input ${v.Input}`)
    if (v.output) parts.push(`Output ${v.output}`)
    if (v.napkin) parts.push(`ผ้าอ้อม ${v.napkin}`)
    if (v.Defecation) parts.push(`ถ่าย ${v.Defecation}`)
    if (v.constipation) parts.push(`ท้องผูกวันที่ ${v.constipation}`)
    return `เวลา ${time}: ${parts.join(', ')}`
    // หมายเหตุ: ไม่ใส่ generalReport เพราะเป็นรายงานเวรเก่า
  }).join('\n')
}

function formatTaskLogs(data: any[]): string {
  return data.map((log) => {
    const title = log.task?.title || log.Descript || 'ไม่ระบุ'
    const status = log.status || 'unknown'
    // แปลง status เป็นภาษาไทย
    const statusMap: Record<string, string> = {
      'complete': 'เสร็จ',
      'Complete': 'เสร็จ',
      'problem': 'มีปัญหา',
      'Problem': 'มีปัญหา',
      'skip': 'ข้าม',
      'Skip': 'ข้าม',
      'pending': 'รอดำเนินการ',
    }
    const statusThai = statusMap[status] || status
    let line = `[${statusThai}] ${title}`
    if (log.problem_type) line += ` (ปัญหา: ${log.problem_type})`
    if (log.Descript && log.task?.title && log.Descript !== log.task.title) {
      line += ` - ${log.Descript}`
    }
    return line
  }).join('\n')
}

function formatMedLogs(data: any[]): string {
  return data.map((m) => {
    const time = formatTime(m.created_at)
    return `เวลา ${time}: จัดยามื้อ ${m.meal || 'ไม่ระบุ'}`
  }).join('\n')
}

function formatPosts(data: any[]): string {
  // is_handover เป็นแค่ flag สำหรับ visibility filter (เพื่อนร่วมงาน vs ญาติ)
  // ไม่เกี่ยวกับเวรก่อน/เวรปัจจุบัน → ปฏิบัติกับทุก post เหมือนกัน
  return data.map((p) => {
    const time = formatTime(p.created_at)
    const title = p.title || ''
    const text = p.Text ? (p.Text.length > 200 ? p.Text.slice(0, 200) + '...' : p.Text) : ''
    return `เวลา ${time}: ${title}${text ? ' - ' + text : ''}`
  }).join('\n')
}

function formatSOAPNotes(data: any[]): string {
  return data.map((n) => {
    const parts: string[] = []
    if (n.Subjective) parts.push(`S: ${n.Subjective}`)
    if (n.Objective) parts.push(`O: ${n.Objective}`)
    if (n.Assessment) parts.push(`A: ${n.Assessment}`)
    if (n.Plan) parts.push(`P: ${n.Plan}`)
    if (n.descriptive_Note) parts.push(`Note: ${n.descriptive_Note}`)
    return parts.join(' | ')
  }).join('\n')
}

function formatBowelMovements(data: any[]): string {
  return data.map((b) => {
    const time = formatTime(b.created_at)
    return `เวลา ${time}: Bristol Score ${b.BristolScore || '-'}, ปริมาณ ${b.Amount || '-'}`
  }).join('\n')
}

function formatScaleReports(data: any[]): string {
  return data.map((s) => {
    const time = formatTime(s.created_at)
    return `เวลา ${time}: ${s.report_description || 'ไม่มีรายละเอียด'}`
  }).join('\n')
}

function formatMedErrors(data: any[]): string {
  return data.map((e) => {
    return `มื้อ ${e.meal || '-'}: ${e.list_of_med || '-'} (สาเหตุ: ${e.reason || '-'})`
  }).join('\n')
}

function formatCalendars(data: any[]): string {
  return data.map((c) => {
    const time = formatTime(c.dateTime)
    let line = `เวลา ${time}: ${c.Title || c.Type || 'นัดหมาย'}`
    if (c.hospital) line += ` (${c.hospital})`
    if (c.isNPO) line += ' [NPO - งดอาหาร]'
    if (c.Description) line += ` - ${c.Description}`
    return line
  }).join('\n')
}

function formatAbnormalValues(data: any[]): string {
  return data.map((a) => {
    const time = formatTime(a.created_at)
    return `เวลา ${time}: ${a.abnormal_value || 'ค่าผิดปกติ'}`
  }).join('\n')
}

// =============================================
// Format: ข้อมูลจากฟอร์มที่ user กรอก (ยังไม่ save)
// =============================================

// Format สัญญาณชีพจากฟอร์ม
function formatFormVitalSigns(vs: Record<string, string>): string {
  // Map key → label ที่อ่านง่าย
  const labels: Record<string, string> = {
    sBP: 'BP (systolic)', dBP: 'BP (diastolic)',
    PR: 'PR', RR: 'RR', Temp: 'Temp', O2: 'SpO2',
    DTX: 'DTX', Insulin: 'Insulin',
    Input: 'Input', Output: 'Output',
    napkin: 'ผ้าอ้อม', defecation: 'การขับถ่าย',
    constipation: 'ท้องผูกวันที่',
  }
  const parts: string[] = []
  // รวม BP เป็นคู่ถ้ามีทั้ง sBP และ dBP
  if (vs.sBP && vs.dBP) {
    parts.push(`BP ${vs.sBP}/${vs.dBP}`)
  } else {
    if (vs.sBP) parts.push(`BP (systolic) ${vs.sBP}`)
    if (vs.dBP) parts.push(`BP (diastolic) ${vs.dBP}`)
  }
  // ส่วนที่เหลือ
  for (const [key, val] of Object.entries(vs)) {
    if (key === 'sBP' || key === 'dBP') continue // จัดการแล้วข้างบน
    const label = labels[key] || key
    parts.push(`${label} ${val}`)
  }
  return parts.join(', ')
}

// Format ratings/scales จากฟอร์ม
function formatFormRatings(ratings: Array<{ subject: string, rating: number, choice?: string, note?: string }>): string {
  return ratings.map((r) => {
    let text = `${r.subject}: ${r.rating}/5`
    if (r.choice) text += ` (${r.choice})`
    if (r.note) text += ` — ${r.note}`
    return text
  }).join('\n')
}

// =============================================
// Main: รวมข้อมูลทั้งหมดเป็น structured text
// =============================================
function buildDataText(
  results: Record<string, any[]>,
  currentFormData?: RequestBody['current_form_data'],
): string {
  const sections: string[] = []

  // --- ข้อมูลจากฟอร์มปัจจุบัน (ยังไม่ save) ---
  // ใส่ไว้ก่อนข้อมูลจาก DB เพราะเป็นข้อมูลล่าสุดที่ user เพิ่งกรอก
  if (currentFormData) {
    if (currentFormData.vital_signs && Object.keys(currentFormData.vital_signs).length > 0) {
      sections.push(`## สัญญาณชีพ (กรอกในฟอร์มปัจจุบัน)\n${formatFormVitalSigns(currentFormData.vital_signs)}`)
    }
    if (currentFormData.ratings && currentFormData.ratings.length > 0) {
      sections.push(`## ผลประเมินสุขภาพ (กรอกในฟอร์มปัจจุบัน)\n${formatFormRatings(currentFormData.ratings)}`)
    }
  }

  // --- ข้อมูลจาก DB (บันทึกไว้ก่อนหน้า) ---
  // แต่ละ section จะถูกเพิ่มเฉพาะเมื่อมีข้อมูล
  if (results.vital_signs?.length > 0) {
    sections.push(`## สัญญาณชีพ (บันทึกก่อนหน้า)\n${formatVitalSigns(results.vital_signs)}`)
  }
  if (results.task_logs?.length > 0) {
    sections.push(`## งานที่ทำ\n${formatTaskLogs(results.task_logs)}`)
  }
  if (results.med_logs?.length > 0) {
    sections.push(`## การจัดยา\n${formatMedLogs(results.med_logs)}`)
  }
  if (results.posts?.length > 0) {
    sections.push(`## โพสต์/รายงาน\n${formatPosts(results.posts)}`)
  }
  if (results.soap_notes?.length > 0) {
    sections.push(`## SOAP Notes\n${formatSOAPNotes(results.soap_notes)}`)
  }
  if (results.bowel_movements?.length > 0) {
    sections.push(`## การขับถ่าย\n${formatBowelMovements(results.bowel_movements)}`)
  }
  if (results.scale_reports?.length > 0) {
    sections.push(`## ผลประเมินสุขภาพ (บันทึกก่อนหน้า)\n${formatScaleReports(results.scale_reports)}`)
  }
  if (results.med_errors?.length > 0) {
    sections.push(`## ข้อผิดพลาดยา\n${formatMedErrors(results.med_errors)}`)
  }
  if (results.calendars?.length > 0) {
    sections.push(`## นัดหมาย\n${formatCalendars(results.calendars)}`)
  }
  if (results.abnormal_values?.length > 0) {
    sections.push(`## ค่าผิดปกติ\n${formatAbnormalValues(results.abnormal_values)}`)
  }

  // --- บันทึกที่ NA เขียนไว้แล้ว (ถ้ามี) ---
  // เนื้อหาที่ NA พิมพ์ไว้ในช่องรายงาน เช่น "วันนี้อารมณ์ดี ยิ้มแย้ม..."
  // ส่งให้ AI เอาไปรวมเป็นส่วนหนึ่งของสรุป ไม่ใช่แค่เลียนแบบรูปแบบ
  if (currentFormData?.report_template && currentFormData.report_template.trim().length > 0) {
    sections.push(`## บันทึกจากผู้ดูแล (NA เขียนไว้แล้ว)\nข้อมูลด้านล่างเป็นสิ่งที่ผู้ดูแลสังเกตเห็นและจดไว้แล้ว ให้นำไปรวมในสรุปด้วย:\n${currentFormData.report_template}`)
  }

  if (sections.length === 0) {
    return 'ไม่มีข้อมูลกิจกรรมในเวรนี้'
  }

  // เพิ่มคำอธิบายให้ AI เข้าใจว่าข้อมูลนี้คือของเวรปัจจุบัน
  const header = '(หมายเหตุ: ข้อมูลด้านล่างทั้งหมดเป็นกิจกรรมที่เกิดขึ้นในเวรนี้เท่านั้น ไม่รวมข้อมูลเวรอื่น ยกเว้นส่วนที่ระบุว่า "ส่งต่อจากเวรก่อน")\n\n'
  return header + sections.join('\n\n')
}

// =============================================
// Main Handler
// =============================================

Deno.serve(async (req) => {
  // CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed', content: '' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  try {
    const body: RequestBody = await req.json()
    const { resident_id, resident_name, date, shift, nursinghome_id, current_form_data } = body

    console.log(`[generate-shift-summary] resident=${resident_id}, date=${date}, shift=${shift}`)

    // Validate input
    if (!resident_id || !date || !shift) {
      return new Response(JSON.stringify({
        error: 'Missing required fields: resident_id, date, shift',
        content: '',
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    // 1. อ่าน config จาก DB (prompt + data sources)
    const config = await loadConfig()
    console.log('[generate-shift-summary] Data sources config:', config.dataSources)

    // 2. คำนวณช่วงเวลาเวร
    const { start, end } = getShiftRange(date, shift)
    console.log(`[generate-shift-summary] Time range: ${start} → ${end}`)

    // 3. Query ข้อมูลจากทุกตารางที่เปิดอยู่ — ใช้ Promise.all เพื่อ parallel
    const queries: Record<string, Promise<any[]>> = {}

    if (config.dataSources.vital_signs) {
      queries.vital_signs = queryVitalSigns(resident_id, start, end)
    }
    if (config.dataSources.task_logs) {
      queries.task_logs = queryTaskLogs(resident_id, start, end)
    }
    if (config.dataSources.med_logs) {
      queries.med_logs = queryMedLogs(resident_id, start, end)
    }
    if (config.dataSources.posts) {
      queries.posts = queryPosts(resident_id, start, end)
    }
    if (config.dataSources.soap_notes) {
      queries.soap_notes = querySOAPNotes(resident_id, start, end)
    }
    if (config.dataSources.bowel_movements) {
      queries.bowel_movements = queryBowelMovements(resident_id, start, end)
    }
    if (config.dataSources.scale_reports) {
      queries.scale_reports = queryScaleReports(resident_id, start, end)
    }
    if (config.dataSources.med_errors) {
      queries.med_errors = queryMedErrors(resident_id, start, end)
    }
    if (config.dataSources.calendars) {
      queries.calendars = queryCalendars(resident_id, start, end)
    }
    if (config.dataSources.abnormal_values) {
      queries.abnormal_values = queryAbnormalValues(resident_id, start, end)
    }

    // รอ query ทั้งหมดพร้อมกัน
    const keys = Object.keys(queries)
    const values = await Promise.all(Object.values(queries))
    const results: Record<string, any[]> = {}
    keys.forEach((key, i) => {
      results[key] = values[i]
    })

    // Log จำนวนข้อมูลแต่ละตาราง
    for (const [key, arr] of Object.entries(results)) {
      if (arr.length > 0) console.log(`[generate-shift-summary] ${key}: ${arr.length} records`)
    }

    // 4. รวมข้อมูลเป็น structured text (รวมข้อมูลจากฟอร์มปัจจุบันด้วย)
    const dataText = buildDataText(results, current_form_data)

    // Log ว่ามีข้อมูลจากฟอร์มหรือไม่
    if (current_form_data) {
      const formKeys = Object.keys(current_form_data)
      console.log(`[generate-shift-summary] current_form_data keys: ${formKeys.join(', ')}`)
    }

    // DEBUG: สร้าง debug info สำหรับตรวจสอบ
    const debug = {
      timeRange: { start, end },
      recordCounts: Object.fromEntries(
        Object.entries(results).map(([k, v]) => [k, v.length])
      ),
      queryErrors: Object.keys(queryErrors).length > 0 ? queryErrors : undefined,
      inputDate: date,
      inputShift: shift,
      inputResidentId: resident_id,
    }

    // ถ้าไม่มีข้อมูลเลย ส่งกลับทันทีโดยไม่ต้องเรียก AI
    if (dataText === 'ไม่มีข้อมูลกิจกรรมในเวรนี้') {
      console.log('[generate-shift-summary] No data found, returning empty message')
      return new Response(JSON.stringify({
        content: 'ไม่มีข้อมูลกิจกรรมในเวรนี้',
        debug, // TODO: ลบ debug ออกเมื่อ production
      }), {
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    // 5. สร้าง prompt โดย replace template tags
    const prompt = config.prompt
      .replace(/\{\{RESIDENT_NAME\}\}/g, resident_name || 'ไม่ระบุชื่อ')
      .replace(/\{\{SHIFT\}\}/g, shift)
      .replace(/\{\{DATE\}\}/g, date)
      .replace(/\{\{DATA\}\}/g, dataText)

    console.log(`[generate-shift-summary] Prompt length: ${prompt.length} chars`)

    // 6. เรียก Gemini AI
    const model = genAI.getGenerativeModel({
      model: 'gemini-3-flash-preview',
      generationConfig: {
        temperature: 0.3, // ค่าต่ำเพื่อให้สรุปตรงตามข้อเท็จจริง
      },
    })

    const result = await model.generateContent(prompt)
    const responseText = result.response.text()

    console.log(`[generate-shift-summary] AI response length: ${responseText?.length || 0} chars`)

    if (!responseText || responseText.trim().length === 0) {
      throw new Error('Empty response from AI')
    }

    // 7. ส่งกลับ (รวม debug ด้วย — TODO: ลบ debug ออกเมื่อ production)
    return new Response(JSON.stringify({ content: responseText.trim(), debug }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })

  } catch (err: unknown) {
    console.error('[generate-shift-summary] Error:', err)
    const errorMessage = err instanceof Error ? err.message : String(err)
    return new Response(JSON.stringify({ error: errorMessage, content: '' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
