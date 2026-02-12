import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../learning/models/badge.dart';
import '../../points/models/models.dart';
import '../../points/services/points_service.dart';

// ==================== Models ====================

/// สรุป points ที่ได้ในเวร (breakdown ตามประเภท)
class ShiftPointsSummary {
  /// Points รวมทั้งหมด (ก่อนหัก penalty)
  final int totalPoints;

  /// Points จาก tasks
  final int taskPoints;

  /// Points จาก quizzes
  final int quizPoints;

  /// Points จากอ่าน content
  final int contentPoints;

  /// Points จาก badges ที่ได้
  final int badgePoints;

  /// Points จากถ่ายรูปจัดยา/เสิร์ฟยา
  final int medicinePhotoPoints;

  /// Dead air penalty (ติดลบ)
  final int deadAirPenalty;

  /// Points สุทธิ (หลังหัก penalty)
  int get netPoints => totalPoints - deadAirPenalty.abs();

  /// จำนวน transactions ทั้งหมด
  final int transactionCount;

  const ShiftPointsSummary({
    this.totalPoints = 0,
    this.taskPoints = 0,
    this.quizPoints = 0,
    this.contentPoints = 0,
    this.badgePoints = 0,
    this.medicinePhotoPoints = 0,
    this.deadAirPenalty = 0,
    this.transactionCount = 0,
  });
}

/// ข้อมูลสรุปเวรทั้งหมด
class ShiftSummary {
  /// Points ที่ได้รับในเวรนี้
  final ShiftPointsSummary points;

  /// Badges ใหม่ที่ได้ในเวรนี้
  final List<Badge> newBadges;

  /// ข้อมูล tier ปัจจุบันและ progress
  final UserTierInfo tierInfo;

  /// อันดับใน leaderboard
  final int leaderboardRank;

  /// จำนวน users ทั้งหมดใน leaderboard
  final int totalUsers;

  /// จำนวนวันทำงานติดต่อกัน (streak)
  final int workStreak;

  /// Dead air minutes (สำหรับแสดง)
  final int deadAirMinutes;

  const ShiftSummary({
    required this.points,
    required this.newBadges,
    required this.tierInfo,
    required this.leaderboardRank,
    required this.totalUsers,
    required this.workStreak,
    this.deadAirMinutes = 0,
  });

  /// สร้าง empty summary
  factory ShiftSummary.empty() {
    return ShiftSummary(
      points: const ShiftPointsSummary(),
      newBadges: [],
      tierInfo: UserTierInfo(
        currentTier: Tier.defaultTier,
        nextTier: null,
        totalPoints: 0,
      ),
      leaderboardRank: 0,
      totalUsers: 0,
      workStreak: 0,
    );
  }
}

// ==================== Service ====================

/// Service สำหรับดึงข้อมูลสรุปเวร
/// ใช้แสดงใน ClockOutSummaryModal
class ShiftSummaryService {
  static final ShiftSummaryService instance = ShiftSummaryService._();
  ShiftSummaryService._();

  final _supabase = Supabase.instance.client;
  final _pointsService = PointsService();

  /// ดึงข้อมูลสรุปเวรทั้งหมด
  /// เรียกหลังจาก clock out สำเร็จ
  Future<ShiftSummary> getShiftSummary({
    required String userId,
    required int nursinghomeId,
    required DateTime clockInTime,
    DateTime? clockOutTime,
    int deadAirMinutes = 0,
    List<Badge>? awardedBadges, // รับ badges ที่ award แล้วจาก BadgeService
  }) async {
    final endTime = clockOutTime ?? DateTime.now();

    try {
      // ถ้ามี awardedBadges ส่งมา ใช้เลย ไม่ต้อง query จาก database
      // เพราะอาจมีปัญหา timing/race condition
      final List<Badge> newBadges;
      if (awardedBadges != null && awardedBadges.isNotEmpty) {
        newBadges = awardedBadges;
      } else {
        // Fallback: query จาก database (กรณีเรียกจากที่อื่น)
        newBadges = await _getNewBadges(userId, clockInTime, endTime);
      }

      // Query ข้อมูลที่เหลือพร้อมกัน (parallel)
      final results = await Future.wait([
        _getShiftPoints(userId, clockInTime, endTime),
        _pointsService.getUserTier(userId),
        _getUserRank(userId, nursinghomeId),
        _getWorkStreak(userId, nursinghomeId),
      ]);

      final shiftPoints = results[0] as ShiftPointsSummary;
      final tierInfo = results[1] as UserTierInfo? ??
          UserTierInfo(
            currentTier: Tier.defaultTier,
            nextTier: null,
            totalPoints: 0,
          );
      final rankData = results[2] as Map<String, int>;
      final workStreak = results[3] as int;

      return ShiftSummary(
        points: shiftPoints,
        newBadges: newBadges,
        tierInfo: tierInfo,
        leaderboardRank: rankData['rank'] ?? 0,
        totalUsers: rankData['total'] ?? 0,
        workStreak: workStreak,
        deadAirMinutes: deadAirMinutes,
      );
    } catch (e) {
      debugPrint('❌ Error getting shift summary: $e');
      return ShiftSummary.empty();
    }
  }

  /// ดึง points ที่ได้ระหว่าง shift
  Future<ShiftPointsSummary> _getShiftPoints(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final result = await _supabase
          .from('Point_Transaction')
          .select()
          .eq('user_id', userId)
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      int taskPoints = 0;
      int quizPoints = 0;
      int contentPoints = 0;
      int badgePoints = 0;
      int medicinePhotoPoints = 0;
      int deadAirPenalty = 0;

      for (final row in result) {
        final points = (row['point_change'] as num?)?.toInt() ?? 0;
        final type = row['transaction_type'] as String? ?? '';

        // แยกประเภท
        if (type.startsWith('task')) {
          taskPoints += points;
        } else if (type.startsWith('quiz')) {
          quizPoints += points;
        } else if (type == 'content_read') {
          contentPoints += points;
        } else if (type == 'badge_earned') {
          badgePoints += points;
        } else if (type == 'medicine_photo') {
          medicinePhotoPoints += points;
        } else if (type == 'dead_air_penalty') {
          deadAirPenalty += points.abs(); // เก็บเป็นค่าบวก
        }
      }

      final totalPoints = taskPoints + quizPoints + contentPoints + badgePoints + medicinePhotoPoints;

      return ShiftPointsSummary(
        totalPoints: totalPoints,
        taskPoints: taskPoints,
        quizPoints: quizPoints,
        contentPoints: contentPoints,
        badgePoints: badgePoints,
        medicinePhotoPoints: medicinePhotoPoints,
        deadAirPenalty: deadAirPenalty,
        transactionCount: result.length,
      );
    } catch (e) {
      debugPrint('❌ Error getting shift points: $e');
      return const ShiftPointsSummary();
    }
  }

  /// ดึง badges ที่ได้ระหว่าง shift
  Future<List<Badge>> _getNewBadges(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final result = await _supabase
          .from('training_user_badges')
          .select('''
            earned_at,
            training_badges(*)
          ''')
          .eq('user_id', userId)
          .gte('earned_at', start.toIso8601String())
          .lte('earned_at', end.toIso8601String());

      return (result as List).map((row) {
        final badgeData = row['training_badges'] as Map<String, dynamic>;
        return Badge.fromBadgeTable(badgeData);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting new badges: $e');
      return [];
    }
  }

  /// ดึง rank ของ user ใน nursinghome
  Future<Map<String, int>> _getUserRank(
    String userId,
    int nursinghomeId,
  ) async {
    try {
      final result = await _supabase
          .from('training_v_leaderboard')
          .select('user_id, rank')
          .eq('nursinghome_id', nursinghomeId)
          .order('rank');

      final totalUsers = (result as List).length;
      final userEntry =
          result.where((r) => r['user_id'] == userId).firstOrNull;
      final rank = userEntry?['rank'] as int? ?? totalUsers;

      return {'rank': rank, 'total': totalUsers};
    } catch (e) {
      debugPrint('❌ Error getting user rank: $e');
      return {'rank': 0, 'total': 0};
    }
  }

  /// ดึง work streak ของ user
  /// นับจากวันที่มี clock_out ติดต่อกัน
  /// ถ้าไม่มีบันทึก "ขาดงาน" = streak ต่อได้
  Future<int> _getWorkStreak(String userId, int nursinghomeId) async {
    try {
      // ดึงวันที่ทำงานทั้งหมด (มี clock_out)
      final result = await _supabase
          .from('clock_in_out_ver2')
          .select('clock_in_timestamp')
          .eq('user_id', userId)
          .eq('nursinghome_id', nursinghomeId)
          .not('clock_out_timestamp', 'is', null)
          .order('clock_in_timestamp', ascending: false);

      if ((result as List).isEmpty) return 0;

      // นับวันติดต่อกัน
      int streak = 0;
      DateTime? prevDate;

      for (final row in result) {
        final workDate =
            DateTime.parse(row['clock_in_timestamp'] as String).toLocal();
        final dateOnly = DateTime(workDate.year, workDate.month, workDate.day);

        if (prevDate == null) {
          // First entry - ตรวจสอบว่าเป็นวันนี้หรือเมื่อวาน
          final today = DateTime.now();
          final todayOnly = DateTime(today.year, today.month, today.day);

          if (dateOnly == todayOnly ||
              dateOnly == todayOnly.subtract(const Duration(days: 1))) {
            streak = 1;
            prevDate = dateOnly;
          } else {
            break; // ไม่มี work ล่าสุด
          }
        } else {
          // ตรวจสอบว่าติดต่อกัน (อนุญาต gap 1-2 วันสำหรับวันหยุด)
          final diff = prevDate.difference(dateOnly).inDays;
          if (diff == 1 || diff == 2) {
            streak++;
            prevDate = dateOnly;
          } else if (diff > 2) {
            break; // Gap มากเกินไป
          }
          // diff == 0 หมายถึงวันเดียวกัน ให้ข้าม
        }
      }

      return streak;
    } catch (e) {
      debugPrint('❌ Error getting work streak: $e');
      return 0;
    }
  }
}
