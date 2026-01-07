import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Placeholder สำหรับ Clinical View - Coming Soon
class ClinicalViewPlaceholder extends StatelessWidget {
  const ClinicalViewPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedMedicine01,
                size: AppIconSize.xxxl,
                color: AppColors.secondaryText,
              ),
            ),
            AppSpacing.verticalGapLg,
            Text(
              'มุมมองคลินิก',
              style: AppTypography.heading2.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            AppSpacing.verticalGapSm,
            Text(
              'เร็วๆ นี้',
              style: AppTypography.title.copyWith(
                color: AppColors.primary,
              ),
            ),
            AppSpacing.verticalGapMd,
            Text(
              'ในเวอร์ชันถัดไปจะมี:',
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            AppSpacing.verticalGapSm,
            _buildFeatureItem(HugeIcons.strokeRoundedChart, 'กราฟแนวโน้มสัญญาณชีพ'),
            _buildFeatureItem(HugeIcons.strokeRoundedNote, 'SOAP Notes'),
            _buildFeatureItem(HugeIcons.strokeRoundedMedicine01, 'จัดการยา'),
            _buildFeatureItem(HugeIcons.strokeRoundedClipboard, 'ประวัติการรักษา'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(dynamic icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: AppIconSize.sm, color: AppColors.primary),
          SizedBox(width: 8),
          Text(
            text,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
