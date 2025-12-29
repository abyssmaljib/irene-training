import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'buttons.dart';

/// Preset types for common confirmation dialogs
enum ConfirmDialogType {
  /// Logout confirmation
  logout,

  /// Delete item/photo confirmation
  delete,

  /// Exit quiz/exam confirmation
  exitQuiz,

  /// Generic warning
  warning,

  /// Custom (use custom title, message, etc.)
  custom,
}

/// Configuration for confirm dialog appearance
class ConfirmDialogConfig {
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final String? imageAsset; // รูปภาพแทน icon (เช่น 'assets/images/confirm_cat.png')
  final double imageSize; // ขนาดรูปภาพ (default 120x120)

  const ConfirmDialogConfig({
    required this.title,
    required this.message,
    this.cancelText = 'ยกเลิก',
    this.confirmText = 'ยืนยัน',
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.imageAsset,
    this.imageSize = 120,
  });

  /// Get preset config based on dialog type
  factory ConfirmDialogConfig.fromType(ConfirmDialogType type) {
    switch (type) {
      case ConfirmDialogType.logout:
        return const ConfirmDialogConfig(
          title: 'ออกจากระบบ',
          message: 'คุณต้องการออกจากระบบหรือไม่?',
          cancelText: 'ยกเลิก',
          confirmText: 'ออกจากระบบ',
          icon: Iconsax.logout,
          iconColor: AppColors.error,
          iconBackgroundColor: AppColors.tagFailedBg,
        );
      case ConfirmDialogType.delete:
        return const ConfirmDialogConfig(
          title: 'ลบรายการ',
          message: 'คุณต้องการลบรายการนี้หรือไม่?\nการดำเนินการนี้ไม่สามารถยกเลิกได้',
          cancelText: 'ยกเลิก',
          confirmText: 'ลบ',
          icon: Iconsax.trash,
          iconColor: AppColors.error,
          iconBackgroundColor: AppColors.tagFailedBg,
        );
      case ConfirmDialogType.exitQuiz:
        return const ConfirmDialogConfig(
          title: 'ออกจากการสอบ?',
          message: 'คุณต้องการออกจากการสอบหรือไม่?\nคำตอบที่ทำไว้จะไม่ถูกบันทึก',
          cancelText: 'ทำต่อ',
          confirmText: 'ออก',
          icon: Iconsax.close_square,
          iconColor: AppColors.error,
          iconBackgroundColor: AppColors.tagFailedBg,
        );
      case ConfirmDialogType.warning:
        return const ConfirmDialogConfig(
          title: 'คำเตือน',
          message: 'คุณแน่ใจหรือไม่ว่าต้องการดำเนินการนี้?',
          cancelText: 'ยกเลิก',
          confirmText: 'ยืนยัน',
          icon: Iconsax.warning_2,
          iconColor: Color(0xFFF59E0B), // Warning orange
          iconBackgroundColor: AppColors.tagPendingBg,
        );
      case ConfirmDialogType.custom:
        return const ConfirmDialogConfig(
          title: 'ยืนยัน',
          message: 'คุณต้องการดำเนินการนี้หรือไม่?',
        );
    }
  }
}

/// Reusable confirmation dialog widget
class ConfirmDialog extends StatelessWidget {
  final ConfirmDialogConfig config;
  final bool showIcon;
  final bool isLoading;

  const ConfirmDialog({
    super.key,
    required this.config,
    this.showIcon = true,
    this.isLoading = false,
  });

  /// Show confirmation dialog and return true if confirmed
  static Future<bool> show(
    BuildContext context, {
    ConfirmDialogType type = ConfirmDialogType.custom,
    String? title,
    String? message,
    String? cancelText,
    String? confirmText,
    IconData? icon,
    Color? iconColor,
    Color? iconBackgroundColor,
    String? imageAsset,
    double? imageSize,
    bool showIcon = true,
    bool barrierDismissible = true,
  }) async {
    // Get base config from type
    final baseConfig = ConfirmDialogConfig.fromType(type);

    // Override with custom values if provided
    final config = ConfirmDialogConfig(
      title: title ?? baseConfig.title,
      message: message ?? baseConfig.message,
      cancelText: cancelText ?? baseConfig.cancelText,
      confirmText: confirmText ?? baseConfig.confirmText,
      icon: icon ?? baseConfig.icon,
      iconColor: iconColor ?? baseConfig.iconColor,
      iconBackgroundColor: iconBackgroundColor ?? baseConfig.iconBackgroundColor,
      imageAsset: imageAsset ?? baseConfig.imageAsset,
      imageSize: imageSize ?? baseConfig.imageSize,
    );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => ConfirmDialog(
        config: config,
        showIcon: showIcon,
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeRadius, // 24px for modals per design system
      ),
      backgroundColor: AppColors.surface,
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon header (optional)
            if (showIcon && config.icon != null) ...[
              SizedBox(height: AppSpacing.lg),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: config.iconBackgroundColor ?? AppColors.tagFailedBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  config.icon,
                  color: config.iconColor ?? AppColors.error,
                  size: 28,
                ),
              ),
              SizedBox(height: AppSpacing.md),
            ] else ...[
              SizedBox(height: AppSpacing.lg),
            ],

            // Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                config.title,
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Image (optional) - แสดงระหว่าง title และ message
            if (config.imageAsset != null) ...[
              SizedBox(height: AppSpacing.md),
              Image.asset(
                config.imageAsset!,
                width: config.imageSize,
                height: config.imageSize,
                fit: BoxFit.contain,
              ),
            ],

            SizedBox(height: AppSpacing.sm),

            // Message
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                config.message,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: AppSpacing.lg),

            // Action buttons
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      text: config.cancelText,
                      onPressed:
                          isLoading ? null : () => Navigator.pop(context, false),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DangerButton(
                      text: config.confirmText,
                      isLoading: isLoading,
                      onPressed:
                          isLoading ? null : () => Navigator.pop(context, true),
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
}
