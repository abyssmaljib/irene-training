import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider สำหรับ current user
/// ใช้ StreamProvider เพื่อ listen auth state changes
final currentUserProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((data) => data.session?.user);
});

/// Provider สำหรับ current user ID (sync)
/// ใช้สำหรับกรณีที่ต้องการ user ID แบบ sync
final currentUserIdProvider = Provider<String>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  return user?.id ?? 'unknown';
});
