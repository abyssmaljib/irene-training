/// ข้อมูลเพื่อนที่เลือกเวลาพัก
class FriendBreakTime {
  final String name;
  final int? zoneId;
  final String? zoneName;

  const FriendBreakTime({
    required this.name,
    this.zoneId,
    this.zoneName,
  });

  /// แสดงชื่อ
  String get displayName => name;

  /// แสดงชื่อพร้อมโซน (ถ้ามี)
  String get displayNameWithZone {
    if (zoneName != null && zoneName!.isNotEmpty) {
      return '$name ($zoneName)';
    }
    return name;
  }
}
