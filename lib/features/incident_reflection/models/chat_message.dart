// Model สำหรับข้อความ Chat กับ AI Coach
// ใช้เก็บประวัติการสนทนาระหว่าง user กับ AI ในการถอดบทเรียน (5 Whys)

import 'dart:convert';

/// ทำความสะอาด content - ตัด JSON metadata ที่ Gemini อาจใส่มา
/// รองรับ 3 กรณี:
/// 1. Raw JSON ทั้งก้อน (valid): {"ai_message": "ข้อความ...", "pillars_progress": ...}
/// 2. Raw JSON ไม่สมบูรณ์: {"ai_message": "ข้อความ...", "pillars_progress": ... (ขาดปีกกา)
/// 3. ข้อความ + JSON metadata: "ข้อความ...", "pillars_progress": {...}
String _cleanMessageContent(String content) {
  if (content.isEmpty) return content;

  var cleaned = content.trim();

  // กรณี 1: เป็น JSON object ทั้งก้อน - ลอง parse ด้วย jsonDecode
  if (cleaned.startsWith('{') && cleaned.contains('"ai_message"')) {
    try {
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      if (json.containsKey('ai_message')) {
        // ดึง ai_message ออกมา แล้ว clean อีกรอบ (กรณี nested)
        cleaned = json['ai_message'] as String? ?? cleaned;
      }
    } catch (_) {
      // กรณี 2: JSON ไม่สมบูรณ์ - ใช้ regex extract ai_message แทน
      // Pattern: {"ai_message": "ข้อความ..." หรือ {"ai_message":"ข้อความ..."
      final aiMessageRegex = RegExp(r'\{\s*"ai_message"\s*:\s*"([^"]*(?:\\.[^"]*)*)"');
      final match = aiMessageRegex.firstMatch(cleaned);
      if (match != null && match.group(1) != null) {
        // Unescape JSON string (แปลง \" เป็น " และ \\ เป็น \)
        cleaned = match.group(1)!
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', r'\');
      }
    }
  }

  // กรณี 3: มี JSON metadata ต่อท้าย (หลังจาก clean แล้วยังอาจมีหลุดมา)
  // Pattern ที่บ่งบอกว่ามี JSON metadata
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
    final match = pattern.firstMatch(cleaned);
    if (match != null) {
      cleaned = cleaned.substring(0, match.start);
      break;
    }
  }

  // ลบ trailing quotes, braces และ whitespace
  cleaned = cleaned.replaceAll(RegExp(r'["{}\s]+$'), '').trim();

  // ลบ leading quotes และ whitespace
  cleaned = cleaned.replaceAll(RegExp(r'^["{}\s]+'), '').trim();

  // Final cleanup: ถ้ายังขึ้นต้นด้วย ai_message อยู่ ให้ลบออก
  if (cleaned.startsWith('ai_message')) {
    cleaned = cleaned.replaceFirst(RegExp(r'^ai_message\s*:\s*'), '').trim();
    // ลบ quotes ที่อาจเหลืออยู่
    cleaned = cleaned.replaceAll(RegExp(r'^["\s]+'), '').trim();
  }

  return cleaned;
}

/// Enum สำหรับระบุว่าข้อความนี้มาจากใคร
enum ChatRole {
  /// ข้อความจาก user (พนักงาน)
  user,

  /// ข้อความจาก AI Coach
  assistant,
}

/// Model เก็บข้อความแต่ละข้อความในการสนทนา
class ChatMessage {
  /// ID ของข้อความ (unique)
  final String id;

  /// ผู้ส่งข้อความ (user หรือ assistant)
  final ChatRole role;

  /// เนื้อหาข้อความ
  final String content;

  /// เวลาที่ส่งข้อความ
  final DateTime timestamp;

  /// สถานะกำลังโหลด (ใช้แสดง typing indicator สำหรับ AI)
  final bool isLoading;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isLoading = false,
  });

  /// สร้างข้อความจาก user
  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.user,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  /// สร้างข้อความจาก AI
  factory ChatMessage.assistant(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.assistant,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  /// สร้างข้อความ placeholder สำหรับแสดง typing indicator
  /// ใช้ตอนรอ AI ตอบกลับ
  factory ChatMessage.loading() {
    return ChatMessage(
      id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isLoading: true,
    );
  }

  /// Parse จาก JSON (ใช้ตอนโหลดจาก chat_history ใน DB)
  /// ทำความสะอาด content กรณีเป็น AI message ที่อาจมี JSON metadata ปนมา
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final role = json['role'] == 'user' ? ChatRole.user : ChatRole.assistant;
    var content = json['content'] as String? ?? '';

    // ทำความสะอาด content เฉพาะข้อความจาก AI (อาจมี JSON ปนมา)
    if (role == ChatRole.assistant && content.isNotEmpty) {
      content = _cleanMessageContent(content);
    }

    return ChatMessage(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      role: role,
      content: content,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      isLoading: false,
    );
  }

  /// แปลงเป็น JSON สำหรับบันทึกลง DB
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role == ChatRole.user ? 'user' : 'assistant',
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Helper: ตรวจสอบว่าเป็นข้อความจาก user หรือไม่
  bool get isUser => role == ChatRole.user;

  /// Helper: ตรวจสอบว่าเป็นข้อความจาก AI หรือไม่
  bool get isAssistant => role == ChatRole.assistant;

  /// สร้าง copy พร้อมเปลี่ยนค่าบางส่วน
  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? timestamp,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  String toString() => 'ChatMessage(role: $role, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
