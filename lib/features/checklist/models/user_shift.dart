/// Model สำหรับข้อมูล shift ของ user จาก clock_in_out_summary
class UserShift {
  final String? shiftType; // เช้า, ดึก
  final List<int> zones; // zone IDs ที่ user เลือกตอนขึ้นเวร
  final List<int> selectedResidentIds; // resident IDs ที่ user เลือก
  final DateTime? clockInTime;
  final DateTime? clockOutTime;

  const UserShift({
    this.shiftType,
    this.zones = const [],
    this.selectedResidentIds = const [],
    this.clockInTime,
    this.clockOutTime,
  });

  /// Parse จาก Supabase response
  factory UserShift.fromJson(Map<String, dynamic> json) {
    return UserShift(
      shiftType: json['shift_type'] as String?,
      zones: _parseIntList(json['zones']),
      selectedResidentIds: _parseIntList(json['selected_resident_id_list']),
      clockInTime: _parseDateTime(json['clock_in_time']),
      clockOutTime: _parseDateTime(json['clock_out_time']),
    );
  }

  static List<int> _parseIntList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.whereType<int>().toList();
    }
    return [];
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// ตรวจสอบว่ามี zone filter หรือไม่
  bool get hasZoneFilter => zones.isNotEmpty;

  /// ตรวจสอบว่ามี resident filter หรือไม่
  bool get hasResidentFilter => selectedResidentIds.isNotEmpty;

  /// ตรวจสอบว่ามี filter ใดๆ หรือไม่
  bool get hasAnyFilter => hasZoneFilter || hasResidentFilter;

  @override
  String toString() {
    return 'UserShift(shiftType: $shiftType, zones: $zones, residents: $selectedResidentIds)';
  }
}
