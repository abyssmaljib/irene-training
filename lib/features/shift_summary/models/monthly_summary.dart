/// Model for clock_in_out_monthly_summary view
/// Represents a monthly summary of shifts for a user
class MonthlySummary {
  final String userId;
  final int? nursinghomeId;
  final int year;
  final int month;
  final String? userNickname;
  final String? userFullname;
  final String? userPhotoUrl;
  final String? nursinghomeName;

  // Shift counts
  final int totalShifts;
  final int totalDayShifts;
  final int totalNightShifts;

  // Special counts (26-25 payroll period)
  final int absentCount;
  final int sickCount;
  final int inchargeCount;
  final int supportCount;

  // Additional/Deduction totals
  final int? totalAdditional;
  final double? totalDeduction;

  // DD record counts
  final int ddCount;

  // Previous month carry-over (ยกมาจากเดือนก่อน)
  final int? pdd; // Previous DD
  final int? pot; // Previous OT

  // Workday info
  final int? workdayTotal;
  final int? requiredWorkdays26To25; // WD - จำนวนวันทำงานที่ต้องทำในรอบเงินเดือน

  const MonthlySummary({
    required this.userId,
    this.nursinghomeId,
    required this.year,
    required this.month,
    this.userNickname,
    this.userFullname,
    this.userPhotoUrl,
    this.nursinghomeName,
    required this.totalShifts,
    required this.totalDayShifts,
    required this.totalNightShifts,
    required this.absentCount,
    required this.sickCount,
    required this.inchargeCount,
    required this.supportCount,
    this.totalAdditional,
    this.totalDeduction,
    required this.ddCount,
    this.pdd,
    this.pot,
    this.workdayTotal,
    this.requiredWorkdays26To25,
  });

  /// Create from Supabase row
  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    return MonthlySummary(
      userId: json['user_id'] as String,
      nursinghomeId: json['nursinghome_id'] as int?,
      year: (json['year'] as num).toInt(),
      month: (json['month'] as num).toInt(),
      userNickname: json['user_nickname'] as String?,
      userFullname: json['user_fullname'] as String?,
      userPhotoUrl: json['user_photo_url'] as String?,
      nursinghomeName: json['nursinghome_name'] as String?,
      totalShifts: (json['total_shifts'] as num?)?.toInt() ?? 0,
      totalDayShifts: (json['total_day_shifts'] as num?)?.toInt() ?? 0,
      totalNightShifts: (json['total_night_shifts'] as num?)?.toInt() ?? 0,
      absentCount: (json['absent_count_26_to_25'] as num?)?.toInt() ?? 0,
      sickCount: (json['sick_count_26_to_25'] as num?)?.toInt() ?? 0,
      inchargeCount: (json['incharge_count_26_to_25'] as num?)?.toInt() ?? 0,
      supportCount: (json['support_count_26_to_25'] as num?)?.toInt() ?? 0,
      totalAdditional: (json['total_additional'] as num?)?.toInt(),
      totalDeduction: (json['total_deduction'] as num?)?.toDouble(),
      ddCount: (json['dd_count_26_to_25'] as num?)?.toInt() ?? 0,
      pdd: (json['pdd'] as num?)?.toInt(),
      pot: (json['pot'] as num?)?.toInt(),
      workdayTotal: (json['workday_total'] as num?)?.toInt(),
      requiredWorkdays26To25: (json['required_workdays_26_to_25'] as num?)?.toInt(),
    );
  }

  /// Display format for month/year (Thai Buddhist Era)
  String get monthYearDisplay {
    final thaiMonths = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    final buddhistYear = year + 543;
    return '${thaiMonths[month]} ${buddhistYear.toString().substring(2)}';
  }

  /// Short format: M/YY
  String get monthYearShort => '$month/${year.toString().substring(2)}';

  /// Check if there are any issues that need attention
  bool get hasIssues => absentCount > 0;

  /// Calculate net additional/deduction
  double get netAdditional =>
      (totalAdditional?.toDouble() ?? 0) - (totalDeduction ?? 0);
}
