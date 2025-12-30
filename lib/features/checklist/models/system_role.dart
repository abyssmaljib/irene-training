/// Model สำหรับ user_system_roles table
/// ใช้กำหนดตำแหน่งงานของ staff เช่น NA, Nurse, Incharge
class SystemRole {
  final int id;
  final String name; // 'na_fulltime', 'nurse', 'shift_leader', etc.
  final String? abb; // ชื่อย่อ เช่น 'NA', 'หน.เวร'
  final List<int> relatedRoleIds; // role ids ที่ role นี้เห็น task ได้ด้วย

  const SystemRole({
    required this.id,
    required this.name,
    this.abb,
    this.relatedRoleIds = const [],
  });

  /// Parse จาก Supabase response
  factory SystemRole.fromJson(Map<String, dynamic> json) {
    return SystemRole(
      id: json['id'] as int,
      name: json['role_name'] as String? ?? '',
      abb: json['abb'] as String?,
      relatedRoleIds: _parseIntList(json['related_role_ids']),
    );
  }

  static List<int> _parseIntList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList();
    }
    return [];
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role_name': name,
      'abb': abb,
      'related_role_ids': relatedRoleIds,
    };
  }

  /// ตรวจสอบว่า role นี้สามารถเห็น task ที่ assign ให้ roleId ได้หรือไม่
  /// - เห็น task ของตัวเอง (assignedRoleId == id)
  /// - เห็น task ที่ไม่ระบุ role (assignedRoleId == null)
  /// - เห็น task ของ role ใน relatedRoleIds
  bool canSeeTasksForRole(int? assignedRoleId) {
    // ถ้า task ไม่ได้ assign role = ทุกคนเห็น
    if (assignedRoleId == null) return true;
    // เห็น task ของตัวเอง
    if (assignedRoleId == id) return true;
    // เห็น task ของ related roles
    return relatedRoleIds.contains(assignedRoleId);
  }

  @override
  String toString() {
    return 'SystemRole(id: $id, name: $name, abb: $abb, relatedRoleIds: $relatedRoleIds)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SystemRole && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
