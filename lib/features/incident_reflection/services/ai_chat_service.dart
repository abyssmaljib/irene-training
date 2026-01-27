// Service สำหรับคุยกับ AI Coach ผ่าน Supabase Edge Functions
// ใช้สำหรับการถอดบทเรียน 5 Whys

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import '../models/reflection_pillars.dart';

/// เนื้อหาที่ extract ได้จาก 4 Pillars
/// ใช้สำหรับบันทึกลง database ทันทีที่ได้ข้อมูล
class PillarContent {
  /// ความสำคัญ/ผลกระทบ (Pillar 1)
  final String? whyItMatters;

  /// สาเหตุที่แท้จริง (Pillar 2)
  final String? rootCause;

  /// Core Values ที่เกี่ยวข้อง (Pillar 3)
  final String? coreValueAnalysis;

  /// รายการ Core Values ที่ถูกละเมิด
  final List<String> violatedCoreValues;

  /// แนวทางป้องกัน (Pillar 4)
  final String? preventionPlan;

  const PillarContent({
    this.whyItMatters,
    this.rootCause,
    this.coreValueAnalysis,
    this.violatedCoreValues = const [],
    this.preventionPlan,
  });

  /// Parse จาก JSON response
  factory PillarContent.fromJson(Map<String, dynamic> json) {
    // Parse violated_core_values จาก list of strings
    final violatedCodes = (json['violated_core_values'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return PillarContent(
      whyItMatters: json['why_it_matters'] as String?,
      rootCause: json['root_cause'] as String?,
      coreValueAnalysis: json['core_value_analysis'] as String?,
      violatedCoreValues: violatedCodes,
      preventionPlan: json['prevention_plan'] as String?,
    );
  }

  /// ตรวจสอบว่ามีเนื้อหาใดๆ หรือไม่
  bool get hasAnyContent =>
      whyItMatters != null ||
      rootCause != null ||
      coreValueAnalysis != null ||
      violatedCoreValues.isNotEmpty ||
      preventionPlan != null;
}

/// ทำความสะอาด ai_message - ตัด JSON metadata ที่ Gemini อาจใส่ต่อท้าย
/// รองรับกรณี:
/// 1. ข้อความ + JSON metadata: "ข้อความ...", "pillars_progress": {...}
/// 2. ขึ้นต้นด้วย {"ai_message": แต่ไม่ใช่ valid JSON
/// 3. ขึ้นต้นด้วย ai_message": "... (JSON ที่ถูกตัดมาไม่สมบูรณ์)
String _cleanAiMessage(String message) {
  if (message.isEmpty) return message;

  var cleanedMessage = message.trim();

  // กรณีที่ 3: ขึ้นต้นด้วย ai_message": "... (ไม่มี { และ " นำหน้า)
  // เช่น: ai_message": "ขออภัยค่ะ พี่อาจจะสรุปเร็วไปนิดนึง..."
  if (cleanedMessage.startsWith('ai_message')) {
    // ลอง extract ข้อความที่อยู่หลัง ai_message": "
    final partialJsonRegex = RegExp(r'ai_message"\s*:\s*"([^"]*(?:\\.[^"]*)*)"?');
    final match = partialJsonRegex.firstMatch(cleanedMessage);
    if (match != null && match.group(1) != null) {
      // Unescape JSON string
      cleanedMessage = match.group(1)!
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\');
      debugPrint('_cleanAiMessage: Extracted from partial JSON (ai_message prefix)');
      return cleanedMessage;
    }
  }

  // กรณีที่ 2: ขึ้นต้นด้วย { และมี "ai_message" - ลอง extract ข้อความออกมา
  if (cleanedMessage.startsWith('{') && cleanedMessage.contains('"ai_message"')) {
    // ใช้ regex extract ai_message (กรณี JSON ไม่สมบูรณ์)
    final aiMessageRegex = RegExp(r'"ai_message"\s*:\s*"([^"]*(?:\\.[^"]*)*)"');
    final match = aiMessageRegex.firstMatch(cleanedMessage);
    if (match != null && match.group(1) != null) {
      // Unescape JSON string
      cleanedMessage = match.group(1)!
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\');
      debugPrint('_cleanAiMessage: Extracted ai_message from JSON wrapper');
    }
  }

  // Pattern ที่บ่งบอกว่ามี JSON metadata ต่อท้าย
  // เช่น ", "pillars_progress" หรือ ", "why_it_matters"
  final jsonMetadataPatterns = [
    RegExp(r'",\s*"pillars_progress"\s*:'),
    RegExp(r'",\s*"pillar_content"\s*:'),
    RegExp(r'",\s*"why_it_matters"\s*:'),
    RegExp(r'",\s*"root_cause"\s*:'),
    RegExp(r'",\s*"core_values"\s*:'),
    RegExp(r'",\s*"prevention_plan"\s*:'),
    RegExp(r'",\s*"is_complete"\s*:'),
    RegExp(r'",\s*"violated_core_values"\s*:'),
    RegExp(r'",\s*"core_value_analysis"\s*:'),
  ];

  // หา pattern แรกที่เจอ และตัดออก
  for (final pattern in jsonMetadataPatterns) {
    final match = pattern.firstMatch(cleanedMessage);
    if (match != null) {
      // ตัดข้อความตั้งแต่ก่อน pattern
      cleanedMessage = cleanedMessage.substring(0, match.start);
      debugPrint('_cleanAiMessage: Found JSON metadata, truncated');
      break;
    }
  }

  // ลบ trailing quotes, braces และ whitespace
  cleanedMessage = cleanedMessage.replaceAll(RegExp(r'["{}\s]+$'), '').trim();

  // ลบ leading quotes, braces และ whitespace
  cleanedMessage = cleanedMessage.replaceAll(RegExp(r'^["{}\s]+'), '').trim();

  return cleanedMessage;
}

/// Core Value ที่ได้จาก API สำหรับแสดงใน picker
class AvailableCoreValue {
  final int id;
  final String name;
  final String? description;

  const AvailableCoreValue({
    required this.id,
    required this.name,
    this.description,
  });

  factory AvailableCoreValue.fromJson(Map<String, dynamic> json) {
    return AvailableCoreValue(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}

/// Response จาก Edge Function: five-whys-chat
class AiChatResponse {
  /// ข้อความตอบกลับจาก AI
  final String message;

  /// ความคืบหน้าของ 4 Pillars
  final ReflectionPillars pillarsProgress;

  /// เนื้อหาที่ extract ได้จาก 4 Pillars (สำหรับบันทึกลง DB)
  final PillarContent? pillarContent;

  /// เสร็จสิ้นการถอดบทเรียนหรือยัง
  final bool isComplete;

  /// Flag บอกว่าต้องแสดง Core Value picker หรือไม่
  /// เมื่อเป็น true จะแสดง UI ให้ user เลือก Core Values แทนการพิมพ์
  final bool showCoreValuePicker;

  /// รายการ Core Values ที่สามารถเลือกได้ (ส่งมาเมื่อ showCoreValuePicker = true)
  final List<AvailableCoreValue> availableCoreValues;

  /// Pillar ที่กำลังถามอยู่ (1-4)
  /// 1 = ความสำคัญ, 2 = สาเหตุ, 3 = Core Values, 4 = การป้องกัน
  /// null = ไม่ได้ถามเรื่องใดเฉพาะ (ทักทาย/ปิดสนทนา)
  final int? currentPillar;

  const AiChatResponse({
    required this.message,
    required this.pillarsProgress,
    this.pillarContent,
    required this.isComplete,
    this.showCoreValuePicker = false,
    this.availableCoreValues = const [],
    this.currentPillar,
  });

  /// Parse จาก JSON response
  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    // Parse pillars_progress จาก nested object
    final pillarsJson = json['pillars_progress'] as Map<String, dynamic>? ?? {};

    // Parse pillar_content ถ้ามี (สำหรับบันทึกลง DB)
    final contentJson = json['pillar_content'] as Map<String, dynamic>?;
    final pillarContent = contentJson != null
        ? PillarContent.fromJson(contentJson)
        : null;

    // ทำความสะอาด ai_message - ตัด JSON metadata ที่ Gemini อาจใส่ต่อท้าย
    final rawMessage = json['ai_message'] as String? ?? '';
    final cleanedMessage = _cleanAiMessage(rawMessage);

    // Parse available_core_values ถ้ามี (สำหรับแสดง picker)
    final coreValuesJson = json['available_core_values'] as List<dynamic>?;
    final availableCoreValues = coreValuesJson != null
        ? coreValuesJson
            .map((cv) => AvailableCoreValue.fromJson(cv as Map<String, dynamic>))
            .toList()
        : <AvailableCoreValue>[];

    // Parse current_pillar (1-4 หรือ null)
    final rawPillar = json['current_pillar'];
    int? currentPillar;
    if (rawPillar is int && rawPillar >= 1 && rawPillar <= 4) {
      currentPillar = rawPillar;
    }

    return AiChatResponse(
      message: cleanedMessage,
      pillarsProgress: ReflectionPillars.fromJson(pillarsJson),
      pillarContent: pillarContent,
      isComplete: json['is_complete'] as bool? ?? false,
      showCoreValuePicker: json['show_core_value_picker'] as bool? ?? false,
      availableCoreValues: availableCoreValues,
      currentPillar: currentPillar,
    );
  }
}

/// Service สำหรับคุยกับ AI Coach
/// เรียก Supabase Edge Functions สำหรับ 5 Whys coaching
class AiChatService {
  // Singleton instance
  static final AiChatService instance = AiChatService._();
  AiChatService._();

  final _supabase = Supabase.instance.client;

  /// ส่งข้อความไปยัง AI Coach และรับการตอบกลับ
  ///
  /// - [incidentId]: ID ของ incident ที่กำลังถอดบทเรียน
  /// - [message]: ข้อความที่ user ส่ง
  /// - [chatHistory]: ประวัติการสนทนาก่อนหน้า
  /// - [incidentTitle]: หัวข้อ incident (สำหรับ context)
  /// - [incidentDescription]: รายละเอียด incident (สำหรับ context)
  /// - [userName]: ชื่อเล่น/ชื่อจริงของ user สำหรับให้ AI เรียก
  ///
  /// Returns [AiChatResponse] ที่มีข้อความตอบกลับ, progress, และ completion status
  Future<AiChatResponse?> sendMessage({
    required int incidentId,
    required String message,
    required List<ChatMessage> chatHistory,
    String? incidentTitle,
    String? incidentDescription,
    String? userName,
  }) async {
    // Log ทันทีที่เข้า function เพื่อ debug
    debugPrint('=== AiChatService.sendMessage CALLED ===');
    debugPrint('AiChatService: incidentId=$incidentId');
    debugPrint('AiChatService: chatHistory.length=${chatHistory.length}');

    try {
      debugPrint('AiChatService: sending message to incident $incidentId');

      // แปลง chat history เป็น format ที่ Edge Function ต้องการ
      final historyJson = chatHistory
          .where((msg) => !msg.isLoading) // ไม่ส่ง loading messages
          .map((msg) => {
                'role': msg.role == ChatRole.user ? 'user' : 'assistant',
                'content': msg.content,
                'timestamp': msg.timestamp.toIso8601String(),
              })
          .toList();

      // เรียก Edge Function พร้อม timeout 30 วินาที
      // เพราะ Gemini AI อาจใช้เวลานานในการตอบ
      debugPrint('AiChatService: calling five-whys-chat...');
      debugPrint('AiChatService: incidentId=$incidentId, message=$message');
      debugPrint('AiChatService: historyLength=${historyJson.length}');

      final response = await _supabase.functions.invoke(
        'five-whys-chat',
        body: {
          'incident_id': incidentId,
          'message': message,
          'chat_history': historyJson,
          'incident_title': incidentTitle,
          'incident_description': incidentDescription,
          'user_name': userName,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('AiChatService: Request timeout after 30 seconds');
          throw TimeoutException('AI ใช้เวลาตอบนานเกินไป กรุณาลองใหม่');
        },
      );

      // Debug: แสดง response ทั้งหมด
      debugPrint('AiChatService: response.status = ${response.status}');
      debugPrint('AiChatService: response.data = ${response.data}');
      debugPrint('AiChatService: response.data.runtimeType = ${response.data.runtimeType}');

      // ตรวจสอบ response - status 200 = success
      if (response.status != 200) {
        debugPrint(
            'AiChatService: Edge Function error - status ${response.status}');
        debugPrint('AiChatService: response data = ${response.data}');
        return null;
      }

      // Parse response
      final data = response.data;
      if (data == null) {
        debugPrint('AiChatService: null response data');
        return null;
      }

      // Handle both Map and String responses
      Map<String, dynamic> jsonData;
      if (data is Map<String, dynamic>) {
        jsonData = data;
      } else if (data is String) {
        jsonData = jsonDecode(data) as Map<String, dynamic>;
      } else {
        debugPrint('AiChatService: unexpected response type: ${data.runtimeType}');
        return null;
      }

      final result = AiChatResponse.fromJson(jsonData);
      debugPrint(
          'AiChatService: received response - progress: ${result.pillarsProgress.completedCount}/4, complete: ${result.isComplete}');

      return result;
    } catch (e, stackTrace) {
      debugPrint('AiChatService.sendMessage error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// สรุป 4 Pillars จาก chat history
  ///
  /// เรียก Edge Function generate-incident-summary เพื่อสรุปผลการถอดบทเรียน
  ///
  /// - [incidentId]: ID ของ incident
  /// - [chatHistory]: ประวัติการสนทนาทั้งหมด
  ///
  /// Returns [ReflectionSummary] ที่มีข้อมูล 4 Pillars
  Future<ReflectionSummary?> generateSummary({
    required int incidentId,
    required List<ChatMessage> chatHistory,
  }) async {
    try {
      debugPrint(
          'AiChatService: generating summary for incident $incidentId');

      // แปลง chat history เป็น format ที่ Edge Function ต้องการ
      final historyJson = chatHistory
          .where((msg) => !msg.isLoading)
          .map((msg) => {
                'role': msg.role == ChatRole.user ? 'user' : 'assistant',
                'content': msg.content,
                'timestamp': msg.timestamp.toIso8601String(),
              })
          .toList();

      // เรียก Edge Function พร้อม timeout 30 วินาที
      final response = await _supabase.functions.invoke(
        'generate-incident-summary',
        body: {
          'incident_id': incidentId,
          'chat_history': historyJson,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('AiChatService: generateSummary timeout after 30 seconds');
          throw TimeoutException('AI ใช้เวลาสรุปนานเกินไป กรุณาลองใหม่');
        },
      );

      // ตรวจสอบ response
      if (response.status != 200) {
        debugPrint(
            'AiChatService: generate-incident-summary error - status ${response.status}');
        return null;
      }

      // Parse response
      final data = response.data;
      if (data == null) {
        debugPrint('AiChatService: null response data');
        return null;
      }

      // Handle both Map and String responses
      Map<String, dynamic> jsonData;
      if (data is Map<String, dynamic>) {
        jsonData = data;
      } else if (data is String) {
        jsonData = jsonDecode(data) as Map<String, dynamic>;
      } else {
        debugPrint('AiChatService: unexpected response type: ${data.runtimeType}');
        return null;
      }

      // ตรวจสอบว่าสรุปได้ครบหรือไม่
      final isComplete = jsonData['is_complete'] as bool? ?? false;
      if (!isComplete) {
        debugPrint('AiChatService: summary incomplete');
      }

      final summary = ReflectionSummary.fromJson(jsonData);
      debugPrint(
          'AiChatService: summary generated - isComplete: ${summary.isComplete}, violations: ${summary.violatedCoreValues.length}');

      return summary;
    } catch (e, stackTrace) {
      debugPrint('AiChatService.generateSummary error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
}
