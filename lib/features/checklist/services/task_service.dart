import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_log.dart';
import '../models/user_shift.dart';

/// Service สำหรับจัดการ Tasks
/// ใช้ in-memory cache สำหรับ tasks เพื่อลด API calls
class TaskService {
  static final instance = TaskService._();
  TaskService._();

  final _supabase = Supabase.instance.client;

  // Cache สำหรับ tasks (per date + nursinghome)
  DateTime? _cachedDate;
  int? _cachedNursinghomeId;
  List<TaskLog>? _cachedTasks;
  DateTime? _cacheTime;
  static const _cacheMaxAge = Duration(minutes: 2);

  // Cache สำหรับ user shift
  String? _cachedUserId;
  int? _cachedShiftNursinghomeId;
  UserShift? _cachedUserShift;
  DateTime? _shiftCacheTime;
  static const _shiftCacheMaxAge = Duration(minutes: 5);

  /// ตรวจสอบว่า task cache ยังใช้ได้อยู่
  bool _isTaskCacheValid(DateTime date, int nursinghomeId) {
    if (_cachedDate == null || !_isSameDay(_cachedDate!, date)) return false;
    if (_cachedNursinghomeId != nursinghomeId) return false;
    if (_cachedTasks == null) return false;
    if (_cacheTime == null) return false;
    return DateTime.now().difference(_cacheTime!) < _cacheMaxAge;
  }

  /// ตรวจสอบว่า shift cache ยังใช้ได้อยู่
  bool _isShiftCacheValid(String userId, int nursinghomeId) {
    if (_cachedUserId != userId) return false;
    if (_cachedShiftNursinghomeId != nursinghomeId) return false;
    if (_cachedUserShift == null) return false;
    if (_shiftCacheTime == null) return false;
    return DateTime.now().difference(_shiftCacheTime!) < _shiftCacheMaxAge;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// ล้าง cache ทั้งหมด
  void invalidateCache() {
    _cachedTasks = null;
    _cacheTime = null;
    _cachedUserShift = null;
    _shiftCacheTime = null;
    debugPrint('TaskService: cache invalidated');
  }

  /// ดึง tasks ทั้งหมดของวันที่กำหนด
  ///
  /// ใช้ adjust_date ที่คำนวณตาม "วันทำงาน" (07:00-06:59 วันถัดไป) ใน database แล้ว
  Future<List<TaskLog>> getTasksByDate(
    DateTime date,
    int nursinghomeId, {
    bool forceRefresh = false,
  }) async {
    // ใช้ cache ถ้ายังใช้ได้และไม่ได้บังคับ refresh
    if (!forceRefresh && _isTaskCacheValid(date, nursinghomeId)) {
      debugPrint(
          'getTasksByDate: using cached data (${_cachedTasks!.length} tasks)');
      return _cachedTasks!;
    }

    try {
      // Format date เป็น YYYY-MM-DD
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final stopwatch = Stopwatch()..start();

      final response = await _supabase
          .from('v2_task_logs_with_details')
          .select()
          .eq('nursinghome_id', nursinghomeId)
          .eq('adjust_date', dateStr)
          // กรองเฉพาะ tasks ที่มี timeBlock (มาจาก A_Repeated_Task หรือ C_Task)
          // task ที่ไม่มี timeBlock = ไม่มี Task_Repeat_Id = ไม่สมบูรณ์
          .not('timeBlock', 'is', null)
          .order('ExpectedDateTime', ascending: true);

      stopwatch.stop();

      final tasks =
          (response as List).map((json) => TaskLog.fromJson(json)).toList();

      // Update cache
      _cachedDate = date;
      _cachedNursinghomeId = nursinghomeId;
      _cachedTasks = tasks;
      _cacheTime = DateTime.now();

      debugPrint(
          'getTasksByDate: fetched ${tasks.length} tasks for $dateStr in ${stopwatch.elapsedMilliseconds}ms');
      return tasks;
    } catch (e) {
      debugPrint('getTasksByDate error: $e');
      // Return cached data if available even on error
      if (_cachedDate != null &&
          _isSameDay(_cachedDate!, date) &&
          _cachedNursinghomeId == nursinghomeId &&
          _cachedTasks != null) {
        debugPrint('getTasksByDate: returning stale cache on error');
        return _cachedTasks!;
      }
      return [];
    }
  }

  /// ดึงข้อมูล shift ของ user (zones และ residents ที่เลือกตอนขึ้นเวร)
  Future<UserShift?> getCurrentUserShift(
    String userId,
    int nursinghomeId, {
    bool forceRefresh = false,
  }) async {
    // ใช้ cache ถ้ายังใช้ได้
    if (!forceRefresh && _isShiftCacheValid(userId, nursinghomeId)) {
      debugPrint('getCurrentUserShift: using cached data');
      return _cachedUserShift;
    }

    try {
      // ดึง shift ล่าสุดของวันนี้
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final response = await _supabase
          .from('clock_in_out_summary')
          .select(
              'shift_type, zones, selected_resident_id_list, clock_in_time, clock_out_time')
          .eq('user_id', userId)
          .eq('nursinghome_id', nursinghomeId)
          .gte('clock_in_time', todayStart.toIso8601String())
          .order('clock_in_time', ascending: false)
          .limit(1);

      if ((response as List).isEmpty) {
        debugPrint('getCurrentUserShift: no shift found for today');
        return null;
      }

      final shift = UserShift.fromJson(response.first);

      // Update cache
      _cachedUserId = userId;
      _cachedShiftNursinghomeId = nursinghomeId;
      _cachedUserShift = shift;
      _shiftCacheTime = DateTime.now();

      debugPrint('getCurrentUserShift: got shift - ${shift.shiftType}, '
          'zones: ${shift.zones}, residents: ${shift.selectedResidentIds}');
      return shift;
    } catch (e) {
      debugPrint('getCurrentUserShift error: $e');
      return _cachedUserShift; // Return stale cache on error
    }
  }

  /// Mark task เป็น complete
  Future<bool> markTaskComplete(
    int logId,
    String userId, {
    String? imageUrl,
  }) async {
    try {
      await _supabase.from('A_Task_logs_ver2').update({
        'status': 'complete',
        'completed_by': userId,
        'completed_at': DateTime.now().toIso8601String(),
        if (imageUrl != null) 'confirmImage': imageUrl,
      }).eq('id', logId);

      invalidateCache();
      debugPrint('markTaskComplete: log $logId marked as complete');
      return true;
    } catch (e) {
      debugPrint('markTaskComplete error: $e');
      return false;
    }
  }

  /// Mark task เป็น problem
  Future<bool> markTaskProblem(int logId, String description) async {
    try {
      await _supabase.from('A_Task_logs_ver2').update({
        'status': 'problem',
        'Descript': description,
      }).eq('id', logId);

      invalidateCache();
      debugPrint('markTaskProblem: log $logId marked as problem');
      return true;
    } catch (e) {
      debugPrint('markTaskProblem error: $e');
      return false;
    }
  }

  /// Untick task (ลบ completion)
  Future<bool> unmarkTask(int logId) async {
    try {
      await _supabase.from('A_Task_logs_ver2').update({
        'status': null,
        'completed_by': null,
        'completed_at': null,
      }).eq('id', logId);

      invalidateCache();
      debugPrint('unmarkTask: log $logId unmarked');
      return true;
    } catch (e) {
      debugPrint('unmarkTask error: $e');
      return false;
    }
  }
}

/// Extension สำหรับ filter tasks
extension TaskServiceFilters on TaskService {
  /// ดึง tasks ที่ยังไม่ได้ทำ (งานถัดไป)
  /// - status = null (pending)
  /// - อยู่ใน zones/residents ของ user (ถ้ามี shift)
  /// - ภายใน 2 ชั่วโมงข้างหน้า
  List<TaskLog> getUpcomingTasks(List<TaskLog> tasks, UserShift? shift) {
    final now = DateTime.now();
    final twoHoursLater = now.add(const Duration(hours: 2));

    return tasks.where((t) {
      // ต้องยังไม่ได้ทำ
      if (!t.isPending) return false;

      // ต้องมี expectedDateTime และอยู่ภายใน 2 ชม.
      if (t.expectedDateTime == null) return false;
      if (t.expectedDateTime!.isAfter(twoHoursLater)) return false;

      // Filter by user's zones/residents from clock-in
      if (shift != null && shift.hasAnyFilter) {
        if (!t.isInZones(shift.zones)) return false;
        if (!t.isInResidents(shift.selectedResidentIds)) return false;
      }

      return true;
    }).toList();
  }

  /// ดึง tasks ทั้งหมด (grouped by timeBlock)
  Map<String, List<TaskLog>> groupTasksByTimeBlock(List<TaskLog> tasks) {
    final grouped = <String, List<TaskLog>>{};

    for (final task in tasks) {
      // timeBlock ต้องไม่เป็น null เพราะเราใช้ .not('timeBlock', 'is', null) ใน query แล้ว
      final timeBlock = task.timeBlock ?? 'ไม่ระบุเวลา';
      grouped.putIfAbsent(timeBlock, () => []).add(task);
    }

    return grouped;
  }

  /// ดึง tasks ที่ติดปัญหา
  List<TaskLog> getProblemTasks(List<TaskLog> tasks) {
    return tasks.where((t) => t.isProblem).toList();
  }

  /// ดึง tasks ที่ user ทำเสร็จแล้ว
  List<TaskLog> getMyCompletedTasks(List<TaskLog> tasks, String userId) {
    return tasks.where((t) => t.completedByUid == userId).toList();
  }
}
