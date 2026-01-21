// Model สำหรับติดตามความคืบหน้าของ 4 Pillars ในการถอดบทเรียน
// 4 Pillars = ความสำคัญ, สาเหตุ, Core Values, การป้องกัน

/// Core Values ที่อาจถูกละเมิด (ใช้เป็น reference)
enum CoreValue {
  speakUp('SPEAK_UP', 'Speak Up', 'กล้าพูด กล้าเสนอ'),
  serviceMind('SERVICE_MIND', 'Service Mind', 'ใจรักบริการ'),
  systemFocus('SYSTEM_FOCUS', 'System Focus', 'มุ่งเน้นระบบ'),
  integrity('INTEGRITY', 'Integrity', 'ซื่อสัตย์'),
  learning('LEARNING', 'Learning', 'เรียนรู้ตลอดเวลา'),
  teamwork('TEAMWORK', 'Teamwork', 'ทำงานเป็นทีม');

  const CoreValue(this.code, this.nameEn, this.nameTh);

  /// รหัสสำหรับเก็บใน DB (uppercase)
  final String code;

  /// ชื่อภาษาอังกฤษ
  final String nameEn;

  /// ชื่อภาษาไทย
  final String nameTh;

  /// แสดงชื่อเต็ม (TH + EN)
  String get displayName => '$nameTh ($nameEn)';

  /// แปลงจาก string เป็น enum
  /// รองรับหลาย format:
  /// - Code: "INTEGRITY", "SPEAK_UP"
  /// - English name: "Integrity", "Speak Up"
  /// - Full name from DB: "Integrity (ซื่อสัตย์ รับผิดชอบ)"
  static CoreValue? fromCode(String input) {
    final upperInput = input.toUpperCase().trim();

    for (final value in CoreValue.values) {
      // ตรวจสอบ code (INTEGRITY, SPEAK_UP, etc.)
      if (value.code == upperInput) return value;

      // ตรวจสอบ English name (Integrity, Speak Up, etc.)
      if (value.nameEn.toUpperCase() == upperInput) return value;

      // ตรวจสอบว่า input เริ่มต้นด้วย English name (สำหรับ format "Integrity (ซื่อสัตย์)")
      // เช่น "INTEGRITY (ซื่อสัตย์ รับผิดชอบ)" starts with "INTEGRITY"
      if (upperInput.startsWith(value.nameEn.toUpperCase())) return value;
    }
    return null;
  }

  /// แปลงจาก list of strings เป็น list of CoreValue
  static List<CoreValue> fromCodes(List<String> codes) {
    return codes
        .map((code) => CoreValue.fromCode(code))
        .where((v) => v != null)
        .cast<CoreValue>()
        .toList();
  }
}

/// Model สำหรับติดตามความคืบหน้าของ 4 Pillars
class ReflectionPillars {
  /// Pillar 1: ความสำคัญ/ผลกระทบของเหตุการณ์
  final bool whyItMattersCompleted;

  /// Pillar 2: สาเหตุที่แท้จริง (Root Cause)
  final bool rootCauseCompleted;

  /// Pillar 3: Core Values ที่ถูกละเมิด
  final bool coreValuesCompleted;

  /// Pillar 4: แนวทางป้องกัน
  final bool preventionPlanCompleted;

  const ReflectionPillars({
    this.whyItMattersCompleted = false,
    this.rootCauseCompleted = false,
    this.coreValuesCompleted = false,
    this.preventionPlanCompleted = false,
  });

  /// สร้างจากค่าเริ่มต้น (ยังไม่ได้เริ่มทำ)
  factory ReflectionPillars.initial() {
    return const ReflectionPillars();
  }

  /// สร้างจาก JSON response ของ AI (Edge Function)
  /// รองรับทั้ง format เก่า (xxx_completed) และใหม่ (xxx)
  factory ReflectionPillars.fromJson(Map<String, dynamic> json) {
    return ReflectionPillars(
      // รองรับทั้ง 'why_it_matters' และ 'why_it_matters_completed'
      whyItMattersCompleted: json['why_it_matters'] as bool? ??
          json['why_it_matters_completed'] as bool? ?? false,
      rootCauseCompleted: json['root_cause'] as bool? ??
          json['root_cause_completed'] as bool? ?? false,
      coreValuesCompleted: json['core_values'] as bool? ??
          json['core_values_completed'] as bool? ?? false,
      preventionPlanCompleted: json['prevention_plan'] as bool? ??
          json['prevention_plan_completed'] as bool? ?? false,
    );
  }

  /// นับจำนวน Pillars ที่เสร็จแล้ว (0-4)
  int get completedCount {
    int count = 0;
    if (whyItMattersCompleted) count++;
    if (rootCauseCompleted) count++;
    if (coreValuesCompleted) count++;
    if (preventionPlanCompleted) count++;
    return count;
  }

  /// คำนวณ progress เป็น percentage (0.0 - 1.0)
  double get progress => completedCount / 4;

  /// ตรวจสอบว่าครบทุก Pillar หรือยัง
  bool get isComplete =>
      whyItMattersCompleted &&
      rootCauseCompleted &&
      coreValuesCompleted &&
      preventionPlanCompleted;

  /// ตรวจสอบว่าเริ่มทำแล้วหรือยัง (มีอย่างน้อย 1 pillar เสร็จ)
  bool get hasStarted => completedCount > 0;

  /// สร้าง copy พร้อมเปลี่ยนค่าบางส่วน
  ReflectionPillars copyWith({
    bool? whyItMattersCompleted,
    bool? rootCauseCompleted,
    bool? coreValuesCompleted,
    bool? preventionPlanCompleted,
  }) {
    return ReflectionPillars(
      whyItMattersCompleted:
          whyItMattersCompleted ?? this.whyItMattersCompleted,
      rootCauseCompleted: rootCauseCompleted ?? this.rootCauseCompleted,
      coreValuesCompleted: coreValuesCompleted ?? this.coreValuesCompleted,
      preventionPlanCompleted:
          preventionPlanCompleted ?? this.preventionPlanCompleted,
    );
  }

  @override
  String toString() =>
      'ReflectionPillars(completed: $completedCount/4, isComplete: $isComplete)';
}

/// Model สำหรับเก็บสรุปผลจาก AI หลังคุยครบ 4 Pillars
class ReflectionSummary {
  /// ความสำคัญ/ผลกระทบของเหตุการณ์
  final String whyItMatters;

  /// สาเหตุที่แท้จริง
  final String rootCause;

  /// การวิเคราะห์ Core Values ที่ถูกละเมิด
  final String coreValueAnalysis;

  /// รายการ Core Values ที่ถูกละเมิด
  final List<CoreValue> violatedCoreValues;

  /// แนวทางป้องกันไม่ให้เกิดซ้ำ
  final String preventionPlan;

  const ReflectionSummary({
    required this.whyItMatters,
    required this.rootCause,
    required this.coreValueAnalysis,
    required this.violatedCoreValues,
    required this.preventionPlan,
  });

  /// สร้างจาก JSON response ของ AI
  factory ReflectionSummary.fromJson(Map<String, dynamic> json) {
    // Parse violated_core_values จาก list of strings
    final violatedCodes = (json['violated_core_values'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return ReflectionSummary(
      whyItMatters: json['why_it_matters'] as String? ?? '',
      rootCause: json['root_cause'] as String? ?? '',
      coreValueAnalysis: json['core_value_analysis'] as String? ?? '',
      violatedCoreValues: CoreValue.fromCodes(violatedCodes),
      preventionPlan: json['prevention_plan'] as String? ?? '',
    );
  }

  /// แปลงเป็น JSON สำหรับบันทึกลง DB
  Map<String, dynamic> toJson() {
    return {
      'why_it_matters': whyItMatters,
      'root_cause': rootCause,
      'core_value_analysis': coreValueAnalysis,
      'violated_core_values':
          violatedCoreValues.map((v) => v.code).toList(),
      'prevention_plan': preventionPlan,
    };
  }

  /// ตรวจสอบว่าสรุปครบทุกส่วนหรือไม่
  bool get isComplete =>
      whyItMatters.isNotEmpty &&
      rootCause.isNotEmpty &&
      coreValueAnalysis.isNotEmpty &&
      violatedCoreValues.isNotEmpty &&
      preventionPlan.isNotEmpty;

  @override
  String toString() =>
      'ReflectionSummary(isComplete: $isComplete, violations: ${violatedCoreValues.length})';
}
