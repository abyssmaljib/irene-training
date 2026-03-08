// Edge Function: generate-incident-summary
// สรุป 4 Pillars จาก chat history โดยใช้ Google Gemini AI
// v3: เพิ่ม 4M Root Cause Classification (Man/Material/Method/Machine) + theme extraction → save ลง DB โดยตรง
// v4: เพิ่ม conversation quality scoring (root_cause_depth_achieved, conversation_quality_score, explored_categories)
//     เปลี่ยนเป็น Gemini 3 Pro สำหรับ summary (ฉลาดกว่า ไม่ต้อง real-time)

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
  // 4M Classification (v3)
  root_cause_categories: string[]  // ['Man', 'Method'] etc.
  root_cause_themes: string[]      // ['ขาดการสื่อสาร', 'ไม่ทำตาม checklist']
  // Quality scoring (v4) — ประเมินคุณภาพการวิเคราะห์
  root_cause_depth_achieved: number | null       // 1-5 ระดับความลึกที่ทำได้
  conversation_quality_score: number | null      // 0-100 คะแนนคุณภาพ
  explored_categories_summary: string[] | null   // หมวด Fishbone ที่สำรวจแล้ว
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

5. root_cause_categories: จำแนกสาเหตุตามหลัก 4M — เลือกได้มากกว่า 1 ข้อ:
   - "Man" = คน (ขาดทักษะ/ความรู้/ทัศนคติ เช่น ลืม, ประมาท, ไม่รู้ขั้นตอน)
   - "Material" = วัสดุ/อุปกรณ์ (ของหมด/ชำรุด/ไม่เพียงพอ เช่น ยาหมด, เครื่องมือเสีย)
   - "Method" = วิธีการ/กระบวนการ (SOP ไม่ชัด/ขั้นตอนขาดหาย เช่น ไม่มี checklist)
   - "Machine" = ระบบ/เทคโนโลยี (ซอฟต์แวร์มีปัญหา/ระบบล่ม เช่น แอปค้าง)

6. root_cause_themes: สรุปสาเหตุเป็น theme สั้นๆ 2-4 ข้อ (ภาษาไทย กระชับ)
   - เช่น ["ขาดการสื่อสารระหว่างเวร", "ไม่ปฏิบัติตาม SOP"]

7. root_cause_depth_achieved: ประเมินว่าบทสนทนานี้ลงลึกถึงระดับไหน (1-5):
   - 1 = แค่อาการ (ผู้สูงอายุล้ม)
   - 2 = สาเหตุตรง (ไม่จับราวจับ)
   - 3 = ปัจจัยร่วม (รีบไปทำอย่างอื่น)
   - 4 = สาเหตุเชิงระบบ (พนักงานไม่พอ)
   - 5 = สาเหตุราก (ระบบจัดเวรไม่คำนึงถึง peak hours)

8. conversation_quality_score: คะแนนคุณภาพ 0-100 ดูจาก:
   - ความลึกของสาเหตุ (30 คะแนน): Level 1=5, Level 2=10, Level 3=20, Level 4=25, Level 5=30
   - จำนวนมิติ Fishbone ที่สำรวจ (30 คะแนน): 0=0, 1=10, 2=20, 3+=30
   - ความละเอียดของแผนป้องกัน (20 คะแนน): คลุมเครือ=5, มีขั้นตอน=15, เป็นรูปธรรมวัดผลได้=20
   - ความร่วมมือของพนักงาน (20 คะแนน): ตอบสั้น/ตั้งรับ=5, ตอบปกติ=10, ร่วมวิเคราะห์ดี=20

9. explored_categories_summary: หมวดที่สำรวจแล้ว เลือกจาก ["คน", "กระบวนการ", "อุปกรณ์", "สภาพแวดล้อม", "การบริหาร"]

หมายเหตุ: ไม่ต้องส่ง violated_core_values เพราะ user เลือกไว้แล้ว

และประเมิน is_complete = true ก็ต่อเมื่อได้ข้อมูลครบทั้ง 4 ส่วนเท่านั้น

ตอบกลับเป็น JSON เท่านั้น:
{
  "why_it_matters": "...",
  "root_cause": "...",
  "core_value_analysis": "...",
  "prevention_plan": "...",
  "is_complete": true/false,
  "root_cause_categories": ["Man"],
  "root_cause_themes": ["สาเหตุสั้นๆ"],
  "root_cause_depth_achieved": 3,
  "conversation_quality_score": 65,
  "explored_categories_summary": ["คน", "กระบวนการ"]
}`

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey, x-client-info',
      },
    })
  }

  try {
    const body = await req.json()
    const { incident_id } = body
    let { chat_history } = body as { chat_history?: ChatMessage[] }

    console.log('Generating summary for incident:', incident_id)

    if (!incident_id) {
      return new Response(JSON.stringify({
        error: 'Missing required field: incident_id'
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // ถ้าไม่ส่ง chat_history มา → อ่านจาก DB (สำหรับ batch classification)
    if (!chat_history || chat_history.length === 0) {
      const { data: incRow, error: chatErr } = await supabase
        .from('B_Incident')
        .select('chat_history')
        .eq('id', incident_id)
        .maybeSingle()

      if (chatErr || !incRow?.chat_history || incRow.chat_history.length === 0) {
        return new Response(JSON.stringify({
          error: 'No chat_history found for incident ' + incident_id
        }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        })
      }
      chat_history = incRow.chat_history
      console.log('Read chat_history from DB:', chat_history!.length, 'messages')
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

    // สร้าง Gemini model - ใช้ Gemini 3 Pro Preview (ฉลาดกว่า สำหรับ summary ไม่ต้อง real-time)
    const model = genAI.getGenerativeModel({
      model: 'gemini-3-pro-preview',
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

    // ============================================
    // 4M Classification — validate + save ลง DB
    // ============================================
    const VALID_CATEGORIES = ['Man', 'Material', 'Method', 'Machine']

    // Validate root_cause_categories — เอาเฉพาะค่าที่ถูกต้อง
    const classifiedCategories = (summary.root_cause_categories || [])
      .filter((c: string) => VALID_CATEGORIES.includes(c))

    // Validate root_cause_themes — เอาเฉพาะ string ที่ไม่ว่าง, จำกัด 4 ข้อ
    const classifiedThemes = (summary.root_cause_themes || [])
      .filter((t: string) => typeof t === 'string' && t.trim().length > 0)
      .map((t: string) => t.trim())
      .slice(0, 4)

    // v4: Parse quality scoring fields
    const depthAchieved = typeof summary.root_cause_depth_achieved === 'number'
      && summary.root_cause_depth_achieved >= 1
      && summary.root_cause_depth_achieved <= 5
      ? summary.root_cause_depth_achieved
      : null

    const qualityScore = typeof summary.conversation_quality_score === 'number'
      && summary.conversation_quality_score >= 0
      && summary.conversation_quality_score <= 100
      ? summary.conversation_quality_score
      : null

    const validFishboneCategories = ['คน', 'กระบวนการ', 'อุปกรณ์', 'สภาพแวดล้อม', 'การบริหาร']
    const exploredCats = Array.isArray(summary.explored_categories_summary)
      ? summary.explored_categories_summary.filter((c: string) => validFishboneCategories.includes(c))
      : null

    // v4: Derive analysis_quality จาก depth + categories
    let analysisQuality: string | null = null
    if (depthAchieved !== null) {
      if (depthAchieved >= 4 && (exploredCats?.length ?? 0) >= 3) {
        analysisQuality = 'deep'
      } else if (depthAchieved >= 3 && (exploredCats?.length ?? 0) >= 2) {
        analysisQuality = 'moderate'
      } else {
        analysisQuality = 'shallow'
      }
    }

    // Save classification + quality scoring ลง DB โดยตรง (Flutter ไม่ต้องรู้)
    const updateData: Record<string, unknown> = {
      classified_at: new Date().toISOString(),
    }

    // 4M classification
    if (classifiedCategories.length > 0) updateData.root_cause_categories = classifiedCategories
    if (classifiedThemes.length > 0) updateData.root_cause_themes = classifiedThemes

    // Quality scoring (v4) — save เฉพาะที่มีค่า
    if (depthAchieved !== null) updateData.root_cause_depth = depthAchieved
    if (qualityScore !== null) updateData.conversation_quality_score = qualityScore
    if (exploredCats !== null && exploredCats.length > 0) updateData.explored_categories = exploredCats
    if (analysisQuality !== null) updateData.analysis_quality = analysisQuality

    if (Object.keys(updateData).length > 1) { // มากกว่าแค่ classified_at
      const { error: classifyError } = await supabase
        .from('B_Incident')
        .update(updateData)
        .eq('id', incident_id)

      if (classifyError) {
        console.error('Error saving classification + quality:', classifyError)
      } else {
        console.log('Classification + quality saved:', updateData)
      }
    }

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
