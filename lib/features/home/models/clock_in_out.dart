/// Model สำหรับข้อมูล Clock In/Out จาก clock_in_out_ver2 table
class ClockInOut {
  final int? id;
  final String userId;
  final int nursinghomeId;
  final bool isAuto;
  final bool incharge;
  final List<int> zones;
  final DateTime? clockInTimestamp;
  final DateTime? clockOutTimestamp;
  final String shift; // 'เวรเช้า' | 'เวรดึก'
  final List<int> selectedResidentIdList;
  final List<int> selectedBreakTime;
  final DateTime? createdAt;

  const ClockInOut({
    this.id,
    required this.userId,
    required this.nursinghomeId,
    this.isAuto = false,
    this.incharge = false,
    this.zones = const [],
    this.clockInTimestamp,
    this.clockOutTimestamp,
    required this.shift,
    this.selectedResidentIdList = const [],
    this.selectedBreakTime = const [],
    this.createdAt,
  });

  /// Parse จาก Supabase response
  factory ClockInOut.fromJson(Map<String, dynamic> json) {
    return ClockInOut(
      id: json['id'] as int?,
      userId: json['user_id'] as String? ?? '',
      nursinghomeId: json['nursinghome_id'] as int? ?? 0,
      isAuto: json['isAuto'] as bool? ?? false,
      incharge: json['Incharge'] as bool? ?? false,
      zones: _parseIntList(json['zones']),
      clockInTimestamp: _parseDateTime(json['clock_in_timestamp']),
      clockOutTimestamp: _parseDateTime(json['clock_out_timestamp']),
      shift: json['shift'] as String? ?? 'เวรเช้า',
      selectedResidentIdList: _parseIntList(json['selected_resident_id_list']),
      selectedBreakTime: _parseIntList(json['selected_break_time']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  /// Convert เป็น JSON สำหรับ insert
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'nursinghome_id': nursinghomeId,
      'isAuto': isAuto,
      'Incharge': incharge,
      'zones': zones,
      if (clockInTimestamp != null)
        'clock_in_timestamp': clockInTimestamp!.toIso8601String(),
      if (clockOutTimestamp != null)
        'clock_out_timestamp': clockOutTimestamp!.toIso8601String(),
      'shift': shift,
      'selected_resident_id_list': selectedResidentIdList,
      'selected_break_time': selectedBreakTime,
    };
  }

  /// ตรวจสอบว่ากำลังอยู่ในเวรหรือไม่
  bool get isClockedIn =>
      clockInTimestamp != null && clockOutTimestamp == null;

  /// ตรวจสอบว่าลงเวรแล้วหรือไม่
  bool get isClockedOut => clockOutTimestamp != null;

  /// จำนวน zone ที่เลือก
  int get zoneCount => zones.length;

  /// จำนวนคนไข้ที่เลือก
  int get residentCount => selectedResidentIdList.length;

  static List<int> _parseIntList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) {
        if (e is int) return e;
        if (e is String) return int.tryParse(e) ?? 0;
        return 0;
      }).where((e) => e != 0).toList();
    }
    return [];
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  String toString() {
    return 'ClockInOut(id: $id, shift: $shift, zones: $zones, residents: ${selectedResidentIdList.length})';
  }
}
