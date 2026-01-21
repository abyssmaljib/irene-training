import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
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

  /// Exit edit (post, etc.) - ยกเลิกการแก้ไข
  exitEdit,

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
  final dynamic icon; // icon เล็กด้านบน
  final Color iconColor;
  final Color iconBackgroundColor;
  final String imageAsset; // รูปแมว
  final double imageSize;

  const ConfirmDialogConfig({
    required this.title,
    required this.message,
    this.cancelText = 'ยกเลิก',
    this.confirmText = 'ยืนยัน',
    this.icon = HugeIcons.strokeRoundedAlert02,
    this.iconColor = AppColors.error,
    this.iconBackgroundColor = AppColors.tagFailedBg,
    this.imageAsset = 'assets/images/confirm_cat.webp',
    this.imageSize = 100,
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
          icon: HugeIcons.strokeRoundedLogout01,
        );
      case ConfirmDialogType.delete:
        return const ConfirmDialogConfig(
          title: 'ลบรายการ',
          message: 'คุณต้องการลบรายการนี้หรือไม่?\nการดำเนินการนี้ไม่สามารถยกเลิกได้',
          cancelText: 'ยกเลิก',
          confirmText: 'ลบ',
          icon: HugeIcons.strokeRoundedDelete01,
        );
      case ConfirmDialogType.exitQuiz:
        return const ConfirmDialogConfig(
          title: 'ออกจากการสอบ?',
          message: 'คุณต้องการออกจากการสอบหรือไม่?\nคำตอบที่ทำไว้จะไม่ถูกบันทึก',
          cancelText: 'ทำต่อ',
          confirmText: 'ออก',
          icon: HugeIcons.strokeRoundedCancel02,
        );
      case ConfirmDialogType.exitEdit:
        return const ConfirmDialogConfig(
          title: 'ยกเลิกการแก้ไข?',
          message: 'การแก้ไขจะหายไป\nต้องการดำเนินการต่อหรือไม่?',
          cancelText: 'กลับไปแก้ไข',
          confirmText: 'ยกเลิกการแก้ไข',
          icon: HugeIcons.strokeRoundedAlert02,
          iconColor: Color(0xFFF59E0B),
          iconBackgroundColor: AppColors.tagPendingBg,
        );
      case ConfirmDialogType.warning:
        return const ConfirmDialogConfig(
          title: 'คำเตือน',
          message: 'คุณแน่ใจหรือไม่ว่าต้องการดำเนินการนี้?',
          cancelText: 'ยกเลิก',
          confirmText: 'ยืนยัน',
          icon: HugeIcons.strokeRoundedAlert02,
          iconColor: Color(0xFFF59E0B),
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
  final bool isLoading;

  const ConfirmDialog({
    super.key,
    required this.config,
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
    dynamic icon,
    Color? iconColor,
    Color? iconBackgroundColor,
    String? imageAsset,
    double? imageSize,
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
      builder: (context) => ConfirmDialog(config: config),
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
            SizedBox(height: AppSpacing.lg),

            // Icon เล็ก (ด้านบน)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: config.iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HugeIcon(
                  icon: config.icon,
                  color: config.iconColor,
                  size: AppIconSize.lg,
                ),
              ),
            ),

            SizedBox(height: AppSpacing.sm),

            // Title
            Text(
              config.title,
              style: AppTypography.title.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppSpacing.xs),

            // Image (รูปแมว)
            Image.asset(
              config.imageAsset,
              width: config.imageSize,
              height: config.imageSize,
              fit: BoxFit.contain,
            ),

            SizedBox(height: AppSpacing.xs),

            // Message
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                config.message,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: AppSpacing.md),

            // Action buttons
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
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

// ============================================================
// Exit Create Dialog (3 ปุ่ม: กลับไปแก้ไข, บันทึกร่าง, ยกเลิก)
// ============================================================

/// ผลลัพธ์จาก ExitCreateDialog
enum ExitCreateResult {
  /// กลับไปแก้ไขต่อ
  continueEditing,

  /// บันทึกร่างแล้วปิด
  saveDraft,

  /// ยกเลิก (ไม่บันทึก) แล้วปิด
  discard,
}

/// Dialog สำหรับ exit create post (3 ปุ่ม)
class ExitCreateDialog extends StatelessWidget {
  final String title;
  final String message;
  final String continueText;
  final String saveDraftText;
  final String discardText;
  final dynamic icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String imageAsset;
  final double imageSize;

  const ExitCreateDialog({
    super.key,
    this.title = 'ยกเลิกการสร้างโพส?',
    this.message = 'ข้อมูลที่กรอกจะหายไป\nต้องการบันทึกร่างไว้ไหม?',
    this.continueText = 'กลับไปแก้ไข',
    this.saveDraftText = 'บันทึกร่าง',
    this.discardText = 'ยกเลิก',
    this.icon = HugeIcons.strokeRoundedAlert02,
    this.iconColor = const Color(0xFFF59E0B),
    this.iconBackgroundColor = AppColors.tagPendingBg,
    this.imageAsset = 'assets/images/confirm_cat.webp',
    this.imageSize = 100,
  });

  /// Show exit create dialog และ return ผลลัพธ์
  static Future<ExitCreateResult?> show(
    BuildContext context, {
    String? title,
    String? message,
    String? continueText,
    String? saveDraftText,
    String? discardText,
    dynamic icon,
    Color? iconColor,
    Color? iconBackgroundColor,
    String? imageAsset,
    double? imageSize,
  }) async {
    return showDialog<ExitCreateResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExitCreateDialog(
        title: title ?? 'ยกเลิกการสร้างโพส?',
        message: message ?? 'ข้อมูลที่กรอกจะหายไป\nต้องการบันทึกร่างไว้ไหม?',
        continueText: continueText ?? 'กลับไปแก้ไข',
        saveDraftText: saveDraftText ?? 'บันทึกร่าง',
        discardText: discardText ?? 'ยกเลิก',
        icon: icon ?? HugeIcons.strokeRoundedAlert02,
        iconColor: iconColor ?? const Color(0xFFF59E0B),
        iconBackgroundColor: iconBackgroundColor ?? AppColors.tagPendingBg,
        imageAsset: imageAsset ?? 'assets/images/confirm_cat.webp',
        imageSize: imageSize ?? 100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeRadius,
      ),
      backgroundColor: AppColors.surface,
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: AppSpacing.lg),

            // Icon เล็ก (ด้านบน)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  color: iconColor,
                  size: AppIconSize.lg,
                ),
              ),
            ),

            SizedBox(height: AppSpacing.sm),

            // Title
            Text(
              title,
              style: AppTypography.title.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppSpacing.xs),

            // Image (รูปแมว)
            Image.asset(
              imageAsset,
              width: imageSize,
              height: imageSize,
              fit: BoxFit.contain,
            ),

            SizedBox(height: AppSpacing.xs),

            // Message
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                message,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: AppSpacing.md),

            // Action buttons (3 ปุ่ม แบบ vertical)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  // กลับไปแก้ไข (Primary - เด่นที่สุด)
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: continueText,
                      onPressed: () =>
                          Navigator.pop(context, ExitCreateResult.continueEditing),
                    ),
                  ),

                  SizedBox(height: AppSpacing.sm),

                  // บันทึกร่าง และ ยกเลิก (อยู่แถวเดียวกัน)
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          text: saveDraftText,
                          onPressed: () =>
                              Navigator.pop(context, ExitCreateResult.saveDraft),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pop(context, ExitCreateResult.discard),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                          ),
                          child: Text(
                            discardText,
                            style: AppTypography.body.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
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

// ============================================================
// Restore Draft Dialog (2 ปุ่ม: เริ่มใหม่, ใช้บันทึกร่าง)
// ============================================================

/// Dialog สำหรับถาม user ว่าต้องการใช้ draft ที่บันทึกไว้หรือไม่
class RestoreDraftDialog extends StatelessWidget {
  final String title;
  final String message;
  final String discardText;
  final String restoreText;
  final dynamic icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String imageAsset;
  final double imageSize;

  const RestoreDraftDialog({
    super.key,
    this.title = 'มีบันทึกร่างค้างอยู่',
    this.message = 'ต้องการใช้ข้อมูลที่บันทึกไว้ต่อหรือไม่?',
    this.discardText = 'เริ่มใหม่',
    this.restoreText = 'ใช้บันทึกร่าง',
    this.icon = HugeIcons.strokeRoundedNote,
    this.iconColor = AppColors.primary,
    this.iconBackgroundColor = AppColors.tagPendingBg,
    this.imageAsset = 'assets/images/confirm_cat.webp',
    this.imageSize = 100,
  });

  /// Show restore draft dialog และ return ผลลัพธ์
  /// Returns true ถ้า user เลือก "ใช้บันทึกร่าง", false ถ้าเลือก "เริ่มใหม่"
  static Future<bool?> show(
    BuildContext context, {
    String? title,
    String? message,
    String? discardText,
    String? restoreText,
    dynamic icon,
    Color? iconColor,
    Color? iconBackgroundColor,
    String? imageAsset,
    double? imageSize,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RestoreDraftDialog(
        title: title ?? 'มีบันทึกร่างค้างอยู่',
        message: message ?? 'ต้องการใช้ข้อมูลที่บันทึกไว้ต่อหรือไม่?',
        discardText: discardText ?? 'เริ่มใหม่',
        restoreText: restoreText ?? 'ใช้บันทึกร่าง',
        icon: icon ?? HugeIcons.strokeRoundedNote,
        iconColor: iconColor ?? AppColors.primary,
        iconBackgroundColor: iconBackgroundColor ?? AppColors.tagPendingBg,
        imageAsset: imageAsset ?? 'assets/images/confirm_cat.webp',
        imageSize: imageSize ?? 100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeRadius,
      ),
      backgroundColor: AppColors.surface,
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: AppSpacing.lg),

            // Icon เล็ก (ด้านบน)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  color: iconColor,
                  size: AppIconSize.lg,
                ),
              ),
            ),

            SizedBox(height: AppSpacing.sm),

            // Title
            Text(
              title,
              style: AppTypography.title.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppSpacing.xs),

            // Image (รูปแมว)
            Image.asset(
              imageAsset,
              width: imageSize,
              height: imageSize,
              fit: BoxFit.contain,
            ),

            SizedBox(height: AppSpacing.xs),

            // Message
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                message,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: AppSpacing.md),

            // Action buttons (2 ปุ่ม)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  // เริ่มใหม่ (Secondary)
                  Expanded(
                    child: SecondaryButton(
                      text: discardText,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  // ใช้บันทึกร่าง (Primary)
                  Expanded(
                    child: PrimaryButton(
                      text: restoreText,
                      onPressed: () => Navigator.pop(context, true),
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
