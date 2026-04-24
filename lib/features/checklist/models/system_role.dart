/// Model สำหรับ user_system_roles table
/// ใช้กำหนดตำแหน่งงานของ staff เช่น NA, Nurse, Incharge
class SystemRole {
  final int id;
  final String name; // 'na_fulltime', 'nurse', 'shift_leader', etc.
  final String? abb; // ชื่อย่อ เช่น 'NA', 'หน.เวร'
  final int level; // ระดับสิทธิ์ (จาก database)

  const SystemRole({
    required this.id,
    required this.name,
    this.abb,
    this.level = 0,
  });

  /// Parse จาก Supabase response
  factory SystemRole.fromJson(Map<String, dynamic> json) {
    return SystemRole(
      id: json['id'] as int,
      name: json['role_name'] as String? ?? '',
      abb: json['abb'] as String?,
      level: json['level'] as int? ?? 0,
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role_name': name,
      'abb': abb,
      'level': level,
    };
  }

  @override
  String toString() {
    return 'SystemRole(id: $id, name: $name, abb: $abb, level: $level)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SystemRole && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // ============================================================
  // Permission Level Constants
  // ============================================================

  /// Level thresholds for permission checking
  static const int shiftLeaderLevel = 30;
  static const int nurseLevel = 25;
  static const int managerLevel = 40;

  /// Check if this role is at least shift leader level (หัวหน้าเวรขึ้นไป)
  /// Used for QC permissions
  bool get canQC => level >= shiftLeaderLevel;

  /// Check if this role is at least nurse level
  bool get isAtLeastNurse => level >= nurseLevel;

  /// Check if this role is at least manager level
  bool get isAtLeastManager => level >= managerLevel;

  /// Check if this role is owner
  bool get isOwner => name == 'owner';

  /// Check if this role is shift leader (หัวหน้าเวร - role 12)
  /// ใช้สำหรับ auto-set Incharge = true ตอน clock in เสมอ
  bool get isShiftLeader => id == 12;

  /// Check if this role is backup shift leader (หัวหน้าเวรสำรอง - role 13)
  /// จะ auto-set Incharge = true เฉพาะเมื่อไม่มี role 12 ขึ้นเวรอยู่
  bool get isBackupShiftLeader => id == 13;

  /// Check if this role can be incharge (หัวหน้าเวร หรือ หัวหน้าเวรสำรอง)
  bool get canBeIncharge => isShiftLeader || isBackupShiftLeader;

  /// Check if this role is doctor (แพทย์ - role 6)
  bool get isDoctor => id == 6;

  /// Check if this role can cancel a task
  /// อนุญาตให้: หัวหน้าเวรขึ้นไป (level >= 30), แพทย์ (id == 6)
  /// หมายเหตุ: ต้อง check ร่วมกับ completedByUid == currentUserId ที่ UI ด้วย
  bool get canCancelTask => canQC || isDoctor;
}
