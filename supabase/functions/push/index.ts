import { createClient } from 'npm:@supabase/supabase-js@2'

// Configuration — ดึงจาก Supabase Edge Function Secrets
// ตั้งค่าผ่าน: supabase secrets set ONESIGNAL_APP_ID=xxx ONESIGNAL_API_KEY=xxx
const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID')!
const ONESIGNAL_API_KEY = Deno.env.get('ONESIGNAL_API_KEY')!

interface Notification {
  id: string
  user_id: string
  title: string
  body: string
  image_url?: string
  // Deep linking metadata — ส่งไปกับ push เพื่อให้ app navigate ไปหน้าที่เกี่ยวข้อง
  type?: string           // notification type (post, task, incident, etc.)
  reference_id?: number   // ID ของ record ที่เกี่ยวข้อง
  reference_table?: string // ชื่อ table ที่ reference_id ชี้ไป
  action_url?: string     // custom deep link URL
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

Deno.serve(async (req) => {
  try {
    const payload = await req.json()
    console.log('Received payload:', JSON.stringify(payload))

    const notification: Notification = payload.record || payload

    if (!notification.user_id) {
      return new Response(JSON.stringify({ error: 'Missing user_id' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // With OneSignal, we rely on the External User ID which matches Supabase User ID.
    // We send directly to the specific user via 'include_aliases' (External ID).

    console.log('Sending message via OneSignal...')

    const response = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${ONESIGNAL_API_KEY}`,
      },
      body: JSON.stringify({
        app_id: ONESIGNAL_APP_ID,
        include_aliases: {
          external_id: [notification.user_id]
        },
        target_channel: "push",
        headings: { en: notification.title || 'แจ้งเตือน' },
        contents: { en: notification.body || '' },
        // รูปภาพ (ถ้ามี) — แสดงเป็น big picture บน Android, attachment บน iOS
        ...(notification.image_url ? { big_picture: notification.image_url } : {}),
        ...(notification.image_url ? { ios_attachments: { thumbnail: notification.image_url } } : {}),
        // Metadata สำหรับ deep linking — app จะใช้ข้อมูลนี้ navigate ไปหน้าที่เกี่ยวข้อง
        data: {
          notification_id: notification.id,
          type: notification.type || 'system',
          reference_id: notification.reference_id || null,
          reference_table: notification.reference_table || null,
          action_url: notification.action_url || `irene://notifications/${notification.id}`,
        },
      }),
    });

    const resData = await response.json()
    console.log('OneSignal response:', response.status, JSON.stringify(resData))

    if (response.status !== 200 || resData.errors) {
      // Log full error for debugging
      console.error("OneSignal Error Details:", resData)
      return new Response(JSON.stringify({ error: 'OneSignal Error', details: resData }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ success: true, data: resData }), {
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (err: any) {
    console.error('Error:', err)
    return new Response(JSON.stringify({ error: String(err), code: err?.code }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
