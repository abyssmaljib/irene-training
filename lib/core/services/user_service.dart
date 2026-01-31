import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/checklist/models/system_role.dart';

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

/// Simple user info for dev mode user selection
class DevUserInfo {
  final String id;
  final String? nickname;
  final String? fullName;
  final String? photoUrl;
  final bool isClockedIn;
  final List<String> clockedInZones; // โซนที่ขึ้นเวรอยู่

  const DevUserInfo({
    required this.id,
    this.nickname,
    this.fullName,
    this.photoUrl,
    this.isClockedIn = false,
    this.clockedInZones = const [],
  });

  String get displayName => nickname ?? fullName ?? id;

  factory DevUserInfo.fromJson(
    Map<String, dynamic> json, {
    bool isClockedIn = false,
    List<String> clockedInZones = const [],
  }) {
    return DevUserInfo(
      id: json['id'] as String,
      nickname: json['nickname'] as String?,
      fullName: json['full_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      isClockedIn: isClockedIn,
      clockedInZones: clockedInZones,
    );
  }
}

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  int? _cachedNursinghomeId;
  String? _cachedUserId;
  String? _cachedUserName;
  UserRole? _cachedRole;

  // Dev mode impersonation
  String? _impersonatedUserId;
  String? _originalUserId;

  /// Notifier that fires when effective user changes (for UI refresh)
  final userChangedNotifier = ValueNotifier<int>(0);

  /// Check if currently impersonating another user
  bool get isImpersonating => _impersonatedUserId != null;

  /// Get the original user ID (before impersonation)
  String? get originalUserId => _originalUserId;

  /// Get the current effective user ID (impersonated or real)
  String? get effectiveUserId {
    if (_impersonatedUserId != null) return _impersonatedUserId;
    return Supabase.instance.client.auth.currentUser?.id;
  }

  /// Impersonate another user (dev mode only)
  Future<bool> impersonateUser(String userId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return false;

    try {
      // Save original user ID if not already impersonating
      _originalUserId ??= currentUser.id;

      _impersonatedUserId = userId;
      clearCache();
      _notifyUserChanged();
      
      debugPrint('Impersonating user: $userId (Original: $_originalUserId)');
      return true;
    } catch (e) {
      debugPrint('Impersonation failed: $e');
      return false;
    }
  }

  /// Stop impersonating and return to original user
  void stopImpersonating() {
    _impersonatedUserId = null;
    _originalUserId = null;
    clearCache();
    _notifyUserChanged();
    debugPrint('Stopped impersonating. Returning to original user.');
  }

  /// Alias for stopImpersonating
  void clearImpersonation() => stopImpersonating();

  /// Notify listeners that effective user has changed
  void _notifyUserChanged() {
    userChangedNotifier.value++;
  }

  /// Get current user's nursinghome_id
  /// Returns null if user is not logged in or doesn't have a nursinghome_id
  Future<int?> getNursinghomeId({bool forceRefresh = false}) async {
    final userId = effectiveUserId;
    if (userId == null) return null;

    // Return cached value if same user and not forcing refresh
    if (!forceRefresh &&
        _cachedUserId == userId &&
        _cachedNursinghomeId != null) {
      return _cachedNursinghomeId;
    }

    try {
      final response = await Supabase.instance.client
          .from('user_info')
          .select('nursinghome_id')
          .eq('id', userId)
          .maybeSingle();

      _cachedUserId = userId;
      _cachedNursinghomeId = response?['nursinghome_id'] as int?;
      return _cachedNursinghomeId;
    } catch (e) {
      return null;
    }
  }

  /// Get current user's name from user_info table
  ///
  /// Returns nickname if available, otherwise full_name
  Future<String?> getUserName({bool forceRefresh = false}) async {
    final userId = effectiveUserId;
    if (userId == null) return null;

    // Return cached value if same user and not forcing refresh
    if (!forceRefresh && _cachedUserId == userId && _cachedUserName != null) {
      return _cachedUserName;
    }

    try {
      // Query user_info table (ไม่ใช่ users)
      // ดึงทั้ง nickname และ full_name เพื่อใช้แสดงชื่อ
      final response = await Supabase.instance.client
          .from('user_info')
          .select('nickname, full_name')
          .eq('id', userId)
          .maybeSingle();

      _cachedUserId = userId;
      // Prefer nickname over full_name (เหมือน DevUserInfo.displayName)
      _cachedUserName =
          response?['nickname'] as String? ?? response?['full_name'] as String?;
      return _cachedUserName;
    } catch (e) {
      debugPrint('UserService: Error getting user name: $e');
      return null;
    }
  }

  /// Get current user's role
  /// Returns UserRole with displayName 'พนักงาน' if no role set
  Future<UserRole> getRole({bool forceRefresh = false}) async {
    final userId = effectiveUserId;
    if (userId == null) return UserRole.fromDbValue(null);

    // Return cached value if same user and not forcing refresh
    if (!forceRefresh && _cachedUserId == userId && _cachedRole != null) {
      return _cachedRole!;
    }

    try {
      final response = await Supabase.instance.client
          .from('user_info')
          .select('user_role')
          .eq('id', userId)
          .maybeSingle();

      _cachedUserId = userId;
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

  /// Check if current user can QC medicine photos (หัวหน้าเวรขึ้นไป)
  /// Uses SystemRole instead of UserRole (admin/superAdmin)
  Future<bool> canQC() async {
    final systemRole = await getSystemRole();
    return systemRole?.canQC ?? false;
  }

  /// Update current user's role (for dev mode)
  Future<bool> updateRole(String? roleName) async {
    final userId = effectiveUserId;
    if (userId == null) return false;

    try {
      await Supabase.instance.client
          .from('user_info')
          .update({'user_role': roleName})
          .eq('id', userId);

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
    _cachedSystemRole = null;
  }

  // ============================================================
  // System Role (ตำแหน่งงาน: NA, Nurse, Incharge, etc.)
  // ============================================================

  SystemRole? _cachedSystemRole;

  /// Get current user's system role (from user_system_roles table)
  /// Returns null if user doesn't have a system role assigned
  Future<SystemRole?> getSystemRole({bool forceRefresh = false}) async {
    final userId = effectiveUserId;
    if (userId == null) return null;

    // Return cached value if same user and not forcing refresh
    if (!forceRefresh &&
        _cachedUserId == userId &&
        _cachedSystemRole != null) {
      return _cachedSystemRole;
    }

    try {
      // Query user_info joined with user_system_roles (รวม level, related_role_ids)
      final response = await Supabase.instance.client
          .from('user_info')
          .select('role_id, user_system_roles(id, role_name, abb, level, related_role_ids)')
          .eq('id', userId)
          .maybeSingle();

      if (response == null || response['role_id'] == null) {
        return null;
      }

      final roleData = response['user_system_roles'];
      if (roleData != null) {
        _cachedSystemRole = SystemRole.fromJson(roleData as Map<String, dynamic>);
      }

      return _cachedSystemRole;
    } catch (e) {
      return null;
    }
  }

  /// Get all available system roles
  Future<List<SystemRole>> getAllSystemRoles() async {
    try {
      final response = await Supabase.instance.client
          .from('user_system_roles')
          .select()
          .order('id');

      return (response as List)
          .map((json) => SystemRole.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // Dev Mode: Get all users for impersonation
  // ============================================================

  /// Get all users in the same nursinghome (for dev mode impersonation)
  /// Users who are currently clocked in will be sorted to the top
  Future<List<DevUserInfo>> getAllUsers({bool debugFetchAll = false}) async {
    try {
      // Use REAL user's nursinghome_id (not impersonated)
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final isDevSuperUser = user.email == 'beautyheechul@gmail.com';

      // Get real user's nursinghome_id directly (bypass effectiveUserId)
      final userInfoResponse = await Supabase.instance.client
          .from('user_info')
          .select('nursinghome_id')
          .eq('id', user.id)
          .maybeSingle();

      final nursinghomeId = userInfoResponse?['nursinghome_id'] as int?;

      debugPrint('getAllUsers: nursinghomeId=$nursinghomeId, isDev=$isDevSuperUser, debug=$debugFetchAll');

      // If no nursinghome and not dev/debug, return empty
      if (nursinghomeId == null && !debugFetchAll && !isDevSuperUser) {
        return [];
      }

      // Build query
      var query = Supabase.instance.client
          .from('user_info')
          .select('id, nickname, full_name, photo_url');

      if (nursinghomeId != null) {
        query = query.eq('nursinghome_id', nursinghomeId);
      }
      
      // Order first (converts to TransformBuilder)
      var transformQuery = query.order('nickname');

      if (nursinghomeId == null) {
        // Dev mode without nursinghome: limit results
        transformQuery = transformQuery.limit(50);
      }

      final usersResponse = await transformQuery;
      debugPrint('getAllUsers: found ${usersResponse.length} users');

      // Get users who are currently clocked in (simple query only)
      final clockedInUserIds = <String>{};

      if (nursinghomeId != null) {
        try {
          final clockedInResponse = await Supabase.instance.client
              .from('clock_in_out_ver2')
              .select('user_id')
              .eq('nursinghome_id', nursinghomeId)
              .isFilter('clock_out_timestamp', null);

          for (final row in clockedInResponse) {
            final odUserId = row['user_id'] as String?;
            if (odUserId != null) {
              clockedInUserIds.add(odUserId);
            }
          }
          debugPrint('getAllUsers: ${clockedInUserIds.length} users clocked in');
        } catch (e) {
          debugPrint('getAllUsers: Failed to get clocked-in users: $e');
        }
      }

      // Map users with clocked-in status
      final users = (usersResponse as List).map((json) {
        final odUserId = json['id'] as String;
        final isClockedIn = clockedInUserIds.contains(odUserId);

        return DevUserInfo.fromJson(
          json as Map<String, dynamic>,
          isClockedIn: isClockedIn,
          clockedInZones: const [], // ไม่ดึงโซนแล้ว
        );
      }).toList();

      // Sort: clocked-in users first, then by nickname
      users.sort((a, b) {
        if (a.isClockedIn && !b.isClockedIn) return -1;
        if (!a.isClockedIn && b.isClockedIn) return 1;
        return (a.nickname ?? '').compareTo(b.nickname ?? '');
      });

      return users;
    } catch (e) {
      debugPrint('getAllUsers error: $e');
      return [];
    }
  }
}
