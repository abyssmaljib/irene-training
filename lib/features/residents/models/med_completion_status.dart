/// Model สำหรับข้อมูลสถานะการจัดยาของผู้พัก
/// ดึงจาก view: resident_med_completion_status
class MedCompletionStatus {
  final int residentId;
  final String residentName;
  final int nursinghomeId;
  final int? sZone;
  final String? sStatus;
  final DateTime checkDate;
  final List<String> requiredMeals;
  final int totalRequiredMeals;
  final List<String> completedMeals;
  final int totalCompletedMeals;
  final String completionStatus; // 'completed', 'partial', 'not_started', 'no_medication'
  final String completionFraction; // e.g. "2/4"
  final int completionPercentage;
  final List<String> pendingMeals;
  final Map<String, dynamic>? mealDetails;
  final DateTime? lastArrangedAt;
  final DateTime? last2cCheckedAt;

  const MedCompletionStatus({
    required this.residentId,
    required this.residentName,
    required this.nursinghomeId,
    this.sZone,
    this.sStatus,
    required this.checkDate,
    required this.requiredMeals,
    required this.totalRequiredMeals,
    required this.completedMeals,
    required this.totalCompletedMeals,
    required this.completionStatus,
    required this.completionFraction,
    required this.completionPercentage,
    required this.pendingMeals,
    this.mealDetails,
    this.lastArrangedAt,
    this.last2cCheckedAt,
  });

  factory MedCompletionStatus.fromJson(Map<String, dynamic> json) {
    return MedCompletionStatus(
      residentId: json['resident_id'] as int,
      residentName: json['resident_name'] as String? ?? '-',
      nursinghomeId: json['nursinghome_id'] as int? ?? 0,
      sZone: json['s_zone'] as int?,
      sStatus: json['s_status'] as String?,
      checkDate: DateTime.parse(json['check_date'] as String),
      requiredMeals: _parseStringList(json['required_meals']),
      totalRequiredMeals: json['total_required_meals'] as int? ?? 0,
      completedMeals: _parseStringList(json['completed_meals']),
      totalCompletedMeals: json['total_completed_meals'] as int? ?? 0,
      completionStatus: json['completion_status'] as String? ?? 'no_medication',
      completionFraction: json['completion_fraction'] as String? ?? '0/0',
      completionPercentage: json['completion_percentage'] as int? ?? 0,
      pendingMeals: _parseStringList(json['pending_meals']),
      mealDetails: json['meal_details'] as Map<String, dynamic>?,
      lastArrangedAt: json['last_arranged_at'] != null
          ? DateTime.tryParse(json['last_arranged_at'] as String)
          : null,
      last2cCheckedAt: json['last_2c_checked_at'] != null
          ? DateTime.tryParse(json['last_2c_checked_at'] as String)
          : null,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// ตรวจสอบว่าจัดยาเรียบร้อยหรือยัง
  bool get isCompleted => completionStatus == 'completed';

  /// ตรวจสอบว่าจัดยาบางส่วน
  bool get isPartial => completionStatus == 'partial';

  /// ตรวจสอบว่ายังไม่ได้เริ่มจัดยา
  bool get isNotStarted => completionStatus == 'not_started';

  /// ตรวจสอบว่าไม่มียาต้องจัด
  bool get hasNoMedication => completionStatus == 'no_medication';

  /// ตรวจสอบว่ามียาต้องจัดหรือไม่
  bool get hasMedication => completionStatus != 'no_medication';
}
