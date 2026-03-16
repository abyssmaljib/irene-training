import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../../points/services/points_service.dart';
import '../models/badge.dart';
import '../models/quiz_session.dart';

/// Model สำหรับเก็บ stats ของ staff ในเวร
/// ใช้สำหรับเปรียบเทียบและหา winners ของ shift badges
/// @visibleForTesting — เปิดให้ test access ได้
class ShiftStaffStats {
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

  const ShiftStaffStats({
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
  // UNSEEN BADGE CHECK — เช็ค badge ใหม่ตอนเปิด app
  // =========================================================================

  /// ดึง shift badges ที่ user ได้รับแล้ว แต่ยังไม่เคยเห็น (หลัง lastCheck)
  /// ใช้ตอน app resume เพื่อแสดง BadgeEarnedDialog
  ///
  /// Query: training_user_badges JOIN training_badges
  ///   WHERE user_id = current user
  ///   AND category = 'shift'
  ///   AND created_at > lastCheck
  Future<List<Badge>> getUnseenShiftBadges({
    required DateTime lastCheck,
  }) async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) return [];

      // ดึง badges ที่ได้รับหลัง lastCheck
      // training_user_badges.created_at = เวลาที่ cron award badge
      final response = await _client
          .from('training_user_badges')
          .select('''
            id, created_at, badge_id,
            training_badges!inner(
              id, name, description, icon, image_url,
              category, points, rarity,
              requirement_type, requirement_value
            )
          ''')
          .eq('user_id', userId)
          // [BUG-TZ FIX] ใช้ UTC เพื่อให้ตรงกับ timestamptz ใน Supabase
          .gt('created_at', lastCheck.toUtc().toIso8601String())
          .order('created_at', ascending: false);

      final badges = <Badge>[];
      for (final row in response as List) {
        final badgeData = row['training_badges'] as Map<String, dynamic>?;
        if (badgeData == null) continue;

        // [BUG-FILTER FIX] filter category='shift' ฝั่ง Dart
        // เพราะ .eq() กับ joined table อาจไม่ work ใน PostgREST ทุก version
        final category = badgeData['category'] as String? ?? '';
        if (category != 'shift') continue;

        badges.add(Badge(
          id: badgeData['id'] as String,
          name: badgeData['name'] as String,
          description: badgeData['description'] as String?,
          icon: badgeData['icon'] as String?,
          imageUrl: badgeData['image_url'] as String?,
          category: category,
          points: badgeData['points'] as int? ?? 0,
          rarity: badgeData['rarity'] as String? ?? 'common',
          requirementType: badgeData['requirement_type'] as String,
          requirementValue:
              badgeData['requirement_value'] as Map<String, dynamic>?,
          isEarned: true,
          earnedAt: row['created_at'] != null
              ? DateTime.tryParse(row['created_at'] as String)
              : DateTime.now(),
        ));
      }

      return badges;
    } catch (e) {
      debugPrint('getUnseenShiftBadges error: $e');
      return [];
    }
  }

  // =========================================================================
  // SHIFT BADGES
  // Badge เหล่านี้รับซ้ำได้ทุกเวร
  // ระบบ Hybrid: App คำนวณ stats → save JSONB → Cron เทียบ + award
  // =========================================================================


  /// นับ kindness tasks (ช่วยคนไข้ที่ไม่ได้ assign ให้)
  /// ใช้ assigned residents ของ staff คนนั้นจริงๆ (ดึงจาก clock_in_out_ver2)
  int countKindnessTasks({
    required List<dynamic> staffTasks,
    required List<int> assignedResidentIds,
  }) {
    // ถ้าไม่มี assigned residents (ไม่ได้เลือกตอน clock in)
    // → ถือว่าทุก task เป็น "ของตัวเอง" → kindness = 0
    if (assignedResidentIds.isEmpty) return 0;

    return staffTasks.where((t) {
      final residentId = t['resident_id'] as int?;
      if (residentId == null) return false;
      // task กับ resident ที่ไม่ได้อยู่ใน list ที่เลือกตอน clock in = kindness
      return !assignedResidentIds.contains(residentId);
    }).length;
  }

  /// คำนวณค่าเบี่ยงเบนเวลาเฉลี่ย (นาที)
  double calculateAvgTimingDiff(List<dynamic> tasks) {
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
  int calculateDeadAirMinutes({
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
  (int, int) calculateDifficultyScores(List<dynamic> tasks) {
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
  /// @visibleForTesting — เปิดให้ test เรียกตรงได้
  @visibleForTesting
  bool checkShiftBadgeCondition({
    required String requirementType,
    required Map<String, dynamic> requirementValue,
    required ShiftStaffStats myStats,
    required List<ShiftStaffStats> allStats,
  }) {
    switch (requirementType) {
      case 'shift_most_problems':
        // ติ๊กปัญหามากที่สุด (ต้องมีอย่างน้อย 1)
        if (myStats.problemCount == 0) return false;
        return isWinner(
          myValue: myStats.problemCount,
          myTime: myStats.lastTaskTime,
          myStaffId: myStats.staffId,
          allStats: allStats,
          getValue: (s) => s.problemCount,
          getTime: (s) => s.lastTaskTime,
          higherIsBetter: true,
        );

      case 'shift_most_completed':
        // ทำงานเสร็จเยอะที่สุด (ต้องมีอย่างน้อย 1)
        if (myStats.completedCount == 0) return false;
        return isWinner(
          myValue: myStats.completedCount,
          myTime: myStats.lastTaskTime,
          myStaffId: myStats.staffId,
          allStats: allStats,
          getValue: (s) => s.completedCount,
          getTime: (s) => s.lastTaskTime,
          higherIsBetter: true,
        );

      case 'shift_most_kindness':
        // ช่วยคนไข้คนอื่นมากที่สุด (ต้องมีอย่างน้อย 1)
        if (myStats.kindnessCount == 0) return false;
        return isWinner(
          myValue: myStats.kindnessCount,
          myTime: myStats.lastTaskTime,
          myStaffId: myStats.staffId,
          allStats: allStats,
          getValue: (s) => s.kindnessCount,
          getTime: (s) => s.lastTaskTime,
          higherIsBetter: true,
        );

      case 'shift_best_timing':
        // ค่าเบี่ยงเบนเวลาต่ำสุด (ต้องมี tasks ที่มี expected time)
        if (myStats.avgTimingDiff == double.infinity) return false;
        return isWinnerDouble(
          myValue: myStats.avgTimingDiff,
          myTime: myStats.lastTaskTime,
          myStaffId: myStats.staffId,
          allStats: allStats,
          getValue: (s) => s.avgTimingDiff,
          getTime: (s) => s.lastTaskTime,
          lowerIsBetter: true,
        );

      case 'shift_most_dead_air':
        // Dead air มากที่สุด (ต้องมี dead air > 0)
        if (myStats.deadAirMinutes == 0) return false;
        return isWinner(
          myValue: myStats.deadAirMinutes,
          myTime: myStats.lastTaskTime,
          myStaffId: myStats.staffId,
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
  /// [myStaffId] ใช้ skip ตัวเอง เพื่อไม่ให้เปรียบเทียบกับตัวเอง
  bool isWinner({
    required int myValue,
    required DateTime? myTime,
    required String myStaffId,
    required List<ShiftStaffStats> allStats,
    required int Function(ShiftStaffStats) getValue,
    required DateTime? Function(ShiftStaffStats) getTime,
    required bool higherIsBetter,
  }) {
    for (final other in allStats) {
      // ข้ามตัวเอง — ไม่งั้น tie-breaker จะเปรียบเทียบ myTime กับ myTime
      if (other.staffId == myStaffId) continue;

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
  /// [myStaffId] ใช้ skip ตัวเอง เพื่อไม่ให้เปรียบเทียบกับตัวเอง
  bool isWinnerDouble({
    required double myValue,
    required DateTime? myTime,
    required String myStaffId,
    required List<ShiftStaffStats> allStats,
    required double Function(ShiftStaffStats) getValue,
    required DateTime? Function(ShiftStaffStats) getTime,
    required bool lowerIsBetter,
  }) {
    for (final other in allStats) {
      // ข้ามตัวเอง
      if (other.staffId == myStaffId) continue;

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


  /// คำนวณ stats ของ current user สำหรับเวรนี้ แล้ว save เป็น JSONB
  /// ลง column shift_badge_stats ใน clock_in_out_ver2
  ///
  /// Cron job จะอ่าน JSONB นี้ → เทียบกับ staff คนอื่น → award badges
  ///
  /// Stats ที่คำนวณ:
  /// - completed_count: จำนวน tasks ที่เสร็จ
  /// - problem_count: จำนวน tasks ที่เจอปัญหา
  /// - kindness_count: จำนวน tasks ที่ช่วยดูแล resident คนอื่น
  /// - avg_timing_diff: ค่าเบี่ยงเบนเวลาเฉลี่ย (นาที)
  /// - difficulty_diff_sum: ผลรวม (user_rating - norm) เฉพาะที่ > 0
  /// - norm_difficulty_sum: ผลรวม (norm - user_rating) เฉพาะที่ > 0
  /// - last_task_time: ISO 8601 ของ task สุดท้าย (tie-break)
  /// - total_tasks: จำนวน tasks ทั้งหมด
  /// - adjust_date: วันที่ปรับ (local, hour<7 shift back 1 day)
  Future<void> computeAndSaveShiftStats({
    required int clockRecordId,
    required int nursinghomeId,
    required DateTime clockIn,
    required DateTime clockOut,
    required List<int> assignedResidentIds,
  }) async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) {
        debugPrint('computeAndSaveShiftStats: No user');
        return;
      }

      // ดึง task logs จาก raw table (ไม่ใช่ view)
      // FIX ROOT CAUSE: v2_task_logs_with_details ไม่มี difficulty_score
      // ต้อง query A_Task_logs_ver2 ตรง + JOIN task_difficulty_cache
      //
      // ใช้ completed_at ในช่วง clock_in → clock_out ของ current user
      // เพื่อ scope tasks ให้ตรงกับเวร (BUG-72: cross-midnight fix)
      final taskLogs = await _client
          .from('A_Task_logs_ver2')
          .select('''
            id, completed_by, status,
            completed_at, "ExpectedDateTime",
            difficulty_score, task_id, c_task_id
          ''')
          .eq('completed_by', userId)
          // [BUG-TZ FIX] ใช้ UTC เพื่อให้ตรงกับ timestamptz ใน Supabase
          // ไม่งั้น local time (ICT +7) จะถูกตีความเป็น UTC → เลื่อน 7 ชม.
          .gte('completed_at', clockIn.toUtc().toIso8601String())
          .lte('completed_at', clockOut.toUtc().toIso8601String());

      final tasks = taskLogs as List;

      // ดึง task_difficulty_cache สำหรับ tasks ที่มี difficulty_score
      // เพื่อคำนวณ novice/master scores
      final taskIds = <int>{};
      for (final t in tasks) {
        final taskId = t['task_id'] as int?;
        final cTaskId = t['c_task_id'] as int?;
        // task_difficulty_cache ใช้ COALESCE(task_id, c_task_id) เป็น key
        final cacheKey = taskId ?? cTaskId;
        if (cacheKey != null) taskIds.add(cacheKey);
      }

      // ดึง avg difficulty norms จาก cache
      // ใช้คำนวณ novice/master scores (user_rating vs norm)
      final normMap = <int, double>{};
      if (taskIds.isNotEmpty) {
        final norms = await _client
            .from('task_difficulty_cache')
            .select('task_id, avg_score')
            .inFilter('task_id', taskIds.toList());

        for (final n in norms as List) {
          final id = n['task_id'] as int;
          final score = (n['avg_score'] as num?)?.toDouble();
          if (score != null) normMap[id] = score;
        }
      }

      // [BUG-8 FIX] Warning ถ้า normMap ว่าง แต่มี tasks ที่มี difficulty_score
      // → novice/master badges จะไม่ถูก award เพราะ scores = 0
      if (normMap.isEmpty && taskIds.isNotEmpty) {
        debugPrint(
          'WARNING: task_difficulty_cache empty for ${taskIds.length} tasks '
          '→ novice/master scores will be 0'
        );
      }

      // ดึง resident_id mapping สำหรับ kindness calculation
      final residentMap = <int, int?>{};
      if (assignedResidentIds.isNotEmpty) {
        final taskIdList =
            tasks.map((t) => t['task_id'] as int?).whereType<int>().toList();
        final cTaskIdList =
            tasks.map((t) => t['c_task_id'] as int?).whereType<int>().toList();

        // ดึง resident_id จาก A_Tasks (repeated tasks)
        if (taskIdList.isNotEmpty) {
          final aTasks = await _client
              .from('A_Tasks')
              .select('id, resident_id')
              .inFilter('id', taskIdList);
          for (final at in aTasks as List) {
            residentMap[at['id'] as int] = at['resident_id'] as int?;
          }
        }

        // ดึง resident_id จาก C_Tasks (calendar tasks)
        if (cTaskIdList.isNotEmpty) {
          final cTasks = await _client
              .from('C_Tasks')
              .select('id, resident_id')
              .inFilter('id', cTaskIdList);
          for (final ct in cTasks as List) {
            residentMap[ct['id'] as int] = ct['resident_id'] as int?;
          }
        }
      }

      // [BUG-15 FIX] Warning ถ้า residentMap ว่างแต่มี assignedResidentIds
      // → kindness_count จะเป็น 0 ทุกคน เพราะหา resident ไม่ได้
      if (residentMap.isEmpty && assignedResidentIds.isNotEmpty) {
        debugPrint(
          'WARNING: residentMap empty but ${assignedResidentIds.length} '
          'assigned residents → kindness_count will be 0',
        );
      }

      // === คำนวณ stats ด้วย pure function (testable) ===
      final stats = buildStatsJson(
        taskLogs: tasks.cast<Map<String, dynamic>>(),
        normMap: normMap,
        residentMap: residentMap,
        assignedResidentIds: assignedResidentIds,
        clockIn: clockIn,
      );

      // === Save JSONB ลง clock_in_out_ver2 ===
      await _client
          .from('clock_in_out_ver2')
          .update({'shift_badge_stats': stats})
          .eq('id', clockRecordId);

      debugPrint('=== Shift Badge Stats Saved ===');
      debugPrint('ClockRecord: $clockRecordId');
      debugPrint('Stats: $stats');
    } catch (e, stackTrace) {
      // Stats save failure ไม่ block clock-out flow
      // Cron จะ skip record ที่ไม่มี stats (JSONB = NULL)
      // [BUG-9 FIX] Log ทั้ง error + stackTrace เพื่อ debug ได้ง่ายขึ้น
      debugPrint('computeAndSaveShiftStats ERROR: $e');
      debugPrint('StackTrace: $stackTrace');
    }
  }

  /// Pure function สำหรับคำนวณ shift badge stats จาก raw data
  /// แยกออกจาก computeAndSaveShiftStats() เพื่อให้ test ได้
  ///
  /// Parameters:
  /// - [taskLogs]: task logs จาก A_Task_logs_ver2 (status, completed_at, etc.)
  /// - [normMap]: task_id → avg difficulty score จาก cache
  /// - [residentMap]: task_id/c_task_id → resident_id จาก A_Tasks/C_Tasks
  /// - [assignedResidentIds]: resident IDs ที่ staff ถูก assign ตอน clock-in
  /// - [clockIn]: เวลา clock-in (ใช้คำนวณ adjust_date)
  @visibleForTesting
  static Map<String, dynamic> buildStatsJson({
    required List<Map<String, dynamic>> taskLogs,
    required Map<int, double> normMap,
    required Map<int, int?> residentMap,
    required List<int> assignedResidentIds,
    required DateTime clockIn,
  }) {
    // 1. completed_count
    final completedCount =
        taskLogs.where((t) => t['status'] == 'complete').length;

    // 2. problem_count (ใช้ status เท่านั้น เพราะ problem_type ไม่มีใน raw table)
    final problemCount =
        taskLogs.where((t) => t['status'] == 'problem').length;

    // 3. kindness_count — tasks ที่ดูแล resident ที่ไม่ใช่ของตัวเอง
    int kindnessCount = 0;
    if (assignedResidentIds.isNotEmpty) {
      for (final t in taskLogs) {
        final taskId = t['task_id'] as int?;
        final cTaskId = t['c_task_id'] as int?;
        final residentId = residentMap[taskId] ?? residentMap[cTaskId];
        if (residentId != null &&
            !assignedResidentIds.contains(residentId)) {
          kindnessCount++;
        }
      }
    }

    // 4. avg_timing_diff — ค่าเบี่ยงเบนเวลาเฉลี่ย (นาที)
    int totalDiff = 0;
    int timingCount = 0;
    for (final t in taskLogs) {
      final completedStr = t['completed_at'] as String?;
      final expectedStr = t['ExpectedDateTime'] as String?;
      if (completedStr != null && expectedStr != null) {
        final completed = DateTime.tryParse(completedStr);
        final expected = DateTime.tryParse(expectedStr);
        if (completed != null && expected != null) {
          totalDiff += completed.difference(expected).inMinutes.abs();
          timingCount++;
        }
      }
    }
    // ใช้ 999999 แทน infinity (JSONB ไม่รองรับ infinity)
    final avgTimingDiff =
        timingCount > 0 ? (totalDiff / timingCount).toDouble() : 999999.0;

    // 5. difficulty scores — novice/master
    int difficultyDiffSum = 0; // novice: user rated harder than norm
    int normDifficultySum = 0; // master: user rated easier than norm
    for (final t in taskLogs) {
      final userDiff = t['difficulty_score'] as int?;
      if (userDiff == null) continue;

      final taskId = t['task_id'] as int?;
      final cTaskId = t['c_task_id'] as int?;
      final cacheKey = taskId ?? cTaskId;
      final normDiff = cacheKey != null ? normMap[cacheKey]?.toInt() : null;
      if (normDiff == null) continue;

      final diff = userDiff - normDiff;
      if (diff > 0) {
        difficultyDiffSum += diff;
      } else if (diff < 0) {
        normDifficultySum += diff.abs();
      }
    }

    // 6. last_task_time — เวลา task สุดท้าย (สำหรับ tie-break)
    DateTime? lastTaskTime;
    for (final t in taskLogs) {
      final completedStr = t['completed_at'] as String?;
      if (completedStr != null) {
        final dt = DateTime.tryParse(completedStr);
        if (dt != null &&
            (lastTaskTime == null || dt.isAfter(lastTaskTime))) {
          lastTaskTime = dt;
        }
      }
    }

    // 7. adjust_date — คำนวณจาก local clock-in time
    //    hour < 7 = เวรดึก → shift back 1 day
    final localClockIn = clockIn.toLocal();
    final adjustDate = localClockIn.hour < 7
        ? DateTime(
            localClockIn.year, localClockIn.month, localClockIn.day - 1)
        : DateTime(
            localClockIn.year, localClockIn.month, localClockIn.day);
    final dateStr =
        '${adjustDate.year}-${adjustDate.month.toString().padLeft(2, '0')}-${adjustDate.day.toString().padLeft(2, '0')}';

    return {
      'completed_count': completedCount,
      'problem_count': problemCount,
      'kindness_count': kindnessCount,
      'avg_timing_diff': avgTimingDiff,
      'difficulty_diff_sum': difficultyDiffSum,
      'norm_difficulty_sum': normDifficultySum,
      'last_task_time': lastTaskTime?.toIso8601String(),
      'total_tasks': taskLogs.length,
      'adjust_date': dateStr,
      'version': 1,
    };
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
