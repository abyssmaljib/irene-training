/// Model สำหรับตัวเลือกเวลาพัก จาก clock_break_time_nursinghome table
class BreakTimeOption {
  final int id;
  final String breakTime; // e.g., "12:00 - 12:20"
  final String? breakName; // e.g., "ช่วงเที่ยง 1"
  final String shift; // 'เวรเช้า' | 'เวรดึก'
  final int quota;
  final int index;
  final int nursinghomeId;

  const BreakTimeOption({
    required this.id,
    required this.breakTime,
    this.breakName,
    required this.shift,
    this.quota = 0,
    this.index = 0,
    required this.nursinghomeId,
  });

  /// Parse จาก Supabase response
  factory BreakTimeOption.fromJson(Map<String, dynamic> json) {
    // Debug: print keys to see actual column names
    // print('BreakTimeOption keys: ${json.keys.toList()}');
    // print('BreakTimeOption json: $json');

    return BreakTimeOption(
      id: json['id'] as int? ?? 0,
      // Database column is "breakTime" (camelCase) - try multiple variants
      breakTime: _parseString(json, ['breakTime', 'break_time', 'BreakTime']) ?? '',
      breakName: _parseString(json, ['break_name', 'breakName', 'BreakName']),
      shift: json['shift'] as String? ?? 'เวรเช้า',
      quota: json['quota'] as int? ?? 0,
      index: json['index'] as int? ?? 0,
      nursinghomeId: json['nursinghome_id'] as int? ?? 0,
    );
  }

  /// Helper to parse string from multiple possible keys
  static String? _parseString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  /// แสดงชื่อช่วงเวลาพัก
  String get displayName => breakName ?? breakTime;

  /// ตรวจสอบว่าเป็นช่วงเช้าหรือไม่
  bool get isMorningBreak => shift == 'เวรเช้า';

  /// ตรวจสอบว่าเป็นช่วงดึกหรือไม่
  bool get isNightBreak => shift == 'เวรดึก';

  @override
  String toString() {
    return 'BreakTimeOption(id: $id, time: $breakTime, shift: $shift)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BreakTimeOption && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
