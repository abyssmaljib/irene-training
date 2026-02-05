import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/points_provider.dart';
import '../screens/leaderboard_screen.dart';

/// Card แสดงสรุป points ของ user สำหรับ HomeScreen
/// แสดง: Total points, Tier, Rank, Points สัปดาห์นี้
/// เมื่อกดจะไปหน้า LeaderboardScreen
class PointsSummaryCard extends ConsumerWidget {
  const PointsSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(userPointsSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        // ถ้าไม่มีข้อมูล ไม่แสดง card
        if (summary == null) return const SizedBox.shrink();

        // Parse tier color
        Color tierColor = AppColors.primary;
        if (summary.tierColor != null) {
          try {
            tierColor = Color(
              int.parse(summary.tierColor!.replaceFirst('#', '0xFF')),
            );
          } catch (_) {}
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              // Gradient background ตาม tier color
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
              ),
            ),
            child: Row(
              children: [
                // Tier icon (emoji)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.2),
                    borderRadius: AppRadius.smallRadius,
                  ),
                  child: Center(
                    child: Text(
                      summary.tierIcon ?? '🏆',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Points info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tier name
                      Text(
                        summary.tierName ?? 'Bronze',
                        style: AppTypography.label.copyWith(
                          color: tierColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Total points
                      Text(
                        '${summary.totalPoints} คะแนน',
                        style: AppTypography.heading3.copyWith(
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),

                // Week points badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smallRadius,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'สัปดาห์นี้',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '+${summary.weekPoints}',
                        style: AppTypography.label.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.sm),

                // Arrow icon
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: AppIconSize.md,
                  color: AppColors.secondaryText,
                ),
              ],
            ),
          ),
        );
      },
      // ขณะ loading แสดง skeleton
      loading: () => _buildSkeleton(),
      // ถ้า error ไม่แสดง card
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Row(
        children: [
          // Icon skeleton
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.alternate,
              borderRadius: AppRadius.smallRadius,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Text skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.alternate,
                    borderRadius: AppRadius.smallRadius,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 100,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.alternate,
                    borderRadius: AppRadius.smallRadius,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
