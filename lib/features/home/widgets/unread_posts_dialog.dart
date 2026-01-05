import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';

/// Dialog แจ้งเตือนโพสที่ยังไม่อ่าน
class UnreadPostsDialog extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onViewPosts;

  const UnreadPostsDialog({
    super.key,
    required this.unreadCount,
    required this.onViewPosts,
  });

  /// Show the dialog
  static Future<void> show(
    BuildContext context, {
    required int unreadCount,
    required VoidCallback onViewPosts,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UnreadPostsDialog(
        unreadCount: unreadCount,
        onViewPosts: () {
          Navigator.of(context).pop();
          onViewPosts();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeRadius,
      ),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.tagPendingBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.document_text,
                color: AppColors.tagPendingText,
                size: 32,
              ),
            ),

            AppSpacing.verticalGapMd,

            // Title
            Text(
              'ยังไม่ได้อ่านประกาศ',
              style: AppTypography.heading3,
              textAlign: TextAlign.center,
            ),

            AppSpacing.verticalGapSm,

            // Message
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                ),
                children: [
                  const TextSpan(text: 'มี '),
                  TextSpan(
                    text: '$unreadCount โพส',
                    style: AppTypography.body.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' ที่ยังไม่ได้อ่าน\nกรุณาอ่านให้ครบก่อนลงเวร'),
                ],
              ),
            ),

            AppSpacing.verticalGapLg,

            // View Posts Button
            PrimaryButton(
              text: 'ไปอ่านโพส',
              onPressed: onViewPosts,
              icon: Iconsax.arrow_right,
            ),

            AppSpacing.verticalGapSm,

            // Cancel Button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'ยกเลิก',
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
