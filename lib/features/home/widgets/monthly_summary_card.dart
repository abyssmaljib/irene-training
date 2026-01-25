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
  final int absentCount;
  final VoidCallback? onTap;

  const MonthlySummaryCard({
    super.key,
    required this.morningShifts,
    required this.nightShifts,
    this.targetShifts,
    this.absentCount = 0,
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
                    HugeIcon(
                        icon: HugeIcons.strokeRoundedCalendar01,
                        color: AppColors.primary,
                        size: AppIconSize.lg),
                    AppSpacing.horizontalGapSm,
                    Text('สรุปเวรเดือนนี้', style: AppTypography.title),
                  ],
                ),
                if (onTap != null)
                  Row(
                    children: [
                      // Absent notification badge - จุดแดงเตือน
                      if (absentCount > 0) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        AppSpacing.horizontalGapXs,
                      ],
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

            // ข้อความเตือนเมื่อมีการขาดเวร
            if (absentCount > 0) ...[
              AppSpacing.verticalGapSm,
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smallRadius,
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    // หัวข้อเตือน
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAlert02,
                          color: AppColors.error,
                          size: AppIconSize.sm,
                        ),
                        AppSpacing.horizontalGapXs,
                        Text(
                          'ขาดเวร $absentCount ครั้ง = ยินยอมให้หัก ${absentCount * 3} เวร',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.verticalGapXs,
                    // คำแนะนำ
                    Text(
                      'กรุณาแนบใบรับรองแพทย์หรือติดต่อหัวหน้าเวรโดยเร็ว',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.error.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
