import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/user_service.dart';
import '../../checklist/providers/task_provider.dart'; // for userChangeCounterProvider
import '../models/models.dart';
import '../services/points_service.dart';

// Riverpod Providers สำหรับ Points System
// ใช้สำหรับ state management ใน Flutter app

/// Provider สำหรับ PointsService instance
final pointsServiceProvider = Provider<PointsService>((ref) {
  return PointsService();
});

/// Provider สำหรับ user's points summary
/// รวม total points, week/month points, tier info
final userPointsSummaryProvider = FutureProvider<UserPointsSummary?>((ref) async {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);
  final userId = UserService().effectiveUserId;
  if (userId == null) return null;

  final service = ref.read(pointsServiceProvider);
  return service.getUserSummary(userId);
});

/// Provider สำหรับ user's tier info
final userTierProvider = FutureProvider<UserTierInfo?>((ref) async {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);
  final userId = UserService().effectiveUserId;
  if (userId == null) return null;

  final service = ref.read(pointsServiceProvider);
  return service.getUserTier(userId);
});

/// Provider สำหรับ user's total points (simple version)
final userTotalPointsProvider = FutureProvider<int>((ref) async {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);
  final userId = UserService().effectiveUserId;
  if (userId == null) return 0;

  final service = ref.read(pointsServiceProvider);
  return service.getUserTotalPoints(userId);
});

/// Provider สำหรับ leaderboard
/// ใช้ family เพื่อรับ parameters
final leaderboardProvider = FutureProvider.family<List<LeaderboardEntry>, LeaderboardParams>(
  (ref, params) async {
    final service = ref.read(pointsServiceProvider);
    return service.getLeaderboard(
      nursinghomeId: params.nursinghomeId,
      period: params.period,
      limit: params.limit,
    );
  },
);

/// Parameters สำหรับ leaderboard query
class LeaderboardParams {
  final int? nursinghomeId;
  final LeaderboardPeriod period;
  final int limit;

  const LeaderboardParams({
    this.nursinghomeId,
    this.period = LeaderboardPeriod.allTime,
    this.limit = 50,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaderboardParams &&
        other.nursinghomeId == nursinghomeId &&
        other.period == period &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(nursinghomeId, period, limit);
}

/// Provider สำหรับ user's rank
final userRankProvider = FutureProvider.family<int?, LeaderboardParams>(
  (ref, params) async {
    // Watch user change counter เพื่อ refresh เมื่อ impersonate
    ref.watch(userChangeCounterProvider);
    final userId = UserService().effectiveUserId;
    if (userId == null) return null;

    final service = ref.read(pointsServiceProvider);
    return service.getUserRank(
      userId: userId,
      nursinghomeId: params.nursinghomeId,
      period: params.period,
    );
  },
);

/// Provider สำหรับ points history
final pointsHistoryProvider = FutureProvider.family<List<PointTransaction>, HistoryParams>(
  (ref, params) async {
    // Watch user change counter เพื่อ refresh เมื่อ impersonate
    ref.watch(userChangeCounterProvider);
    final userId = UserService().effectiveUserId;
    if (userId == null) return [];

    final service = ref.read(pointsServiceProvider);
    return service.getUserHistory(
      userId: userId,
      limit: params.limit,
      offset: params.offset,
    );
  },
);

/// Parameters สำหรับ history query
class HistoryParams {
  final int limit;
  final int offset;

  const HistoryParams({
    this.limit = 50,
    this.offset = 0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HistoryParams &&
        other.limit == limit &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(limit, offset);
}

/// Provider สำหรับ all tiers
final allTiersProvider = FutureProvider<List<Tier>>((ref) async {
  final service = ref.read(pointsServiceProvider);
  return service.getAllTiers();
});

/// Provider สำหรับ all rewards
final allRewardsProvider = FutureProvider<List<PointReward>>((ref) async {
  final service = ref.read(pointsServiceProvider);
  return service.getAllRewards();
});

/// Provider สำหรับ user's rewards with status
final userRewardsProvider = FutureProvider<List<RewardWithStatus>>((ref) async {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);
  final userId = UserService().effectiveUserId;
  if (userId == null) return [];

  final service = ref.read(pointsServiceProvider);
  return service.getUserRewards(userId);
});

/// StateNotifier สำหรับ selected period ใน leaderboard
class LeaderboardPeriodNotifier extends StateNotifier<LeaderboardPeriod> {
  LeaderboardPeriodNotifier() : super(LeaderboardPeriod.allTime);

  void setPeriod(LeaderboardPeriod period) {
    state = period;
  }
}

final leaderboardPeriodProvider =
    StateNotifierProvider<LeaderboardPeriodNotifier, LeaderboardPeriod>(
  (ref) => LeaderboardPeriodNotifier(),
);

/// Combined provider สำหรับ leaderboard data พร้อม current user rank
final leaderboardDataProvider = FutureProvider.family<LeaderboardData, int?>(
  (ref, nursinghomeId) async {
    // Watch user change counter เพื่อ refresh เมื่อ impersonate
    ref.watch(userChangeCounterProvider);
    final period = ref.watch(leaderboardPeriodProvider);
    final userId = UserService().effectiveUserId;

    final params = LeaderboardParams(
      nursinghomeId: nursinghomeId,
      period: period,
    );

    final entries = await ref.watch(leaderboardProvider(params).future);

    // หา current user ใน leaderboard
    LeaderboardEntry? currentUser;
    int? currentUserRank;

    if (userId != null) {
      currentUser = entries.where((e) => e.userId == userId).firstOrNull;
      currentUserRank = currentUser?.rank;
    }

    return LeaderboardData(
      period: period,
      entries: entries,
      currentUser: currentUser,
      currentUserRank: currentUserRank,
    );
  },
);

// Note: simpleLeaderboardProvider removed - using history view instead
