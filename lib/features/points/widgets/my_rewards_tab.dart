import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/models.dart';
import '../providers/points_provider.dart';

// MyRewardsTab - Tab "รางวัล"
// แสดงรางวัลที่ user ได้รับจาก period completions (weekly/monthly/seasonal)
// ข้อมูลมาจาก period_reward_distributions + JOIN กับ leaderboard_periods

class MyRewardsTab extends ConsumerWidget {
  const MyRewardsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ดึงรางวัลจาก provider
    final rewardsAsync = ref.watch(userPeriodRewardsProvider);

    return rewardsAsync.when(
      data: (rewards) => _buildContent(rewards),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'เกิดข้อผิดพลาด: $e',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<PeriodRewardEntry> rewards) {
    if (rewards.isEmpty) {
      return _buildEmpty();
    }

    // คำนวณ summary (จำนวนรางวัล + bonus points รวม)
    final totalBonusPoints = rewards
        .where((r) =>
            r.rewardType == PeriodRewardType.bonusPoints && r.isDistributed)
        .fold<int>(0, (sum, r) => sum + r.bonusPoints);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Summary Header
        _buildSummaryHeader(rewards.length, totalBonusPoints),
        const SizedBox(height: AppSpacing.md),

        // Reward Cards
        ...rewards.map((reward) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _RewardCard(reward: reward),
            )),
      ],
    );
  }

  /// Header แสดงสรุป: จำนวนรางวัล + bonus points รวม
  Widget _buildSummaryHeader(int rewardCount, int totalBonusPoints) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Row(
        children: [
          // Icon
          const Text('🎁', style: TextStyle(fontSize: 32)),
          const SizedBox(width: AppSpacing.md),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'รางวัลของฉัน',
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ได้ $rewardCount รางวัล${totalBonusPoints > 0 ? ' | +$totalBonusPoints pts' : ''}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Empty state เมื่อยังไม่มีรางวัล
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 64)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'ยังไม่มีรางวัล',
              style: AppTypography.title.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'ทำผลงานให้ติด Top แล้วจะได้รางวัลอัตโนมัติ\nเมื่อจบรอบแต่ละสัปดาห์/เดือน/Season',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card แสดงรางวัลแต่ละรายการ
class _RewardCard extends StatelessWidget {
  final PeriodRewardEntry reward;

  const _RewardCard({required this.reward});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(
          color: AppColors.inputBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Period name + date range
          Row(
            children: [
              // Period type icon
              Text(
                _periodTypeIcon(),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Period name + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.periodName ?? 'ไม่ระบุรอบ',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (reward.periodStartDate != null &&
                        reward.periodEndDate != null)
                      Text(
                        _formatDateRange(
                            reward.periodStartDate!, reward.periodEndDate!),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),

              // Status badge
              _buildStatusBadge(),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Row 2: Rank + Reward
          Row(
            children: [
              // Rank badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: _rankColor().withValues(alpha: 0.15),
                  borderRadius: AppRadius.smallRadius,
                ),
                child: Text(
                  '${reward.rankIcon} อันดับ ${reward.rank}',
                  style: AppTypography.label.copyWith(
                    color: _rankColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Reward type + value
              Expanded(
                child: Row(
                  children: [
                    Text(
                      reward.rewardType.icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        reward.rewardDescription,
                        style: AppTypography.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Icon ตามประเภท period (weekly/monthly/seasonal)
  String _periodTypeIcon() {
    switch (reward.periodType) {
      case PeriodType.weekly:
        return '📅';
      case PeriodType.monthly:
        return '📆';
      case PeriodType.seasonal:
        return '🏆';
      default:
        return '📋';
    }
  }

  /// สี rank badge ตามอันดับ
  Color _rankColor() {
    switch (reward.rank) {
      case 1:
        return const Color(0xFFB8860B); // Gold
      case 2:
        return const Color(0xFF808080); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.textSecondary;
    }
  }

  /// Badge แสดงสถานะการแจกรางวัล
  Widget _buildStatusBadge() {
    final Color bgColor;
    final Color textColor;

    switch (reward.status) {
      case 'distributed':
        bgColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        break;
      case 'pending':
        bgColor = AppColors.warning.withValues(alpha: 0.1);
        textColor = AppColors.warning;
        break;
      default:
        bgColor = AppColors.error.withValues(alpha: 0.1);
        textColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.smallRadius,
      ),
      child: Text(
        reward.statusLabel,
        style: AppTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  /// Format date range เป็นภาษาไทย เช่น "3-9 ก.พ. 69"
  String _formatDateRange(DateTime start, DateTime end) {
    final startStr =
        DateFormat('d MMM', 'th').format(start);
    final endStr =
        DateFormat('d MMM yy', 'th').format(end);
    return '$startStr - $endStr';
  }
}
