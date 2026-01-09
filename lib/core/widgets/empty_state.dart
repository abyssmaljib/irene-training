import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Reusable Empty State Widget with cat image
/// ใช้แสดงเมื่อไม่มีข้อมูล
class EmptyStateWidget extends StatelessWidget {
  final String message;
  final String? subMessage;
  final String imagePath;
  final double imageSize;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.subMessage,
    this.imagePath = 'assets/images/relax_cat.webp',
    this.imageSize = 200,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            width: imageSize,
            height: imageSize,
          ),
          AppSpacing.verticalGapMd,
          Text(
            message,
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          if (subMessage != null) ...[
            AppSpacing.verticalGapSm,
            Text(
              subMessage!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryText.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            AppSpacing.verticalGapMd,
            action!,
          ],
        ],
      ),
    );
  }
}
