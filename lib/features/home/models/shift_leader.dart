/// Model สำหรับข้อมูลหัวหน้าเวร (คนที่ Incharge = true)
/// ใช้แสดงใน ClockOutSurveyForm เพื่อให้ประเมินหัวหน้าเวร
class ShiftLeader {
  final String id;
  final String? nickname;
  final String? fullName;
  final String? photoUrl;

  const ShiftLeader({
    required this.id,
    this.nickname,
    this.fullName,
    this.photoUrl,
  });

  /// ชื่อที่ใช้แสดง - ใช้ nickname ก่อน ถ้าไม่มีใช้ fullName
  String get displayName => nickname ?? fullName ?? 'ไม่ทราบชื่อ';

  /// Parse จาก Supabase response (join กับ user_info)
  factory ShiftLeader.fromJson(Map<String, dynamic> json) {
    // ข้อมูล user มาจาก nested user_info
    final userInfo = json['user_info'] as Map<String, dynamic>?;

    return ShiftLeader(
      id: json['user_id'] as String? ?? '',
      nickname: userInfo?['nickname'] as String?,
      fullName: userInfo?['full_name'] as String?,
      photoUrl: userInfo?['photo_url'] as String?,
    );
  }

  @override
  String toString() {
    return 'ShiftLeader(id: $id, displayName: $displayName)';
  }
}
