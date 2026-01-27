// Model สำหรับ Incident จาก v_incidents_with_details view
// ใช้สำหรับหน้าถอดบทเรียน (5 Whys)

import 'chat_message.dart';
import 'reflection_pillars.dart';

/// สถานะการถอดบทเรียน
enum ReflectionStatus {
  /// รอดำเนินการ (ยังไม่เริ่มถอดบทเรียน)
  pending('pending', 'รอดำเนินการ'),

  /// กำลังดำเนินการ (เริ่มคุยกับ AI แล้วแต่ยังไม่เสร็จ)
  inProgress('in_progress', 'กำลังดำเนินการ'),

  /// เสร็จสิ้น (ถอดบทเรียนครบ 4 Pillars แล้ว)
  completed('completed', 'เสร็จแล้ว');

  const ReflectionStatus(this.value, this.displayText);

  /// ค่าที่เก็บใน DB
  final String value;

  /// ข้อความสำหรับแสดงผล
  final String displayText;

  /// แปลงจาก string เป็น enum
  static ReflectionStatus fromString(String? value) {
    switch (value) {
      case 'in_progress':
        return ReflectionStatus.inProgress;
      case 'completed':
        return ReflectionStatus.completed;
      default:
        return ReflectionStatus.pending;
    }
  }
}

/// ระดับความรุนแรง
enum IncidentSeverity {
  low('low', 'เล็กน้อย'),
  medium('medium', 'ปานกลาง'),
  high('high', 'สูง'),
  critical('critical', 'วิกฤต');

  const IncidentSeverity(this.value, this.displayText);

  final String value;
  final String displayText;

  static IncidentSeverity fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'medium':
        return IncidentSeverity.medium;
      case 'high':
        return IncidentSeverity.high;
      case 'critical':
        return IncidentSeverity.critical;
      default:
        return IncidentSeverity.low;
    }
  }
}

/// Model สำหรับ Incident จาก v_incidents_with_details view
class Incident {
  final int id;
  final DateTime createdAt;
  final String? title;
  final String? description;
  final int? nursinghomeId;

  /// รายการ staff_id ที่เกี่ยวข้อง (uuid array)
  final List<String> staffIds;
  final String? reportedBy;
  final DateTime? incidentDate;

  /// กะ: 'DAY' หรือ 'NIGHT'
  final String? shift;

  /// ระดับความรุนแรง
  final IncidentSeverity severity;

  /// หมวดหมู่
  final String? category;

  /// สถานะ incident (PENDING, IN_PROGRESS, RESOLVED)
  final String? status;

  /// ข้อมูลผู้อยู่อาศัยที่เกี่ยวข้อง
  final int? residentId;
  final String? residentName;
  final String? residentPictureUrl;

  /// ข้อมูล zone
  final String? zoneName;

  /// รูปภาพประกอบ
  final String? imageUrl;

  // ===== Reflection fields (4 Pillars) =====

  /// Pillar 1: ความสำคัญ/ผลกระทบ
  final String? whyItMatters;

  /// Pillar 2: สาเหตุที่แท้จริง
  final String? rootCause;

  /// Pillar 3: การวิเคราะห์ Core Values
  final String? coreValueAnalysis;

  /// Pillar 3: รายการ Core Values ที่ถูกละเมิด
  /// เก็บเป็น String ตามที่อยู่ใน DB (เช่น "ใช้ระบบแทนความจำ เพื่อใช้ศักยภาพทำเรื่องสำคัญ")
  final List<String> violatedCoreValues;

  /// Pillar 4: แนวทางป้องกัน
  final String? preventionPlan;

  /// ประวัติการสนทนากับ AI
  final List<ChatMessage> chatHistory;

  /// สถานะการถอดบทเรียน
  final ReflectionStatus reflectionStatus;

  /// เวลาที่เริ่มถอดบทเรียน
  final DateTime? reflectionStartedAt;

  /// เวลาที่ถอดบทเรียนเสร็จ
  final DateTime? reflectionCompletedAt;

  // ===== Resolution fields =====

  /// เวลาที่ resolve
  final DateTime? resolvedAt;

  /// ผู้ที่ resolve
  final String? resolvedBy;

  /// หมายเหตุการ resolve
  final String? resolutionNotes;

  // ===== Joined fields from view =====

  /// ชื่อผู้รายงาน
  final String? reportedByName;

  /// รูปผู้รายงาน
  final String? reportedByPhoto;

  final DateTime? updatedAt;

  const Incident({
    required this.id,
    required this.createdAt,
    this.title,
    this.description,
    this.nursinghomeId,
    this.staffIds = const [],
    this.reportedBy,
    this.incidentDate,
    this.shift,
    this.severity = IncidentSeverity.low,
    this.category,
    this.status,
    this.residentId,
    this.residentName,
    this.residentPictureUrl,
    this.zoneName,
    this.imageUrl,
    this.whyItMatters,
    this.rootCause,
    this.coreValueAnalysis,
    this.violatedCoreValues = const [],
    this.preventionPlan,
    this.chatHistory = const [],
    this.reflectionStatus = ReflectionStatus.pending,
    this.reflectionStartedAt,
    this.reflectionCompletedAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNotes,
    this.reportedByName,
    this.reportedByPhoto,
    this.updatedAt,
  });

  /// Parse จาก JSON (v_incidents_with_details view)
  factory Incident.fromJson(Map<String, dynamic> json) {
    // Parse staff_id array
    List<String> staffIds = [];
    if (json['staff_id'] != null) {
      if (json['staff_id'] is List) {
        staffIds = (json['staff_id'] as List)
            .map((e) => e.toString())
            .toList();
      }
    }

    // Parse chat_history จาก jsonb
    List<ChatMessage> chatHistory = [];
    if (json['chat_history'] != null) {
      if (json['chat_history'] is List) {
        chatHistory = (json['chat_history'] as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    // Parse violated_core_values จาก text array (เก็บเป็น string ตรงๆ)
    List<String> violatedCoreValues = [];
    if (json['violated_core_values'] != null) {
      if (json['violated_core_values'] is List) {
        violatedCoreValues = (json['violated_core_values'] as List)
            .map((e) => e.toString())
            .toList();
      }
    }

    return Incident(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      title: json['title'] as String?,
      description: json['description'] as String?,
      nursinghomeId: json['nursinghome_id'] as int?,
      staffIds: staffIds,
      reportedBy: json['reported_by'] as String?,
      incidentDate: _parseDateTime(json['incident_date']),
      shift: json['shift'] as String?,
      severity: IncidentSeverity.fromString(json['severity'] as String?),
      category: json['category'] as String?,
      status: json['status'] as String?,
      residentId: json['resident_id'] as int?,
      residentName: json['resident_name'] as String?,
      residentPictureUrl: json['resident_picture_url'] as String?,
      zoneName: json['zone_name'] as String?,
      imageUrl: json['image_url'] as String?,
      // Reflection fields
      whyItMatters: json['why_it_matters'] as String?,
      rootCause: json['root_cause'] as String?,
      coreValueAnalysis: json['core_value_analysis'] as String?,
      violatedCoreValues: violatedCoreValues,
      preventionPlan: json['prevention_plan'] as String?,
      chatHistory: chatHistory,
      reflectionStatus:
          ReflectionStatus.fromString(json['reflection_status'] as String?),
      reflectionStartedAt: _parseDateTime(json['reflection_started_at']),
      reflectionCompletedAt: _parseDateTime(json['reflection_completed_at']),
      // Resolution fields
      resolvedAt: _parseDateTime(json['resolved_at']),
      resolvedBy: json['resolved_by'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
      // Joined fields
      reportedByName: json['reported_by_name'] as String?,
      reportedByPhoto: json['reported_by_photo'] as String?,
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  /// Helper: parse DateTime จากหลายรูปแบบ
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ===== Computed properties =====

  /// ตรวจสอบว่า user นี้เป็นเจ้าของ incident หรือไม่
  bool isStaffOwner(String? userId) {
    if (userId == null) return false;
    return staffIds.contains(userId);
  }

  /// คำนวณ progress ของ 4 Pillars จากข้อมูลที่มี
  ReflectionPillars get pillarsProgress {
    return ReflectionPillars(
      whyItMattersCompleted: whyItMatters?.isNotEmpty ?? false,
      rootCauseCompleted: rootCause?.isNotEmpty ?? false,
      // Core Values completed ถ้ามี analysis หรือมี violated list
      // (กรณี AI ตอบว่า "ไม่มี Core Values ที่ถูกละเมิด" จะมี analysis แต่ list ว่าง)
      coreValuesCompleted: (coreValueAnalysis?.isNotEmpty ?? false) ||
          violatedCoreValues.isNotEmpty,
      preventionPlanCompleted: preventionPlan?.isNotEmpty ?? false,
    );
  }

  /// ตรวจสอบว่าถอดบทเรียนครบแล้วหรือยัง
  bool get isReflectionComplete => pillarsProgress.isComplete;

  /// ตรวจสอบว่ารอการถอดบทเรียนอยู่
  bool get isPendingReflection => reflectionStatus == ReflectionStatus.pending;

  /// ตรวจสอบว่ากำลังถอดบทเรียนอยู่
  bool get isReflectionInProgress =>
      reflectionStatus == ReflectionStatus.inProgress;

  /// ตรวจสอบว่าถอดบทเรียนเสร็จแล้ว
  bool get isReflectionCompleted =>
      reflectionStatus == ReflectionStatus.completed;

  /// มี chat history หรือไม่
  bool get hasChatHistory => chatHistory.isNotEmpty;

  /// จำนวนข้อความใน chat
  int get chatMessageCount => chatHistory.length;

  /// ข้อความ shift สำหรับแสดงผล
  /// รองรับทั้ง 'DAY'/'MORNING' (เวรเช้า) และ 'NIGHT' (เวรดึก)
  String get shiftDisplayText {
    switch (shift?.toUpperCase()) {
      case 'DAY':
      case 'MORNING':
        return 'เวรเช้า';
      case 'NIGHT':
        return 'เวรดึก';
      default:
        return shift ?? '-';
    }
  }

  /// รายการ Core Values ที่ละเมิดเป็น text
  String get violatedCoreValuesText {
    if (violatedCoreValues.isEmpty) return '-';
    return violatedCoreValues.join(', ');
  }

  /// สร้าง copy พร้อมเปลี่ยนค่าบางส่วน
  Incident copyWith({
    int? id,
    DateTime? createdAt,
    String? title,
    String? description,
    int? nursinghomeId,
    List<String>? staffIds,
    String? reportedBy,
    DateTime? incidentDate,
    String? shift,
    IncidentSeverity? severity,
    String? category,
    String? status,
    int? residentId,
    String? residentName,
    String? residentPictureUrl,
    String? zoneName,
    String? imageUrl,
    String? whyItMatters,
    String? rootCause,
    String? coreValueAnalysis,
    List<String>? violatedCoreValues,
    String? preventionPlan,
    List<ChatMessage>? chatHistory,
    ReflectionStatus? reflectionStatus,
    DateTime? reflectionStartedAt,
    DateTime? reflectionCompletedAt,
    DateTime? resolvedAt,
    String? resolvedBy,
    String? resolutionNotes,
    String? reportedByName,
    String? reportedByPhoto,
    DateTime? updatedAt,
  }) {
    return Incident(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      description: description ?? this.description,
      nursinghomeId: nursinghomeId ?? this.nursinghomeId,
      staffIds: staffIds ?? this.staffIds,
      reportedBy: reportedBy ?? this.reportedBy,
      incidentDate: incidentDate ?? this.incidentDate,
      shift: shift ?? this.shift,
      severity: severity ?? this.severity,
      category: category ?? this.category,
      status: status ?? this.status,
      residentId: residentId ?? this.residentId,
      residentName: residentName ?? this.residentName,
      residentPictureUrl: residentPictureUrl ?? this.residentPictureUrl,
      zoneName: zoneName ?? this.zoneName,
      imageUrl: imageUrl ?? this.imageUrl,
      whyItMatters: whyItMatters ?? this.whyItMatters,
      rootCause: rootCause ?? this.rootCause,
      coreValueAnalysis: coreValueAnalysis ?? this.coreValueAnalysis,
      violatedCoreValues: violatedCoreValues ?? this.violatedCoreValues,
      preventionPlan: preventionPlan ?? this.preventionPlan,
      chatHistory: chatHistory ?? this.chatHistory,
      reflectionStatus: reflectionStatus ?? this.reflectionStatus,
      reflectionStartedAt: reflectionStartedAt ?? this.reflectionStartedAt,
      reflectionCompletedAt:
          reflectionCompletedAt ?? this.reflectionCompletedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      reportedByName: reportedByName ?? this.reportedByName,
      reportedByPhoto: reportedByPhoto ?? this.reportedByPhoto,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Incident(id: $id, title: $title, reflectionStatus: ${reflectionStatus.value})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Incident && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
