// ============================================
// Edge Function: read-measurement-photo
// ============================================
// ใช้ Gemini Vision อ่านค่าจากรูปถ่ายอุปกรณ์วัด (ตาชั่ง, ที่วัดส่วนสูง, เครื่อง DTX ฯลฯ)
// เรียกตรงจาก Flutter app หลังถ่ายรูป → auto-fill ค่าในช่อง input
//
// Flow:
//   1. รับ photo_url + measurement_type จาก client
//   2. ดาวน์โหลดรูปเป็น base64
//   3. ส่ง Gemini Vision อ่านตัวเลข
//   4. Return ค่าที่อ่านได้ + confidence

import { GoogleGenerativeAI } from 'npm:@google/generative-ai'

const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!)

// ============================================
// Types
// ============================================
interface RequestBody {
  photo_url: string
  measurement_type: string // 'weight', 'height', 'dtx', 'insulin'
}

interface ReadingResult {
  value: number | null       // ค่าที่อ่านได้
  unit: string               // หน่วย เช่น 'kg', 'cm'
  raw_text: string           // สิ่งที่ AI เห็นจากจอ/รูป
  confidence: number         // 0-100
  warning: string | null     // คำเตือน (ถ้ามี)
}

// ============================================
// Config สำหรับแต่ละ measurement type
// ============================================
const MEASUREMENT_CONFIG: Record<string, {
  label: string
  unit: string
  prompt: string
  min: number
  max: number
}> = {
  weight: {
    label: 'น้ำหนัก',
    unit: 'kg',
    prompt: `อ่านค่าน้ำหนัก (กิโลกรัม) จากหน้าจอตาชั่งดิจิตอลหรือตาชั่งเข็ม
- ค่าจะเป็นทศนิยม 1 ตำแหน่ง เช่น 65.5, 72.0
- ถ้าเป็นตาชั่งเข็ม ให้อ่านตำแหน่งเข็มชี้`,
    min: 20,
    max: 200,
  },
  height: {
    label: 'ส่วนสูง',
    unit: 'cm',
    prompt: `อ่านค่าส่วนสูง (เซนติเมตร) จากที่วัดส่วนสูงหรืออุปกรณ์วัด
- ค่าจะเป็นจำนวนเต็ม หรือทศนิยม 1 ตำแหน่ง เช่น 165, 158.5`,
    min: 50,
    max: 220,
  },
  dtx: {
    label: 'น้ำตาลในเลือด (DTX)',
    unit: 'mg/dL',
    prompt: `อ่านค่าน้ำตาลในเลือด (mg/dL) จากหน้าจอเครื่องวัดน้ำตาลปลายนิ้ว (Glucometer)
- ค่าจะเป็นจำนวนเต็ม เช่น 120, 95, 250`,
    min: 30,
    max: 500,
  },
  insulin: {
    label: 'อินซูลิน',
    unit: 'units',
    prompt: `อ่านค่าอินซูลินที่ฉีด (units) จากรูปปากกาอินซูลินหรือ syringe
- อ่านตัวเลขที่แสดงบน dial/window ของปากกา
- ค่าจะเป็นจำนวนเต็ม เช่น 10, 20, 8`,
    min: 0,
    max: 100,
  },
  fasting_glucose: {
    label: 'น้ำตาลเช้า (FBS)',
    unit: 'mg/dL',
    prompt: `อ่านค่าน้ำตาลในเลือด (mg/dL) จากหน้าจอเครื่องวัด
- ค่าจะเป็นจำนวนเต็ม เช่น 100, 85, 130`,
    min: 50,
    max: 400,
  },
}

// ============================================
// ดาวน์โหลดรูปเป็น base64
// ============================================
async function downloadImageAsBase64(url: string): Promise<{ base64: string; mimeType: string } | null> {
  try {
    const response = await fetch(url)
    if (!response.ok) return null
    const arrayBuffer = await response.arrayBuffer()
    const uint8Array = new Uint8Array(arrayBuffer)
    let binary = ''
    for (let i = 0; i < uint8Array.length; i++) {
      binary += String.fromCharCode(uint8Array[i])
    }
    return {
      base64: btoa(binary),
      mimeType: response.headers.get('content-type') || 'image/jpeg',
    }
  } catch {
    return null
  }
}

// ============================================
// Main Handler
// ============================================
Deno.serve(async (req: Request) => {
  // CORS headers
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
      },
    })
  }

  try {
    const { photo_url, measurement_type } = await req.json() as RequestBody

    // Validate input
    if (!photo_url || !measurement_type) {
      return new Response(
        JSON.stringify({ error: 'Missing photo_url or measurement_type' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const config = MEASUREMENT_CONFIG[measurement_type]
    if (!config) {
      return new Response(
        JSON.stringify({ error: `Unknown measurement_type: ${measurement_type}` }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // ดาวน์โหลดรูป
    const image = await downloadImageAsBase64(photo_url)
    if (!image) {
      return new Response(
        JSON.stringify({
          value: null,
          unit: config.unit,
          raw_text: '',
          confidence: 0,
          warning: 'ไม่สามารถโหลดรูปได้',
        } as ReadingResult),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }

    // สร้าง prompt
    const prompt = `คุณเป็น AI อ่านค่าจากอุปกรณ์วัดในสถานดูแลผู้สูงอายุ

${config.prompt}

## กฎ:
- อ่านเฉพาะตัวเลขค่า${config.label}เท่านั้น
- ถ้ารูปเบลอ/อ่านไม่ได้ → value = null
- ถ้ามีหลายตัวเลข ให้เลือกตัวที่เป็นค่า${config.label}
- ค่าที่สมเหตุสมผล: ${config.min}-${config.max} ${config.unit}

## Output JSON เท่านั้น (ห้ามมี text อื่น):
{
  "value": <number|null>,
  "raw_text": "<สิ่งที่เห็นบนจอ/อุปกรณ์>",
  "confidence": <0-100>,
  "warning": "<ข้อกังวล ภาษาไทย หรือ null>"
}

confidence scoring:
- 90-100: อ่านค่าชัดเจน
- 70-89: อ่านได้แต่รูปไม่ชัดบางส่วน
- 50-69: ไม่แน่ใจ ควรตรวจสอบ
- 0-49: อ่านไม่ได้`

    // เรียก Gemini Vision
    const model = genAI.getGenerativeModel({
      model: 'gemini-2.5-flash',
      generationConfig: {
        responseMimeType: 'application/json',
        temperature: 0.1, // ลด creativity เพื่อความแม่นยำ
      },
    })

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          mimeType: image.mimeType,
          data: image.base64,
        },
      },
    ])

    const responseText = result.response.text()
    let parsed: { value: number | null; raw_text: string; confidence: number; warning: string | null }

    try {
      parsed = JSON.parse(responseText)
    } catch {
      // Gemini ส่ง text แทน JSON → parse เอา
      parsed = { value: null, raw_text: responseText, confidence: 0, warning: 'AI ตอบกลับไม่ถูก format' }
    }

    // Validate range
    if (parsed.value !== null) {
      if (parsed.value < config.min || parsed.value > config.max) {
        parsed.warning = `ค่า ${parsed.value} อยู่นอกช่วงปกติ (${config.min}-${config.max} ${config.unit})`
      }
    }

    const response: ReadingResult = {
      value: parsed.value,
      unit: config.unit,
      raw_text: parsed.raw_text || '',
      confidence: parsed.confidence || 0,
      warning: parsed.warning || null,
    }

    return new Response(
      JSON.stringify(response),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (err) {
    console.error('read-measurement-photo error:', err)
    return new Response(
      JSON.stringify({
        value: null,
        unit: '',
        raw_text: '',
        confidence: 0,
        warning: `เกิดข้อผิดพลาด: ${err instanceof Error ? err.message : String(err)}`,
      } as ReadingResult),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  }
})
