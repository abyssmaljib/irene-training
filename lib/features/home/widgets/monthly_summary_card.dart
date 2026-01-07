import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Card แสดงสรุปเวรประจำเดือน
class MonthlySummaryCard extends StatelessWidget {
  final int morningShifts;
  final int nightShifts;
  final int? targetShifts;
  final VoidCallback? onTap;

  const MonthlySummaryCard({
    super.key,
    required this.morningShifts,
    required this.nightShifts,
    this.targetShifts,
    this.onTap,
  });

  int get totalShifts => morningShifts + nightShifts;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          boxShadow: [AppShadows.subtle],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, color: AppColors.primary, size: AppIconSize.lg),
                    AppSpacing.horizontalGapSm,
                    Text('สรุปเวรเดือนนี้', style: AppTypography.title),
                  ],
                ),
                if (onTap != null)
                  Row(
                    children: [
                      Text(
                        'ดูรายละเอียด',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      AppSpacing.horizontalGapXs,
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        color: AppColors.primary,
                        size: AppIconSize.sm,
                      ),
                    ],
                  ),
              ],
            ),

            AppSpacing.verticalGapMd,

            // Shift counts row
            Row(
              children: [
                // Morning shifts
                Expanded(
                  child: _buildShiftItem(
                    icon: HugeIcons.strokeRoundedSun01,
                    iconColor: AppColors.warning,
                    label: 'เวรเช้า',
                    count: morningShifts,
                  ),
                ),

                // Divider
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.alternate,
                ),

                // Night shifts
                Expanded(
                  child: _buildShiftItem(
                    icon: HugeIcons.strokeRoundedMoon02,
                    iconColor: AppColors.secondary,
                    label: 'เวรดึก',
                    count: nightShifts,
                  ),
                ),
              ],
            ),

            AppSpacing.verticalGapSm,

            // Total
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.smallRadius,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'รวม: ',
                    style: AppTypography.body.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    '$totalShifts',
                    style: AppTypography.title.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  if (targetShifts != null) ...[
                    Text(
                      '/$targetShifts',
                      style: AppTypography.body.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                  Text(
                    ' เวร',
                    style: AppTypography.body.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftItem({
    required dynamic icon,
    required Color iconColor,
    required String label,
    required int count,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HugeIcon(icon: icon, color: iconColor, size: AppIconSize.lg),
        AppSpacing.horizontalGapSm,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            Text(
              '$count เวร',
              style: AppTypography.title,
            ),
          ],
        ),
      ],
    );
  }
}
