// Edge Function: auto-create-medicine-tickets
// สร้าง Ticket อัตโนมัติสำหรับยาที่สต็อกใกล้หมดหรือหมดแล้ว
//
// Logic:
// 1. ดึงยาจาก vw_med_stock_by_nursinghome ที่ urgency_level = 'urgent' หรือ 'out_of_stock'
// 2. กรองเฉพาะยาที่ยังไม่มี open ticket (has_open_ticket = false)
// 3. กรองเฉพาะ resident ที่ยังอยู่ (resident_active_status = 'Stay') และยาที่ยังใช้งาน (med_status = 'on')
// 4. สร้าง B_Ticket ใหม่สำหรับแต่ละรายการยา
//
// Input: { nursinghome_id: number }
// Output: { success: true, created: number, skipped: number, details: [...] }

import { createClient } from 'npm:@supabase/supabase-js@2'

// Supabase client — ใช้ service role key เพื่อ bypass RLS
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// =============================================
// Types
// =============================================

interface RequestBody {
  nursinghome_id: number
}

// โครงสร้างข้อมูลยาจาก view — เลือกเฉพาะ columns ที่ใช้
interface MedStockRow {
  medicine_list_id: number
  brand_name: string | null
  generic_name: string | null
  strength: string | null
  resident_id: number | null
  resident_name: string | null
  nursinghome_id: number
  urgency_level: string       // 'urgent' | 'out_of_stock' | 'warning' | 'normal'
  remaining_pills: number | null
  predicted_run_out_date: string | null
  has_open_ticket: boolean
  med_status: string | null   // 'on' | 'off'
  resident_active_status: string | null  // 'Stay' | 'Discharged'
}

// ผลลัพธ์ของการสร้าง ticket แต่ละรายการ
interface TicketResult {
  medicine_list_id: number
  brand_name: string | null
  resident_name: string | null
  status: 'created' | 'skipped' | 'error'
  reason?: string
}

// =============================================
// Helper: สร้างชื่อ ticket ตาม pattern ที่ใช้อยู่ในระบบ
// =============================================
// Pattern จากข้อมูลจริง: "ยา {brand_name} ({generic_name}) ของคุณ{resident_name} กำลังจะหมด"
function buildTicketTitle(med: MedStockRow): string {
  // สร้างชื่อยา — ใช้ brand_name เป็นหลัก, ถ้ามี generic_name ใส่ในวงเล็บ
  let medName = med.brand_name || med.generic_name || 'ไม่ระบุชื่อยา'
  if (med.brand_name && med.generic_name && med.brand_name !== med.generic_name) {
    medName = `${med.brand_name} (${med.generic_name})`
  }
  // ถ้ามี strength ต่อท้ายชื่อยา
  if (med.strength) {
    medName += ` ${med.strength}`
  }

  const residentName = med.resident_name || 'ไม่ระบุชื่อ'

  // แยก title ตาม urgency level
  if (med.urgency_level === 'out_of_stock') {
    return `ยาหมด - ${medName} - ${residentName}`
  }
  return `ยาใกล้หมด - ${medName} - ${residentName}`
}

// =============================================
// Helper: สร้าง description สำหรับ ticket
// =============================================
function buildTicketDescription(med: MedStockRow): string {
  const parts: string[] = []

  // ข้อมูลสต็อก
  if (med.remaining_pills !== null && med.remaining_pills !== undefined) {
    parts.push(`คงเหลือ: ${med.remaining_pills} เม็ด`)
  }
  if (med.predicted_run_out_date) {
    // แปลง predicted_run_out_date เป็นวันที่อ่านง่าย (YYYY-MM-DD)
    const dateStr = med.predicted_run_out_date.split('T')[0] || med.predicted_run_out_date.split(' ')[0]
    parts.push(`คาดว่าจะหมดวันที่: ${dateStr}`)
  }

  // คำอธิบายหลัก
  parts.push('ทำตามขั้นตอนเพื่อนำยากลับมาให้พร้อมสำหรับคนไข้')

  return parts.join('\n')
}

// =============================================
// Main Handler
// =============================================

Deno.serve(async (req) => {
  // CORS — รองรับการเรียกจาก admin web app
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
      },
    })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }

  try {
    const body: RequestBody = await req.json()
    const { nursinghome_id } = body

    // Validate input
    if (!nursinghome_id) {
      return new Response(JSON.stringify({ error: 'nursinghome_id is required' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      })
    }

    console.log(`[auto-create-medicine-tickets] Starting for nursinghome_id=${nursinghome_id}`)

    // =============================================
    // Step 1: ดึงยาที่สต็อกวิกฤตจาก view
    // =============================================
    // กรองเงื่อนไข:
    // - nursinghome_id ตรงกับที่ระบุ
    // - urgency_level เป็น 'urgent' หรือ 'out_of_stock'
    // - has_open_ticket = false (ยังไม่มี ticket เปิดอยู่)
    // - med_status = 'on' (ยายังใช้งานอยู่ ไม่ได้ถูก off)
    // - resident_active_status = 'Stay' (ผู้พักยังอยู่ ไม่ได้ discharged)
    const { data: urgentMeds, error: medsError } = await supabase
      .from('vw_med_stock_by_nursinghome')
      .select('medicine_list_id, brand_name, generic_name, strength, resident_id, resident_name, nursinghome_id, urgency_level, remaining_pills, predicted_run_out_date, has_open_ticket, med_status, resident_active_status')
      .eq('nursinghome_id', nursinghome_id)
      .in('urgency_level', ['urgent', 'out_of_stock'])
      .eq('has_open_ticket', false)
      .eq('med_status', 'on')
      .eq('resident_active_status', 'Stay')

    if (medsError) {
      console.error('[auto-create-medicine-tickets] Error querying view:', medsError)
      throw new Error(`Failed to query medicine stock: ${medsError.message}`)
    }

    const meds = (urgentMeds || []) as MedStockRow[]
    console.log(`[auto-create-medicine-tickets] Found ${meds.length} urgent medicines without open tickets`)

    // =============================================
    // Step 2: สร้าง ticket สำหรับแต่ละยา
    // =============================================
    let created = 0
    let skipped = 0
    const details: TicketResult[] = []

    for (const med of meds) {
      try {
        // Double-check: ตรวจซ้ำว่ายังไม่มี open/in_progress ticket สำหรับ med_list_id นี้
        // (ป้องกัน race condition กรณีเรียก function พร้อมกันหลาย request)
        const { data: existingTickets, error: checkError } = await supabase
          .from('B_Ticket')
          .select('id')
          .eq('med_list_id', med.medicine_list_id)
          .in('status', ['open', 'in_progress'])
          .limit(1)

        if (checkError) {
          console.error(`[auto-create-medicine-tickets] Error checking existing ticket for med ${med.medicine_list_id}:`, checkError)
          details.push({
            medicine_list_id: med.medicine_list_id,
            brand_name: med.brand_name,
            resident_name: med.resident_name,
            status: 'error',
            reason: checkError.message,
          })
          continue
        }

        // ถ้ามี ticket อยู่แล้ว → ข้าม (view อาจยังไม่ refresh)
        if (existingTickets && existingTickets.length > 0) {
          skipped++
          details.push({
            medicine_list_id: med.medicine_list_id,
            brand_name: med.brand_name,
            resident_name: med.resident_name,
            status: 'skipped',
            reason: `Existing open ticket id=${existingTickets[0].id}`,
          })
          continue
        }

        // สร้าง ticket ใหม่
        const ticketTitle = buildTicketTitle(med)
        const ticketDescription = buildTicketDescription(med)

        const { error: insertError } = await supabase.from('B_Ticket').insert({
          'ticket_Title': ticketTitle,
          'ticket_Description': ticketDescription,
          nursinghome_id: nursinghome_id,
          category: 'medicine',
          status: 'open',
          // priority: true ถ้ายาหมดแล้ว (out_of_stock) — ต้องเร่งดำเนินการ
          priority: med.urgency_level === 'out_of_stock',
          source_type: 'medicine',
          source_id: med.medicine_list_id,
          med_list_id: med.medicine_list_id,
          resident_id: med.resident_id,
          // stock_status เริ่มต้นที่ 'pending' — รอดำเนินการจัดซื้อ
          stock_status: 'pending',
        })

        if (insertError) {
          console.error(`[auto-create-medicine-tickets] Error creating ticket for med ${med.medicine_list_id}:`, insertError)
          details.push({
            medicine_list_id: med.medicine_list_id,
            brand_name: med.brand_name,
            resident_name: med.resident_name,
            status: 'error',
            reason: insertError.message,
          })
          continue
        }

        created++
        details.push({
          medicine_list_id: med.medicine_list_id,
          brand_name: med.brand_name,
          resident_name: med.resident_name,
          status: 'created',
        })

        console.log(`[auto-create-medicine-tickets] Created ticket: ${ticketTitle}`)

      } catch (err) {
        console.error(`[auto-create-medicine-tickets] Unexpected error for med ${med.medicine_list_id}:`, err)
        details.push({
          medicine_list_id: med.medicine_list_id,
          brand_name: med.brand_name,
          resident_name: med.resident_name,
          status: 'error',
          reason: String(err),
        })
      }
    }

    // =============================================
    // Step 3: สรุปผลลัพธ์
    // =============================================
    const summary = {
      success: true,
      nursinghome_id,
      total_urgent: meds.length,
      created,
      skipped,
      errors: details.filter(d => d.status === 'error').length,
      details,
    }

    console.log(`[auto-create-medicine-tickets] Done: created=${created}, skipped=${skipped}, errors=${summary.errors}`)

    return new Response(JSON.stringify(summary), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })

  } catch (err: unknown) {
    console.error('[auto-create-medicine-tickets] Error:', err)
    const errorMessage = err instanceof Error ? err.message : String(err)
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
