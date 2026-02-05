class UserProfile {
  final String id;
  final String? photoUrl;
  final String? nickname;
  final String? fullName;
  final String? prefix;
  final int? nursinghomeId;
  final String? employmentType; // full_time, part_time, trainee, resigned

  const UserProfile({
    required this.id,
    this.photoUrl,
    this.nickname,
    this.fullName,
    this.prefix,
    this.nursinghomeId,
    this.employmentType,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      photoUrl: json['photo_url'] as String?,
      nickname: json['nickname'] as String?,
      fullName: json['full_name'] as String?,
      prefix: json['prefix'] as String?,
      nursinghomeId: json['nursinghome_id'] as int?,
      employmentType: json['employment_type'] as String?,
    );
  }

  /// แปลง employment_type เป็นข้อความภาษาไทย
  String? get employmentTypeDisplay {
    switch (employmentType) {
      case 'full_time':
        return 'ประจำ';
      case 'part_time':
        return 'พาร์ทไทม์';
      case 'trainee':
        return 'ฝึกงาน';
      case 'resigned':
        return 'ลาออกแล้ว';
      default:
        return null;
    }
  }

  /// ตรวจสอบว่าลาออกแล้วหรือไม่
  bool get isResigned => employmentType == 'resigned';

  String get displayName {
    if (nickname != null && nickname!.isNotEmpty) {
      return nickname!;
    }
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName!;
    }
    return '-';
  }

  String get fullNameWithPrefix {
    final parts = <String>[];
    if (prefix != null && prefix!.isNotEmpty) {
      parts.add(prefix!);
    }
    if (fullName != null && fullName!.isNotEmpty) {
      parts.add(fullName!);
    }
    return parts.isNotEmpty ? parts.join(' ') : '-';
  }
}
