/// Model สำหรับ Resident แบบง่าย (ใช้สำหรับ filter)
class ResidentSimple {
  final int id;
  final String name;
  final int zoneId;

  const ResidentSimple({
    required this.id,
    required this.name,
    required this.zoneId,
  });

  factory ResidentSimple.fromJson(Map<String, dynamic> json) {
    final zoneData = json['nursinghome_zone'] as Map<String, dynamic>?;
    return ResidentSimple(
      id: json['id'] as int,
      name: json['i_Name_Surname'] as String? ?? '-',
      zoneId: zoneData?['id'] as int? ?? 0,
    );
  }
}
