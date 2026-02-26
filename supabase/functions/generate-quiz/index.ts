// Edge Function: generate-quiz
// สร้างคำถาม Quiz จากเนื้อหาที่ส่งมา โดยใช้ Google Gemini AI
// ใช้แทน n8n webhook เพื่อความเสถียรและเร็วกว่า

import { GoogleGenerativeAI } from 'npm:@google/generative-ai'

// Google Gemini AI - ใช้ gemini-3-flash-preview (เร็วมาก และฉลาดกว่า 2.0)
const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!)

// Interface สำหรับ request body
interface RequestBody {
  text: string
  timestamp?: number // optional - ไม่ได้ใช้ แต่รับไว้เพื่อ backward compatible
}

// Interface สำหรับ quiz response
interface QuizResponse {
  question: string
  options: {
    A: string
    B: string
    C: string
  }
  correct_answer: 'A' | 'B' | 'C'
}

// System prompt สำหรับสร้างคำถาม
// ใช้ prompt เดียวกับ n8n workflow เพื่อให้ผลลัพธ์เหมือนกัน
const QUIZ_SYSTEM_PROMPT = `You are a professional nursing home manager with strong communication skills — firm, confident, and clear — guiding nurse assistants (users).
You will create simple question–answer exercises based on the provided material.
Each question must have three multiple-choice options (A, B, C), with only one correct answer.

The output must be written in Thai, using simple and easy-to-understand language suitable for a Grade 6 level.

IMPORTANT: You must respond with valid JSON only. No markdown, no explanations.
The JSON must have this exact structure:
{
  "question": "คำถามภาษาไทย",
  "options": {
    "A": "ตัวเลือก A",
    "B": "ตัวเลือก B",
    "C": "ตัวเลือก C"
  },
  "correct_answer": "A"
}`

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

    console.log('Generate quiz request received, text length:', text?.length || 0)

    // Validate input - ต้องมี text และยาวพอ
    if (!text || text.trim().length < 20) {
      return new Response(JSON.stringify({
        error: 'Text is required and must be at least 20 characters',
        question: '',
        options: { A: '', B: '', C: '' },
        correct_answer: 'A'
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
        responseMimeType: 'application/json', // บังคับให้ return JSON
        temperature: 0.7, // ค่ากลางๆ สำหรับความคิดสร้างสรรค์
        maxOutputTokens: 1024,
      },
    })

    // สร้าง prompt โดยรวม system prompt กับ text ที่ส่งมา
    const prompt = `${QUIZ_SYSTEM_PROMPT}

Here is the material to create a quiz from:
---
${text}
---

Create one quiz question based on this material. Respond with JSON only.`

    // Generate quiz
    const result = await model.generateContent(prompt)
    const responseText = result.response.text()

    console.log('Gemini response:', responseText)

    // Parse JSON response
    let quiz: QuizResponse
    try {
      quiz = JSON.parse(responseText)
    } catch (parseError) {
      console.error('Error parsing JSON:', parseError)
      // ถ้า parse ไม่ได้ ลอง extract JSON จาก response
      const jsonMatch = responseText.match(/\{[\s\S]*\}/)
      if (jsonMatch) {
        quiz = JSON.parse(jsonMatch[0])
      } else {
        throw new Error('Failed to parse AI response as JSON')
      }
    }

    // Validate quiz structure
    if (!quiz.question || !quiz.options || !quiz.correct_answer) {
      throw new Error('Invalid quiz structure from AI')
    }

    // Validate correct_answer is A, B, or C
    if (!['A', 'B', 'C'].includes(quiz.correct_answer)) {
      quiz.correct_answer = 'A' // fallback
    }

    console.log('Quiz generated successfully:', quiz.question.substring(0, 50) + '...')

    // Return quiz response
    return new Response(JSON.stringify(quiz), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })

  } catch (err: unknown) {
    console.error('Error in generate-quiz:', err)
    const errorMessage = err instanceof Error ? err.message : String(err)

    // Return error response พร้อม empty quiz structure
    // เพื่อให้ Flutter app handle ได้ง่าย
    return new Response(JSON.stringify({
      error: errorMessage,
      question: '',
      options: { A: '', B: '', C: '' },
      correct_answer: 'A'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  }
})
