/// Model แบบย่อสำหรับแสดงรายชื่อคนไข้ในหน้า Clock-in
class ResidentSimple {
  final int id;
  final String name;
  final int? zoneId;
  final String? zoneName;
  final String? gender;
  final int? age;
  final String? photoUrl;

  const ResidentSimple({
    required this.id,
    required this.name,
    this.zoneId,
    this.zoneName,
    this.gender,
    this.age,
    this.photoUrl,
  });

  /// Parse จาก Supabase response (combined_resident_details_view)
  factory ResidentSimple.fromJson(Map<String, dynamic> json) {
    return ResidentSimple(
      id: json['resident_id'] as int? ?? json['id'] as int? ?? 0,
      name: json['i_Name_Surname'] as String? ??
            json['name'] as String? ??
            'ไม่ระบุชื่อ',
      zoneId: json['zone_id'] as int?,
      zoneName: json['s_zone'] as String? ?? json['zone_name'] as String?,
      gender: json['s_sex'] as String? ?? json['gender'] as String?,
      age: _calculateAge(json['i_Birthday']),
      photoUrl: json['profile_url'] as String? ?? json['photo_url'] as String?,
    );
  }

  /// คำนวณอายุจากวันเกิด
  static int? _calculateAge(dynamic birthday) {
    if (birthday == null) return null;
    DateTime? birthDate;
    if (birthday is DateTime) {
      birthDate = birthday;
    } else if (birthday is String) {
      birthDate = DateTime.tryParse(birthday);
    }
    if (birthDate == null) return null;

    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// แสดงข้อมูลเพศและอายุ
  String get genderAndAge {
    final parts = <String>[];
    if (gender != null && gender!.isNotEmpty) {
      parts.add(gender!);
    }
    if (age != null) {
      parts.add('$age ปี');
    }
    return parts.join(', ');
  }

  @override
  String toString() {
    return 'ResidentSimple(id: $id, name: $name, zone: $zoneName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResidentSimple && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
