import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  int? _cachedNursinghomeId;
  String? _cachedUserId;

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

  /// Clear cached data (call on logout)
  void clearCache() {
    _cachedNursinghomeId = null;
    _cachedUserId = null;
  }
}
