import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Notifier สำหรับจัดการ checkbox state ของแต่ละวันในเวร
/// เก็บ state ใน SharedPreferences (local only, ไม่ sync กับ database)
class CheckboxStateNotifier extends StateNotifier<Map<String, bool>> {
  final String userId;
  final SharedPreferences prefs;

  CheckboxStateNotifier(this.userId, this.prefs) : super({}) {
    _loadCheckboxStates();
  }

  /// สร้าง key สำหรับเก็บใน SharedPreferences
  /// Format: shift_checkbox_{userId}_{year}_{month}_{day}
  String _makeKey(int year, int month, int day) {
    return 'shift_checkbox_${userId}_${year}_${month}_$day';
  }

  /// เช็คว่าวันนี้ถูก tick หรือไม่
  bool isChecked(int year, int month, int day) {
    final key = _makeKey(year, month, day);
    return state[key] ?? false;
  }

  /// Toggle checkbox state (checked <-> unchecked)
  void toggle(int year, int month, int day) {
    final key = _makeKey(year, month, day);
    final newValue = !(state[key] ?? false);
    final newState = Map<String, bool>.from(state);
    newState[key] = newValue;
    state = newState;
    prefs.setBool(key, newValue);
  }

  /// Tick all checkboxes สำหรับเดือนนั้นๆ
  void tickAll(int year, int month, List<int> days) {
    final updates = <String, bool>{};
    for (final day in days) {
      final key = _makeKey(year, month, day);
      updates[key] = true;
      prefs.setBool(key, true);
    }
    state = {...state, ...updates};
  }

  /// Untick all checkboxes สำหรับเดือนนั้นๆ
  void untickAll(int year, int month, List<int> days) {
    final updates = <String, bool>{};
    for (final day in days) {
      final key = _makeKey(year, month, day);
      updates[key] = false;
      prefs.remove(key); // ลบออกจาก SharedPreferences
    }
    state = {...state, ...updates};
  }

  /// Load checkbox states จาก SharedPreferences
  void _loadCheckboxStates() {
    final keys = prefs.getKeys().where((k) => k.startsWith('shift_checkbox_$userId'));
    final loadedState = <String, bool>{};
    for (final key in keys) {
      loadedState[key] = prefs.getBool(key) ?? false;
    }
    state = loadedState;
  }
}

/// Provider สำหรับ CheckboxStateNotifier
final checkboxStateProvider =
    StateNotifierProvider<CheckboxStateNotifier, Map<String, bool>>((ref) {
  // Get userId from auth
  final userId = ref.watch(currentUserIdProvider);
  // Get SharedPreferences instance
  final prefs = ref.watch(sharedPreferencesProvider);
  return CheckboxStateNotifier(userId, prefs);
});
