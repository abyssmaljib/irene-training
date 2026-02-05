import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../../points/services/points_service.dart';
import '../models/badge.dart';
import '../models/quiz_session.dart';

/// Model สำหรับเก็บ stats ของ staff ในเวร
/// ใช้สำหรับเปรียบเทียบและหา winners ของ shift badges
class _ShiftStaffStats {
  final String staffId;
  final String staffName;
  final int problemCount;          // จำนวนงานที่ติ๊กปัญหา
  final int completedCount;        // จำนวนงานที่เสร็จ
  final int kindnessCount;         // จำนวนงานที่ช่วยคนอื่น
  final double avgTimingDiff;      // ค่าเบี่ยงเบนเวลาเฉลี่ย (นาที)
  final int deadAirMinutes;        // เวลา dead air (นาที)
  final int noviceScore;           // SUM(user_diff - norm) ที่เป็นบวก
  final int masterScore;           // SUM(norm - user_diff) ที่เป็นบวก
  final DateTime? lastTaskTime;    // เวลา task สุดท้าย (สำหรับ tie breaker)

  const _ShiftStaffStats({
    required this.staffId,
    required this.staffName,
    this.problemCount = 0,
    this.completedCount = 0,
    this.kindnessCount = 0,
    this.avgTimingDiff = double.infinity,
    this.deadAirMinutes = 0,
    this.noviceScore = 0,
    this.masterScore = 0,
    this.lastTaskTime,
  });
}

/// Service สำหรับจัดการ Badge (ตรวจสอบและแจก badge)
class BadgeService {
  final SupabaseClient _client;

  BadgeService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// ตรวจสอบและแจก badge หลังทำ quiz เสร็จ
  /// คืนค่า list ของ Badge ที่ได้รับใหม่
  Future<List<Badge>> checkAndAwardBadges({
    required String sessionId,
  }) async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) {
        debugPrint('BadgeService: No user logged in');
        return [];
      }

      // ดึงข้อมูล session
      final sessionData = await _client
          .from('training_quiz_sessions')
          .select()
          .eq('id', sessionId)
          .single();

      final session = QuizSession.fromJson(sessionData);

      // ดึง badge ที่ user มีอยู่แล้วใน season นี้
      final existingBadges = await _client
          .from('training_user_badges')
          .select('badge_id')
          .eq('user_id', userId)
          .or('season_id.eq.${session.seasonId},season_id.is.null');

      final existingBadgeIds =
          (existingBadges as List).map((e) => e['badge_id'] as String).toSet();

      debugPrint('BadgeService: Existing badges: ${existingBadgeIds.length}');

      // ดึง badge ทั้งหมดที่ active
      final allBadges = await _client
          .from('training_badges')
          .select()
          .eq('is_active', true);

      final newBadges = <Badge>[];

      for (final badgeData in allBadges as List) {
        final badgeId = badgeData['id'] as String;

        // ข้ามถ้ามีแล้ว
        if (existingBadgeIds.contains(badgeId)) {
          continue;
        }

        final requirementType = badgeData['requirement_type'] as String;
        final requirementValue =
            badgeData['requirement_value'] as Map<String, dynamic>? ?? {};

        final shouldAward = await _checkBadgeCondition(
          requirementType: requirementType,
          requirementValue: requirementValue,
          session: session,
          userId: userId,
        );

        if (shouldAward) {
          // บันทึก badge ใหม่
          try {
            await _client.from('training_user_badges').insert({
              'user_id': userId,
              'badge_id': badgeId,
              'season_id': session.seasonId,
            });

            newBadges.add(Badge.fromBadgeTable(badgeData));
            debugPrint('BadgeService: Awarded badge: ${badgeData['name']}');

            // บันทึก points สำหรับ badge ที่ได้รับ
            final badgePoints = badgeData['points'] as int? ?? 10;
            final badgeName = badgeData['name'] as String? ?? 'Badge';
            await PointsService().recordBadgeEarned(
              userId: userId,
              badgeId: badgeId,
              badgePoints: badgePoints,
              badgeName: badgeName,
              seasonId: session.seasonId,
            );
            debugPrint('BadgeService: Recorded $badgePoints points for badge');
          } catch (e) {
            // อาจ conflict ถ้ามีอยู่แล้ว
            debugPrint('BadgeService: Failed to award badge: $e');
          }
        }
      }

      debugPrint('BadgeService: Total new badges: ${newBadges.length}');
      return newBadges;
    } catch (e) {
      debugPrint('BadgeService: Error checking badges: $e');
      return [];
    }
  }

  /// ตรวจสอบเงื่อนไขของ badge แต่ละประเภท
  Future<bool> _checkBadgeCondition({
    required String requirementType,
    required Map<String, dynamic> requirementValue,
    required QuizSession session,
    required String userId,
  }) async {
    switch (requirementType) {
      case 'perfect_score':
        // ได้คะแนนเต็ม
        return session.score == session.totalQuestions;

      case 'high_score_count':
        // ทำคะแนนสูงหลายครั้ง
        final minScore = requirementValue['min_score'] as int? ?? 8;
        final requiredCount = requirementValue['count'] as int? ?? 3;

        final count = await _client
            .from('training_quiz_sessions')
            .select('id')
            .eq('user_id', userId)
            .eq('season_id', session.seasonId)
            .gte('score', minScore)
            .not('completed_at', 'is', null);

        return (count as List).length >= requiredCount;

      case 'first_try':
        // ผ่านครั้งแรก
        return session.quizType == 'posttest' &&
            session.attemptNumber == 1 &&
            session.passed;

      case 'first_try_count':
        // ผ่านครั้งแรกหลายหัวข้อ
        final requiredCount = requirementValue['count'] as int? ?? 5;

        final result = await _client
            .from('training_quiz_sessions')
            .select('topic_id')
            .eq('user_id', userId)
            .eq('season_id', session.seasonId)
            .eq('quiz_type', 'posttest')
            .eq('attempt_number', 1)
            .eq('is_passed', true);

        final uniqueTopics =
            (result as List).map((e) => e['topic_id']).toSet();
        return uniqueTopics.length >= requiredCount;

      case 'improvement':
        // พัฒนาขึ้นจาก pretest
        final percentImprovement = requirementValue['percent'] as int? ?? 50;

        final progress = await _client
            .from('training_user_progress')
            .select('pretest_score, posttest_score')
            .eq('user_id', userId)
            .eq('season_id', session.seasonId)
            .gt('pretest_score', 0)
            .not('posttest_score', 'is', null);

        for (final p in progress as List) {
          final pretest = p['pretest_score'] as int;
          final posttest = p['posttest_score'] as int;
          if (posttest >= pretest * (1 + percentImprovement / 100)) {
            return true;
          }
        }
        return false;

      case 'streak':
        // ทำ quiz ติดต่อกันหลายวัน
        final requiredDays = requirementValue['days'] as int? ?? 7;

        final streak = await _client
            .from('training_streaks')
            .select('current_streak')
            .eq('user_id', userId)
            .eq('season_id', session.seasonId)
            .maybeSingle();

        if (streak == null) return false;
        return (streak['current_streak'] as int? ?? 0) >= requiredDays;

      case 'topics_completed':
        // ผ่านหลายหัวข้อ
        final requiredCount = requirementValue['count'] as int? ?? 10;

        final result = await _client
            .from('training_user_progress')
            .select('topic_id')
            .eq('user_id', userId)
            .eq('season_id', session.seasonId)
            .not('posttest_completed_at', 'is', null);

        return (result as List).length >= requiredCount;

      case 'review_count':
        // ทำ review หลายครั้ง
        final requiredCount = requirementValue['count'] as int? ?? 10;

        final result = await _client
            .from('training_user_progress')
            .select('review_count')
            .eq('user_id', userId)
            .eq('season_id', session.seasonId);

        final totalReviews = (result as List)
            .fold<int>(0, (sum, p) => sum + (p['review_count'] as int? ?? 0));

        return totalReviews >= requiredCount;

      case 'speed_demon':
        // ทำเสร็จภายในเวลาที่กำหนด
        final maxSeconds = requirementValue['max_seconds'] as int? ?? 300;
        final duration = session.durationSeconds ?? 0;
        return session.passed && duration > 0 && duration <= maxSeconds;

      default:
        debugPrint('BadgeService: Unknown requirement type: $requirementType');
        return false;
    }
  }

  /// ดึง badge ทั้งหมดของ user
  Future<List<Badge>> getUserBadges({String? seasonId}) async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) {
        debugPrint('BadgeService.getUserBadges: No user');
        return [];
      }

      debugPrint('BadgeService.getUserBadges: user_id=$userId');

      // Query จาก training_user_badges join กับ training_badges
      final response = await _client
          .from('training_user_badges')
          .select('''
            id,
            user_id,
            badge_id,
            season_id,
            earned_at,
            training_badges (
              id,
              name,
              description,
              icon,
              image_url,
              category,
              points,
              rarity,
              requirement_type,
              requirement_value
            )
          ''')
          .eq('user_id', userId);

      debugPrint('BadgeService.getUserBadges: found ${(response as List).length} badges');

      return response.map((json) {
        final badgeData = json['training_badges'] as Map<String, dynamic>;
        return Badge(
          id: badgeData['id'] as String,
          name: badgeData['name'] as String,
          description: badgeData['description'] as String?,
          icon: badgeData['icon'] as String?,
          imageUrl: badgeData['image_url'] as String?,
          category: badgeData['category'] as String? ?? 'general',
          points: badgeData['points'] as int? ?? 10,
          rarity: badgeData['rarity'] as String? ?? 'common',
          requirementType: badgeData['requirement_type'] as String,
          requirementValue: badgeData['requirement_value'] as Map<String, dynamic>?,
          isEarned: true,
          earnedAt: json['earned_at'] != null
              ? DateTime.parse(json['earned_at'] as String)
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('BadgeService: Error getting user badges: $e');
      return [];
    }
  }

  /// ดึงสถิติ badge ทั้งหมด (จำนวน user ที่ได้แต่ละ badge)
  Future<BadgeStats> getBadgeStats() async {
    try {
      final currentUserId = UserService().effectiveUserId;

      // ดึง badge ทั้งหมด
      final allBadges = await _client
          .from('training_badges')
          .select()
          .eq('is_active', true)
          .order('rarity')
          .order('category')
          .order('name');

      // ดึงจำนวน user ที่ได้แต่ละ badge
      final userBadgeCounts = await _client
          .from('training_user_badges')
          .select('badge_id');

      // นับจำนวน user ต่อ badge
      final countMap = <String, int>{};
      for (final row in userBadgeCounts as List) {
        final badgeId = row['badge_id'] as String;
        countMap[badgeId] = (countMap[badgeId] ?? 0) + 1;
      }

      // ดึง badge ที่ current user ได้
      final earnedBadgeIds = <String>{};
      if (currentUserId != null) {
        final userBadges = await _client
            .from('training_user_badges')
            .select('badge_id')
            .eq('user_id', currentUserId);
        for (final row in userBadges as List) {
          earnedBadgeIds.add(row['badge_id'] as String);
        }
      }

      // ดึงจำนวน user ทั้งหมด
      final totalUsersResult = await _client
          .from('user_info')
          .select('id');
      final totalUsers = (totalUsersResult as List).length;

      // สร้าง badge info list
      final badges = <BadgeInfo>[];
      for (final badgeData in allBadges as List) {
        final badgeId = badgeData['id'] as String;
        badges.add(BadgeInfo(
          badge: Badge.fromBadgeTable(badgeData),
          earnedCount: countMap[badgeId] ?? 0,
          totalUsers: totalUsers,
          isEarnedByCurrentUser: earnedBadgeIds.contains(badgeId),
        ));
      }

      // Sort: earned first, then by rarity
      badges.sort((a, b) {
        if (a.isEarnedByCurrentUser != b.isEarnedByCurrentUser) {
          return a.isEarnedByCurrentUser ? -1 : 1;
        }
        return 0;
      });

      // Group by category (earned first in each category)
      final byCategory = <String, List<BadgeInfo>>{};
      for (final info in badges) {
        final cat = info.badge.category;
        byCategory[cat] = [...(byCategory[cat] ?? []), info];
      }
      // Sort each category: earned first
      for (final cat in byCategory.keys) {
        byCategory[cat]!.sort((a, b) {
          if (a.isEarnedByCurrentUser != b.isEarnedByCurrentUser) {
            return a.isEarnedByCurrentUser ? -1 : 1;
          }
          return 0;
        });
      }

      // Group by rarity (earned first in each rarity)
      final byRarity = <String, List<BadgeInfo>>{};
      for (final info in badges) {
        final rar = info.badge.rarity;
        byRarity[rar] = [...(byRarity[rar] ?? []), info];
      }
      // Sort each rarity: earned first
      for (final rar in byRarity.keys) {
        byRarity[rar]!.sort((a, b) {
          if (a.isEarnedByCurrentUser != b.isEarnedByCurrentUser) {
            return a.isEarnedByCurrentUser ? -1 : 1;
          }
          return 0;
        });
      }

      return BadgeStats(
        badges: badges,
        byCategory: byCategory,
        byRarity: byRarity,
        totalBadges: badges.length,
        totalUsers: totalUsers,
        earnedBadgeIds: earnedBadgeIds,
      );
    } catch (e) {
      debugPrint('BadgeService: Error getting badge stats: $e');
      return BadgeStats(
        badges: [],
        byCategory: {},
        byRarity: {},
        totalBadges: 0,
        totalUsers: 0,
      );
    }
  }

  /// ดึง badge ทั้งหมด (รวมที่ยังไม่ได้)
  Future<List<Badge>> getAllBadges({String? seasonId, String? userId}) async {
    try {
      final uid = userId ?? UserService().effectiveUserId;
      if (uid == null) return [];

      var query = _client.from('training_v_badges').select();

      if (seasonId != null) {
        query = query.or('season_id.eq.$seasonId,season_id.is.null,user_id.is.null');
      }

      final response = await query;

      // Group by badge_id และ filter เอาเฉพาะที่ match user
      final badgeMap = <String, Badge>{};
      for (final json in response as List) {
        final badgeId = json['badge_id'] as String;
        final rowUserId = json['user_id'] as String?;

        if (rowUserId == uid) {
          // User earned this badge
          badgeMap[badgeId] = Badge.fromJson(json);
        } else if (!badgeMap.containsKey(badgeId)) {
          // Badge not earned by user yet
          badgeMap[badgeId] = Badge.fromJson({
            ...json,
            'is_earned': false,
            'earned_at': null,
          });
        }
      }

      return badgeMap.values.toList();
    } catch (e) {
      debugPrint('BadgeService: Error getting all badges: $e');
      return [];
    }
  }

  // =========================================================================
  // SHIFT BADGES - ตรวจสอบและ award badges หลังลงเวร
  // Badge เหล่านี้รับซ้ำได้ทุกเวร (ไม่ check unique)
  // =========================================================================

  /// ตรวจสอบและ award shift badges หลังลงเวร
  /// เปรียบเทียบกับ staff คนอื่นในเวรเดียวกัน
  /// - shift_most_problems: ติ๊กปัญหามากที่สุด
  /// - shift_most_completed: ทำงานเสร็จเยอะที่สุด
  /// - shift_most_kindness: ช่วยคนไข้คนอื่นมากที่สุด
  /// - shift_best_timing: ค่าเบี่ยงเบนเวลาน้อยที่สุด
  /// - shift_most_dead_air: Dead air มากที่สุด
  /// - shift_novice_rating: ประเมินยากกว่า norm (threshold)
  /// - shift_master_rating: ประเมินง่ายกว่า norm (threshold)
  Future<List<Badge>> checkAndAwardShiftBadges({
    required int clockRecordId,
    required int nursinghomeId,
    required DateTime clockIn,
    required DateTime clockOut,
    required List<int> assignedResidentIds,
  }) async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) {
        debugPrint('BadgeService.checkAndAwardShiftBadges: No user');
        return [];
      }

      debugPrint('=== Checking Shift Badges ===');
      debugPrint('User: $userId, ClockRecord: $clockRecordId');
      debugPrint('ClockIn: $clockIn, ClockOut: $clockOut');

      // 1. ดึง shift badges ที่ active
      final shiftBadges = await _client
          .from('training_badges')
          .select()
          .eq('is_active', true)
          .eq('category', 'shift');

      if ((shiftBadges as List).isEmpty) {
        debugPrint('No shift badges found');
        return [];
      }

      // 2. ดึง staff ทั้งหมดที่ทำงานในเวรเดียวกัน
      final staffStats = await _getShiftStaffStats(
        nursinghomeId: nursinghomeId,
        clockIn: clockIn,
        clockOut: clockOut,
        currentUserId: userId,
        assignedResidentIds: assignedResidentIds,
      );

      if (staffStats.isEmpty) {
        debugPrint('No staff stats found');
        return [];
      }

      debugPrint('Found ${staffStats.length} staff in shift');
      for (final s in staffStats) {
        debugPrint(
            '  ${s.staffName}: completed=${s.completedCount}, problems=${s.problemCount}, '
            'kindness=${s.kindnessCount}, timing=${s.avgTimingDiff.toStringAsFixed(1)}, '
            'deadAir=${s.deadAirMinutes}, novice=${s.noviceScore}, master=${s.masterScore}');
      }

      // 3. หา current user stats
      final myStats = staffStats.firstWhere(
        (s) => s.staffId == userId,
        orElse: () => _ShiftStaffStats(staffId: userId, staffName: 'Unknown'),
      );

      // 4. ตรวจสอบและ award แต่ละ badge
      final awardedBadges = <Badge>[];

      for (final badgeData in shiftBadges) {
        final requirementType = badgeData['requirement_type'] as String;
        final requirementValue =
            badgeData['requirement_value'] as Map<String, dynamic>? ?? {};

        final shouldAward = _checkShiftBadgeCondition(
          requirementType: requirementType,
          requirementValue: requirementValue,
          myStats: myStats,
          allStats: staffStats,
        );

        if (shouldAward) {
          final badge = await _awardShiftBadge(
            userId: userId,
            badgeData: badgeData,
          );
          if (badge != null) {
            awardedBadges.add(badge);
          }
        }
      }

      debugPrint('Awarded ${awardedBadges.length} shift badges');
      return awardedBadges;
    } catch (e) {
      debugPrint('BadgeService.checkAndAwardShiftBadges error: $e');
      return [];
    }
  }

  /// ดึง stats ของ staff ทั้งหมดในเวรเดียวกัน
  Future<List<_ShiftStaffStats>> _getShiftStaffStats({
    required int nursinghomeId,
    required DateTime clockIn,
    required DateTime clockOut,
    required String currentUserId,
    required List<int> assignedResidentIds,
  }) async {
    try {
      // คำนวณ adjust_date จาก clockIn
      final localClockIn = clockIn.toLocal();
      final adjustDate = localClockIn.hour < 7
          ? DateTime(localClockIn.year, localClockIn.month, localClockIn.day - 1)
          : DateTime(localClockIn.year, localClockIn.month, localClockIn.day);
      final dateStr =
          '${adjustDate.year}-${adjustDate.month.toString().padLeft(2, '0')}-${adjustDate.day.toString().padLeft(2, '0')}';

      // ดึง staff ที่ clock in ในวันเดียวกัน
      // ตัด shift leaders (Incharge = true) ออก เพราะลักษณะงานต่างกัน
      final clockRecords = await _client
          .from('clock_record')
          .select('user_id, user_info!inner(id, nickname)')
          .eq('nursinghome_id', nursinghomeId)
          .gte('time_in', '${dateStr}T00:00:00')
          .lte('time_in', '${dateStr}T23:59:59')
          .neq('Incharge', true);

      final staffList = <String, String>{};
      for (final record in clockRecords as List) {
        final staffId = record['user_id'] as String;
        final userInfo = record['user_info'] as Map<String, dynamic>?;
        final nickname = userInfo?['nickname'] as String? ?? 'Unknown';
        staffList[staffId] = nickname;
      }

      if (staffList.isEmpty) {
        // ถ้าไม่มี staff อื่น ให้ใช้ current user
        final userInfo = await _client
            .from('user_info')
            .select('nickname')
            .eq('id', currentUserId)
            .maybeSingle();
        staffList[currentUserId] = userInfo?['nickname'] as String? ?? 'Me';
      }

      // ดึง task logs ของวันนี้
      final taskLogs = await _client
          .from('v2_task_logs_with_details')
          .select('''
            log_id, completed_by, status, problem_type, resident_id,
            log_completed_at, ExpectedDateTime,
            difficulty_score, avg_difficulty_score_30d
          ''')
          .eq('nursinghome_id', nursinghomeId)
          .eq('adjust_date', dateStr)
          .not('completed_by', 'is', null);

      // คำนวณ stats ของแต่ละ staff
      final statsMap = <String, _ShiftStaffStats>{};

      for (final staffId in staffList.keys) {
        final staffName = staffList[staffId]!;
        final staffTasks = (taskLogs as List)
            .where((t) => t['completed_by'] == staffId)
            .toList();

        // นับ problems
        final problemCount = staffTasks
            .where((t) =>
                t['status'] == 'problem' || t['problem_type'] != null)
            .length;

        // นับ completed
        final completedCount =
            staffTasks.where((t) => t['status'] == 'complete').length;

        // นับ kindness (task ที่ resident ไม่ได้ assign ให้)
        // ต้อง query assigned residents ของ staff นี้
        final kindnessCount = _countKindnessTasks(
          staffId: staffId,
          staffTasks: staffTasks,
          currentUserId: currentUserId,
          assignedResidentIds: assignedResidentIds,
        );

        // คำนวณ avg timing diff
        final timingDiff = _calculateAvgTimingDiff(staffTasks);

        // คำนวณ dead air (simplified - นับ gaps ระหว่าง tasks)
        final deadAirMinutes = _calculateDeadAirMinutes(
          staffTasks: staffTasks,
          clockIn: clockIn,
          clockOut: clockOut,
        );

        // คำนวณ novice/master scores
        final (noviceScore, masterScore) =
            _calculateDifficultyScores(staffTasks);

        // หา last task time
        DateTime? lastTaskTime;
        for (final task in staffTasks) {
          final completedAt = task['log_completed_at'] as String?;
          if (completedAt != null) {
            final dt = DateTime.tryParse(completedAt);
            if (dt != null && (lastTaskTime == null || dt.isAfter(lastTaskTime))) {
              lastTaskTime = dt;
            }
          }
        }

        statsMap[staffId] = _ShiftStaffStats(
          staffId: staffId,
          staffName: staffName,
          problemCount: problemCount,
          completedCount: completedCount,
          kindnessCount: kindnessCount,
          avgTimingDiff: timingDiff,
          deadAirMinutes: deadAirMinutes,
          noviceScore: noviceScore,
          masterScore: masterScore,
          lastTaskTime: lastTaskTime,
        );
      }

      return statsMap.values.toList();
    } catch (e) {
      debugPrint('_getShiftStaffStats error: $e');
      return [];
    }
  }

  /// นับ kindness tasks (ช่วยคนไข้ที่ไม่ได้ assign ให้)
  int _countKindnessTasks({
    required String staffId,
    required List<dynamic> staffTasks,
    required String currentUserId,
    required List<int> assignedResidentIds,
  }) {
    // สำหรับ current user ใช้ assignedResidentIds
    // สำหรับ staff อื่น ไม่มีข้อมูล assigned residents จึงไม่สามารถนับได้
    // TODO: อาจต้อง query assigned residents ของ staff อื่นด้วย
    if (staffId != currentUserId) {
      return 0; // ไม่สามารถนับ kindness ของ staff อื่นได้
    }

    return staffTasks.where((t) {
      final residentId = t['resident_id'] as int?;
      if (residentId == null) return false;
      return !assignedResidentIds.contains(residentId);
    }).length;
  }

  /// คำนวณค่าเบี่ยงเบนเวลาเฉลี่ย (นาที)
  double _calculateAvgTimingDiff(List<dynamic> tasks) {
    if (tasks.isEmpty) return double.infinity;

    int totalDiff = 0;
    int count = 0;

    for (final task in tasks) {
      final completedAtStr = task['log_completed_at'] as String?;
      final expectedStr = task['ExpectedDateTime'] as String?;

      if (completedAtStr != null && expectedStr != null) {
        final completedAt = DateTime.tryParse(completedAtStr);
        final expectedAt = DateTime.tryParse(expectedStr);

        if (completedAt != null && expectedAt != null) {
          totalDiff += completedAt.difference(expectedAt).inMinutes.abs();
          count++;
        }
      }
    }

    return count > 0 ? totalDiff / count : double.infinity;
  }

  /// คำนวณ dead air minutes (simplified)
  int _calculateDeadAirMinutes({
    required List<dynamic> staffTasks,
    required DateTime clockIn,
    required DateTime clockOut,
  }) {
    if (staffTasks.isEmpty) {
      // ถ้าไม่มี task เลย dead air = ทั้งเวร
      return clockOut.difference(clockIn).inMinutes;
    }

    // Sort by completed_at
    final sortedTasks = List<Map<String, dynamic>>.from(staffTasks)
      ..sort((a, b) {
        final aTime = a['log_completed_at'] as String? ?? '';
        final bTime = b['log_completed_at'] as String? ?? '';
        return aTime.compareTo(bTime);
      });

    int totalGapMinutes = 0;
    DateTime lastTime = clockIn;

    for (final task in sortedTasks) {
      final completedAtStr = task['log_completed_at'] as String?;
      if (completedAtStr != null) {
        final completedAt = DateTime.tryParse(completedAtStr);
        if (completedAt != null) {
          final gap = completedAt.difference(lastTime).inMinutes;
          if (gap > 0) {
            totalGapMinutes += gap;
          }
          lastTime = completedAt;
        }
      }
    }

    // Gap สุดท้ายถึง clockOut
    final lastGap = clockOut.difference(lastTime).inMinutes;
    if (lastGap > 0) {
      totalGapMinutes += lastGap;
    }

    // หัก allowance 75 นาที
    const allowance = 75;
    return (totalGapMinutes - allowance).clamp(0, 999);
  }

  /// คำนวณ novice และ master scores
  (int, int) _calculateDifficultyScores(List<dynamic> tasks) {
    int noviceScore = 0;
    int masterScore = 0;

    for (final task in tasks) {
      final userDiff = task['difficulty_score'] as int?;
      final normDiff = (task['avg_difficulty_score_30d'] as num?)?.toInt();

      if (userDiff != null && normDiff != null) {
        final diff = userDiff - normDiff;
        if (diff > 0) {
          noviceScore += diff; // ประเมินว่ายากกว่า norm
        } else if (diff < 0) {
          masterScore += diff.abs(); // ประเมินว่าง่ายกว่า norm
        }
      }
    }

    return (noviceScore, masterScore);
  }

  /// ตรวจเงื่อนไข shift badge
  bool _checkShiftBadgeCondition({
    required String requirementType,
    required Map<String, dynamic> requirementValue,
    required _ShiftStaffStats myStats,
    required List<_ShiftStaffStats> allStats,
  }) {
    switch (requirementType) {
      case 'shift_most_problems':
        // ติ๊กปัญหามากที่สุด (ต้องมีอย่างน้อย 1)
        if (myStats.problemCount == 0) return false;
        return _isWinner(
          myValue: myStats.problemCount,
          myTime: myStats.lastTaskTime,
          allStats: allStats,
          getValue: (s) => s.problemCount,
          getTime: (s) => s.lastTaskTime,
          higherIsBetter: true,
        );

      case 'shift_most_completed':
        // ทำงานเสร็จเยอะที่สุด (ต้องมีอย่างน้อย 1)
        if (myStats.completedCount == 0) return false;
        return _isWinner(
          myValue: myStats.completedCount,
          myTime: myStats.lastTaskTime,
          allStats: allStats,
          getValue: (s) => s.completedCount,
          getTime: (s) => s.lastTaskTime,
          higherIsBetter: true,
        );

      case 'shift_most_kindness':
        // ช่วยคนไข้คนอื่นมากที่สุด (ต้องมีอย่างน้อย 1)
        if (myStats.kindnessCount == 0) return false;
        return _isWinner(
          myValue: myStats.kindnessCount,
          myTime: myStats.lastTaskTime,
          allStats: allStats,
          getValue: (s) => s.kindnessCount,
          getTime: (s) => s.lastTaskTime,
          higherIsBetter: true,
        );

      case 'shift_best_timing':
        // ค่าเบี่ยงเบนเวลาต่ำสุด (ต้องมี tasks ที่มี expected time)
        if (myStats.avgTimingDiff == double.infinity) return false;
        return _isWinnerDouble(
          myValue: myStats.avgTimingDiff,
          myTime: myStats.lastTaskTime,
          allStats: allStats,
          getValue: (s) => s.avgTimingDiff,
          getTime: (s) => s.lastTaskTime,
          lowerIsBetter: true,
        );

      case 'shift_most_dead_air':
        // Dead air มากที่สุด (ต้องมี dead air > 0)
        if (myStats.deadAirMinutes == 0) return false;
        return _isWinner(
          myValue: myStats.deadAirMinutes,
          myTime: myStats.lastTaskTime,
          allStats: allStats,
          getValue: (s) => s.deadAirMinutes,
          getTime: (s) => s.lastTaskTime,
          higherIsBetter: true,
        );

      case 'shift_novice_rating':
        // ประเมินยากกว่า norm (threshold based)
        final minDiffSum = requirementValue['min_diff_sum'] as int? ?? 10;
        return myStats.noviceScore >= minDiffSum;

      case 'shift_master_rating':
        // ประเมินง่ายกว่า norm (threshold based)
        final minDiffSum = requirementValue['min_diff_sum'] as int? ?? 10;
        return myStats.masterScore >= minDiffSum;

      default:
        return false;
    }
  }

  /// ตรวจสอบว่าเป็น winner หรือไม่ (int value)
  /// Tie breaker: คนแรกที่ทำถึง (lastTaskTime เร็วกว่า)
  bool _isWinner({
    required int myValue,
    required DateTime? myTime,
    required List<_ShiftStaffStats> allStats,
    required int Function(_ShiftStaffStats) getValue,
    required DateTime? Function(_ShiftStaffStats) getTime,
    required bool higherIsBetter,
  }) {
    for (final other in allStats) {
      final otherValue = getValue(other);
      final otherTime = getTime(other);

      if (higherIsBetter) {
        if (otherValue > myValue) return false;
        if (otherValue == myValue && myValue > 0) {
          // Tie breaker: เวลาเร็วกว่าชนะ
          if (myTime == null) return false;
          if (otherTime != null && otherTime.isBefore(myTime)) return false;
        }
      } else {
        if (otherValue < myValue) return false;
        if (otherValue == myValue) {
          if (myTime == null) return false;
          if (otherTime != null && otherTime.isBefore(myTime)) return false;
        }
      }
    }
    return true;
  }

  /// ตรวจสอบว่าเป็น winner หรือไม่ (double value)
  bool _isWinnerDouble({
    required double myValue,
    required DateTime? myTime,
    required List<_ShiftStaffStats> allStats,
    required double Function(_ShiftStaffStats) getValue,
    required DateTime? Function(_ShiftStaffStats) getTime,
    required bool lowerIsBetter,
  }) {
    for (final other in allStats) {
      final otherValue = getValue(other);
      final otherTime = getTime(other);

      if (lowerIsBetter) {
        if (otherValue < myValue) return false;
        if ((otherValue - myValue).abs() < 0.01) {
          // Tie (within 0.01 difference)
          if (myTime == null) return false;
          if (otherTime != null && otherTime.isBefore(myTime)) return false;
        }
      } else {
        if (otherValue > myValue) return false;
        if ((otherValue - myValue).abs() < 0.01) {
          if (myTime == null) return false;
          if (otherTime != null && otherTime.isBefore(myTime)) return false;
        }
      }
    }
    return true;
  }

  /// Award shift badge (ไม่ check unique - รับซ้ำได้)
  Future<Badge?> _awardShiftBadge({
    required String userId,
    required Map<String, dynamic> badgeData,
  }) async {
    try {
      final badgeId = badgeData['id'] as String;
      final badgeName = badgeData['name'] as String? ?? 'Badge';
      final badgePoints = badgeData['points'] as int? ?? 0;

      // Insert badge (ไม่ check existing - รับซ้ำได้)
      await _client.from('training_user_badges').insert({
        'user_id': userId,
        'badge_id': badgeId,
        'season_id': null, // Shift badges ไม่เกี่ยวกับ season
      });

      debugPrint('Awarded shift badge: $badgeName');

      // บันทึก points (ถ้ามี)
      if (badgePoints > 0) {
        await PointsService().recordBadgeEarned(
          userId: userId,
          badgeId: badgeId,
          badgePoints: badgePoints,
          badgeName: badgeName,
        );
        debugPrint('Recorded $badgePoints points for badge');
      }

      return Badge.fromBadgeTable(badgeData);
    } catch (e) {
      debugPrint('_awardShiftBadge error: $e');
      return null;
    }
  }

  /// มอบ badge "The Perfect Starter" สำหรับ user ที่กรอกข้อมูลครบตั้งแต่ onboarding
  /// คืนค่า Badge ที่ได้รับ หรือ null ถ้าไม่ได้รับ (เช่น มีอยู่แล้ว)
  Future<Badge?> awardPerfectStarterBadge() async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) {
        debugPrint('BadgeService.awardPerfectStarterBadge: No user logged in');
        return null;
      }

      // ค้นหา badge "The Perfect Starter" จาก requirement_type
      final badgeData = await _client
          .from('training_badges')
          .select()
          .eq('requirement_type', 'profile_complete_onboarding')
          .eq('is_active', true)
          .maybeSingle();

      if (badgeData == null) {
        debugPrint('BadgeService: Perfect Starter badge not found');
        return null;
      }

      final badgeId = badgeData['id'] as String;

      // ตรวจสอบว่ามี badge นี้อยู่แล้วหรือยัง
      final existing = await _client
          .from('training_user_badges')
          .select('id')
          .eq('user_id', userId)
          .eq('badge_id', badgeId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('BadgeService: User already has Perfect Starter badge');
        return null;
      }

      // มอบ badge (ไม่ต้องใส่ season_id เพราะไม่เกี่ยวกับ training season)
      await _client.from('training_user_badges').insert({
        'user_id': userId,
        'badge_id': badgeId,
        'season_id': null,
      });

      debugPrint('BadgeService: Awarded Perfect Starter badge to $userId');
      return Badge.fromBadgeTable(badgeData);
    } catch (e) {
      debugPrint('BadgeService: Error awarding Perfect Starter badge: $e');
      return null;
    }
  }
}
