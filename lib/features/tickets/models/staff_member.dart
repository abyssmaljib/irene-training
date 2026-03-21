/// โมเดลสำหรับเก็บข้อมูลพนักงาน (staff) ที่ใช้ในระบบ @mention
/// ดึงข้อมูลจากตาราง user_info ใน Supabase
class StaffMember {
  /// uuid ของ user จากตาราง user_info
  final String id;

  /// ชื่อเล่น (nickname) ของ user
  final String nickname;

  /// ชื่อ-นามสกุลเต็ม (อาจเป็น null ถ้ายังไม่ได้กรอก)
  final String? fullName;

  /// URL รูปโปรไฟล์ (อาจเป็น null ถ้ายังไม่ได้อัปโหลด)
  final String? photoUrl;

  const StaffMember({
    required this.id,
    required this.nickname,
    this.fullName,
    this.photoUrl,
  });

  /// สร้าง StaffMember จาก JSON ที่ได้จากการ query ตาราง user_info
  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] as String,
      nickname: json['nickname'] as String? ?? '',
      fullName: json['i_Name_Surname'] as String?,
      photoUrl: json['photo_url'] as String?,
    );
  }

  /// ชื่อที่แสดง — ใช้ nickname เป็นหลัก ถ้าไม่มีใช้ fullName
  String get displayName =>
      nickname.isNotEmpty ? nickname : (fullName ?? 'ไม่ทราบชื่อ');
}
