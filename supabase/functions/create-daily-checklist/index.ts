// create-daily-checklist/index.ts
// Edge Function: สร้าง task logs (checklist) รายวันจาก recurring tasks
// แทนที่ n8n workflow "Create Checklist" flow "สร้าง Task ปกติ"
//
// ถูกเรียกโดย pg_cron ทุกวัน 07:05 (เวลาไทย = 00:05 UTC)
//
// Logic:
// 1. ดึง recurring tasks ทั้งหมดที่ active (end_Date IS NULL) + resident status = Stay
// 2. คำนวณ recurrence ว่า task ไหนควรสร้างวันนี้
//    - สำหรับ is_next_day tasks (เวลาก่อน 07:00) → เช็ค recurrence กับ "วันพรุ่งนี้"
//    - เพราะ task เวลา 06:00 วันที่ 1 เม.ย. → ต้องสร้างตอน n8n run 31 มี.ค.
//    - Flutter adjust_date จะคำนวณเป็น 31 มี.ค. → เวรดึกเห็นงานถูกวัน
// 3. ตรวจว่ายังไม่มี log ซ้ำ (ป้องกัน duplicate)
// 4. INSERT เข้า A_Task_logs_ver2
//
// DRY_RUN: ส่ง ?dry_run=true เพื่อดู preview โดยไม่ INSERT จริง

import { createClient } from 'npm:@supabase/supabase-js@2'

// สร้าง Supabase client ด้วย service role key (bypass RLS)
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

// ────────────────────────────────────────────────────────
// Timezone & Date helpers (เวลาไทย Asia/Bangkok = UTC+7)
// ────────────────────────────────────────────────────────

// วันที่วันนี้ เวลาไทย (YYYY-MM-DD)
function getBangkokToday(): string {
  const now = new Date()
  return now.toLocaleDateString('en-CA', { timeZone: 'Asia/Bangkok' })
}

// วันที่พรุ่งนี้ เวลาไทย (YYYY-MM-DD)
function getBangkokTomorrow(): string {
  const now = new Date()
  // +1 วัน
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000)
  return tomorrow.toLocaleDateString('en-CA', { timeZone: 'Asia/Bangkok' })
}

// วันในสัปดาห์ (ภาษาไทย) จาก date string YYYY-MM-DD
// ★ ใช้ getUTCDay() + parse เป็น UTC midnight ตรงๆ เพื่อไม่ให้ timezone ของ server มีผล
const DAY_THAI = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์']
function getDayOfWeekThai(dateStr: string): string {
  // parse "2026-04-01" เป็น UTC midnight → getUTCDay() ได้วันถูกเสมอ
  const [y, m, d] = dateStr.split('-').map(Number)
  const utcDate = new Date(Date.UTC(y, m - 1, d))
  return DAY_THAI[utcDate.getUTCDay()]
}

// Normalize ชื่อวันไทยทุกรูปแบบเป็นชื่อเต็มมาตรฐาน
// DB อาจเก็บ 'พฤ' (ย่อ), 'พฤหัส' (กลาง), 'พฤหัสบดี' (เต็ม) ขึ้นกับแหล่งที่สร้าง
const DAY_NORMALIZE: Record<string, string> = {
  'จ': 'จันทร์', 'อ': 'อังคาร', 'พ': 'พุธ', 'พฤ': 'พฤหัสบดี',
  'ศ': 'ศุกร์', 'ส': 'เสาร์', 'อา': 'อาทิตย์',
  'พฤหัส': 'พฤหัสบดี', // กลาง → เต็ม
}
function normalizeDayName(day: string): string {
  return DAY_NORMALIZE[day] ?? day
}

// Parse YYYY-MM-DD → { year, month (1-based), day }
function parseDateParts(dateStr: string) {
  const [y, m, d] = dateStr.split('-').map(Number)
  return { year: y, month: m, day: d }
}

// ผลต่างเดือนระหว่าง 2 dates (YYYY-MM-DD strings)
function monthsDiff(startStr: string, endStr: string): number {
  const s = parseDateParts(startStr)
  const e = parseDateParts(endStr)
  return (e.year - s.year) * 12 + (e.month - s.month)
}

// จำนวนวันสุดท้ายของเดือน
function lastDayOfMonth(dateStr: string): number {
  const { year, month } = parseDateParts(dateStr)
  return new Date(year, month, 0).getDate()
}

// ผลต่างวันระหว่าง 2 dates (YYYY-MM-DD strings)
function daysDiff(startStr: string, endStr: string): number {
  const s = new Date(startStr + 'T00:00:00+07:00')
  const e = new Date(endStr + 'T00:00:00+07:00')
  return Math.floor((e.getTime() - s.getTime()) / (1000 * 60 * 60 * 24))
}

// ────────────────────────────────────────────────────────
// Recurrence Logic
// ────────────────────────────────────────────────────────

interface RecurringTask {
  repeated_task_id: number
  task_id: number
  title: string
  resident_id: number | null
  recurrenceType: string
  recurrenceInterval: number
  start_Date: string          // YYYY-MM-DD
  recurring_dates: number[] | null
  daysofweek: string[] | null
  previous_days: string[] | null
  is_next_day: number         // 0 หรือ 1
  start_time: string          // HH:MM:SS
  nursinghome_id: number | null
}

// ตรวจว่า task ควรสร้าง log วันนี้ไหม
// - calendarDate = วันที่ n8n/cron run (เวลาไทย YYYY-MM-DD)
// - สำหรับ is_next_day=1 tasks → เช็ค recurrence กับ "วันถัดไป"
function shouldCreateToday(task: RecurringTask, todayStr: string, tomorrowStr: string): boolean {
  const recurType = task.recurrenceType || 'วัน'
  const startDate = task.start_Date
  const interval = task.recurrenceInterval || 1

  // ★ สำหรับ monthly/yearly: ถ้า is_next_day=1 → เช็คกับวันพรุ่งนี้
  // เพราะ task เวลา 06:00 วันที่ 1 เม.ย. → ต้องสร้างตอน run 31 มี.ค.
  // เพื่อให้เวรดึก 31 มี.ค. เห็นงาน (Flutter adjust_date จะ -1 วัน)
  //
  // สำหรับ daily: ไม่ต้อง shift เพราะ interval=1 match ทุกวัน
  //   และถ้า shift จะทำให้ interval>1 (วันเว้นวัน) เพี้ยน
  // สำหรับ weekly: ใช้ previous_days จาก SQL view handle อยู่แล้ว

  switch (recurType) {
    case 'วัน': {
      // Daily — เช็คกับ todayStr เสมอ
      const diff = daysDiff(startDate, todayStr)
      return diff >= 0 && diff % interval === 0
    }

    case 'สัปดาห์': {
      // Weekly — ใช้ previous_days สำหรับ is_next_day (เหมือน n8n เดิม)
      const todayDow = getDayOfWeekThai(todayStr)
      const diff = daysDiff(startDate, todayStr)
      const weeksDiff = Math.floor(diff / 7)

      if (task.is_next_day === 1 && task.previous_days && task.previous_days.length > 0) {
        // Normalize ชื่อวันจาก DB ก่อน compare เพราะอาจเก็บเป็น 'พฤ', 'พฤหัส', หรือ 'พฤหัสบดี'
        const normalizedPrev = task.previous_days.map(normalizeDayName)
        return normalizedPrev.includes(todayDow) && weeksDiff >= 0 && weeksDiff % interval === 0
      } else if (task.daysofweek && task.daysofweek.length > 0) {
        const normalizedDow = task.daysofweek.map(normalizeDayName)
        return normalizedDow.includes(todayDow) && weeksDiff >= 0 && weeksDiff % interval === 0
      } else {
        // fallback: ใช้วันเดียวกับ start_Date
        const startDow = getDayOfWeekThai(startDate)
        return todayDow === startDow && weeksDiff >= 0 && weeksDiff % interval === 0
      }
    }

    case 'เดือน': {
      // ★ Monthly — ใช้ checkDate (วันพรุ่งนี้ถ้า is_next_day=1)
      const checkDate = task.is_next_day === 1 ? tomorrowStr : todayStr
      const { day: checkDay } = parseDateParts(checkDate)
      const lastDay = lastDayOfMonth(checkDate)
      const mDiff = monthsDiff(startDate, checkDate)

      // recurring_dates: ถ้าไม่กำหนด → ใช้วันที่ของ start_Date
      let recurDates = task.recurring_dates && task.recurring_dates.length > 0
        ? task.recurring_dates
        : [parseDateParts(startDate).day]

      // ปรับวันที่เกินจำนวนวันในเดือน → ใช้วันสุดท้ายของเดือน
      const validDates = recurDates.map(d => d > lastDay ? lastDay : d)

      if (validDates.includes(checkDay)) {
        return mDiff >= 0 && mDiff % interval === 0
      }
      return false
    }

    case 'ปี': {
      // ★ Yearly — ใช้ checkDate (วันพรุ่งนี้ถ้า is_next_day=1)
      const checkDate = task.is_next_day === 1 ? tomorrowStr : todayStr
      const { month: checkMonth, day: checkDay } = parseDateParts(checkDate)
      const { month: startMonth, day: startDay, year: startYear } = parseDateParts(startDate)
      const { year: checkYear } = parseDateParts(checkDate)
      const yDiff = checkYear - startYear

      if (checkMonth === startMonth && checkDay === startDay) {
        return yDiff >= 0 && yDiff % interval === 0
      }
      return false
    }

    default:
      console.warn(`Unknown recurrence type: ${recurType}`)
      return false
  }
}

// ────────────────────────────────────────────────────────
// ExpectedDateTime calculation
// ────────────────────────────────────────────────────────

// คำนวณ ExpectedDateTime สำหรับ task
// is_next_day=1 → วันพรุ่งนี้ + start_time
// is_next_day=0 → วันนี้ + start_time
function calcExpectedDateTime(task: RecurringTask, todayStr: string, tomorrowStr: string): string {
  const dateStr = task.is_next_day === 1 ? tomorrowStr : todayStr
  // start_time อาจเป็น "06:00:00" หรือ "06:00"
  const time = task.start_time.replace(/^"|"$/g, '')
  return `${dateStr} ${time}`
}

// ────────────────────────────────────────────────────────
// Main handler
// ────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  // CORS preflight
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
  // override วันที่สำหรับ testing เช่น ?date=2026-04-01
  const dateOverride = url.searchParams.get('date')
  // mode: "resident" (default) = tasks ที่มี resident (flow สร้าง Task ปกติ)
  //        "shared" = tasks ที่ resident_id IS NULL (flow สร้าง Task ให้ resident_id = null)
  //        "all" = ทั้งหมด (รวม 2 flows)
  const mode = url.searchParams.get('mode') || 'all'

  try {
    const todayStr = dateOverride || getBangkokToday()
    // คำนวณ tomorrow จาก todayStr
    const todayDate = new Date(todayStr + 'T00:00:00+07:00')
    const tomorrowDate = new Date(todayDate.getTime() + 24 * 60 * 60 * 1000)
    const tomorrowStr = dateOverride
      ? tomorrowDate.toLocaleDateString('en-CA', { timeZone: 'Asia/Bangkok' })
      : getBangkokTomorrow()
    console.log(`=== create-daily-checklist ===`)
    console.log(`Today (Bangkok): ${todayStr}, Tomorrow: ${tomorrowStr}, DRY_RUN: ${dryRun}, MODE: ${mode}`)

    // ────────────────────────────────────────────────────
    // Step 1: ดึง recurring tasks ที่ active
    // mode="resident" → tasks ที่มี resident + status Stay/zone (n8n flow 07:05)
    // mode="shared"   → tasks ที่ resident_id IS NULL (n8n flow 07:10)
    // mode="all"      → ทั้ง 2 flows รวมกัน
    // ────────────────────────────────────────────────────
    const selectCols = 'repeated_task_id, task_id, title, resident_id, recurrenceType, recurrenceInterval, start_Date, recurring_dates, daysofweek, previous_days, is_next_day, start_time, nursinghome_id, resident_status'
    let allTasks: RecurringTask[] = []

    if (mode === 'resident' || mode === 'all') {
      // Flow 1: tasks ที่มี resident (เดิมคือ n8n 07:05)
      const { data, error } = await supabase
        .from('v_tasks_with_logs')
        .select(selectCols)
        .is('end_Date', null)
        .not('resident_id', 'is', null)
        .in('resident_status', ['Stay', 'zone'])
      if (error) throw new Error(`Failed to fetch resident tasks: ${error.message}`)
      allTasks.push(...(data || []) as RecurringTask[])
    }

    if (mode === 'shared' || mode === 'all') {
      // Flow 2: tasks ที่ resident_id IS NULL (เดิมคือ n8n 07:10)
      const { data, error } = await supabase
        .from('v_tasks_with_logs')
        .select(selectCols)
        .is('end_Date', null)
        .is('resident_id', null)
      if (error) throw new Error(`Failed to fetch shared tasks: ${error.message}`)
      allTasks.push(...(data || []) as RecurringTask[])
    }

    const tasks = allTasks
    console.log(`Fetched ${tasks.length} active recurring tasks (mode=${mode})`)

    // ────────────────────────────────────────────────────
    // Step 2: Filter tasks ตาม recurrence rules
    // ────────────────────────────────────────────────────
    const matchedTasks: RecurringTask[] = []
    for (const task of (tasks || [])) {
      if (!task.title) continue
      if (shouldCreateToday(task as RecurringTask, todayStr, tomorrowStr)) {
        matchedTasks.push(task as RecurringTask)
      }
    }

    console.log(`Matched ${matchedTasks.length} tasks for today`)

    // ────────────────────────────────────────────────────
    // Step 3: ตรวจ duplicate — หา logs ที่สร้างแล้ววันนี้
    // เช็คจาก Task_Repeat_Id + ExpectedDateTime
    // ────────────────────────────────────────────────────
    const repeatIds = matchedTasks.map(t => t.repeated_task_id)

    // ดึง logs ที่สร้างวันนี้ (Bangkok time) สำหรับ repeat IDs ที่ match
    const { data: existingLogs, error: logsError } = await supabase
      .from('A_Task_logs_ver2')
      .select('Task_Repeat_Id, ExpectedDateTime')
      .in('Task_Repeat_Id', repeatIds.length > 0 ? repeatIds : [0])

    if (logsError) {
      console.warn(`Failed to check existing logs: ${logsError.message}`)
    }

    // สร้าง set ของ "repeatId|expectedDate" ที่มีอยู่แล้ว
    const existingSet = new Set<string>()
    for (const log of (existingLogs || [])) {
      if (log.ExpectedDateTime) {
        // แปลง ExpectedDateTime เป็น YYYY-MM-DD (Bangkok time)
        const dt = new Date(log.ExpectedDateTime)
        const dateStr = dt.toLocaleDateString('en-CA', { timeZone: 'Asia/Bangkok' })
        existingSet.add(`${log.Task_Repeat_Id}|${dateStr}`)
      }
    }

    // ────────────────────────────────────────────────────
    // Step 4: สร้าง logs ที่ยังไม่มี
    // ────────────────────────────────────────────────────
    const toInsert: Array<{
      Task_Repeat_Id: number
      task_id: number
      ExpectedDateTime: string
    }> = []

    for (const task of matchedTasks) {
      const expectedDT = calcExpectedDateTime(task, todayStr, tomorrowStr)
      // expectedDT = "YYYY-MM-DD HH:MM:SS" → ดึงเฉพาะ date part
      const expectedDateStr = expectedDT.split(' ')[0]
      const key = `${task.repeated_task_id}|${expectedDateStr}`

      if (existingSet.has(key)) {
        console.log(`SKIP (duplicate): ${task.title} [rt=${task.repeated_task_id}] expected=${expectedDT}`)
        continue
      }

      toInsert.push({
        Task_Repeat_Id: task.repeated_task_id,
        task_id: task.task_id,
        ExpectedDateTime: expectedDT,
      })
    }

    console.log(`To insert: ${toInsert.length} logs (skipped ${matchedTasks.length - toInsert.length} duplicates)`)

    // ────────────────────────────────────────────────────
    // Step 5: INSERT (ถ้าไม่ใช่ dry run)
    // ────────────────────────────────────────────────────
    let insertedCount = 0
    if (!dryRun && toInsert.length > 0) {
      // INSERT เป็น batch (Supabase รองรับ array insert)
      // แบ่ง batch ละ 100 เพื่อป้องกัน timeout
      const BATCH_SIZE = 100
      for (let i = 0; i < toInsert.length; i += BATCH_SIZE) {
        const batch = toInsert.slice(i, i + BATCH_SIZE)
        const { error: insertError } = await supabase
          .from('A_Task_logs_ver2')
          .insert(batch)

        if (insertError) {
          console.error(`Insert batch ${i / BATCH_SIZE + 1} failed: ${insertError.message}`)
          // ไม่ throw — ลอง batch ถัดไป
        } else {
          insertedCount += batch.length
        }
      }
    }

    // ────────────────────────────────────────────────────
    // Step 6: Mark Refer residents' tasks as "refer"
    // คนที่ s_special_status=Refer → mark ทุก log วันนี้เป็น status=refer
    // (เดิมคือ n8n flow 07:15)
    // ────────────────────────────────────────────────────
    const SYSTEM_USER_ID = '8378d45d-6823-4747-9c56-90c90e676f04'
    let referUpdatedCount = 0
    let referLogs: Array<{ log_id: number; ExpectedDateTime: string }> | null = []

    // ดึง residents ที่ Refer
    const { data: referResidents, error: referError } = await supabase
      .from('combined_resident_details_view')
      .select('resident_id')
      .eq('s_status', 'Stay')
      .eq('s_special_status', 'Refer')

    if (referError) {
      console.warn(`Failed to fetch refer residents: ${referError.message}`)
    }

    const referResidentIds = (referResidents || []).map(r => r.resident_id)
    console.log(`Refer residents: ${referResidentIds.length}`)

    if (referResidentIds.length > 0) {
      // ดึง task logs วันนี้ของ Refer residents (ใช้ adjust_date)
      // adjust_date = todayStr สำหรับ tasks ที่ is_next_day=0
      // adjust_date = todayStr สำหรับ tasks ที่ is_next_day=1 (เพราะ expected tomorrow 06:00 → adjust = today)
      const { data: referLogsData, error: referLogsError } = await supabase
        .from('v2_task_logs_with_details')
        .select('log_id, ExpectedDateTime')
        .is('end_Date', null)
        .eq('adjust_date', todayStr)
        .in('resident_id', referResidentIds)

      if (referLogsError) {
        console.warn(`Failed to fetch refer logs: ${referLogsError.message}`)
      }

      referLogs = referLogsData
      const referLogIds = (referLogs || []).map(l => l.log_id)
      console.log(`Refer task logs to update: ${referLogIds.length}`)

      if (!dryRun && referLogIds.length > 0) {
        // UPDATE แต่ละ log เป็น refer status
        // ใช้ batch update ทีละ 50
        for (let i = 0; i < referLogIds.length; i += 50) {
          const batchIds = referLogIds.slice(i, i + 50)
          const { error: updateError } = await supabase
            .from('A_Task_logs_ver2')
            .update({
              completed_by: SYSTEM_USER_ID,
              completed_at: new Date().toISOString(),
              Descript: 'อยู่ที่โรงพยาบาล (Refer)',
              status: 'refer',
            })
            .in('id', batchIds)

          if (updateError) {
            console.error(`Refer update batch failed: ${updateError.message}`)
          } else {
            referUpdatedCount += batchIds.length
          }
        }
      }
    }

    // ────────────────────────────────────────────────────
    // Response
    // ────────────────────────────────────────────────────
    const result = {
      success: true,
      dry_run: dryRun,
      mode,
      today: todayStr,
      tomorrow: tomorrowStr,
      total_active_tasks: tasks?.length || 0,
      matched_tasks: matchedTasks.length,
      skipped_duplicates: matchedTasks.length - toInsert.length,
      inserted: dryRun ? 0 : insertedCount,
      would_insert: dryRun ? toInsert.length : undefined,
      refer_residents: referResidentIds.length,
      refer_logs_updated: dryRun ? 0 : referUpdatedCount,
      refer_logs_would_update: dryRun ? (referLogs || []).length : undefined,
      // ใน dry_run mode: แสดง preview + matched rt_ids สำหรับเทียบกับ n8n
      preview: dryRun ? toInsert.map(t => ({
        ...t,
        title: matchedTasks.find(m => m.repeated_task_id === t.Task_Repeat_Id)?.title,
      })) : undefined,
      matched_rt_ids: dryRun ? matchedTasks.map(t => t.repeated_task_id).sort((a, b) => a - b) : undefined,
    }

    console.log(`Result: inserted=${dryRun ? 0 : insertedCount}, matched=${matchedTasks.length}`)

    return new Response(JSON.stringify(result), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  } catch (err) {
    console.error(`Error: ${err}`)
    return new Response(JSON.stringify({ success: false, error: String(err) }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  }
})
