// Edge Function: generate-incident-summary
// สรุป 4 Pillars จาก chat history โดยใช้ Google Gemini AI
// v2: อ่าน violated_core_values จาก database แทนการ re-analyze

import { createClient } from 'npm:@supabase/supabase-js@2'
import { GoogleGenerativeAI } from 'npm:@google/generative-ai'

// Supabase client
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// Google Gemini AI
const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!)

interface ChatMessage {
  role: 'user' | 'assistant'
  content: string
  timestamp: string
}

interface RequestBody {
  incident_id: number
  chat_history: ChatMessage[]
}

interface SummaryResponse {
  why_it_matters: string
  root_cause: string
  core_value_analysis: string
  violated_core_values: string[]
  prevention_plan: string
  is_complete: boolean
}

// ข้อมูล incident ที่บันทึกไว้ใน database (4 Pillars content)
interface IncidentData {
  why_it_matters: string | null
  root_cause: string | null
  core_value_analysis: string | null
  violated_core_values: string[] | null
  prevention_plan: string | null
}

// Prompt สำหรับสรุป 4 Pillars
// หมายเหตุ: violated_core_values จะอ่านจาก database แทน (user เลือกไว้แล้ว)
const SUMMARY_PROMPT = `วิเคราะห์บทสนทนาการถอดบทเรียน (5 Whys Coaching) และสรุปเป็น 4 ประเด็นสำคัญ

บทสนทนา:
{CONVERSATION}

ดึงข้อมูล 4 ส่วนสำคัญ (เขียนเป็นภาษาไทย กระชับ ชัดเจน):

1. why_it_matters: ความสำคัญ/ผลกระทบของเหตุการณ์นี้ (1-2 ประโยค)
2. root_cause: สาเหตุที่แท้จริงที่ค้นพบจากการถามว่า "ทำไม?" (1-2 ประโยค)
3. core_value_analysis: สรุปการวิเคราะห์ว่าพฤติกรรมนี้เกี่ยวข้องกับ Core Values อย่างไร (1-2 ประโยค)
4. prevention_plan: แนวทางการป้องกันไม่ให้เกิดซ้ำ (1-2 ประโยค)

หมายเหตุ: ไม่ต้องส่ง violated_core_values เพราะ user เลือกไว้แล้ว

และประเมิน is_complete = true ก็ต่อเมื่อได้ข้อมูลครบทั้ง 4 ส่วนเท่านั้น

ตอบกลับเป็น JSON เท่านั้น:
{
  "why_it_matters": "...",
  "root_cause": "...",
  "core_value_analysis": "...",
  "prevention_plan": "...",
  "is_complete": true/false
}`

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    })
  }

  try {
    const body: RequestBody = await req.json()
    const { incident_id, chat_history } = body

    console.log('Generating summary for incident:', incident_id)

    if (!incident_id || !chat_history || chat_history.length === 0) {
      return new Response(JSON.stringify({
        error: 'Missing required fields: incident_id, chat_history'
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // ดึงข้อมูล 4 Pillars ที่บันทึกไว้แล้วจาก database
    // โดยเฉพาะ violated_core_values ที่ user เลือกไว้
    const { data: incidentData, error: dbError } = await supabase
      .from('B_Incident')
      .select('why_it_matters, root_cause, core_value_analysis, violated_core_values, prevention_plan')
      .eq('id', incident_id)
      .maybeSingle()

    if (dbError) {
      console.error('Error fetching incident data:', dbError)
    }

    // ดึง violated_core_values จาก database (ที่ user เลือกไว้)
    const savedViolatedCoreValues: string[] = incidentData?.violated_core_values || []
    console.log('Saved violated_core_values from DB:', savedViolatedCoreValues)

    // สร้าง conversation text จาก chat history
    const conversationText = chat_history
      .map(msg => `${msg.role === 'user' ? 'พนักงาน' : 'AI Coach'}: ${msg.content}`)
      .join('\n')

    // สร้าง prompt
    const prompt = SUMMARY_PROMPT.replace('{CONVERSATION}', conversationText)

    // สร้าง Gemini model - ใช้ Gemini 3 Flash Preview (เร็วกว่า)
    const model = genAI.getGenerativeModel({
      model: 'gemini-3-flash-preview',
      generationConfig: {
        responseMimeType: 'application/json',
        temperature: 0.3, // ลด temperature สำหรับ output ที่เสถียรกว่า
      },
    })

    // Generate summary
    const result = await model.generateContent(prompt)
    const responseText = result.response.text()

    console.log('Gemini response:', responseText)

    // Parse JSON response
    let summary: SummaryResponse
    try {
      summary = JSON.parse(responseText)
    } catch (parseError) {
      console.error('Error parsing JSON:', parseError)
      // ถ้า parse ไม่ได้ ลอง extract JSON จาก response
      const jsonMatch = responseText.match(/\{[\s\S]*\}/)
      if (jsonMatch) {
        summary = JSON.parse(jsonMatch[0])
      } else {
        throw new Error('Failed to parse AI response as JSON')
      }
    }

    // ใช้ violated_core_values จาก database (ที่ user เลือกไว้) แทนการ re-analyze
    // ค่าใน DB อาจเป็นชื่อเต็ม เช่น "Speak Up (กล้าพูด กล้าสื่อสาร)" หรือ code เช่น "SPEAK_UP"
    // ไม่ต้อง validate เพราะมันถูก validate แล้วตอนบันทึกใน five-whys-chat

    if (savedViolatedCoreValues.length > 0) {
      // ใช้ค่าจาก database (user เลือกไว้แล้ว) โดยตรง
      summary.violated_core_values = savedViolatedCoreValues
      console.log('Using violated_core_values from DB:', summary.violated_core_values)
    } else {
      // Fallback: ถ้า DB ไม่มี ใช้จาก AI (ถ้ามี) และ normalize เป็น code
      const validCoreValues = ['SPEAK_UP', 'SERVICE_MIND', 'SYSTEM_FOCUS', 'INTEGRITY', 'LEARNING', 'TEAMWORK']
      summary.violated_core_values = (summary.violated_core_values || [])
        .map(v => v.toUpperCase())
        .filter(v => validCoreValues.includes(v))
      console.log('Using violated_core_values from AI:', summary.violated_core_values)
    }

    // ตรวจสอบว่าครบทุก field หรือไม่
    summary.is_complete = Boolean(
      summary.why_it_matters &&
      summary.root_cause &&
      summary.core_value_analysis &&
      summary.violated_core_values.length > 0 &&
      summary.prevention_plan
    )

    console.log('Summary generated:', summary.is_complete ? 'complete' : 'incomplete')

    return new Response(JSON.stringify(summary), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })

  } catch (err: unknown) {
    console.error('Error in generate-incident-summary:', err)
    const errorMessage = err instanceof Error ? err.message : String(err)
    return new Response(JSON.stringify({
      error: errorMessage,
      why_it_matters: '',
      root_cause: '',
      core_value_analysis: '',
      violated_core_values: [],
      prevention_plan: '',
      is_complete: false
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  }
})
