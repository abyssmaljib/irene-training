import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../models/shift_activity_item.dart';
import '../models/shift_activity_stats.dart';
import '../models/break_time_option.dart';
import '../models/time_block_progress.dart';
import '../models/time_block_task.dart';

/// Model สำหรับ Dashboard Stats
class DashboardStats {
  final int totalTasks;
  final int completedTasks;
  final double learningProgress;
  final int topicsCompleted;
  final int totalTopics;
  final int topicsNotTested;

  DashboardStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.learningProgress,
    required this.topicsCompleted,
    required this.totalTopics,
    required this.topicsNotTested,
  });

  double get taskProgress =>
      totalTasks > 0 ? completedTasks / totalTasks : 0.0;
}

/// Model สำหรับข่าวล่าสุด
class RecentNews {
  final int id;
  final String title;
  final String? residentName;
  final DateTime createdAt;
  final String? tab;

  RecentNews({
    required this.id,
    required this.title,
    this.residentName,
    required this.createdAt,
    this.tab,
  });

  factory RecentNews.fromJson(Map<String, dynamic> json) {
    return RecentNews(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      residentName: json['resident_name'] as String?,
      createdAt: DateTime.parse(json['post_created_at'] as String),
      tab: json['tab'] as String?,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} นาทีที่แล้ว';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} ชั่วโมงที่แล้ว';
    } else {
      return '${diff.inDays} วันที่แล้ว';
    }
  }
}

/// Service สำหรับดึงข้อมูล Dashboard ที่หน้า Home
class HomeService {
  static final instance = HomeService._();
  HomeService._();

  final _supabase = Supabase.instance.client;
  final _userService = UserService();

  // Cache
  DashboardStats? _cachedStats;
  DateTime? _statsCacheTime;
  String? _cachedUserId; // Track user ID for cache validation
  static const _cacheMaxAge = Duration(minutes: 2);

  bool _isCacheValid() {
    if (_cachedStats == null || _statsCacheTime == null) return false;
    // Also check if user changed
    if (_cachedUserId != _userService.effectiveUserId) return false;
    return DateTime.now().difference(_statsCacheTime!) < _cacheMaxAge;
  }

  void invalidateCache() {
    _cachedStats = null;
    _statsCacheTime = null;
    _cachedUserId = null;
  }

  /// ดึง Task Progress ของวันนี้
  /// นับจาก v2_task_logs_with_details
  Future<({int total, int completed})> getTodayTaskProgress() async {
    try {
      final nursinghomeId = await _userService.getNursinghomeId();
      if (nursinghomeId == null) return (total: 0, completed: 0);

      // วันทำงาน: 07:00 - 06:59 วันถัดไป
      final now = DateTime.now();
      final adjustDate = now.hour < 7
          ? DateTime(now.year, now.month, now.day - 1)
          : DateTime(now.year, now.month, now.day);
      final dateStr =
          '${adjustDate.year}-${adjustDate.month.toString().padLeft(2, '0')}-${adjustDate.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('v2_task_logs_with_details')
          .select('log_id, status')
          .eq('nursinghome_id', nursinghomeId)
          .eq('adjust_date', dateStr)
          .not('timeBlock', 'is', null);

      final tasks = response as List;
      final total = tasks.length;
      final completed = tasks
          .where((t) =>
              t['status'] == 'complete' ||
              t['status'] == 'refer' ||
              t['status'] == 'postpone')
          .length;

      debugPrint('getTodayTaskProgress: $completed/$total tasks');
      return (total: total, completed: completed);
    } catch (e) {
      debugPrint('getTodayTaskProgress error: $e');
      return (total: 0, completed: 0);
    }
  }

  /// ดึงจำนวนงานที่ยังไม่เสร็จ (completed_by is null) สำหรับ shift นี้
  /// [clockInTime] - เวลาที่ clock in (ใช้คำนวณ adjust_date)
  Future<int> getRemainingTasksCount({
    required String shift,
    DateTime? clockInTime,
  }) async {
    try {
      final nursinghomeId = await _userService.getNursinghomeId();
      if (nursinghomeId == null) return 0;

      // วันทำงาน: 07:00 - 06:59 วันถัดไป
      // ใช้เวลา clock in ถ้ามี ไม่งั้นใช้เวลาปัจจุบัน
      final referenceTime = clockInTime?.toLocal() ?? DateTime.now();
      final adjustDate = referenceTime.hour < 7
          ? DateTime(referenceTime.year, referenceTime.month, referenceTime.day - 1)
          : DateTime(referenceTime.year, referenceTime.month, referenceTime.day);
      final dateStr =
          '${adjustDate.year}-${adjustDate.month.toString().padLeft(2, '0')}-${adjustDate.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('v2_task_logs_with_details')
          .select('log_id')
          .eq('nursinghome_id', nursinghomeId)
          .eq('adjust_date', dateStr)
          .eq('shift_response', shift)
          .isFilter('completed_by', null)
          .neq('s_special_status', 'Refer')
          .neq('s_special_status', 'Home');

      return (response as List).length;
    } catch (e) {
      debugPrint('getRemainingTasksCount error: $e');
      return 0;
    }
  }

  /// ดึงข้อมูล jobs ที่ยังไม่เสร็จ (completed_by is null)
  /// [clockInTime] - เวลาที่ clock in (ใช้คำนวณ adjust_date)
  Future<List<Map<String, dynamic>>> getRemainingTasks({
    required String shift,
    DateTime? clockInTime,
    int limit = 5,
  }) async {
    try {
      final nursinghomeId = await _userService.getNursinghomeId();
      if (nursinghomeId == null) return [];

      // วันทำงาน: 07:00 - 06:59 วันถัดไป
      // ใช้เวลา clock in ถ้ามี ไม่งั้นใช้เวลาปัจจุบัน
      final referenceTime = clockInTime?.toLocal() ?? DateTime.now();
      final adjustDate = referenceTime.hour < 7
          ? DateTime(referenceTime.year, referenceTime.month, referenceTime.day - 1)
          : DateTime(referenceTime.year, referenceTime.month, referenceTime.day);
      final dateStr =
          '${adjustDate.year}-${adjustDate.month.toString().padLeft(2, '0')}-${adjustDate.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('v2_task_logs_with_details')
          .select('log_id, task_title, resident_name, timeBlock, status')
          .eq('nursinghome_id', nursinghomeId)
          .eq('adjust_date', dateStr)
          .eq('shift_response', shift)
          .isFilter('completed_by', null)
          .neq('s_special_status', 'Refer')
          .neq('s_special_status', 'Home')
          .order('timeBlock', ascending: true)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('getRemainingTasks error: $e');
      return [];
    }
  }

  /// ดึง Task Progress ของวันนี้ filter ตาม residents ที่ user เลือกตอน clock in
  Future<({int total, int completed})> getMyShiftTaskProgress({
    required List<int> residentIds,
  }) async {
    try {
      if (residentIds.isEmpty) return (total: 0, completed: 0);

      final nursinghomeId = await _userService.getNursinghomeId();
      if (nursinghomeId == null) return (total: 0, completed: 0);

      // วันทำงาน: 07:00 - 06:59 วันถัดไป
      final now = DateTime.now();
      final adjustDate = now.hour < 7
          ? DateTime(now.year, now.month, now.day - 1)
          : DateTime(now.year, now.month, now.day);
      final dateStr =
          '${adjustDate.year}-${adjustDate.month.toString().padLeft(2, '0')}-${adjustDate.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('v2_task_logs_with_details')
          .select('log_id, status, resident_id')
          .eq('nursinghome_id', nursinghomeId)
          .eq('adjust_date', dateStr)
          .not('timeBlock', 'is', null)
          .inFilter('resident_id', residentIds);

      final tasks = response as List;
      final total = tasks.length;
      final completed = tasks
          .where((t) =>
              t['status'] == 'complete' ||
              t['status'] == 'refer' ||
              t['status'] == 'postpone')
          .length;

      debugPrint('getMyShiftTaskProgress: $completed/$total tasks for ${residentIds.length} residents');
      return (total: total, completed: completed);
    } catch (e) {
      debugPrint('getMyShiftTaskProgress error: $e');
      return (total: 0, completed: 0);
    }
  }

  /// ดึง Learning Progress จาก training_user_progress
  /// - นับจำนวน topics ที่ผู้ใช้สอบผ่านแล้ว (posttest_completed_at != null)
  /// - นับจำนวน topics ทั้งหมด
  Future<({int completed, int total, int notTested})>
      getLearningProgress() async {
    try {
      final userId = _userService.effectiveUserId;
      if (userId == null) return (completed: 0, total: 0, notTested: 0);

      // ดึง topics ทั้งหมดที่ active
      final topicsResponse = await _supabase
          .from('training_topics')
          .select('id')
          .eq('is_active', true);
      final totalTopics = (topicsResponse as List).length;

      // ดึง active season
      final seasonResponse = await _supabase
          .from('training_seasons')
          .select('id')
          .eq('is_active', true)
          .maybeSingle();

      if (seasonResponse == null) {
        return (completed: 0, total: totalTopics, notTested: totalTopics);
      }
      final seasonId = seasonResponse['id'];

      // ดึง progress ของ user
      final progressResponse = await _supabase
          .from('training_user_progress')
          .select('topic_id, posttest_completed_at, content_read_at')
          .eq('user_id', userId)
          .eq('season_id', seasonId);

      final progress = progressResponse as List;
      final completed =
          progress.where((p) => p['posttest_completed_at'] != null).length;

      // topics ที่ยังไม่สอบ = อ่านแล้วแต่ยังไม่สอบ
      final readButNotTested = progress
          .where((p) =>
              p['content_read_at'] != null &&
              p['posttest_completed_at'] == null)
          .length;

      debugPrint(
          'getLearningProgress: $completed/$totalTopics completed, $readButNotTested not tested');
      return (
        completed: completed,
        total: totalTopics,
        notTested: readButNotTested
      );
    } catch (e) {
      debugPrint('getLearningProgress error: $e');
      return (completed: 0, total: 0, notTested: 0);
    }
  }

  /// ดึงข่าวล่าสุด (posts) จาก postwithuserinfo
  Future<List<RecentNews>> getRecentNews({int limit = 3}) async {
    try {
      final nursinghomeId = await _userService.getNursinghomeId();
      if (nursinghomeId == null) {
        debugPrint('getRecentNews: nursinghomeId is null');
        return [];
      }

      debugPrint('getRecentNews: fetching for nursinghomeId=$nursinghomeId');
      final response = await _supabase
          .from('postwithuserinfo')
          .select('id, title, resident_name, post_created_at, tab')
          .eq('nursinghome_id', nursinghomeId)
          .order('post_created_at', ascending: false)
          .limit(limit);

      debugPrint('getRecentNews: got ${(response as List).length} posts');
      return response.map((json) => RecentNews.fromJson(json)).toList();
    } catch (e) {
      debugPrint('getRecentNews error: $e');
      return [];
    }
  }

  /// ดึงข้อมูล Dashboard ทั้งหมด
  Future<DashboardStats> getDashboardStats({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid()) {
      return _cachedStats!;
    }

    final taskProgress = await getTodayTaskProgress();
    final learningProgress = await getLearningProgress();

    final stats = DashboardStats(
      totalTasks: taskProgress.total,
      completedTasks: taskProgress.completed,
      learningProgress: learningProgress.total > 0
          ? learningProgress.completed / learningProgress.total
          : 0.0,
      topicsCompleted: learningProgress.completed,
      totalTopics: learningProgress.total,
      topicsNotTested: learningProgress.notTested,
    );

    _cachedStats = stats;
    _statsCacheTime = DateTime.now();
    _cachedUserId = _userService.effectiveUserId;

    return stats;
  }

  /// ดึง activity logs ที่ user ทำเสร็จในเวรนี้
  /// - Filter ตาม completed_by = current user
  /// - Filter ตาม adjust_date = วันทำงานวันนี้
  /// - Filter ตาม resident IDs ที่เลือกตอน clock in
  /// - เรียงตาม completed_at ASC (เก่าไปใหม่)
  Future<List<ShiftActivityItem>> getShiftActivities({
    required List<int> residentIds,
    int? limit,
  }) async {
    try {
      final userId = _userService.effectiveUserId;
      if (userId == null) return [];
      if (residentIds.isEmpty) return [];

      final nursinghomeId = await _userService.getNursinghomeId();
      if (nursinghomeId == null) return [];

      // วันทำงาน: 07:00 - 06:59 วันถัดไป
      final now = DateTime.now();
      final adjustDate = now.hour < 7
          ? DateTime(now.year, now.month, now.day - 1)
          : DateTime(now.year, now.month, now.day);
      final dateStr =
          '${adjustDate.year}-${adjustDate.month.toString().padLeft(2, '0')}-${adjustDate.day.toString().padLeft(2, '0')}';

      var query = _supabase
          .from('v2_task_logs_with_details')
          .select(
              'log_id, task_title, resident_name, resident_id, log_completed_at, ExpectedDateTime')
          .eq('nursinghome_id', nursinghomeId)
          .eq('adjust_date', dateStr)
          .eq('completed_by', userId)
          .eq('status', 'complete') // เฉพาะงานที่ complete
          .not('log_completed_at', 'is', null)
          .order('log_completed_at', ascending: true); // เก่าไปใหม่
      // ไม่ filter resident_id เพื่อให้เห็นงาน "น้ำใจ" ที่ช่วยคนอื่นด้วย

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      return (response as List)
          .map((json) => ShiftActivityItem.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getShiftActivities error: $e');
      return [];
    }
  }

  /// ดึง recent activity logs (ล่าสุดก่อน)
  Future<List<ShiftActivityItem>> getRecentShiftActivities({
    required List<int> residentIds,
    int limit = 3,
  }) async {
    try {
      final userId = _userService.effectiveUserId;
      if (userId == null) return [];
      if (residentIds.isEmpty) return [];

      final nursinghomeId = await _userService.getNursinghomeId();
      if (nursinghomeId == null) return [];

      // วันทำงาน: 07:00 - 06:59 วันถัดไป
      final now = DateTime.now();
      final adjustDate = now.hour < 7
          ? DateTime(now.year, now.month, now.day - 1)
          : DateTime(now.year, now.month, now.day);
      final dateStr =
          '${adjustDate.year}-${adjustDate.month.toString().padLeft(2, '0')}-${adjustDate.day.toString().padLeft(2, '0')}';

      // ไม่ filter resident_id เพื่อให้เห็นงาน "น้ำใจ" ที่ช่วยคนอื่นด้วย
      final response = await _supabase
          .from('v2_task_logs_with_details')
          .select(
              'log_id, task_title, resident_name, resident_id, log_completed_at, ExpectedDateTime')
          .eq('nursinghome_id', nursinghomeId)
          .eq('adjust_date', dateStr)
          .eq('completed_by', userId)
          .eq('status', 'complete')
          .not('log_completed_at', 'is', null)
          .order('log_completed_at', ascending: false) // ใหม่ก่อน
          .limit(limit);

      return (response as List)
          .map((json) => ShiftActivityItem.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getRecentShiftActivities error: $e');
      return [];
    }
  }

  /// ดึง stats ความตรงเวลาของ user ในเวรนี้
  Future<ShiftActivityStats> getShiftActivityStats({
    required List<int> residentIds,
    required DateTime clockInTime,
    required List<BreakTimeOption> selectedBreakTimes,
  }) async {
    try {
      if (residentIds.isEmpty) return ShiftActivityStats.empty();

      // ดึง activities ทั้งหมด
      final activities = await getShiftActivities(residentIds: residentIds);

      // ดึง total tasks สำหรับ residents เหล่านี้
      final taskProgress = await getMyShiftTaskProgress(residentIds: residentIds);

      return ShiftActivityStats.fromActivities(
        activities: activities,
        totalTasks: taskProgress.total,
        teamTotalCompleted: taskProgress.completed,
        clockInTime: clockInTime,
        selectedBreakTimes: selectedBreakTimes,
        myResidentIds: residentIds,
      );
    } catch (e) {
      debugPrint('getShiftActivityStats error: $e');
      return ShiftActivityStats.empty();
    }
  }

  /// ดึง progress แยกตาม time block สำหรับงานที่ user ทำ
  Future<List<TimeBlockProgress>> getTimeBlockProgress({
    required List<int> residentIds,
  }) async {
    try {
      if (residentIds.isEmpty) return [];

      final nursinghomeId = await _userService.getNursinghomeId();
      if (nursinghomeId == null) return [];

      final userId = _userService.effectiveUserId;
      if (userId == null) return [];

      // วันทำงาน: 07:00 - 06:59 วันถัดไป
      final now = DateTime.now();
      final adjustDate = now.hour < 7
          ? DateTime(now.year, now.month, now.day - 1)
          : DateTime(now.year, now.month, now.day);
      final dateStr =
          '${adjustDate.year}-${adjustDate.month.toString().padLeft(2, '0')}-${adjustDate.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('v2_task_logs_with_details')
          .select('log_id, status, timeBlock, log_completed_at, ExpectedDateTime')
          .eq('nursinghome_id', nursinghomeId)
          .eq('adjust_date', dateStr)
          .eq('completed_by', userId)
          .not('timeBlock', 'is', null);

      final tasks = response as List;

      // Group by timeBlock with timeliness
      final Map<String, ({int total, int completed, int onTime, int slightlyLate, int veryLate})> grouped = {};

      for (final task in tasks) {
        final timeBlock = task['timeBlock'] as String?;
        if (timeBlock == null) continue;

        final current = grouped[timeBlock] ?? (total: 0, completed: 0, onTime: 0, slightlyLate: 0, veryLate: 0);
        final status = task['status'] as String?;
        final isCompleted = status == 'complete' ||
            status == 'refer' ||
            status == 'postpone';

        // Calculate timeliness
        int onTime = current.onTime;
        int slightlyLate = current.slightlyLate;
        int veryLate = current.veryLate;

        if (isCompleted) {
          final completedAtStr = task['log_completed_at'] as String?;
          final expectedStr = task['ExpectedDateTime'] as String?;

          if (completedAtStr != null && expectedStr != null) {
            final completedAt = DateTime.tryParse(completedAtStr);
            final expectedAt = DateTime.tryParse(expectedStr);

            if (completedAt != null && expectedAt != null) {
              final diffMinutes = completedAt.difference(expectedAt).inMinutes.abs();
              if (diffMinutes <= 30) {
                onTime++;
              } else if (diffMinutes <= 60) {
                slightlyLate++;
              } else {
                veryLate++;
              }
            } else {
              onTime++; // Default to onTime if can't calculate
            }
          } else {
            onTime++; // Default to onTime if no expected time
          }
        }

        grouped[timeBlock] = (
          total: current.total + 1,
          completed: current.completed + (isCompleted ? 1 : 0),
          onTime: onTime,
          slightlyLate: slightlyLate,
          veryLate: veryLate,
        );
      }

      // Sort time blocks chronologically
      final sortedKeys = grouped.keys.toList()
        ..sort((a, b) => _timeBlockOrder(a).compareTo(_timeBlockOrder(b)));

      return sortedKeys
          .map((key) => TimeBlockProgress.fromDataWithTimeliness(
                timeBlock: key,
                total: grouped[key]!.total,
                completed: grouped[key]!.completed,
                onTime: grouped[key]!.onTime,
                slightlyLate: grouped[key]!.slightlyLate,
                veryLate: grouped[key]!.veryLate,
              ))
          .toList();
    } catch (e) {
      debugPrint('getTimeBlockProgress error: $e');
      return [];
    }
  }

  /// Helper เพื่อเรียง time blocks ตามลำดับเวลา
  int _timeBlockOrder(String timeBlock) {
    // Extract start hour from time block like "07:00-09:00"
    final parts = timeBlock.split('-');
    if (parts.isEmpty) return 99;

    final startTime = parts[0].trim();
    final hourParts = startTime.split(':');
    if (hourParts.isEmpty) return 99;

    final hour = int.tryParse(hourParts[0]) ?? 99;

    // Adjust for overnight shifts (hours before 7am come after hours >= 7am)
    if (hour < 7) {
      return hour + 24; // 01:00 becomes 25, 03:00 becomes 27, etc.
    }
    return hour;
  }

  /// ดึงรายละเอียด tasks ตาม time block (เฉพาะงานที่ user ทำ)
  Future<List<TimeBlockTask>> getTasksByTimeBlock({
    required List<int> residentIds,
    required String timeBlock,
  }) async {
    try {
      final nursinghomeId = await _userService.getNursinghomeId();
      if (nursinghomeId == null) return [];

      final userId = _userService.effectiveUserId;
      if (userId == null) return [];

      // วันทำงาน: 07:00 - 06:59 วันถัดไป
      final now = DateTime.now();
      final adjustDate = now.hour < 7
          ? DateTime(now.year, now.month, now.day - 1)
          : DateTime(now.year, now.month, now.day);
      final dateStr =
          '${adjustDate.year}-${adjustDate.month.toString().padLeft(2, '0')}-${adjustDate.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('v2_task_logs_with_details')
          .select(
              'log_id, task_title, resident_name, status, log_completed_at, ExpectedDateTime')
          .eq('nursinghome_id', nursinghomeId)
          .eq('adjust_date', dateStr)
          .eq('timeBlock', timeBlock)
          .eq('completed_by', userId)
          .order('log_completed_at', ascending: true);

      return (response as List)
          .map((json) => TimeBlockTask.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('getTasksByTimeBlock error: $e');
      return [];
    }
  }
}
