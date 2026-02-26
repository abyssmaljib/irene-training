import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// AppSnackbar — Helper สำหรับแสดง SnackBar ที่ consistent ทั้ง app
///
/// มี 4 variant ตาม severity:
/// - [success] — สีเขียว, icon checkmark
/// - [error] — สีแดง, icon alert + ปุ่ม retry (optional)
/// - [info] — สี primary (teal), icon info
/// - [warning] — สีส้ม, icon warning
///
/// ตัวอย่างการใช้งาน:
/// ```dart
/// // Success
/// AppSnackbar.success(context, 'บันทึกเรียบร้อย');
///
/// // Error + retry
/// AppSnackbar.error(
///   context,
///   'โหลดข้อมูลไม่สำเร็จ',
///   onRetry: () => fetchData(),
/// );
///
/// // Info
/// AppSnackbar.info(context, 'กำลังประมวลผล...');
///
/// // Warning
/// AppSnackbar.warning(context, 'ข้อมูลยังไม่ครบ');
/// ```
class AppSnackbar {
  AppSnackbar._(); // ป้องกันไม่ให้ instantiate

  /// แสดง success snackbar (สีเขียว)
  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
      backgroundColor: AppColors.tagPassedBg,
      textColor: AppColors.tagPassedText,
      iconColor: AppColors.tagPassedText,
    );
  }

  /// แสดง error snackbar (สีแดง) พร้อม retry action (optional)
  static void error(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    _show(
      context,
      message: message,
      icon: HugeIcons.strokeRoundedAlert02,
      backgroundColor: AppColors.tagFailedBg,
      textColor: AppColors.tagFailedText,
      iconColor: AppColors.tagFailedText,
      action: onRetry != null
          ? SnackBarAction(
              label: 'ลองใหม่',
              textColor: AppColors.tagFailedText,
              onPressed: onRetry,
            )
          : null,
    );
  }

  /// แสดง info snackbar (สี primary teal)
  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: HugeIcons.strokeRoundedInformationCircle,
      backgroundColor: AppColors.accent1,
      textColor: AppColors.primary,
      iconColor: AppColors.primary,
    );
  }

  /// แสดง warning snackbar (สีส้ม)
  static void warning(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: HugeIcons.strokeRoundedAlertCircle,
      backgroundColor: AppColors.tagPendingBg,
      textColor: AppColors.tagPendingText,
      iconColor: AppColors.tagPendingText,
    );
  }

  /// Internal method สำหรับแสดง snackbar
  static void _show(
    BuildContext context, {
    required String message,
    required dynamic icon,
    required Color backgroundColor,
    required Color textColor,
    required Color iconColor,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    // ลบ snackbar เดิมก่อน (ถ้ามี) เพื่อไม่ให้ซ้อนกัน
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            // Icon
            if (icon is IconData)
              Icon(icon, size: AppIconSize.lg, color: iconColor)
            else
              HugeIcon(icon: icon, size: AppIconSize.lg, color: iconColor),
            AppSpacing.horizontalGapSm,

            // ข้อความ — ใช้ Expanded เพื่อไม่ให้ล้น
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySmall.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        // ขอบมน ตาม design system
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smallRadius,
        ),
        margin: AppSpacing.paddingMd,
        duration: duration,
        action: action,
        // ลบปุ่ม X default ออก (ปิดโดย swipe หรือหมดเวลา)
        showCloseIcon: false,
      ),
    );
  }
}
