// checklist-shift-summary/index.ts
// สรุป Checklist ส่ง LINE ตอนจบเวร — query DB จริง ส่งทีละ 1 bubble ต่อ 1 คนไข้
// Cron: 08:00 → shift=night (สรุปเวรดึกเมื่อคืน) / 20:00 → shift=morning (สรุปเวรเช้าวันนี้)
// ⚠️ DEV MODE: ส่งไปห้อง dev (resident_id=3) เท่านั้น

import { pushToLine } from '../_shared/line-flex.ts'

const LINE_TOKEN = Deno.env.get('LINE_CHANNEL_ACCESS_TOKEN') || ''
const DEV_LINE_GROUP_ID = 'C57c1c76d5500d7eb9d617e1590734290'

// ============================================
// Constants
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

// ============================================
// Types
// ============================================

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
}

interface CatItem {
  title: string; time: string; status: string | null; note: string | null
  problem_type?: string | null; resolution_status?: string | null
  resolution_note?: string | null; resolved_by?: string | null
  has_photo?: boolean; completed_at?: string | null
  confirm_image_url?: string | null  // URL รูปยืนยัน — ให้ญาติกดดูได้
}

interface CatGroup { taskType: string; emoji: string; items: CatItem[] }

// ตัด emoji ออกจาก title เพื่อจัดกลุ่ม/แสดงผลสะอาด
const stripEmoji = (s: string) => s.replace(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}\u{200D}]/gu, '').trim()

// ============================================
// จัดกลุ่ม + สร้าง bubble (เหมือน test-checklist-summary)
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
    })
  }

  const sorted = [...groups.values()].sort((a, b) => {
    const ia = TASK_TYPE_ORDER.indexOf(a.taskType), ib = TASK_TYPE_ORDER.indexOf(b.taskType)
    return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib)
  })

  return { categories: sorted, totalDone, totalProblem, totalPending, totalRefer, totalWithPhoto, total: tasks.length, staffNames: [...staffSet] }
}

function buildBubble(
  name: string, residentId: number, shiftLabel: string, shiftEmoji: string,
  dateLabel: string, data: ReturnType<typeof categorizeTasks>,
  summaryId: string,  // UUID จาก checklist_summaries — ใช้เป็น link ไปหน้าเว็บ
): Record<string, unknown> {
  const c: Record<string, unknown>[] = []

  // Header
  c.push({ type: 'text', text: `${shiftEmoji} เช็คลิสต์${shiftLabel}`, weight: 'bold', size: 'lg', color: '#1a1a1a' })
  c.push({ type: 'text', text: name, size: 'sm', color: '#666666', margin: 'xs' })
  c.push({ type: 'text', text: dateLabel, size: 'xs', color: '#999999', margin: 'xs' })
  c.push({ type: 'separator', margin: 'lg' })

  // สรุป
  const act = data.total - data.totalRefer
  if (data.totalRefer === data.total) {
    c.push({ type: 'text', text: `🏥 อยู่โรงพยาบาล — ${data.totalRefer} รายการ (Refer)`, size: 'sm', weight: 'bold', color: '#3498DB', margin: 'lg' })
  } else {
    const ok = data.totalProblem === 0 && data.totalPending === 0
    const emoji = ok ? '✅' : data.totalProblem > 0 ? '⚠️' : '🔄'
    const color = ok ? '#27AE60' : data.totalProblem > 0 ? '#F39C12' : '#3498DB'
    let txt = `${emoji} สำเร็จ ${data.totalDone}/${act}`
    if (data.totalProblem > 0) txt += `  ❌ ติดปัญหา ${data.totalProblem}`
    if (data.totalPending > 0) txt += `  ⏳ รอ ${data.totalPending}`
    if (data.totalRefer > 0) txt += `  🏥 Refer ${data.totalRefer}`
    c.push({ type: 'text', text: txt, size: 'sm', weight: 'bold', color, margin: 'lg' })

    // แสดง photo count — ญาติเห็นว่ายืนยันด้วยรูปจริง
    if (data.totalWithPhoto > 0) {
      c.push({ type: 'text', text: `📸 ยืนยันด้วยรูปถ่าย ${data.totalWithPhoto}/${data.totalDone} รายการ`, size: 'xs', color: '#888888', margin: 'sm' })
    }
  }

  // หมวด
  for (const g of data.categories) {
    c.push({ type: 'separator', margin: 'lg' })
    const cnt = g.items.length > 1 ? ` (${g.items.length} ครั้ง)` : ''
    c.push({ type: 'text', text: `${g.emoji} ${g.taskType}${cnt}`, size: 'sm', weight: 'bold', color: '#333333', margin: 'lg' })

    const uniq = new Set(g.items.map(i => stripEmoji(i.title)))

    // ใช้ time grid เฉพาะเมื่อ title เหมือนกันทั้งหมด AND ไม่มี problem (เพราะ problem ต้องแสดงเหตุผล)
    // AND ไม่มี completion note (เพราะ grid ไม่มีที่แสดง 📝 note → fall back เป็น per-item เพื่อไม่ให้ note หายเงียบ)
    const hasProblem = g.items.some(i => i.status === 'problem')
    const hasCompleteNote = g.items.some(i => i.status === 'complete' && i.note)
    if (uniq.size === 1 && g.items.length > 1 && !hasProblem && !hasCompleteNote) {
      c.push({ type: 'text', text: [...uniq][0], size: 'xs', color: '#777777', margin: 'sm' })
      for (let i = 0; i < g.items.length; i += 4) {
        const line = g.items.slice(i, i + 4).map(it => {
          const ic = it.status === 'complete' ? '☑' : it.status === 'problem' ? '✗' : it.status === 'refer' ? '🏥' : '○'
          const photo = it.has_photo ? '📸' : ''
          return `${ic} ${it.time}${photo}`
        }).join('  ')
        c.push({ type: 'text', text: line, size: 'xs', color: '#555555', margin: 'sm' })
      }
    } else {
      for (const it of g.items) {
        const ic = it.status === 'complete' ? '☑' : it.status === 'problem' ? '✗' : it.status === 'refer' ? '🏥' : '○'
        const col = it.status === 'problem' ? '#E74C3C' : it.status === 'refer' ? '#3498DB' : it.status === 'complete' ? '#555555' : '#999999'
        const photo = it.has_photo ? ' 📸' : ''
        c.push({ type: 'text', text: `${ic} ${stripEmoji(it.title)} ${it.time}${photo}`, size: 'xs', color: col, wrap: true, margin: 'sm' })

        if (it.status === 'problem') {
          const rl = PROBLEM_LABEL[it.problem_type || ''] || ''
          const dt = it.note ? `: ${it.note}` : ''
          c.push({ type: 'text', text: `    เหตุผล: ${rl ? rl + dt : (it.note || 'ไม่ระบุ')}`, size: 'xxs', color: '#E74C3C', wrap: true, margin: 'none' })
          if (it.resolution_status && it.resolution_status !== 'dismiss') {
            let rd = it.resolution_status
            if (it.resolution_note) { const p = it.resolution_note.split('|'); rd = p.length > 1 ? p.slice(1).join('|') : p[0] }
            c.push({ type: 'text', text: `    จัดการ: ${rd}${it.resolved_by ? ` (${it.resolved_by})` : ''}`, size: 'xxs', color: '#F39C12', wrap: true, margin: 'none' })
          }
        }
        if (it.status === 'refer' && it.note) {
          c.push({ type: 'text', text: `    ${it.note}`, size: 'xxs', color: '#3498DB', wrap: true, margin: 'none' })
        }
        // หมายเหตุของ complete task (user ระบุตอนทำเสร็จ) — สีเขียวให้สอดคล้องกับ status "เสร็จเรียบร้อย"
        if (it.status === 'complete' && it.note) {
          c.push({ type: 'text', text: `    📝 ${it.note}`, size: 'xxs', color: '#27AE60', wrap: true, margin: 'none' })
        }
      }
    }
  }

  c.push({ type: 'separator', margin: 'lg' })
  c.push({ type: 'text', text: `ผู้ดูแล: ${data.staffNames.join(', ') || '-'}`, size: 'xs', color: '#888888', margin: 'md' })

  // ไม่มี CTA — pause เรื่อง share ไว้ก่อน
  return {
    type: 'bubble', size: 'mega',
    body: { type: 'box', layout: 'vertical', spacing: 'sm', paddingAll: '16px', contents: c },
  }
}

// ============================================
// Main Handler
// ============================================

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url)
    const shift = url.searchParams.get('shift') || 'morning'
    const dateOverride = url.searchParams.get('date') // สำหรับทดสอบ เช่น 2026-03-20
    // Filter เฉพาะ resident id เดียว — ใช้ตอน test ไม่ให้ flood DEV group ด้วย bubble ทุกคน
    const residentFilter = url.searchParams.get('resident_id')
      ? Number(url.searchParams.get('resident_id'))
      : null

    // คำนวณช่วงเวลา
    const now = new Date()
    const bkk = new Date(now.getTime() + 7 * 3600000)
    const today = dateOverride || bkk.toISOString().substring(0, 10)
    const yesterdayDate = new Date(new Date(today + 'T00:00:00Z').getTime() - 86400000).toISOString().substring(0, 10)

    let startTime: string, endTime: string, shiftLabel: string, shiftEmoji: string, dateLabel: string

    if (shift === 'night') {
      startTime = `${yesterdayDate} 19:00:00+07`
      endTime = `${today} 07:00:00+07`
      shiftLabel = 'เวรดึก'
      shiftEmoji = '🌙'
      dateLabel = `${yesterdayDate} 19:00 – ${today} 07:00`
    } else {
      startTime = `${today} 07:00:00+07`
      endTime = `${today} 19:00:00+07`
      shiftLabel = 'เวรเช้า'
      shiftEmoji = '☀️'
      dateLabel = `${today} (07:00 – 19:00)`
    }

    console.log(`Shift=${shift}, Date=${today}, Range: ${startTime} → ${endTime}`)

    // Query DB จริงผ่าน Postgres direct connection
    const dbUrl = Deno.env.get('SUPABASE_DB_URL')
    if (!dbUrl) throw new Error('SUPABASE_DB_URL not set')

    const { Pool } = await import('https://deno.land/x/postgres@v0.19.3/mod.ts')
    const pool = new Pool(dbUrl, 3, true)
    const conn = await pool.connect()

    let rows: TaskRow[]
    try {
      const result = await conn.queryObject<TaskRow>(`
        SELECT
          tl.status,
          to_char(tl."ExpectedDateTime" AT TIME ZONE 'Asia/Bangkok', 'YYYY-MM-DD HH24:MI:SS') as expected_time,
          t.title,
          COALESCE(NULLIF(t."taskType", ''), 'อื่นๆ') as task_type,
          ui.nickname as done_by,
          tl."Descript" as note,
          tl.problem_type,
          tl.resolution_status,
          tl.resolution_note,
          ui_r.nickname as resolved_by_name,
          t.resident_id::int as resident_id,
          r."i_Name_Surname" as resident_name,
          tl."confirmImage" as confirm_image,
          to_char(tl.completed_at AT TIME ZONE 'Asia/Bangkok', 'YYYY-MM-DD HH24:MI:SS') as completed_at
        FROM "A_Task_logs_ver2" tl
        JOIN "A_Tasks" t ON tl.task_id = t.id
        JOIN residents r ON t.resident_id = r.id
        LEFT JOIN user_info ui ON tl.completed_by = ui.id
        LEFT JOIN user_info ui_r ON tl.resolved_by = ui_r.id
        WHERE r.s_status = 'Stay'
          AND tl."ExpectedDateTime" >= $1::timestamptz
          AND tl."ExpectedDateTime" < $2::timestamptz
        ORDER BY r."i_Name_Surname", tl."ExpectedDateTime" ASC
      `, [startTime, endTime])
      rows = result.rows as TaskRow[]
    } catch (queryErr) {
      conn.release()
      await pool.end()
      throw queryErr
    }

    console.log(`Fetched ${rows.length} task rows`)

    if (rows.length === 0) {
      conn.release()
      await pool.end()
      return new Response(JSON.stringify({ success: true, message: 'No tasks found', shift, date: today }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Group by resident (กรองตาม residentFilter ถ้ามี — ใช้ตอน test)
    const rMap = new Map<number, { name: string; tasks: TaskRow[] }>()
    for (const r of rows) {
      const rid = Number(r.resident_id)
      if (residentFilter !== null && rid !== residentFilter) continue
      if (!rMap.has(rid)) rMap.set(rid, { name: r.resident_name, tasks: [] })
      rMap.get(rid)!.tasks.push(r)
    }

    console.log(`Processing ${rMap.size} residents`)

    const results: { id: number; name: string; total: number; done: number; problem: number; refer: number; sent: boolean; summaryId?: string; skipped?: string }[] = []

    // ใช้ shiftDate สำหรับ INSERT
    const shiftDate = shift === 'night' ? yesterdayDate : today

    try {
      for (const [residentId, { name, tasks }] of rMap) {
        const data = categorizeTasks(tasks)

        // ข้าม resident ที่ทุก task เป็น refer (อยู่ รพ → ไม่ต้องส่ง)
        if (data.totalRefer === data.total) {
          results.push({ id: residentId, name, total: data.total, done: 0, problem: 0, refer: data.totalRefer, sent: false, skipped: 'all_refer' })
          continue
        }

        // บันทึกสรุปลง DB — ได้ UUID สำหรับ public link
        let summaryId = ''
        try {
          const insertResult = await conn.queryObject<{ id: string }>(`
            INSERT INTO checklist_summaries (resident_id, resident_name, shift, shift_date, date_label, summary_json, total, done, problem, refer, with_photo, staff_names)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            ON CONFLICT (resident_id, shift, shift_date) DO UPDATE SET
              resident_name = EXCLUDED.resident_name,
              date_label = EXCLUDED.date_label,
              summary_json = EXCLUDED.summary_json,
              total = EXCLUDED.total,
              done = EXCLUDED.done,
              problem = EXCLUDED.problem,
              refer = EXCLUDED.refer,
              with_photo = EXCLUDED.with_photo,
              staff_names = EXCLUDED.staff_names,
              created_at = now()
            RETURNING id
          `, [
            residentId, name, shift, shiftDate, dateLabel,
            JSON.stringify(data),
            data.total, data.totalDone, data.totalProblem, data.totalRefer,
            data.totalWithPhoto, data.staffNames,
          ])
          summaryId = String(insertResult.rows[0].id)
          console.log(`  Saved summary ${summaryId} for ${name}`)
        } catch (insertErr) {
          // INSERT fail ไม่ควร break flow — ส่ง LINE ต่อได้ แต่ไม่มี link แชร์
          console.error(`  Failed to save summary for ${name}:`, insertErr)
        }

        const bubble = buildBubble(name, residentId, shiftLabel, shiftEmoji, dateLabel, data, summaryId)

        const flexMsg = {
          type: 'flex',
          altText: `📋 ${shiftLabel} — ${name}`,
          contents: bubble,
        }

        // ⚠️ DEV MODE: ส่งห้อง dev เท่านั้น
        const res = await pushToLine(LINE_TOKEN, DEV_LINE_GROUP_ID, [flexMsg])

        results.push({
          id: residentId, name,
          total: data.total, done: data.totalDone,
          problem: data.totalProblem, refer: data.totalRefer,
          sent: res.success, summaryId: summaryId || undefined,
        })

        // LINE rate limit: delay 150ms
        await new Promise(r => setTimeout(r, 150))
      }
    } finally {
      // คืน connection หลังจบ loop ทั้งหมด
      conn.release()
      await pool.end()
    }

    const sentOk = results.filter(r => r.sent).length
    const skipped = results.filter(r => r.skipped).length

    return new Response(JSON.stringify({
      success: true,
      shift, date: today,
      range: `${startTime} → ${endTime}`,
      totalResidents: rMap.size,
      totalTasks: rows.length,
      sentSuccess: sentOk,
      sentFailed: rMap.size - sentOk - skipped,
      skippedRefer: skipped,
      residents: results,
    }, null, 2), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err: unknown) {
    console.error('Error:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
