import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
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
              child: Icon(
                Iconsax.health,
                size: 48,
                color: AppColors.secondaryText,
              ),
            ),
            AppSpacing.verticalGapLg,
            Text(
              'Clinical View',
              style: AppTypography.heading2.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            AppSpacing.verticalGapSm,
            Text(
              'Coming Soon',
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
            _buildFeatureItem(Iconsax.chart_2, 'กราฟแนวโน้มสัญญาณชีพ'),
            _buildFeatureItem(Iconsax.note_text, 'SOAP Notes'),
            _buildFeatureItem(Iconsax.health, 'จัดการยา'),
            _buildFeatureItem(Iconsax.clipboard_text, 'ประวัติการรักษา'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
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
