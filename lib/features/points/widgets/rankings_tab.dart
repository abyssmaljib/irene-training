import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/network_image.dart';
import '../models/models.dart';
import '../providers/points_provider.dart';

// RankingsTab - Tab "อันดับ"
// แสดง leaderboard จริง: period selector + podium top 3 + full list
// ใช้ leaderboardDataProvider ที่มีอยู่แล้ว (ไม่ต้องเขียน query ใหม่)

class RankingsTab extends ConsumerWidget {
  final int? nursinghomeId;

  const RankingsTab({super.key, this.nursinghomeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Period ที่เลือก (this_week / this_month / all_time)
    final selectedPeriod = ref.watch(leaderboardPeriodProvider);
    // Leaderboard data จาก provider (ใช้ที่มีอยู่แล้ว)
    final leaderboardAsync = ref.watch(leaderboardDataProvider(nursinghomeId));

    return Column(
      children: [
        // Period Selector (ChoiceChips)
        _buildPeriodSelector(ref, selectedPeriod),

        // Leaderboard Content
        Expanded(
          child: leaderboardAsync.when(
            data: (data) => _buildLeaderboardContent(data),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'เกิดข้อผิดพลาด: $e',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Period selector: สัปดาห์นี้ / เดือนนี้ / ทั้งหมด
  Widget _buildPeriodSelector(WidgetRef ref, LeaderboardPeriod selectedPeriod) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: LeaderboardPeriod.values.map((period) {
          final isSelected = period == selectedPeriod;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(period.displayName),
              selected: isSelected,
              onSelected: (_) {
                // เปลี่ยน period ผ่าน provider
                ref.read(leaderboardPeriodProvider.notifier).setPeriod(period);
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundColor: AppColors.surface,
              labelStyle: AppTypography.label.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color:
                    isSelected ? AppColors.primary : AppColors.inputBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Content หลัก: podium + list + my rank
  Widget _buildLeaderboardContent(LeaderboardData data) {
    if (data.entries.isEmpty) {
      return _buildEmpty();
    }

    return Stack(
      children: [
        // Scrollable content (podium + list)
        CustomScrollView(
          slivers: [
            // Podium top 3
            if (data.topThree.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildPodium(data.topThree),
              ),

            // Divider
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Divider(
                  color: AppColors.inputBorder,
                  height: 1,
                ),
              ),
            ),

            // Rest of list (อันดับ 4+)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = data.restOfList[index];
                  final isCurrentUser =
                      data.currentUser?.userId == entry.userId;
                  return _RankingListItem(
                    entry: entry,
                    isCurrentUser: isCurrentUser,
                  );
                },
                childCount: data.restOfList.length,
              ),
            ),

            // Bottom padding สำหรับ floating card
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),

        // Floating "My Rank" card ด้านล่าง (ถ้า user ไม่อยู่ top 10)
        if (data.currentUser != null && !data.isCurrentUserInTopTen)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: _buildMyRankCard(data.currentUser!, data.currentUserRank),
          ),
      ],
    );
  }

  /// Podium สำหรับ top 3 — layout: อันดับ 2 | อันดับ 1 | อันดับ 3
  Widget _buildPodium(List<LeaderboardEntry> topThree) {
    // จัด entries ตามอันดับ
    final first = topThree.firstWhere((e) => e.rank == 1,
        orElse: () => topThree.first);
    final second = topThree.where((e) => e.rank == 2).firstOrNull;
    final third = topThree.where((e) => e.rank == 3).firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        // Gradient background คล้ายกับ admin leaderboard
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // อันดับ 2 (ซ้าย, เตี้ยกว่า)
          if (second != null)
            Expanded(child: _PodiumItem(entry: second, height: 80))
          else
            const Expanded(child: SizedBox()),

          const SizedBox(width: AppSpacing.sm),

          // อันดับ 1 (กลาง, สูงสุด)
          Expanded(child: _PodiumItem(entry: first, height: 100)),

          const SizedBox(width: AppSpacing.sm),

          // อันดับ 3 (ขวา, เตี้ยสุด)
          if (third != null)
            Expanded(child: _PodiumItem(entry: third, height: 64))
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  /// Floating card แสดงอันดับของ user ปัจจุบัน
  Widget _buildMyRankCard(LeaderboardEntry user, int? rank) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${rank ?? '-'}',
                style: AppTypography.title.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '📍 คุณอยู่อันดับที่ ${rank ?? '-'}',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${user.totalPoints} คะแนน',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Tier badge
          if (user.tierIcon != null)
            Text(
              user.tierIcon!,
              style: const TextStyle(fontSize: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 64)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'ยังไม่มีข้อมูลอันดับ',
            style: AppTypography.title.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'ทำกิจกรรมเพื่อขึ้นอันดับ!',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget สำหรับแต่ละคนบน Podium (top 3)
class _PodiumItem extends StatelessWidget {
  final LeaderboardEntry entry;
  final double height; // ความสูงของ pedestal

  const _PodiumItem({required this.entry, required this.height});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rank icon (🥇🥈🥉)
        Text(
          entry.rankIcon ?? '#${entry.rank}',
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Avatar (รูปหรือตัวอักษร)
        _buildAvatar(),
        const SizedBox(height: AppSpacing.xs),

        // ชื่อ
        Text(
          entry.displayName,
          style: AppTypography.label.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),

        // คะแนน
        Text(
          '${entry.totalPoints} pts',
          style: AppTypography.caption.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Pedestal (แท่นรางวัล)
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _pedestalColors(),
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Center(
            child: Text(
              '${entry.rank}',
              style: AppTypography.heading2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Avatar ของ user (ใช้ IreneNetworkAvatar เพื่อ error handling + memory optimization)
  Widget _buildAvatar() {
    return IreneNetworkAvatar(
      imageUrl: entry.photoUrl,
      radius: 24,
      fallbackIcon: Text(
        entry.displayName.isNotEmpty ? entry.displayName[0] : '?',
        style: AppTypography.title.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// สีของแท่นรางวัลตามอันดับ
  List<Color> _pedestalColors() {
    switch (entry.rank) {
      case 1: // ทอง
        return [const Color(0xFFFFD700), const Color(0xFFB8860B)];
      case 2: // เงิน
        return [const Color(0xFFC0C0C0), const Color(0xFF808080)];
      case 3: // ทองแดง
        return [const Color(0xFFCD7F32), const Color(0xFF8B5A2B)];
      default:
        return [AppColors.primary, AppColors.primary];
    }
  }
}

/// แต่ละ row ใน ranking list (อันดับ 4+)
class _RankingListItem extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isCurrentUser;

  const _RankingListItem({
    required this.entry,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        // Highlight ถ้าเป็น current user
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        border: isCurrentUser
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 32,
            child: Text(
              '${entry.rank}',
              style: AppTypography.title.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Avatar
          _buildSmallAvatar(),
          const SizedBox(width: AppSpacing.sm),

          // Name + tier
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(คุณ)',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                if (entry.tierName != null)
                  Row(
                    children: [
                      if (entry.tierIcon != null)
                        Text(
                          entry.tierIcon!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(width: 4),
                      Text(
                        entry.tierName!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Points
          Text(
            '${entry.totalPoints}',
            style: AppTypography.title.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Avatar เล็ก (32px) — ใช้ IreneNetworkAvatar เพื่อ error handling + memory optimization
  Widget _buildSmallAvatar() {
    return IreneNetworkAvatar(
      imageUrl: entry.photoUrl,
      radius: 16,
      fallbackIcon: Text(
        entry.displayName.isNotEmpty ? entry.displayName[0] : '?',
        style: AppTypography.label.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
