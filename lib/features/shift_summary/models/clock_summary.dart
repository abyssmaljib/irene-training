import 'shift_row_type.dart';

/// Model for clock_in_out_summary view
/// Represents detailed daily clock in/out records
class ClockSummary {
  final String userId;
  final int? nursinghomeId;
  final DateTime? clockInTime;
  final DateTime? clockOutTime;
  final int? clockInId;
  final int? clockOutId;

  // Shift info
  final String? shiftType;
  final List<String> zoneNames;

  // Status flags
  final bool isManualAddDeduct;
  final bool? isAbsent;
  final bool isSick;
  final bool? isSupport;
  final bool? incharge;
  final bool? clockInIsAuto;
  final bool? clockOutIsAuto;

  // Sick leave
  final String? sickEvident;
  final String? sickReason;

  // DD record
  final int? ddRecordId;
  final int? ddPostId;
  final int? specialRecordId;

  // Additional/Deduction
  final int? additional;
  final String? additionalReason;
  final double? deduction;
  final String? deductionReason;
  final double? finalDeduction;
  final String? finalDeductionReason;

  // User info
  final String? userNickname;
  final String? userFullname;
  final String? userPhotoUrl;

  // Payroll period
  final int? year;
  final int? month;
  final DateTime? clockInDate;

  const ClockSummary({
    required this.userId,
    this.nursinghomeId,
    this.clockInTime,
    this.clockOutTime,
    this.clockInId,
    this.clockOutId,
    this.shiftType,
    this.zoneNames = const [],
    required this.isManualAddDeduct,
    this.isAbsent,
    required this.isSick,
    this.isSupport,
    this.incharge,
    this.clockInIsAuto,
    this.clockOutIsAuto,
    this.sickEvident,
    this.sickReason,
    this.ddRecordId,
    this.ddPostId,
    this.specialRecordId,
    this.additional,
    this.additionalReason,
    this.deduction,
    this.deductionReason,
    this.finalDeduction,
    this.finalDeductionReason,
    this.userNickname,
    this.userFullname,
    this.userPhotoUrl,
    this.year,
    this.month,
    this.clockInDate,
  });

  /// Create from Supabase row
  factory ClockSummary.fromJson(Map<String, dynamic> json) {
    // Parse zone_names which could be an array of strings
    List<String> parseZoneNames(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .where((e) => e != null)
            .map((e) => e.toString())
            .toList();
      }
      return [];
    }

    return ClockSummary(
      userId: json['user_id'] as String,
      nursinghomeId: json['nursinghome_id'] as int?,
      clockInTime: json['clock_in_time'] != null
          ? DateTime.parse(json['clock_in_time'] as String).toLocal()
          : null,
      clockOutTime: json['clock_out_time'] != null
          ? DateTime.parse(json['clock_out_time'] as String).toLocal()
          : null,
      clockInId: json['clock_in_id'] as int?,
      clockOutId: json['clock_out_id'] as int?,
      shiftType: json['shift_type'] as String?,
      zoneNames: parseZoneNames(json['zone_names']),
      isManualAddDeduct: json['is_manual_add_deduct'] as bool? ?? false,
      isAbsent: json['isAbsent'] as bool?,
      isSick: json['isSick'] as bool? ?? false,
      isSupport: json['isSupport'] as bool?,
      incharge: json['Incharge'] as bool?,
      clockInIsAuto: json['clock_in_is_auto'] as bool?,
      clockOutIsAuto: json['clock_out_is_auto'] as bool?,
      sickEvident: json['sick_evident'] as String?,
      sickReason: json['sick_reason'] as String?,
      ddRecordId: json['dd_record_id'] as int?,
      ddPostId: json['dd_post_id'] as int?,
      specialRecordId: json['special_record_id'] as int?,
      additional: (json['Additional'] as num?)?.toInt(),
      additionalReason: json['additional_reason'] as String?,
      deduction: (json['Deduction'] as num?)?.toDouble(),
      deductionReason: json['deduction_reason'] as String?,
      finalDeduction: (json['final_deduction'] as num?)?.toDouble(),
      finalDeductionReason: json['final_deduction_reason'] as String?,
      userNickname: json['user_nickname'] as String?,
      userFullname: json['user_fullname'] as String?,
      userPhotoUrl: json['user_photo_url'] as String?,
      year: (json['year'] as num?)?.toInt(),
      month: (json['month'] as num?)?.toInt(),
      clockInDate: json['clock_in_date'] != null
          ? DateTime.parse(json['clock_in_date'] as String).toLocal()
          : null,
    );
  }

  /// Determine the row type based on conditions
  ShiftRowType get rowType {
    if (!isManualAddDeduct) return ShiftRowType.normal;
    if (ddRecordId != null) return ShiftRowType.ddRecord;
    return ShiftRowType.manualAddDeduct;
  }

  /// Check if user can claim sick leave (Absent but not Sick yet)
  bool get canClaimSickLeave => isAbsent == true && !isSick;

  /// Check if this is a DD record that has a post
  bool get hasDDPost => ddRecordId != null && ddPostId != null;

  /// Check if this is a DD record without a post
  bool get needsDDPost => ddRecordId != null && ddPostId == null;

  /// Format clock in time as HH:mm
  String get clockInTimeFormatted {
    if (clockInTime == null) return '-';
    return '${clockInTime!.hour.toString().padLeft(2, '0')}:${clockInTime!.minute.toString().padLeft(2, '0')}';
  }

  /// Format clock out time as HH:mm
  String get clockOutTimeFormatted {
    if (clockOutTime == null) return '-';
    return '${clockOutTime!.hour.toString().padLeft(2, '0')}:${clockOutTime!.minute.toString().padLeft(2, '0')}';
  }

  /// Format clock in date as d/M
  String get dateFormatted {
    if (clockInTime == null) return '-';
    return '${clockInTime!.day}/${clockInTime!.month}';
  }

  /// Get zones as comma-separated string
  String get zonesFormatted {
    if (zoneNames.isEmpty) return '-';
    return zoneNames.join(', ');
  }

  /// Get status text based on conditions
  String get statusText {
    if (isAbsent == true && !isSick) return 'ขาด';
    if (isAbsent == true && isSick) return 'ป่วย';
    if (ddRecordId != null && ddPostId == null) return 'ยังไม่ส่งเวร';
    if (ddRecordId != null && ddPostId != null) return 'ส่งเวรแล้ว';
    return '';
  }
}
