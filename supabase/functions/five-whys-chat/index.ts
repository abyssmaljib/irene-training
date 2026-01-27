// Edge Function: five-whys-chat (Version 23)
// ใช้ Google Gemini API สำหรับ 5 Whys Coaching AI
// รับข้อความจาก user และตอบกลับพร้อมติดตาม progress ของ 4 pillars
// AI ประเมิน progress และ extract content เอง แล้ว return ให้ Flutter บันทึกลง DB ทันที
// v15: รองรับ user_name parameter เพื่อให้ AI เรียกชื่อผู้ใช้ได้ถูกต้อง (จาก nickname หรือ full_name)
// v16: แก้ไขการ clean response - ดึงเฉพาะ JSON object ออกจาก response ที่อาจมีข้อความปนมา
// v17: ใช้ Gemini JSON mode (responseMimeType: "application/json") เพื่อบังคับให้ return valid JSON
// v18: เพิ่ม cleanAiMessage() เพื่อตัด JSON metadata ที่ Gemini อาจใส่ต่อท้ายใน ai_message
// v19: ปรับปรุง prompt ให้ชัดเจนมากขึ้น - ai_message ต้องเป็นข้อความสนทนาเท่านั้น ห้ามมี JSON metadata
// v20: เพิ่มกฎการสนทนา - ห้ามขอบคุณ user ทุกรอบ ให้ถามคำถามต่อทันที
// v21: เปลี่ยนจาก gemini-2.5-flash เป็น gemini-2.5-pro (ฉลาดกว่า)
// v22: เพิ่ม show_core_value_picker flag - เมื่อ AI พร้อมให้ user เลือก Core Values จะส่ง flag + core_values list มาให้ Flutter แสดง UI picker
// v23: เพิ่ม current_pillar field (1-4) - บอกว่า AI กำลังถามเรื่องอะไรอยู่ เพื่อให้ Flutter แสดง highlight ที่ pillar นั้น

import { createClient } from 'npm:@supabase/supabase-js@2'
import { GoogleGenerativeAI } from 'npm:@google/generative-ai'

// Supabase client
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// Google Gemini AI - ใช้ Gemini 2.5 Pro
const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!)

// Default System prompt (ใช้เมื่อไม่มีใน DB)
const DEFAULT_SYSTEM_PROMPT = `คุณเป็น AI Coach ที่ช่วยพนักงาน Nursing Home ถอดบทเรียนจากเหตุการณ์ที่เกิดขึ้น
ใช้เทคนิค 5 Whys เพื่อหาสาเหตุที่แท้จริง และช่วยวิเคราะห์ 4 ประเด็นสำคัญ:

1. **ความสำคัญ (Why It Matters)**: ทำไมเรื่องนี้ถึงสำคัญ? ผลกระทบที่อาจเกิดขึ้นคืออะไร?
2. **สาเหตุที่แท้จริง (Root Cause)**: ถามว่า "ทำไม?" ซ้ำๆ จนเจอสาเหตุที่แท้จริง
3. **Core Values Analysis**: พฤติกรรมนี้ขัดแย้งกับค่านิยมหลักข้อใด?
4. **แนวทางการป้องกัน (Prevention Plan)**: จะป้องกันไม่ให้เกิดซ้ำได้อย่างไร?

แนวทางการสนทนา:
- ใช้ภาษาไทย เป็นมิตร ให้กำลังใจ ไม่ตำหนิ
- ถามทีละคำถาม ไม่ถามหลายคำถามพร้อมกัน
- ฟังอย่างตั้งใจ สรุปสิ่งที่ได้ยิน
- ช่วยให้พนักงานค้นพบคำตอบด้วยตัวเอง ไม่ใช่บอกคำตอบ
- เมื่อครบ 4 ประเด็น ให้สรุปและแสดงความชื่นชม
- **ห้ามขอบคุณ user ทุกรอบ** - ไม่ต้องพูดว่า "ขอบคุณที่เล่าให้ฟัง" หรือ "ขอบคุณที่ตอบ" ทุกครั้ง ให้ตอบกลับและถามคำถามต่อทันที

เริ่มต้นด้วยการทักทายและขอให้เล่าเหตุการณ์ในมุมมองของพนักงาน`

interface ChatMessage {
  role: 'user' | 'assistant'
  content: string
  timestamp: string
}

interface PillarsProgress {
  why_it_matters: boolean
  root_cause: boolean
  core_values: boolean
  prevention_plan: boolean
}

// เนื้อหาที่ extract ได้จาก 4 Pillars (สำหรับบันทึกลง DB ทันที)
interface PillarContent {
  why_it_matters: string | null
  root_cause: string | null
  core_value_analysis: string | null
  violated_core_values: string[]
  prevention_plan: string | null
}

// Interface ตรงกับ B_Core_Value_Global table schema
interface CoreValue {
  id: number
  name: string           // เช่น "Speak Up (กล้าพูด กล้าสื่อสาร)"
  description: string | null
  is_active: boolean
  sort_order: number
}

interface RequestBody {
  incident_id: number
  message: string
  chat_history: ChatMessage[]
  incident_title?: string
  incident_description?: string
  user_name?: string  // ชื่อเล่น/ชื่อจริงของ user สำหรับให้ AI เรียก
}

// ดึง System Prompt จาก B_AI_Config table
// ใช้ config_key = 'incident_coach_prompt'
async function getSystemPrompt(): Promise<string> {
  try {
    const { data, error } = await supabase
      .from('B_AI_Config')
      .select('config_value')
      .eq('config_key', 'incident_coach_prompt')
      .eq('is_active', true)
      .single()

    if (error || !data) {
      console.log('Using default system prompt')
      return DEFAULT_SYSTEM_PROMPT
    }

    return data.config_value
  } catch (e) {
    console.error('Error fetching system prompt:', e)
    return DEFAULT_SYSTEM_PROMPT
  }
}

// ดึง Core Values จาก B_Core_Value_Global table
async function getCoreValues(): Promise<CoreValue[]> {
  try {
    const { data, error } = await supabase
      .from('B_Core_Value_Global')
      .select('id, name, description, is_active, sort_order')
      .eq('is_active', true)
      .order('sort_order')

    if (error || !data) {
      console.log('Using default core values, error:', error)
      return []
    }

    return data as CoreValue[]
  } catch (e) {
    console.error('Error fetching core values:', e)
    return []
  }
}

// สร้าง Core Values list สำหรับใส่ใน prompt
// Format: "- Speak Up (กล้าพูด กล้าสื่อสาร): description"
function formatCoreValuesForPrompt(coreValues: CoreValue[]): string {
  return coreValues.map((cv: CoreValue) =>
    `- ${cv.name}${cv.description ? ': ' + cv.description : ''}`
  ).join('\n')
}

// Extract Core Value name เป็น list สำหรับ validate violated_core_values
// เช่น ["Speak Up (กล้าพูด กล้าสื่อสาร)", "Service Mind (มีใจรักบริการ)"]
function getCoreValueNames(coreValues: CoreValue[]): string[] {
  return coreValues.map((cv: CoreValue) => cv.name)
}

// ดึงเฉพาะ JSON object จาก AI response
// เนื่องจากบางครั้ง AI ตอบข้อความมาปนกับ JSON
// เช่น "เข้าใจค่ะ {...json...} ลองเล่าต่อนะคะ" -> ดึงเฉพาะ {...json...}
function extractJsonFromResponse(text: string): string {
  // ลบ markdown code block ถ้ามี
  let cleaned = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()

  // หา JSON object ที่เริ่มด้วย { และจบด้วย }
  // ใช้ bracket counting เพื่อหา matching braces
  const startIndex = cleaned.indexOf('{')
  if (startIndex === -1) {
    return cleaned // ไม่เจอ { ให้ return เดิม
  }

  let bracketCount = 0
  let endIndex = -1

  for (let i = startIndex; i < cleaned.length; i++) {
    if (cleaned[i] === '{') {
      bracketCount++
    } else if (cleaned[i] === '}') {
      bracketCount--
      if (bracketCount === 0) {
        endIndex = i
        break
      }
    }
  }

  if (endIndex === -1) {
    return cleaned // ไม่เจอ matching } ให้ return เดิม
  }

  // ดึงเฉพาะ JSON object
  return cleaned.substring(startIndex, endIndex + 1)
}

// ทำความสะอาด ai_message - ตัด JSON metadata ที่ Gemini อาจใส่ต่อท้าย
// เช่น "ข้อความ...", "pillars_progress": {...} -> "ข้อความ..."
// หรือ "ข้อความ...", "why_it_matters": true -> "ข้อความ..."
function cleanAiMessage(message: string): string {
  if (!message) return message

  // Pattern ที่บ่งบอกว่ามี JSON metadata ต่อท้าย
  // เช่น ", "pillars_progress" หรือ ", "why_it_matters" หรือ ", "pillar_content"
  const jsonMetadataPatterns = [
    /",\s*"pillars_progress"\s*:/,
    /",\s*"pillar_content"\s*:/,
    /",\s*"why_it_matters"\s*:/,
    /",\s*"root_cause"\s*:/,
    /",\s*"core_values"\s*:/,
    /",\s*"prevention_plan"\s*:/,
    /",\s*"is_complete"\s*:/,
    /",\s*"violated_core_values"\s*:/,
    /",\s*"core_value_analysis"\s*:/,
  ]

  let cleanedMessage = message

  // หา pattern แรกที่เจอ และตัดออก
  for (const pattern of jsonMetadataPatterns) {
    const match = cleanedMessage.match(pattern)
    if (match && match.index !== undefined) {
      // ตัดข้อความตั้งแต่ก่อน pattern
      cleanedMessage = cleanedMessage.substring(0, match.index)
      console.log(`cleanAiMessage: Found JSON metadata at index ${match.index}, truncated`)
      break
    }
  }

  // ลบ trailing quotes และ whitespace
  cleanedMessage = cleanedMessage.replace(/["'\s]+$/, '').trim()

  return cleanedMessage
}

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
    const { incident_id, message, chat_history, incident_title, incident_description, user_name } = body

    console.log('Received request:', { incident_id, message, historyLength: chat_history.length, user_name })

    if (!message || !incident_id) {
      return new Response(JSON.stringify({
        error: 'Missing required fields: incident_id, message'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      })
    }

    // ดึงข้อมูลที่จำเป็นพร้อมกัน
    const [systemPrompt, coreValues, incidentResult] = await Promise.all([
      getSystemPrompt(),
      getCoreValues(),
      supabase
        .from('B_Incident')
        .select('title, description, category, severity')
        .eq('id', incident_id)
        .single()
    ])

    const incident = incidentResult.data
    if (incidentResult.error) {
      console.error('Error fetching incident:', incidentResult.error)
    }

    // สร้าง Core Values list สำหรับใส่ใน prompt
    const coreValuesText = formatCoreValuesForPrompt(coreValues)
    // List ของ Core Value names สำหรับ validate violated_core_values
    const coreValueNames = getCoreValueNames(coreValues)

    // ชื่อ user สำหรับให้ AI เรียก (ถ้าไม่มีให้ใช้ "คุณ")
    const userName = user_name || 'คุณ'

    // Replace placeholders ใน system prompt จาก DB
    // {{USER_NAME}}, {{INCIDENT_DESCRIPTION}}, {{CORE_VALUES_LIST}}
    const processedPrompt = systemPrompt
      .replace(/\{\{USER_NAME\}\}/g, userName)
      .replace(/\{\{INCIDENT_DESCRIPTION\}\}/g, incident_description || incident?.description || 'ไม่ระบุ')
      .replace(/\{\{CORE_VALUES_LIST\}\}/g, coreValuesText)

    // สร้าง Gemini model - ใช้ Gemini 3 Flash Preview (เร็วกว่า)
    const model = genAI.getGenerativeModel({ model: 'gemini-3-flash-preview' })

    // Build conversation history for Gemini
    const geminiHistory = chat_history.map(msg => ({
      role: msg.role === 'user' ? 'user' : 'model',
      parts: [{ text: msg.content }]
    }))

    // สร้าง enhanced system prompt พร้อม incident details และ JSON format instructions
    const enhancedPrompt = `${processedPrompt}

## Core Values ที่ใช้วิเคราะห์:
${coreValuesText}

## เหตุการณ์ที่กำลังถอดบทเรียน:
- หัวข้อ: ${incident_title || incident?.title || 'ไม่ระบุ'}
- รายละเอียด: ${incident_description || incident?.description || 'ไม่ระบุ'}
- หมวดหมู่: ${incident?.category || 'ไม่ระบุ'}
- ความรุนแรง: ${incident?.severity || 'ไม่ระบุ'}

## สำคัญมาก - การประเมิน Progress และ Extract Content:
หลังจากตอบคำถาม คุณต้อง return JSON ที่มี:
1. "ai_message": ข้อความตอบกลับ
2. "pillars_progress": ประเมินว่า USER ได้ให้ข้อมูลครบในแต่ละหัวข้อหรือยัง
3. "pillar_content": extract เนื้อหาที่ USER ตอบมาในแต่ละหัวข้อ (ถ้ามี)
4. "is_complete": true เมื่อครบทั้ง 4 หัวข้อ
5. "current_pillar": ตัวเลข 1-4 บอกว่าตอนนี้กำลังถามเรื่องอะไร (1=ความสำคัญ, 2=สาเหตุ, 3=Core Values, 4=การป้องกัน)

### กฎการประเมิน pillars_progress (สำคัญมาก!):
- ตั้งค่าเป็น true เฉพาะเมื่อ **USER ตอบ** ข้อมูลในหัวข้อนั้นแล้วเท่านั้น
- ห้าม! ตั้งค่าเป็น true ถ้า AI เป็นคนพูดถึงเรื่องนั้น - ต้องเป็น USER ที่ตอบเอง!
- ถ้าเพิ่งเริ่มสนทนา หรือ AI เพิ่งถาม ทุกค่าต้องเป็น false

### กฎการ extract pillar_content:
- extract เฉพาะข้อมูลที่ USER พูดถึง (ไม่ใช่ที่ AI ถาม)
- สรุปเป็นประโยคสั้นๆ กระชับ
- ถ้ายังไม่มีข้อมูล ให้ใส่ null
- violated_core_values: ใส่ชื่อ Core Value ตรงตามรายการข้างต้น เช่น ["Speak Up (กล้าพูด กล้าสื่อสาร)", "Integrity (ซื่อสัตย์ รับผิดชอบ)"]

### กฎสำหรับ current_pillar (สำคัญมาก!):
- ใส่ตัวเลข 1-4 เพื่อบอกว่าตอนนี้ AI กำลังถามเรื่องอะไร:
  1 = ความสำคัญ (Why It Matters) - กำลังถามเกี่ยวกับความสำคัญหรือผลกระทบ
  2 = สาเหตุ (Root Cause) - กำลังถาม "ทำไม?" เพื่อหาสาเหตุที่แท้จริง
  3 = Core Values - กำลังถามเกี่ยวกับค่านิยมหลักที่เกี่ยวข้อง
  4 = การป้องกัน (Prevention) - กำลังถามเกี่ยวกับแนวทางป้องกัน
- ใส่ null ถ้าเป็นการทักทาย/เปิด/ปิดบทสนทนา หรือไม่ได้ถามเรื่องใดเฉพาะ
- ต้องใส่ค่านี้ทุกครั้ง เพื่อให้ Flutter แสดง highlight ที่ pillar ที่กำลังคุยอยู่

### กฎสำหรับ show_core_value_picker (สำคัญมาก!):
- ใส่ "show_core_value_picker": true เมื่อ:
  1. why_it_matters และ root_cause เป็น true แล้ว (ผ่าน 2 หัวข้อแรกแล้ว)
  2. core_values ยังเป็น false (ยังไม่ได้เลือก Core Values)
  3. AI กำลังจะถาม/เปิดประเด็นเรื่อง Core Values
- เมื่อ show_core_value_picker = true, Flutter จะแสดง UI ให้ user เลือก Core Values แทนการพิมพ์
- หลังจาก user เลือก Core Values แล้ว ข้อความจะถูกส่งมา และ AI ควรตั้ง core_values = true

## กฎการตอบ (สำคัญที่สุด - อ่านให้ดี!):

### กฎเหล็กสำหรับ "ai_message" field:
- "ai_message" ต้องเป็น **ข้อความสนทนาภาษาไทยเท่านั้น** - เป็นประโยคที่พูดกับ user โดยตรง
- **ห้ามเด็ดขาด!** ใส่ JSON keys หรือ metadata ใดๆ ใน ai_message
- **ห้ามเด็ดขาด!** ใส่คำว่า "pillars_progress", "pillar_content", "why_it_matters", "root_cause", "is_complete" หรือ JSON syntax ({, }, :, [, ]) ใน ai_message
- ai_message คือข้อความที่จะแสดงใน chat bubble โดยตรง - ต้องอ่านเข้าใจง่าย ไม่มี code ปน

### โครงสร้าง JSON Response:
Response ต้องเป็น JSON object ที่มี 6 fields แยกกันชัดเจน:
1. "ai_message": string - ข้อความสนทนาภาษาไทยเท่านั้น (ห้ามมี JSON ปน!)
2. "pillars_progress": object - ประเมิน progress ของ 4 หัวข้อ
3. "pillar_content": object - extract เนื้อหาจาก user
4. "is_complete": boolean - สถานะเสร็จสิ้น
5. "show_core_value_picker": boolean - true เมื่อต้องการให้ user เลือก Core Values
6. "current_pillar": number|null - ตัวเลข 1-4 บอกว่ากำลังถามเรื่องอะไร (null ถ้าไม่ได้ถามเรื่องใดเฉพาะ)

### ตัวอย่างที่ถูกต้อง (ai_message เป็นข้อความสนทนาล้วนๆ):
{"ai_message": "สวัสดีค่ะจิ๊บ ขอบคุณที่มาคุยกันนะคะ มาเริ่มถอดบทเรียนกันเลยค่ะ เล่าให้ฟังหน่อยได้ไหมคะว่าเหตุการณ์นี้ส่งผลกระทบอย่างไรบ้าง?", "pillars_progress": {"why_it_matters": false, "root_cause": false, "core_values": false, "prevention_plan": false}, "pillar_content": {"why_it_matters": null, "root_cause": null, "core_value_analysis": null, "violated_core_values": [], "prevention_plan": null}, "is_complete": false, "show_core_value_picker": false, "current_pillar": 1}

### ตัวอย่างเมื่อถึงขั้นตอน Core Values (show_core_value_picker = true, current_pillar = 3):
{"ai_message": "จากที่คุยกันมา เรามาดูกันว่าเหตุการณ์นี้เกี่ยวข้องกับค่านิยมหลักข้อไหนบ้างนะคะ กรุณาเลือก Core Values ที่เกี่ยวข้องค่ะ", "pillars_progress": {"why_it_matters": true, "root_cause": true, "core_values": false, "prevention_plan": false}, "pillar_content": {...}, "is_complete": false, "show_core_value_picker": true, "current_pillar": 3}

### ตัวอย่างที่ผิด (ห้ามทำแบบนี้!):
{"ai_message": "สวัสดีค่ะ", "pillars_progress": {"why_it_matters": true}...} <-- ผิด! ai_message ต้องไม่มี JSON ต่อท้าย
{"ai_message": "ขอบคุณค่ะ, \\"why_it_matters\\": true"} <-- ผิด! ห้ามมี JSON keys ใน ai_message`

    // เริ่ม chat session พร้อม JSON mode
    // ใช้ responseMimeType: "application/json" เพื่อบังคับให้ Gemini return valid JSON
    const chat = model.startChat({
      history: [
        {
          role: 'user',
          parts: [{ text: enhancedPrompt }]
        },
        {
          role: 'model',
          parts: [{ text: '{"ai_message": "เข้าใจแล้วค่ะ ฉันพร้อมช่วยถอดบทเรียนและจะตอบเป็น JSON format", "pillars_progress": {"why_it_matters": false, "root_cause": false, "core_values": false, "prevention_plan": false}, "pillar_content": {"why_it_matters": null, "root_cause": null, "core_value_analysis": null, "violated_core_values": [], "prevention_plan": null}, "is_complete": false, "show_core_value_picker": false, "current_pillar": null}' }]
        },
        ...geminiHistory
      ],
      generationConfig: {
        maxOutputTokens: 1500,
        temperature: 0.7,
        // บังคับให้ Gemini return valid JSON (JSON mode)
        responseMimeType: "application/json",
      },
    })

    // ส่งข้อความและรับคำตอบ
    const result = await chat.sendMessage(message)
    let aiResponseText = result.response.text()

    console.log('Raw AI response:', aiResponseText)

    // Parse JSON response
    let aiMessage = ''
    let pillarsProgress: PillarsProgress = {
      why_it_matters: false,
      root_cause: false,
      core_values: false,
      prevention_plan: false
    }
    let pillarContent: PillarContent = {
      why_it_matters: null,
      root_cause: null,
      core_value_analysis: null,
      violated_core_values: [],
      prevention_plan: null
    }
    let isComplete = false
    let showCoreValuePicker = false
    let currentPillar: number | null = null

    try {
      // ดึงเฉพาะ JSON จาก response (ลบข้อความที่ AI อาจตอบมาปนนอก JSON)
      aiResponseText = extractJsonFromResponse(aiResponseText)
      console.log('Cleaned JSON:', aiResponseText)

      const parsed = JSON.parse(aiResponseText)
      // ทำความสะอาด ai_message - ตัด JSON metadata ที่ Gemini อาจใส่ต่อท้าย
      aiMessage = cleanAiMessage(parsed.ai_message || '')

      if (parsed.pillars_progress) {
        pillarsProgress = {
          why_it_matters: parsed.pillars_progress.why_it_matters === true,
          root_cause: parsed.pillars_progress.root_cause === true,
          core_values: parsed.pillars_progress.core_values === true,
          prevention_plan: parsed.pillars_progress.prevention_plan === true
        }
      }

      // Extract pillar content ถ้ามี
      if (parsed.pillar_content) {
        pillarContent = {
          why_it_matters: parsed.pillar_content.why_it_matters || null,
          root_cause: parsed.pillar_content.root_cause || null,
          core_value_analysis: parsed.pillar_content.core_value_analysis || null,
          violated_core_values: Array.isArray(parsed.pillar_content.violated_core_values)
            ? parsed.pillar_content.violated_core_values.filter((name: string) => coreValueNames.includes(name))
            : [],
          prevention_plan: parsed.pillar_content.prevention_plan || null
        }
      }

      isComplete = parsed.is_complete === true
      showCoreValuePicker = parsed.show_core_value_picker === true
      // Parse current_pillar - ต้องเป็นตัวเลข 1-4 หรือ null
      const parsedPillar = parsed.current_pillar
      if (typeof parsedPillar === 'number' && parsedPillar >= 1 && parsedPillar <= 4) {
        currentPillar = parsedPillar
      } else {
        currentPillar = null
      }
    } catch (parseError) {
      console.error('Error parsing AI response as JSON:', parseError)
      // ถ้า parse ไม่ได้ ใช้ response เดิมเป็น message
      aiMessage = aiResponseText
    }

    // ตรวจสอบว่าครบทุก pillar หรือยัง
    const allComplete = Object.values(pillarsProgress).every(v => v)
    if (allComplete && !isComplete) {
      isComplete = true
    }

    console.log('AI response generated, pillars progress:', pillarsProgress)
    console.log('Pillar content:', pillarContent)
    console.log('Show core value picker:', showCoreValuePicker)
    console.log('Current pillar:', currentPillar)

    // สร้าง response object
    const responseData: Record<string, unknown> = {
      ai_message: aiMessage,
      pillars_progress: pillarsProgress,
      pillar_content: pillarContent,
      is_complete: isComplete,
      show_core_value_picker: showCoreValuePicker,
      current_pillar: currentPillar,
    }

    // ถ้า showCoreValuePicker = true ให้ส่ง available_core_values กลับไปด้วย
    // เพื่อให้ Flutter ใช้แสดง UI picker
    if (showCoreValuePicker) {
      responseData.available_core_values = coreValues.map((cv: CoreValue) => ({
        id: cv.id,
        name: cv.name,
        description: cv.description,
      }))
    }

    return new Response(JSON.stringify(responseData), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })

  } catch (err: unknown) {
    console.error('Error in five-whys-chat:', err)
    const errorMessage = err instanceof Error ? err.message : String(err)
    return new Response(JSON.stringify({
      error: errorMessage
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  }
})
