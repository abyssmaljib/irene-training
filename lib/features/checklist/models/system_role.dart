/// Model สำหรับ user_system_roles table
/// ใช้กำหนดตำแหน่งงานของ staff เช่น NA, Nurse, Incharge
class SystemRole {
  final int id;
  final String name; // 'na_fulltime', 'nurse', 'shift_leader', etc.

  const SystemRole({
    required this.id,
    required this.name,
  });

  /// Parse จาก Supabase response
  factory SystemRole.fromJson(Map<String, dynamic> json) {
    return SystemRole(
      id: json['id'] as int,
      name: json['role_name'] as String? ?? '',
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role_name': name,
    };
  }

  @override
  String toString() {
    return 'SystemRole(id: $id, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SystemRole && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
