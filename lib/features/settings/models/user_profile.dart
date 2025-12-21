class UserProfile {
  final String id;
  final String? photoUrl;
  final String? nickname;
  final String? fullName;
  final String? prefix;
  final int? nursinghomeId;

  const UserProfile({
    required this.id,
    this.photoUrl,
    this.nickname,
    this.fullName,
    this.prefix,
    this.nursinghomeId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      photoUrl: json['photo_url'] as String?,
      nickname: json['nickname'] as String?,
      fullName: json['full_name'] as String?,
      prefix: json['prefix'] as String?,
      nursinghomeId: json['nursinghome_id'] as int?,
    );
  }

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
