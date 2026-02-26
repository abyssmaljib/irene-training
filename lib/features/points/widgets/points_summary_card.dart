import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_state.dart';
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

        // สี tier เข้มขึ้นสำหรับ light background
        // DB colors จางเกินไป (Silver=#C0C0C0, Platinum=#E5E4E2)
        const tierDisplayColors = {
          'Bronze': Color(0xFF92400E),   // amber-800
          'Silver': Color(0xFF4B5563),   // gray-600
          'Gold': Color(0xFFB45309),     // amber-700
          'Platinum': Color(0xFF6D28D9), // violet-700
          'Diamond': Color(0xFF0369A1),  // sky-700
        };
        final tierColor = tierDisplayColors[summary.tierName] ?? AppColors.primary;

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
                      // Tier name + percentile badge
                      Row(
                        children: [
                          Text(
                            summary.tierDisplayName,
                            style: AppTypography.label.copyWith(
                              color: tierColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // แสดง "Top X%" badge ถ้าเป็น percentile mode
                          if (summary.percentileDisplay != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: tierColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                summary.percentileDisplay!,
                                style: AppTypography.caption.copyWith(
                                  color: tierColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ],
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
                        // ถ้าค่าเป็นบวกใส่ + นำหน้า, ค่าลบจะมี - อยู่แล้ว
                        '${summary.weekPoints >= 0 ? '+' : ''}${summary.weekPoints}',
                        style: AppTypography.label.copyWith(
                          color: summary.weekPoints >= 0 ? AppColors.success : AppColors.error,
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
      // แสดง error แทน SizedBox.shrink() เพื่อให้ user รู้ว่าเกิดข้อผิดพลาด
      error: (error, _) => ErrorStateWidget(
        message: 'โหลดข้อมูลคะแนนไม่สำเร็จ',
        compact: true,
        onRetry: () => ref.invalidate(userPointsSummaryProvider),
      ),
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
