/// Model สำหรับเก็บข้อมูล invitation จาก view invitations_with_nursinghomes
///
/// View นี้ JOIN ระหว่าง invitations table กับ nursinghomes table
/// เพื่อแสดงข้อมูลคำเชิญพร้อมข้อมูลศูนย์ดูแลผู้สูงอายุ
class Invitation {
  /// ID ของ invitation (from invitations table)
  final int invitationId;

  /// Email ของ user ที่ถูกเชิญ
  final String userEmail;

  /// ID ของ nursinghome ที่เชิญ
  final int nursinghomeId;

  /// ชื่อ nursinghome
  final String nursinghomeName;

  /// URL รูปภาพของ nursinghome (optional)
  final String? nursinghomePicUrl;

  /// Role ID ที่จะกำหนดให้ user เมื่อ accept invitation (optional)
  /// ถ้าไม่มี จะไม่กำหนด role ให้
  final int? roleId;

  /// ชื่อ role (optional)
  final String? roleName;

  /// ตัวย่อของ role เช่น PT, RN, NA (optional)
  final String? roleAbb;

  /// บอกว่า user accept invitation แล้วหรือยัง
  /// true = มี user_info record ที่มี email ตรงกัน และ nursinghome_id ตรงกัน
  /// false = ยังไม่มี (user ยังไม่ได้ accept)
  final bool acceptedUserInfo;

  const Invitation({
    required this.invitationId,
    required this.userEmail,
    required this.nursinghomeId,
    required this.nursinghomeName,
    this.nursinghomePicUrl,
    this.roleId,
    this.roleName,
    this.roleAbb,
    required this.acceptedUserInfo,
  });

  /// สร้าง Invitation จาก JSON ที่ได้จาก Supabase
  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      invitationId: json['invitation_id'] as int,
      userEmail: json['user_email'] as String,
      nursinghomeId: json['nursinghome_id'] as int,
      nursinghomeName: json['nursinghome_name'] as String,
      nursinghomePicUrl: json['nursinghome_pic_url'] as String?,
      roleId: json['role_id'] as int?,
      roleName: json['role_name'] as String?,
      roleAbb: json['role_abb'] as String?,
      acceptedUserInfo: json['accepted_user_info'] as bool? ?? false,
    );
  }

  /// แปลง Invitation เป็น JSON (สำหรับ debug หรือส่งกลับ)
  Map<String, dynamic> toJson() {
    return {
      'invitation_id': invitationId,
      'user_email': userEmail,
      'nursinghome_id': nursinghomeId,
      'nursinghome_name': nursinghomeName,
      'nursinghome_pic_url': nursinghomePicUrl,
      'role_id': roleId,
      'role_name': roleName,
      'role_abb': roleAbb,
      'accepted_user_info': acceptedUserInfo,
    };
  }

  @override
  String toString() {
    return 'Invitation(invitationId: $invitationId, email: $userEmail, nursinghome: $nursinghomeName, role: $roleName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Invitation && other.invitationId == invitationId;
  }

  @override
  int get hashCode => invitationId.hashCode;
}
