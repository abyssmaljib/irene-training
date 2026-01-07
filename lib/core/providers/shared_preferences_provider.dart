import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider สำหรับ SharedPreferences instance
/// ต้อง override ใน main.dart ด้วย SharedPreferences.getInstance()
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences must be overridden in main.dart with SharedPreferences.getInstance()',
  );
});
