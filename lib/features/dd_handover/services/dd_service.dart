import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../models/dd_record.dart';

/// Service สำหรับจัดการข้อมูล DD (เวรพาคนไข้ไปหาหมอ)
class DDService {
  static final DDService instance = DDService._();
  DDService._() {
    // Listen for user changes (impersonation)
    _userService.userChangedNotifier.addListener(_onUserChanged);
  }

  final _supabase = Supabase.instance.client;
  final _userService = UserService();

  // Cache
  List<DDRecord>? _cachedRecords;
  DateTime? _cacheTime;
  String? _cachedUserId;
  static const _cacheDuration = Duration(minutes: 5);

  void _onUserChanged() {
    invalidateCache();
  }

  /// ดึงรายการ DD ทั้งหมดของ user ปัจจุบัน
  Future<List<DDRecord>> getMyDDRecords({bool forceRefresh = false}) async {
    final userId = _userService.effectiveUserId;
    if (userId == null) return [];

    // Check cache (must be same user)
    if (!forceRefresh &&
        _cachedRecords != null &&
        _cacheTime != null &&
        _cachedUserId == userId &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedRecords!;
    }

    final response = await _supabase
        .from('ddRecordWithCalendar_Clock')
        .select()
        .eq('user_id', userId)
        .order('appointment_datetime', ascending: false);

    final records = (response as List)
        .map((e) => DDRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    // Update cache
    _cachedRecords = records;
    _cacheTime = DateTime.now();
    _cachedUserId = userId;

    return records;
  }

  /// ดึงรายการ DD ที่ยังไม่ได้ทำ
  Future<List<DDRecord>> getPendingDDRecords({bool forceRefresh = false}) async {
    final records = await getMyDDRecords(forceRefresh: forceRefresh);
    return records.where((r) => !r.isCompleted).toList();
  }

  /// ดึงรายการ DD ที่ทำแล้ว
  Future<List<DDRecord>> getCompletedDDRecords({bool forceRefresh = false}) async {
    final records = await getMyDDRecords(forceRefresh: forceRefresh);
    return records.where((r) => r.isCompleted).toList();
  }

  /// ดึง DD record by ID
  Future<DDRecord?> getDDRecordById(int ddId) async {
    final response = await _supabase
        .from('ddRecordWithCalendar_Clock')
        .select()
        .eq('dd_id', ddId)
        .maybeSingle();

    if (response == null) return null;
    return DDRecord.fromJson(response);
  }

  /// ล้าง cache
  void invalidateCache() {
    _cachedRecords = null;
    _cacheTime = null;
    _cachedUserId = null;
  }
}
