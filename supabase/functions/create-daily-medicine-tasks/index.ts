// create-daily-medicine-tasks/index.ts
// Edge Function: สร้าง medicine tasks (C_Tasks + A_Task_logs_ver2) รายวัน
// แทนที่ n8n workflow "Create Checklist" flow "task ของยา" (trigger ตี 4)
//
// Logic:
// 1. ดึง residents จาก n8n_agent_resident_profile
// 2. แยก Feed vs ไม่มี Feed จาก A_Tasks (taskType='Feed') → ใช้ TIME_SLOTS ต่างกัน
// 3. ดึงยาจาก n8n_medicine_summary per resident
// 4. Filter: isToday (วัน/สัปดาห์ schedule), skip PRN, skip waiting
// 5. Group ยาตาม slot (เช้า/กลางวัน/เย็น/ก่อนนอน × ก่อน/หลังอาหาร)
// 6. สร้าง C_Tasks + A_Task_logs_ver2
// 7. นับ total_dose → INSERT "Medication Error Rate"
//
// DRY_RUN: ?dry_run=true → preview โดยไม่ INSERT
// DATE OVERRIDE: ?date=2026-04-01 → simulate วันอื่น

import { createClient } from 'npm:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

// ────────────────────────────────────────────────────────
// Constants
// ────────────────────────────────────────────────────────

const CREATOR_ID = '8378d45d-6823-4747-9c56-90c90e676f04'
const TASK_TYPE = 'จัดยา'
const ASSIGNED_ROLE_ID = 7

// TIME_SLOTS สำหรับคนปกติ (ไม่มี Feed)
const TIME_SLOTS_NORMAL: Record<string, { time: string; label: string }> = {
  'เช้า|ก่อนอาหาร':    { time: '07:30', label: 'ให้ยา 🍛ก่อนอาหาร 🌅เช้า' },
  'เช้า|หลังอาหาร':    { time: '08:30', label: 'ให้ยา 🍽️หลังอาหาร 🌅เช้า' },
  'กลางวัน|ก่อนอาหาร':  { time: '11:30', label: 'ให้ยา 🍛ก่อนอาหาร ☀️กลางวัน' },
  'กลางวัน|หลังอาหาร':  { time: '12:30', label: 'ให้ยา 🍽️หลังอาหาร ☀️กลางวัน' },
  'เย็น|ก่อนอาหาร':     { time: '16:30', label: 'ให้ยา 🍛ก่อนอาหาร 🌇เย็น' },
  'เย็น|หลังอาหาร':     { time: '17:30', label: 'ให้ยา 🍽️หลังอาหาร 🌇เย็น' },
  'ก่อนนอน|':            { time: '20:00', label: '🌙ให้ยาก่อนนอน💤' },
}

// TIME_SLOTS สำหรับคนที่มี Feed (เวลาเร็วกว่า)
const TIME_SLOTS_FEED: Record<string, { time: string; label: string }> = {
  'เช้า|ก่อนอาหาร':    { time: '05:30', label: 'ให้ยา 🍛ก่อนอาหาร 🌅เช้า' },
  'เช้า|หลังอาหาร':    { time: '06:45', label: 'ให้ยา 🍽️หลังอาหาร 🌅เช้า' },
  'กลางวัน|ก่อนอาหาร':  { time: '10:30', label: 'ให้ยา 🍛ก่อนอาหาร ☀️กลางวัน' },
  'กลางวัน|หลังอาหาร':  { time: '11:45', label: 'ให้ยา 🍽️หลังอาหาร ☀️กลางวัน' },
  'เย็น|ก่อนอาหาร':     { time: '15:30', label: 'ให้ยา 🍛ก่อนอาหาร 🌇เย็น' },
  'เย็น|หลังอาหาร':     { time: '16:45', label: 'ให้ยา 🍽️หลังอาหาร 🌇เย็น' },
  'ก่อนนอน|':            { time: '21:45', label: '🌙ให้ยาก่อนนอน💤' },
}

// ────────────────────────────────────────────────────────
// Date/Time helpers (Bangkok timezone)
// ────────────────────────────────────────────────────────

function getBangkokToday(): string {
  return new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Bangkok' })
}

function parseDateParts(dateStr: string) {
  const [y, m, d] = dateStr.split('-').map(Number)
  return { year: y, month: m, day: d }
}

// วันในสัปดาห์ภาษาไทย (ใช้ UTC เพื่อไม่ให้ server timezone มีผล)
const DAY_THAI = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์']
function getDayOfWeekThai(dateStr: string): string {
  const [y, m, d] = dateStr.split('-').map(Number)
  return DAY_THAI[new Date(Date.UTC(y, m - 1, d)).getUTCDay()]
}

// Normalize ชื่อวันไทยทุกรูปแบบเป็นชื่อเต็มมาตรฐาน
// DB อาจเก็บ 'พฤ' (ย่อ), 'พฤหัส' (กลาง), 'พฤหัสบดี' (เต็ม) ขึ้นกับว่าสร้างจากที่ไหน
const DAY_NORMALIZE: Record<string, string> = {
  'จ': 'จันทร์', 'อ': 'อังคาร', 'พ': 'พุธ', 'พฤ': 'พฤหัสบดี',
  'ศ': 'ศุกร์', 'ส': 'เสาร์', 'อา': 'อาทิตย์',
  'พฤหัส': 'พฤหัสบดี', // กลาง → เต็ม
}
function normalizeDayName(day: string): string {
  return DAY_NORMALIZE[day] ?? day
}

function daysDiffStr(startStr: string, endStr: string): number {
  const s = new Date(startStr + 'T00:00:00+07:00')
  const e = new Date(endStr + 'T00:00:00+07:00')
  return Math.floor((e.getTime() - s.getTime()) / (1000 * 60 * 60 * 24))
}

// timeBlock จากชั่วโมง
function calcTimeBlock(hour: number): string {
  let start = (hour === 0) ? 23 : (hour % 2 === 0 ? hour - 1 : hour)
  if (start < 1) start = 23
  const end = (start + 2) % 24
  return `${String(start).padStart(2, '0')}:00 - ${String(end).padStart(2, '0')}:00`
}

// คำนวณ created_at สำหรับ medicine log
// ถ้า ExpectedDateTime ก่อน 07:00 → created_at = เมื่อวาน (YYYY-MM-DD)
// ถ้าไม่ → created_at = now (ISO Bangkok)
function calcCreatedAt(expectedTime: string, todayStr: string): string {
  const [hh] = expectedTime.split(':').map(Number)
  if (hh < 7) {
    // เมื่อวาน
    const { year, month, day } = parseDateParts(todayStr)
    const yesterday = new Date(Date.UTC(year, month - 1, day - 1))
    const y = yesterday.getUTCFullYear()
    const m = String(yesterday.getUTCMonth() + 1).padStart(2, '0')
    const d = String(yesterday.getUTCDate()).padStart(2, '0')
    return `${y}-${m}-${d}`
  }
  // now ในเวลาไทย
  const now = new Date()
  return now.toISOString()
}

// ────────────────────────────────────────────────────────
// Medicine schedule check: ยาตัวนี้ต้องให้วันนี้ไหม
// ────────────────────────────────────────────────────────

interface MedRow {
  medicine_list_id: number
  resident_id: number
  nursinghome_id: number
  resident_name: string
  brand_name: string | null
  generic_name: string | null
  str: string | null
  take_tab: string | null
  BLDB: string[] | null
  BeforeAfter: string[] | null
  every_hr: number
  typeOfTime: string
  DaysOfWeek: string[] | null
  prn: boolean
  first_med_history_on_date: string | null
  last_med_history_off_date: string | null
  status: string | null
}

function isMedToday(med: MedRow, todayStr: string): boolean {
  const startRaw = med.first_med_history_on_date
  if (!startRaw) return false

  const startStr = startRaw.slice(0, 10) // YYYY-MM-DD
  const endRaw = med.last_med_history_off_date
  const endStr = endRaw ? endRaw.slice(0, 10) : null

  // นอกช่วง start–end
  if (todayStr < startStr) return false
  if (endStr && todayStr > endStr) return false

  const type = med.typeOfTime || 'วัน'
  const every = med.every_hr || 1

  // ชั่วโมง → วันนี้มีแน่
  if (type === 'ชั่วโมง') return true

  if (type === 'วัน') {
    const diff = daysDiffStr(startStr, todayStr)
    return diff >= 0 && diff % every === 0
  }

  if (type === 'สัปดาห์') {
    const diff = daysDiffStr(startStr, todayStr)
    const wDiff = Math.floor(diff / 7)

    let dowArr = med.DaysOfWeek || []
    if (!Array.isArray(dowArr)) dowArr = []
    // fallback: ถ้าไม่กรอก DaysOfWeek → ใช้วันเดียวกับวันเริ่ม
    if (dowArr.length === 0) {
      dowArr = [getDayOfWeekThai(startStr)]
    }

    // Normalize ชื่อวันจาก DB เป็นชื่อเต็มก่อน compare
    // เพราะ DB อาจเก็บ 'พฤ', 'พฤหัส', หรือ 'พฤหัสบดี' ขึ้นกับแหล่งที่สร้าง
    const normalizedDow = dowArr.map(normalizeDayName)
    const todayDow = getDayOfWeekThai(todayStr)
    return normalizedDow.includes(todayDow) && wDiff >= 0 && wDiff % every === 0
  }

  return false
}

// ────────────────────────────────────────────────────────
// Group medicines → task items
// ────────────────────────────────────────────────────────

interface TaskItem {
  title: string
  description: string
  resident_id: number
  nursinghome_id: number
  creator_id: string
  taskType: string
  dose_count: number
  start_Date: string    // YYYY-MM-DD
  startTime: string     // HH:MM
  ExpectedDateTime: string  // YYYY-MM-DD HH:MM:SS
  timeBlock: string
  assigned_role_id: number
  created_at_override: string  // สำหรับ log
}

function buildMedTasks(
  meds: MedRow[],
  todayStr: string,
  timeSlots: Record<string, { time: string; label: string }>,
): TaskItem[] {
  // Group by resident → slot
  const residentMap = new Map<number, {
    name: string
    nursinghome_id: number
    slots: Record<string, string[]>
  }>()

  for (const med of meds) {
    if (!isMedToday(med, todayStr)) continue
    if (med.prn) continue
    if (med.status === 'waiting') continue
    if (med.resident_id == null) continue

    if (!residentMap.has(med.resident_id)) {
      residentMap.set(med.resident_id, {
        name: med.resident_name || '',
        nursinghome_id: med.nursinghome_id,
        slots: {},
      })
    }
    const rec = residentMap.get(med.resident_id)!

    const bldb = Array.isArray(med.BLDB) ? med.BLDB : []
    let ba = Array.isArray(med.BeforeAfter) && med.BeforeAfter.length > 0
      ? med.BeforeAfter : ['']

    const takeTab = med.take_tab
    const doseTxt = (takeTab != null && String(takeTab).trim() !== '')
      ? ` (${takeTab})` : ''
    const line = `💊 ${med.generic_name || ''} (${med.brand_name || ''}) ${med.str || ''}${doseTxt}`

    for (const dose of bldb) {
      for (let bef of ba) {
        const befKey = dose === 'ก่อนนอน' ? '' : bef
        const key = `${dose}|${befKey}`
        if (!timeSlots[key]) continue
        if (!rec.slots[key]) rec.slots[key] = []
        rec.slots[key].push(line)
      }
    }
  }

  // สร้าง task items
  const items: TaskItem[] = []
  for (const [rid, { name, nursinghome_id, slots }] of residentMap.entries()) {
    for (const key of Object.keys(slots)) {
      const slot = timeSlots[key]
      const [hh, mm] = slot.time.split(':').map(Number)
      const doseCount = slots[key].length

      items.push({
        title: `${slot.label} สำหรับคุณ ${name} (${doseCount} ตัว)`,
        description: slots[key].join('\n'),
        resident_id: rid,
        nursinghome_id,
        creator_id: CREATOR_ID,
        taskType: TASK_TYPE,
        dose_count: doseCount,
        start_Date: todayStr,
        startTime: slot.time,
        ExpectedDateTime: `${todayStr} ${slot.time}:00`,
        timeBlock: calcTimeBlock(hh),
        assigned_role_id: ASSIGNED_ROLE_ID,
        created_at_override: calcCreatedAt(slot.time, todayStr),
      })
    }
  }

  // Sort by time
  items.sort((a, b) => {
    const [ah, am] = a.startTime.split(':').map(Number)
    const [bh, bm] = b.startTime.split(':').map(Number)
    return (ah * 60 + am) - (bh * 60 + bm)
  })

  return items
}

// ────────────────────────────────────────────────────────
// Main handler
// ────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
      },
    })
  }

  const url = new URL(req.url)
  const dryRun = url.searchParams.get('dry_run') === 'true'
  const dateOverride = url.searchParams.get('date')
  const todayStr = dateOverride || getBangkokToday()
  // resident_id: สร้างเฉพาะ resident คนเดียว (สำหรับเรียกตอนเพิ่มยาระหว่างวัน)
  const residentIdFilter = url.searchParams.get('resident_id')
    ? Number(url.searchParams.get('resident_id'))
    : null

  try {
    console.log(`=== create-daily-medicine-tasks ===`)
    console.log(`Today: ${todayStr}, DRY_RUN: ${dryRun}, resident_id: ${residentIdFilter || 'all'}`)

    // Step 1: ดึง residents (ถ้ามี resident_id filter → ดึงเฉพาะคนนั้น)
    let resQuery = supabase
      .from('n8n_agent_resident_profile')
      .select('resident_id, full_name, nursinghome_id')
    if (residentIdFilter) {
      resQuery = resQuery.eq('resident_id', residentIdFilter)
    }
    const { data: residents, error: resError } = await resQuery

    if (resError) throw new Error(`Failed to fetch residents: ${resError.message}`)
    console.log(`Residents: ${residents?.length || 0}`)

    // แยก Feed vs Normal — detect จาก A_Tasks ที่หัวหน้าเวรจัดจริง
    // (เดิมใช้ program_list.includes('🍼Feed') ซึ่งหัวหน้าเวรลืมใส่บ่อย ทำให้ได้เวลายาผิด)
    // เอาเฉพาะ resident ที่ status='Stay' (อยู่ใน residentIds จาก Step 1)
    const allResidentIds = (residents || []).map(r => r.resident_id).filter(Boolean)
    let feedQuery = supabase
      .from('A_Tasks')
      .select('resident_id')
      .eq('taskType', 'Feed')
      .in('resident_id', allResidentIds)
    if (residentIdFilter) {
      feedQuery = feedQuery.eq('resident_id', residentIdFilter)
    }
    const { data: feedRows, error: feedError } = await feedQuery
    if (feedError) throw new Error(`Failed to fetch Feed tasks: ${feedError.message}`)

    // สร้าง set ของ resident ที่มี Feed tasks (เฉพาะคนที่ Stay เท่านั้น)
    const feedResidentIds = new Set<number>(
      (feedRows || []).map(r => r.resident_id).filter(Boolean)
    )

    const normalResidentIds = new Set<number>()
    for (const r of (residents || [])) {
      if (!feedResidentIds.has(r.resident_id)) {
        normalResidentIds.add(r.resident_id)
      }
    }
    console.log(`Feed residents: ${feedResidentIds.size}, Normal: ${normalResidentIds.size}`)

    // Step 2: ดึงยา (ถ้ามี resident_id filter → ดึงเฉพาะคนนั้น)
    let medQuery = supabase.from('n8n_medicine_summary').select('*')
    if (residentIdFilter) {
      medQuery = medQuery.eq('resident_id', residentIdFilter)
    }
    const { data: allMeds, error: medError } = await medQuery

    if (medError) throw new Error(`Failed to fetch medicines: ${medError.message}`)
    console.log(`Total medicine rows: ${allMeds?.length || 0}`)

    // แยกยาตาม Feed/Normal
    const feedMeds = (allMeds || []).filter(m => feedResidentIds.has(m.resident_id)) as MedRow[]
    const normalMeds = (allMeds || []).filter(m => normalResidentIds.has(m.resident_id)) as MedRow[]

    // Step 3: สร้าง task items
    const feedTasks = buildMedTasks(feedMeds, todayStr, TIME_SLOTS_FEED)
    const normalTasks = buildMedTasks(normalMeds, todayStr, TIME_SLOTS_NORMAL)
    const allTasks = [...feedTasks, ...normalTasks]

    console.log(`Feed tasks: ${feedTasks.length}, Normal tasks: ${normalTasks.length}, Total: ${allTasks.length}`)

    // Step 4: Duplicate check — ดู C_Tasks ที่สร้างแล้ววันนี้
    // เช็คจาก: taskType=จัดยา + resident_id + start_Date = today + title (slot label)
    const residentIdsInTasks = [...new Set(allTasks.map(t => t.resident_id))]
    let existingQuery = supabase
      .from('C_Tasks')
      .select('resident_id, startTme')
      .eq('taskType', TASK_TYPE)
      .eq('start_Date', todayStr)
    if (residentIdsInTasks.length > 0) {
      existingQuery = existingQuery.in('resident_id', residentIdsInTasks)
    }
    const { data: existingCTasks } = await existingQuery

    // สร้าง set ของ "resident_id|startTime" ที่มีอยู่แล้ว
    // เช็คจาก slot เวลา (startTime) ไม่ใช่ title เพราะ title เปลี่ยนตาม dose count
    // DB เก็บ startTme เป็น "HH:MM:SS" แต่ EF ใช้ "HH:MM" → ตัด :SS ออก
    const existingSet = new Set<string>()
    for (const ct of (existingCTasks || [])) {
      const time = ct.startTme ? ct.startTme.slice(0, 5) : ''  // "05:30:00" → "05:30"
      existingSet.add(`${ct.resident_id}|${time}`)
    }
    console.log(`Existing C_Tasks today: ${existingSet.size}`)

    // Step 5: INSERT C_Tasks + A_Task_logs_ver2 (skip duplicates)
    let createdCTasks = 0
    let createdLogs = 0
    let skippedDuplicates = 0
    let totalDoseCount = 0
    let firstNursinghomeId: number | null = null

    for (const task of allTasks) {
      totalDoseCount += task.dose_count
      if (!firstNursinghomeId) firstNursinghomeId = task.nursinghome_id

      // Duplicate check: ถ้ามี C_Task เดิมที่ resident + slot เวลา + วันนี้ตรงกันแล้ว → skip
      // เช็คจาก startTime (slot เวลา) ไม่ใช่ title เพราะถ้าเพิ่มยาใหม่ title จะเปลี่ยน (dose count ต่าง)
      const key = `${task.resident_id}|${task.startTime}`
      if (existingSet.has(key)) {
        skippedDuplicates++
        continue
      }

      if (dryRun) continue

      // INSERT C_Task
      const { data: cTask, error: cErr } = await supabase
        .from('C_Tasks')
        .insert({
          title: task.title,
          description: task.description,
          resident_id: task.resident_id,
          creator_id: task.creator_id,
          nursinghome_id: task.nursinghome_id,
          taskType: task.taskType,
          start_Date: task.start_Date,
          startTme: task.startTime,
          timeBlock: task.timeBlock,
          assigned_role_id: task.assigned_role_id,
        })
        .select('id')
        .single()

      if (cErr) {
        console.error(`C_Task insert failed: ${cErr.message}`)
        continue
      }
      createdCTasks++

      // INSERT A_Task_logs_ver2
      const { error: logErr } = await supabase
        .from('A_Task_logs_ver2')
        .insert({
          c_task_id: cTask.id,
          ExpectedDateTime: task.ExpectedDateTime,
          created_at: task.created_at_override,
        })

      if (logErr) {
        console.error(`Log insert failed: ${logErr.message}`)
      } else {
        createdLogs++
      }
    }

    // Step 6: INSERT Medication Error Rate (total dose count)
    // ไม่ INSERT ถ้า: dry_run, เรียกด้วย resident_id (เฉพาะคน), หรือมี duplicate ทั้งหมด
    let medErrorRateInserted = false
    if (!dryRun && !residentIdFilter && totalDoseCount > 0 && firstNursinghomeId && skippedDuplicates < allTasks.length) {
      const { error: merErr } = await supabase
        .from('Medication Error Rate')
        .insert({
          total_dose: totalDoseCount,
          nursinghome_id: firstNursinghomeId,
        })
      if (merErr) {
        console.error(`Medication Error Rate insert failed: ${merErr.message}`)
      } else {
        medErrorRateInserted = true
      }
    }

    // Response
    const result = {
      success: true,
      dry_run: dryRun,
      today: todayStr,
      residents_total: residents?.length || 0,
      residents_feed: feedResidentIds.size,
      residents_normal: normalResidentIds.size,
      medicine_rows: allMeds?.length || 0,
      tasks_feed: feedTasks.length,
      tasks_normal: normalTasks.length,
      tasks_total: allTasks.length,
      skipped_duplicates: skippedDuplicates,
      would_create: allTasks.length - skippedDuplicates,
      total_dose_count: totalDoseCount,
      resident_id_filter: residentIdFilter,
      created_c_tasks: dryRun ? 0 : createdCTasks,
      created_logs: dryRun ? 0 : createdLogs,
      med_error_rate_inserted: dryRun ? false : medErrorRateInserted,
      // dry_run preview (แค่ 10 ตัวแรก เพื่อไม่ให้ response ใหญ่เกิน)
      preview: dryRun ? allTasks.slice(0, 10).map(t => ({
        title: t.title,
        startTime: t.startTime,
        ExpectedDateTime: t.ExpectedDateTime,
        dose_count: t.dose_count,
        resident_id: t.resident_id,
        created_at_override: t.created_at_override,
      })) : undefined,
    }

    console.log(`Result: tasks=${allTasks.length}, doses=${totalDoseCount}`)

    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (err) {
    console.error(`Error: ${err}`)
    return new Response(JSON.stringify({ success: false, error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
