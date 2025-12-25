import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/badge.dart';
import '../models/quiz_session.dart';

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
      final user = _client.auth.currentUser;
      if (user == null) {
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
          .eq('user_id', user.id)
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
          userId: user.id,
        );

        if (shouldAward) {
          // บันทึก badge ใหม่
          try {
            await _client.from('training_user_badges').insert({
              'user_id': user.id,
              'badge_id': badgeId,
              'season_id': session.seasonId,
            });

            newBadges.add(Badge.fromBadgeTable(badgeData));
            debugPrint('BadgeService: Awarded badge: ${badgeData['name']}');
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
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('BadgeService.getUserBadges: No user');
        return [];
      }

      debugPrint('BadgeService.getUserBadges: user_id=${user.id}');

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
          .eq('user_id', user.id);

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
      final currentUser = _client.auth.currentUser;

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
      if (currentUser != null) {
        final userBadges = await _client
            .from('training_user_badges')
            .select('badge_id')
            .eq('user_id', currentUser.id);
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
      final uid = userId ?? _client.auth.currentUser?.id;
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
}
