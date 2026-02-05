import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/models.dart';
import '../providers/points_provider.dart';

// PointsDisplay Widget
// แสดง total points + tier + progress bar
// ใช้ใน Home หรือ Profile screen

/// Widget แสดง points และ tier ของ user
/// Tap เพื่อไป Leaderboard หรือ History
class PointsDisplay extends ConsumerWidget {
  final VoidCallback? onTap;
  final bool showProgress;
  final bool compact;

  const PointsDisplay({
    super.key,
    this.onTap,
    this.showProgress = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(userPointsSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        if (summary == null) {
          return _buildEmpty(context);
        }
        return _buildContent(context, summary);
      },
      loading: () => _buildLoading(context),
      error: (_, _) => _buildEmpty(context),
    );
  }

  Widget _buildContent(BuildContext context, UserPointsSummary summary) {
    // Parse tier color
    Color tierColor = AppColors.primary;
    if (summary.tierColor != null) {
      try {
        tierColor = Color(
          int.parse(summary.tierColor!.replaceFirst('#', '0xFF')),
        );
      } catch (_) {}
    }

    if (compact) {
      return _buildCompact(context, summary, tierColor);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              tierColor.withValues(alpha: 0.15),
              tierColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.mediumRadius,
          border: Border.all(
            color: tierColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tier badge + points
            Row(
              children: [
                // Tier icon
                Text(
                  summary.tierIcon ?? '🏆',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Tier name + points
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.tierDisplayName,
                        style: AppTypography.title.copyWith(
                          color: tierColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${summary.totalPoints} คะแนน',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow icon
                if (onTap != null)
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
              ],
            ),

            // Progress bar to next tier
            if (showProgress && !summary.isMaxTier) ...[
              const SizedBox(height: AppSpacing.md),
              _buildProgressBar(summary, tierColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(
    BuildContext context,
    UserPointsSummary summary,
    Color tierColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: tierColor.withValues(alpha: 0.1),
          borderRadius: AppRadius.fullRadius,
          border: Border.all(
            color: tierColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              summary.tierIcon ?? '🏆',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${summary.totalPoints}',
              style: AppTypography.label.copyWith(
                color: tierColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(UserPointsSummary summary, Color tierColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: AppRadius.smallRadius,
          child: LinearProgressIndicator(
            value: summary.progressToNextTier,
            backgroundColor: tierColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(tierColor),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Next tier info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'อีก ${summary.pointsToNextTier} คะแนน',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              summary.nextTierName ?? '',
              style: AppTypography.caption.copyWith(
                color: tierColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.sm),
          Text('กำลังโหลด...'),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 24)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เริ่มสะสมคะแนน',
                    style: AppTypography.title,
                  ),
                  Text(
                    'ทำกิจกรรมเพื่อรับคะแนน',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: AppColors.textSecondary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget แสดง points badge เล็กๆ
/// ใช้ใน AppBar หรือ header
class PointsBadge extends ConsumerWidget {
  final VoidCallback? onTap;

  const PointsBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(userPointsSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        if (summary == null) return const SizedBox.shrink();

        Color tierColor = AppColors.primary;
        if (summary.tierColor != null) {
          try {
            tierColor = Color(
              int.parse(summary.tierColor!.replaceFirst('#', '0xFF')),
            );
          } catch (_) {}
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              borderRadius: AppRadius.fullRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.tierIcon ?? '🏆',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                Text(
                  '${summary.totalPoints}',
                  style: AppTypography.caption.copyWith(
                    color: tierColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
