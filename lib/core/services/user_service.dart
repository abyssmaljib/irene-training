import 'package:supabase_flutter/supabase_flutter.dart';

/// User role enum matching database enum
enum UserRoleType {
  admin,
  superAdmin,
}

/// User role information (using user_info.user_role enum)
class UserRole {
  final String? name; // 'admin', 'superAdmin', or null
  final String displayName;

  const UserRole({
    this.name,
    required this.displayName,
  });

  factory UserRole.fromDbValue(String? dbValue) {
    switch (dbValue) {
      case 'superAdmin':
        return const UserRole(name: 'superAdmin', displayName: 'Super Admin');
      case 'admin':
        return const UserRole(name: 'admin', displayName: 'Admin (หัวหน้าเวร)');
      default:
        return const UserRole(name: null, displayName: 'พนักงาน');
    }
  }

  /// Check if user is admin or superAdmin (can QC medicine photos)
  bool get canQC => name == 'admin' || name == 'superAdmin';

  /// Check if user is superAdmin
  bool get isSuperAdmin => name == 'superAdmin';

  /// Check if user is admin
  bool get isAdmin => name == 'admin';

  /// Check if user has any admin role
  bool get hasAdminRole => name != null;
}

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  int? _cachedNursinghomeId;
  String? _cachedUserId;
  UserRole? _cachedRole;

  /// Get current user's nursinghome_id
  /// Returns null if user is not logged in or doesn't have a nursinghome_id
  Future<int?> getNursinghomeId({bool forceRefresh = false}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    // Return cached value if same user and not forcing refresh
    if (!forceRefresh &&
        _cachedUserId == user.id &&
        _cachedNursinghomeId != null) {
      return _cachedNursinghomeId;
    }

    try {
      final response = await Supabase.instance.client
          .from('user_info')
          .select('nursinghome_id')
          .eq('id', user.id)
          .maybeSingle();

      _cachedUserId = user.id;
      _cachedNursinghomeId = response?['nursinghome_id'] as int?;
      return _cachedNursinghomeId;
    } catch (e) {
      return null;
    }
  }

  /// Get current user's role
  /// Returns UserRole with displayName 'พนักงาน' if no role set
  Future<UserRole> getRole({bool forceRefresh = false}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return UserRole.fromDbValue(null);

    // Return cached value if same user and not forcing refresh
    if (!forceRefresh && _cachedUserId == user.id && _cachedRole != null) {
      return _cachedRole!;
    }

    try {
      final response = await Supabase.instance.client
          .from('user_info')
          .select('user_role')
          .eq('id', user.id)
          .maybeSingle();

      _cachedUserId = user.id;
      _cachedRole = UserRole.fromDbValue(response?['user_role'] as String?);

      return _cachedRole!;
    } catch (e) {
      return UserRole.fromDbValue(null);
    }
  }

  /// Get current user's role name (convenience method)
  Future<String?> getRoleName({bool forceRefresh = false}) async {
    final role = await getRole(forceRefresh: forceRefresh);
    return role.name;
  }

  /// Check if current user can QC medicine photos
  Future<bool> canQC() async {
    final role = await getRole();
    return role.canQC;
  }

  /// Update current user's role (for dev mode)
  Future<bool> updateRole(String? roleName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      await Supabase.instance.client
          .from('user_info')
          .update({'user_role': roleName})
          .eq('id', user.id);

      // Clear cache to force refresh
      _cachedRole = null;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear cached data (call on logout)
  void clearCache() {
    _cachedNursinghomeId = null;
    _cachedUserId = null;
    _cachedRole = null;
  }
}
