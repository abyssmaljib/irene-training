import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'buttons.dart';

/// ErrorStateWidget — แสดงเมื่อโหลดข้อมูลไม่สำเร็จ หรือเกิดข้อผิดพลาด
/// มีปุ่ม "ลองใหม่" (retry) ในตัว
///
/// มีหลาย variant:
/// 1. **Default** — icon + ข้อความ + ปุ่ม retry
/// 2. **Network** — สำหรับ connection error
/// 3. **Permission** — สำหรับไม่มีสิทธิ์
/// 4. **Compact** — version เล็กสำหรับ embed ใน section
///
/// ตัวอย่างการใช้งาน:
/// ```dart
/// // แบบพื้นฐาน
/// ErrorStateWidget(
///   onRetry: () => ref.invalidate(dataProvider),
/// )
///
/// // แบบ network error
/// ErrorStateWidget.network(
///   onRetry: () => fetchData(),
/// )
///
/// // แบบ compact ใน section
/// ErrorStateWidget(
///   message: 'โหลดข้อมูลไม่สำเร็จ',
///   compact: true,
///   onRetry: () => reload(),
/// )
/// ```
class ErrorStateWidget extends StatelessWidget {
  /// ข้อความ error หลัก (default: 'เกิดข้อผิดพลาด')
  final String message;

  /// ข้อความรายละเอียด error (optional)
  final String? detail;

  /// Callback เมื่อกดปุ่ม "ลองใหม่"
  /// ถ้า null → ไม่แสดงปุ่ม
  final VoidCallback? onRetry;

  /// Text สำหรับปุ่ม retry (default: 'ลองใหม่')
  final String retryText;

  /// Icon ที่แสดง (default: HugeIcons.strokeRoundedAlert02)
  /// รองรับทั้ง IconData และ HugeIcons
  final dynamic icon;

  /// Path ของรูปภาพ (optional — ใช้แทน icon เช่น รูปแมวเศร้า)
  final String? imagePath;

  /// โหมดกะทัดรัด — ลดขนาดสำหรับ embed ใน section/card
  final bool compact;

  const ErrorStateWidget({
    super.key,
    this.message = 'เกิดข้อผิดพลาด',
    this.detail,
    this.onRetry,
    this.retryText = 'ลองใหม่',
    this.icon = HugeIcons.strokeRoundedAlert02,
    this.imagePath,
    this.compact = false,
  });

  /// Network error — สำหรับเมื่อไม่สามารถเชื่อมต่อ internet ได้
  const ErrorStateWidget.network({
    super.key,
    this.onRetry,
    this.compact = false,
  })  : message = 'ไม่สามารถเชื่อมต่อได้',
        detail = 'กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต',
        retryText = 'ลองใหม่',
        icon = HugeIcons.strokeRoundedWifiDisconnected04,
        imagePath = null;

  /// Permission error — สำหรับเมื่อไม่มีสิทธิ์เข้าถึง
  const ErrorStateWidget.permission({
    super.key,
    this.onRetry,
    this.compact = false,
  })  : message = 'ไม่มีสิทธิ์เข้าถึง',
        detail = 'กรุณาติดต่อผู้ดูแลระบบ',
        retryText = 'ลองใหม่',
        icon = HugeIcons.strokeRoundedSecurityLock,
        imagePath = null;

  @override
  Widget build(BuildContext context) {
    final verticalGap =
        compact ? AppSpacing.verticalGapSm : AppSpacing.verticalGapMd;

    return Center(
      child: Padding(
        padding: compact ? AppSpacing.paddingMd : AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            // Icon หรือรูปภาพ
            _buildVisual(),
            verticalGap,

            // ข้อความ error หลัก
            Text(
              message,
              style: (compact ? AppTypography.body : AppTypography.title)
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),

            // ข้อความรายละเอียด
            if (detail != null) ...[
              AppSpacing.verticalGapXs,
              Text(
                detail!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // ปุ่ม retry
            if (onRetry != null) ...[
              verticalGap,
              compact
                  // Compact mode — ใช้ text button เล็ก
                  ? AppTextButton(
                      text: retryText,
                      icon: HugeIcons.strokeRoundedRefresh,
                      onPressed: onRetry,
                    )
                  // Full mode — ใช้ secondary button
                  : SecondaryButton(
                      text: retryText,
                      icon: HugeIcons.strokeRoundedRefresh,
                      onPressed: onRetry,
                    ),
            ],
          ],
        ),
      ),
    );
  }

  /// สร้าง icon หรือรูปภาพ
  Widget _buildVisual() {
    // ถ้ามี imagePath → แสดงรูป
    if (imagePath != null) {
      final size = compact ? 80.0 : 120.0;
      return Image.asset(
        imagePath!,
        width: size,
        height: size,
      );
    }

    // แสดง icon ในวงกลมพื้นหลังสีแดงอ่อน
    final iconSize = compact ? AppIconSize.xxl : AppIconSize.xxxl;
    final containerSize = iconSize * 1.8;

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        // พื้นหลังสีแดงอ่อน — สื่อว่ามี error
        color: AppColors.tagFailedBg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: icon is IconData
            ? Icon(
                icon as IconData,
                size: iconSize,
                color: AppColors.tagFailedText,
              )
            : HugeIcon(
                icon: icon,
                size: iconSize,
                color: AppColors.tagFailedText,
              ),
      ),
    );
  }
}
