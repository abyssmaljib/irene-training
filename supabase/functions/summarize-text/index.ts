// Edge Function: summarize-text
// สรุปข้อความเป็น bullet points โดยใช้ Google Gemini AI
// ใช้แทน n8n webhook เพื่อความเสถียรและเร็วกว่า

import { GoogleGenerativeAI } from 'npm:@google/generative-ai'

// Google Gemini AI - ใช้ gemini-3-flash-preview (เร็วมาก และฉลาดกว่า 2.0)
const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!)

// Interface สำหรับ request body
interface RequestBody {
  text: string
}

// System prompt สำหรับสรุปข้อความ
const SUMMARIZE_SYSTEM_PROMPT = `You are a professional nursing home manager with strong, confident, and clear communication skills, guiding nurse assistants (users).
You will summarize text into bullet points, making it clear and easy to understand.
Use simple Thai language that a Grade 6 student can read and immediately understand.
Correct any spelling mistakes in the process.

IMPORTANT: Keep ALL important details and instructions. Do NOT over-simplify or remove crucial information.
Each bullet point should contain ONE complete instruction or piece of information.
If there are numbered steps or multiple rules, preserve each one as a separate bullet point.

The output must be written in Thai.

FORMATTING RULES:
- Use ONLY plain text bullet points starting with "- "
- Do NOT use any markdown formatting (no **bold**, no *italic*, no headers, no links)
- Do NOT use emojis
- Keep it simple and clean - just plain Thai text with bullet points`

// Format instruction
const FORMAT_INSTRUCTION = `ให้คำตอบ อยู่ในรูปของ bullet point แบบ plain text
แต่ละข้อต้องครบถ้วน ไม่ตัดรายละเอียดสำคัญออก เช่น
- ล้างถุงและสายด้วยน้ำอุ่นทันทีหลังใช้งาน (ห้ามใช้น้ำเดือดเด็ดขาด)
- ปิดจุกและปิดปากถุงให้สนิททุกครั้ง ห้ามเปิดทิ้งไว้
- เก็บใส่ถุงซิปล็อกที่มีชื่อคนไข้ และปิดถุงให้มิดชิด

ห้ามใช้ **ตัวหนา** หรือ markdown อื่นๆ เด็ดขาด
ห้ามย่อจนสั้นเกินไป ต้องเก็บรายละเอียดสำคัญไว้ครบ`

Deno.serve(async (req) => {
  // Handle CORS - รองรับ preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
      },
    })
  }

  // ตรวจสอบว่าเป็น POST request
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  }

  try {
    // Parse request body
    const body: RequestBody = await req.json()
    const { text } = body

    console.log('Summarize text request received, text length:', text?.length || 0)

    // Validate input - ต้องมี text
    if (!text || text.trim().length < 10) {
      return new Response(JSON.stringify({
        error: 'Text is required and must be at least 10 characters',
        content: ''
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      })
    }

    // สร้าง Gemini model - ใช้ gemini-3-flash-preview (เร็วมาก ฉลาดกว่า 2.0)
    const model = genAI.getGenerativeModel({
      model: 'gemini-3-flash-preview',
      generationConfig: {
        temperature: 0.5, // ค่าต่ำกว่า quiz เพื่อให้สรุปตรงประเด็น
        // ไม่จำกัด maxOutputTokens เพื่อให้สรุปได้ครบถ้วน
      },
    })

    // สร้าง prompt โดยรวม system prompt กับ text ที่ส่งมา (เหมือน n8n)
    // n8n ใช้ 3 messages: assistant (system prompt), user (text), system (format)
    const prompt = `${SUMMARIZE_SYSTEM_PROMPT}

ข้อความที่ต้องการสรุป:
${text}

${FORMAT_INSTRUCTION}`

    // Generate summary
    const result = await model.generateContent(prompt)
    const responseText = result.response.text()

    console.log('Gemini response length:', responseText?.length || 0)

    // ตรวจสอบว่ามี response หรือไม่
    if (!responseText || responseText.trim().length === 0) {
      throw new Error('Empty response from AI')
    }

    // Return response ในรูปแบบที่ Flutter app คาดหวัง
    // Flutter app อ่านจาก response.body โดยตรง หรือ jsonResponse['content']
    return new Response(JSON.stringify({
      content: responseText.trim()
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })

  } catch (err: unknown) {
    console.error('Error in summarize-text:', err)
    const errorMessage = err instanceof Error ? err.message : String(err)

    // Return error response
    return new Response(JSON.stringify({
      error: errorMessage,
      content: ''
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  }
})
