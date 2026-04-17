import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../points/services/points_service.dart';
import '../models/task_log.dart';
import '../models/user_shift.dart';

/// ผลลัพธ์จาก markTaskComplete — บอกสาเหตุเมื่อ fail
/// [success] = true ถ้าบันทึกสำเร็จ
/// [errorCode] = รหัส error สั้นๆ (ให้ user cap ส่งมาได้)
/// [errorDetail] = รายละเอียด error สำหรับ debug
class TaskCompleteResult {
  final bool success;
  final String? errorCode;
  final String? errorDetail;

  const TaskCompleteResult._({
    required this.success,
    this.errorCode,
    this.errorDetail,
  });

  /// สำเร็จ
  factory TaskCompleteResult.ok() =>
      const TaskCompleteResult._(success: true);

  /// งานถูกทำไปแล้ว (คนอื่นทำก่อน)
  factory TaskCompleteResult.alreadyDone(int logId) =>
      TaskCompleteResult._(
        success: false,
        errorCode: 'TASK_ALREADY_DONE',
        errorDetail: 'log $logId already completed by someone else',
      );

  /// Server/network error
  factory TaskCompleteResult.serverError(Object error) =>
      TaskCompleteResult._(
        success: false,
        errorCode: 'SERVER_ERROR',
        errorDetail: error.toString(),
      );

  /// สร้าง user-facing message ภาษาไทย พร้อม error code
  String get userMessage {
    switch (errorCode) {
      case 'TASK_ALREADY_DONE':
        return 'งานนี้ถูกทำไปแล้วโดยคนอื่น (TASK_ALREADY_DONE)';
      case 'SERVER_ERROR':
        // ตัด error detail ไม่เกิน 80 ตัวอักษร เพื่อไม่ให้ toast ยาวเกิน
        final short = (errorDetail ?? 'unknown').length > 80
            ? '${errorDetail!.substring(0, 80)}…'
            : (errorDetail ?? 'unknown');
        return 'เกิดข้อผิดพลาด: $short (SERVER_ERROR)';
      default:
        return 'ไม่สามารถบันทึกได้ กรุณาลองใหม่';
    }
  }
}

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

      // ✨ ใช้ RPC get_tasks_by_date แทน query view โดยตรง
      // RPC = SECURITY DEFINER → ตรวจสิทธิ์ 1 ครั้ง → เร็วกว่า query view ตรงมาก
      // filter: nursinghome_id, adjust_date, timeBlock IS NOT NULL, ORDER BY ExpectedDateTime
      final response = await _supabase.rpc(
        'get_tasks_by_date',
        params: {
          'p_date': dateStr,
          'p_nursinghome_id': nursinghomeId,
        },
      );

      stopwatch.stop();

      final tasks =
          (response as List).map((json) => TaskLog.fromJson(json)).toList();

      final viewMs = stopwatch.elapsedMilliseconds;

      // ดึง history_seen_users แยกผ่าน RPC (view ส่ง [] เพราะลบ LATERAL join ออกแล้ว)
      // ทำแบบ batch เรียกครั้งเดียว เร็วกว่า LATERAL join ที่วนทีละ row
      final enrichedTasks = await _enrichWithSeenUsers(tasks);

      // Update cache
      _cachedDate = date;
      _cachedNursinghomeId = nursinghomeId;
      _cachedTasks = enrichedTasks;
      _cacheTime = DateTime.now();

      debugPrint(
          'getTasksByDate: fetched ${enrichedTasks.length} tasks for $dateStr '
          'in ${stopwatch.elapsedMilliseconds}ms (view: ${viewMs}ms, seen: ${stopwatch.elapsedMilliseconds - viewMs}ms)');
      return enrichedTasks;
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

  /// ดึง history_seen_users แบบ batch ผ่าน RPC function
  /// แทน LATERAL join ที่ลบออกจาก view (เร็วกว่า + ไม่มีปัญหา RLS)
  ///
  /// Flow:
  /// 1. รวบรวม taskId ทั้งหมดจาก tasks
  /// 2. เรียก RPC get_task_seen_users ครั้งเดียว (batch)
  /// 3. Merge seen_users กลับเข้า TaskLog ผ่าน copyWith
  Future<List<TaskLog>> _enrichWithSeenUsers(List<TaskLog> tasks) async {
    if (tasks.isEmpty) return tasks;

    // รวบรวม taskId ที่ไม่ซ้ำ (ไม่รวม null)
    final taskIds = tasks
        .map((t) => t.taskId)
        .where((id) => id != null)
        .cast<int>()
        .toSet()
        .toList();

    if (taskIds.isEmpty) return tasks;

    try {
      // เรียก RPC ครั้งเดียว — ได้ {task_id, seen_users[]} ทุก task
      final response = await _supabase.rpc(
        'get_task_seen_users',
        params: {'p_task_ids': taskIds},
      );

      // สร้าง Map: taskId → List<String> ของ user ที่เคยเห็น
      final seenMap = <int, List<String>>{};
      for (final row in (response as List)) {
        final taskId = row['task_id'] as int;
        final users = (row['seen_users'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        seenMap[taskId] = users;
      }

      // Merge seen_users เข้า TaskLog
      return tasks.map((task) {
        if (task.taskId != null && seenMap.containsKey(task.taskId)) {
          return task.copyWith(historySeenUsers: seenMap[task.taskId!]);
        }
        return task;
      }).toList();
    } catch (e) {
      // ถ้า RPC ล้มเหลว → return tasks เดิม (unseen badge จะแสดงทุก task เป็น unseen)
      debugPrint('_enrichWithSeenUsers error: $e');
      return tasks;
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
  /// video จะดึงจาก Post ผ่าน post_id ใน view แทน
  /// [difficultyScore] - คะแนนความยากของงาน 1-10 (optional)
  /// [difficultyRatedBy] - UUID ของ user ที่ให้คะแนน (optional, ถ้าไม่ระบุจะใช้ userId)
  /// [skipPointsRecording] - ข้าม recording points (ใช้สำหรับ batch mode ที่จัดการ points เอง)
  Future<TaskCompleteResult> markTaskComplete(
    int logId,
    String userId, {
    String? imageUrl,
    int? postId,
    int? difficultyScore,
    String? difficultyRatedBy,
    bool skipPointsRecording = false,
  }) async {
    try {
      // First-write-wins: UPDATE เฉพาะเมื่อ status ยังเป็น null (pending)
      // ป้องกัน 2 คน complete task เดียวกันพร้อมกัน — คนหลังจะไม่ทับคนแรก
      // ใช้ .select() เพื่อได้ affected rows กลับมาตรวจสอบ
      final result = await _supabase
          .from('A_Task_logs_ver2')
          .update({
            'status': 'complete',
            'completed_by': userId,
            'completed_at': DateTime.now().toIso8601String(),
            if (imageUrl != null) 'confirmImage': imageUrl,
            if (postId != null) 'post_id': postId,
            if (difficultyScore != null) 'difficulty_score': difficultyScore,
            if (difficultyScore != null)
              'difficulty_rated_by': difficultyRatedBy ?? userId,
          })
          .eq('id', logId)
          .isFilter('status', null) // เฉพาะ task ที่ยังไม่ได้ทำ (first-write-wins)
          .select('id');

      // ถ้า result ว่าง = task ถูก complete ไปแล้ว (คนอื่นทำก่อน)
      if ((result as List).isEmpty) {
        debugPrint(
            'markTaskComplete: log $logId already completed by someone else');
        return TaskCompleteResult.alreadyDone(logId);
      }

      invalidateCache();
      debugPrint(
          'markTaskComplete: log $logId marked as complete (postId: $postId, difficulty: $difficultyScore)');

      // บันทึก points สำหรับ task completion
      // ข้ามถ้า skipPointsRecording = true (batch mode จัดการ points แยก)
      if (!skipPointsRecording) {
        try {
          String taskName = 'งาน';
          final cachedTask = _cachedTasks?.where((t) => t.logId == logId).firstOrNull;
          if (cachedTask != null) {
            taskName = cachedTask.title ?? 'งาน';
          }

          // ใช้ V1 เพราะ context นี้ไม่มี actualMinutes, expectedMinutes, completionType
          // ignore: deprecated_member_use_from_same_package
          final points = await PointsService().recordTaskCompleted(
            userId: userId,
            taskLogId: logId,
            taskName: taskName,
            difficultyScore: difficultyScore,
          );
          debugPrint('markTaskComplete: recorded $points points');
        } catch (e) {
          // ไม่ให้ error จาก points กระทบ task completion
          debugPrint('markTaskComplete: failed to record points: $e');
        }
      }

      return TaskCompleteResult.ok();
    } catch (e) {
      debugPrint('markTaskComplete error: $e');
      return TaskCompleteResult.serverError(e);
    }
  }

  /// อัพเดตคะแนนความยากของงาน (สำหรับแก้ไขภายหลัง)
  /// [logId] - ID ของ task log ที่ต้องการอัพเดต
  /// [difficultyScore] - คะแนนความยากใหม่ (1-10)
  /// [ratedBy] - UUID ของผู้ให้คะแนน
  Future<bool> updateDifficultyScore(
    int logId,
    int difficultyScore,
    String ratedBy,
  ) async {
    try {
      await _supabase.from('A_Task_logs_ver2').update({
        'difficulty_score': difficultyScore,
        'difficulty_rated_by': ratedBy,
      }).eq('id', logId);

      invalidateCache();
      debugPrint(
          'updateDifficultyScore: log $logId updated to $difficultyScore');
      return true;
    } catch (e) {
      debugPrint('updateDifficultyScore error: $e');
      return false;
    }
  }

  /// Mark task เป็น problem พร้อมระบุประเภทปัญหา
  /// [userId] - UUID ของผู้แจ้งปัญหา
  /// [problemType] - ประเภทปัญหา เช่น patient_refused, not_eating, other
  /// [description] - รายละเอียดเพิ่มเติม (optional, บังคับเฉพาะ type=other)
  Future<bool> markTaskProblem(
    int logId,
    String userId,
    String problemType,
    String? description,
  ) async {
    try {
      await _supabase.from('A_Task_logs_ver2').update({
        'status': 'problem',
        'problem_type': problemType,
        'Descript': description,
        'completed_by': userId, // บันทึกผู้แจ้งปัญหา
        'completed_at': DateTime.now().toUtc().toIso8601String(), // บันทึกเวลาที่แจ้ง
      }).eq('id', logId);

      invalidateCache();
      debugPrint('markTaskProblem: log $logId marked as $problemType by $userId');
      return true;
    } catch (e) {
      debugPrint('markTaskProblem error: $e');
      return false;
    }
  }

  /// Untick task (ลบ completion)
  /// - Clear status, completed_by, completed_at, confirmImage, Descript
  /// - ลบรูป confirmImage จาก storage (ถ้ามี)
  Future<bool> unmarkTask(int logId, {String? confirmImageUrl}) async {
    try {
      // ลบรูป confirmImage จาก storage (ถ้ามี)
      if (confirmImageUrl != null && confirmImageUrl.isNotEmpty) {
        try {
          // Extract path จาก URL
          // URL format: https://xxx.supabase.co/storage/v1/object/public/med-photos/task_confirms/xxx.jpg
          final uri = Uri.parse(confirmImageUrl);
          final pathSegments = uri.pathSegments;
          // หา index ของ bucket name แล้วเอา path หลังจากนั้น
          final bucketIndex = pathSegments.indexOf('med-photos');
          if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
            final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
            await _supabase.storage.from('med-photos').remove([storagePath]);
            debugPrint('unmarkTask: deleted image $storagePath');
          }
        } catch (e) {
          // ไม่ให้ error การลบรูปทำให้ cancel ไม่ได้
          debugPrint('unmarkTask: failed to delete image: $e');
        }
      }

      // ลบ assessment ratings ก่อน (ถ้ามี) — เพราะ CASCADE delete ไม่ทำงานกับ UPDATE
      try {
        await _supabase
            .from('Scale_Report_Log')
            .delete()
            .eq('task_log_id', logId);
      } catch (e) {
        debugPrint('unmarkTask: failed to delete assessment ratings: $e');
      }

      await _supabase.from('A_Task_logs_ver2').update({
        'status': null,
        'completed_by': null,
        'completed_at': null,
        'confirmImage': null,
        'Descript': null,
        'problem_type': null,
        'difficulty_score': null,
        'difficulty_rated_by': null,
        'post_id': null, // Clear post_id เพื่อให้ลบ Post ได้ (FK constraint)
      }).eq('id', logId);

      invalidateCache();
      debugPrint('unmarkTask: log $logId unmarked (+ assessment ratings deleted)');
      return true;
    } catch (e) {
      debugPrint('unmarkTask error: $e');
      return false;
    }
  }

  /// Mark task เป็น refer (ไม่อยู่ศูนย์)
  Future<bool> markTaskRefer(int logId, String userId) async {
    try {
      await _supabase.from('A_Task_logs_ver2').update({
        'status': 'refer',
        'completed_by': userId,
        'completed_at': DateTime.now().toIso8601String(),
        'Descript': 'อยู่ที่โรงพยาบาล (Refer)',
      }).eq('id', logId);

      invalidateCache();
      debugPrint('markTaskRefer: log $logId marked as refer');
      return true;
    } catch (e) {
      debugPrint('markTaskRefer error: $e');
      return false;
    }
  }

  /// Update confirm image URL
  Future<bool> updateConfirmImage(int logId, String imageUrl) async {
    try {
      await _supabase.from('A_Task_logs_ver2').update({
        'confirmImage': imageUrl,
      }).eq('id', logId);

      invalidateCache();
      debugPrint('updateConfirmImage: log $logId image updated');
      return true;
    } catch (e) {
      debugPrint('updateConfirmImage error: $e');
      return false;
    }
  }

  /// ดึงประวัติการแก้ปัญหาของ task ที่คล้ายกัน (same taskId หรือ same residentId + taskType)
  /// ใช้แสดงใน ProblemInputSheet ก่อนที่ user จะเลือกประเภทปัญหา
  /// เพื่อให้ user เห็นว่าปัญหาลักษณะนี้เคยแก้อย่างไร
  Future<List<TaskLog>> getResolutionHistory({
    int? taskId,
    int? residentId,
    String? taskType,
    int nursinghomeId = 0,
    int limit = 5,
  }) async {
    try {
      // สร้าง base query
      // ต้องเรียก filter ก่อน order และ limit เพราะ Supabase SDK chain อย่างนั้น
      var query = _supabase
          .from('v2_task_logs_with_details')
          .select()
          .not('resolution_status', 'is', null)
          .not('resolution_note', 'is', null);

      // Filter ตาม taskId (ถ้ามี) - หา task แบบเดียวกัน
      if (taskId != null) {
        query = query.eq('task_id', taskId);
      }
      // หรือ filter ตาม residentId + taskType (ถ้ามี)
      else if (residentId != null && taskType != null) {
        query = query.eq('resident_id', residentId).eq('taskType', taskType);
      }
      // หรือ filter ตาม nursinghomeId (fallback)
      else if (nursinghomeId > 0) {
        query = query.eq('nursinghome_id', nursinghomeId);
      }

      // order และ limit หลัง filter เสร็จ
      final response = await query
          .order('resolved_at', ascending: false)
          .limit(limit);

      final tasks =
          (response as List).map((json) => TaskLog.fromJson(json)).toList();

      debugPrint(
          'getResolutionHistory: found ${tasks.length} resolution records');
      return tasks;
    } catch (e) {
      debugPrint('getResolutionHistory error: $e');
      return [];
    }
  }

  /// ดึง task เดี่ยวจาก logId (สำหรับ realtime update)
  Future<TaskLog?> getTaskByLogId(int logId) async {
    try {
      final response = await _supabase
          .from('v2_task_logs_with_details')
          .select()
          .eq('log_id', logId)
          .maybeSingle();

      if (response == null) {
        debugPrint('getTaskByLogId: task $logId not found');
        return null;
      }

      return TaskLog.fromJson(response);
    } catch (e) {
      debugPrint('getTaskByLogId error: $e');
      return null;
    }
  }

  /// ดึง task เดี่ยวจาก C_Tasks.id (สำหรับ one-time task notification)
  /// Step 1: หา log_id จาก A_Task_logs_ver2 ที่มี c_task_id ตรงกัน
  /// Step 2: ใช้ log_id ไป fetch จาก v2_task_logs_with_details (view ไม่มี c_task_id column)
  Future<TaskLog?> getTaskByCTaskId(int cTaskId) async {
    try {
      // หา log_id จาก A_Task_logs_ver2 ที่ผูกกับ C_Tasks นี้
      final logRow = await _supabase
          .from('A_Task_logs_ver2')
          .select('id')
          .eq('c_task_id', cTaskId)
          .maybeSingle();

      if (logRow == null) {
        debugPrint('getTaskByCTaskId: no log found for c_task_id $cTaskId');
        return null;
      }

      // ใช้ log_id ไป fetch จาก view ที่มีข้อมูลครบ
      return getTaskByLogId(logRow['id'] as int);
    } catch (e) {
      debugPrint('getTaskByCTaskId error: $e');
      return null;
    }
  }

  /// ดึงข้อมูล user พื้นฐาน (nickname, photo_url) จาก user_info
  /// ใช้สำหรับ enrich ข้อมูลที่ view ส่งมาเป็น NULL dummy
  /// เช่น sample image creator ที่มีแค่ UUID แต่ไม่มีชื่อ+รูป
  Future<Map<String, String?>?> getUserBasicInfo(String userId) async {
    try {
      final response = await _supabase
          .from('user_info')
          .select('nickname, photo_url')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      return {
        'nickname': response['nickname'] as String?,
        'photo_url': response['photo_url'] as String?,
      };
    } catch (e) {
      debugPrint('getUserBasicInfo error: $e');
      return null;
    }
  }

  /// เลื่อนงานไปวันพรุ่งนี้
  /// 1. Update log เดิม: status='postpone', completed_by, completed_at
  /// 2. Insert log ใหม่: postpone_from=logId, expectedDateTime+1day
  /// 3. Update log เดิม: postpone_to=newLogId
  Future<bool> postponeTask(int logId, String userId, TaskLog task) async {
    try {
      final now = DateTime.now();

      // 1. Update original log
      await _supabase.from('A_Task_logs_ver2').update({
        'status': 'postpone',
        'completed_by': userId,
        'completed_at': now.toIso8601String(),
      }).eq('id', logId);

      // 2. Insert new log for tomorrow
      final tomorrow = task.expectedDateTime != null
          ? task.expectedDateTime!.add(const Duration(days: 1))
          : now.add(const Duration(days: 1));

      final insertResponse = await _supabase
          .from('A_Task_logs_ver2')
          .insert({
            'task_id': task.taskId,
            'postpone_from': logId,
            'created_at': now.toIso8601String(),
            'ExpectedDateTime': tomorrow.toIso8601String(),
          })
          .select('id')
          .single();

      final newLogId = insertResponse['id'] as int;

      // 3. Update original with postpone_to
      await _supabase.from('A_Task_logs_ver2').update({
        'postpone_to': newLogId,
      }).eq('id', logId);

      invalidateCache();
      debugPrint('postponeTask: log $logId postponed to $newLogId');
      return true;
    } catch (e) {
      debugPrint('postponeTask error: $e');
      return false;
    }
  }

  /// ยกเลิก postpone (ลบ log ที่ถูกเลื่อน และ reset log เดิม)
  Future<bool> cancelPostpone(int originalLogId, int postponedLogId) async {
    try {
      // 1. Delete the postponed log
      await _supabase.from('A_Task_logs_ver2').delete().eq('id', postponedLogId);

      // 2. Reset original log - clear ทุก field ที่เกี่ยวข้องกับ completion/status
      await _supabase.from('A_Task_logs_ver2').update({
        'status': null,
        'completed_by': null,
        'completed_at': null,
        'postpone_to': null,
        'problem_type': null,
        'Descript': null,
        'confirmImage': null,
        'difficulty_score': null,
        'difficulty_rated_by': null,
      }).eq('id', originalLogId);

      invalidateCache();
      debugPrint('cancelPostpone: cancelled postpone from $originalLogId to $postponedLogId');
      return true;
    } catch (e) {
      debugPrint('cancelPostpone error: $e');
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
