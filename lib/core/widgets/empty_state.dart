import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// EmptyStateWidget - แสดงเมื่อไม่มีข้อมูล
/// มีหลาย variant ให้เลือกใช้ตามสถานการณ์:
///
/// 1. **Default** — รูปแมว + ข้อความ (เต็มหน้าจอ)
/// ```dart
/// EmptyStateWidget(message: 'ยังไม่มีข้อมูล')
/// ```
///
/// 2. **Icon variant** — ใช้ icon แทนรูป (กะทัดรัดกว่า)
/// ```dart
/// EmptyStateWidget.icon(
///   message: 'ยังไม่มีงาน',
///   icon: HugeIcons.strokeRoundedTask01,
/// )
/// ```
///
/// 3. **No results** — สำหรับค้นหาไม่พบ
/// ```dart
/// EmptyStateWidget.noResults(searchTerm: 'สมศรี')
/// ```
///
/// 4. **Compact** — version เล็กสำหรับ embed ใน section/tab
/// ```dart
/// EmptyStateWidget.compact(message: 'ยังไม่มีรายการ')
/// ```
class EmptyStateWidget extends StatelessWidget {
  /// ข้อความหลัก
  final String message;

  /// ข้อความรอง (รายละเอียดเพิ่มเติม)
  final String? subMessage;

  /// Path ของรูปภาพ (default: แมวนอนชิลๆ)
  final String? imagePath;

  /// ขนาดรูปภาพ (default: 200)
  final double imageSize;

  /// Icon แทนรูปภาพ (ถ้าระบุจะใช้ icon แทน image)
  /// รองรับทั้ง IconData และ HugeIcons
  final dynamic icon;

  /// ขนาด icon (default: AppIconSize.display = 64)
  final double iconSize;

  /// สี icon (default: AppColors.textSecondary)
  final Color? iconColor;

  /// ปุ่ม action (เช่น ปุ่ม "สร้างใหม่")
  final Widget? action;

  /// โหมดกะทัดรัด — ลดขนาดและ spacing สำหรับ embed ใน section
  final bool compact;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.subMessage,
    this.imagePath,
    this.imageSize = 200,
    this.icon,
    this.iconSize = AppIconSize.display,
    this.iconColor,
    this.action,
    this.compact = false,
  });

  /// Icon variant — ใช้ icon แทนรูปภาพ
  /// เหมาะสำหรับเมื่อไม่ต้องการรูปแมว แค่ icon + ข้อความ
  const EmptyStateWidget.icon({
    super.key,
    required this.message,
    required this.icon,
    this.subMessage,
    this.action,
    this.iconSize = AppIconSize.display,
    this.iconColor,
  })  : imagePath = null,
        imageSize = 0,
        compact = false;

  /// No results variant — สำหรับหน้าค้นหาที่ไม่พบผลลัพธ์
  /// แสดง icon search + ข้อความ "ไม่พบข้อมูล"
  /// ใช้ factory เพราะมี conditional logic (searchTerm)
  factory EmptyStateWidget.noResults({
    Key? key,
    String? searchTerm,
    Widget? action,
  }) {
    return EmptyStateWidget(
      key: key,
      message: searchTerm != null
          ? 'ไม่พบผลลัพธ์สำหรับ "$searchTerm"'
          : 'ไม่พบข้อมูลที่ค้นหา',
      subMessage: 'ลองเปลี่ยนคำค้นหาหรือตัวกรอง',
      icon: HugeIcons.strokeRoundedSearch01,
      iconSize: AppIconSize.xxxl,
      iconColor: AppColors.textSecondary,
      action: action,
    );
  }

  /// Compact variant — version เล็กสำหรับ embed ใน section/tab
  /// spacing น้อยลง, ข้อความเล็กลง
  const EmptyStateWidget.compact({
    super.key,
    required this.message,
    this.icon,
    this.subMessage,
    this.action,
    this.iconColor,
  })  : imagePath = null,
        imageSize = 0,
        iconSize = AppIconSize.xxl,
        compact = true;

  @override
  Widget build(BuildContext context) {
    // Compact mode — ใช้ spacing น้อยลง
    final verticalGap =
        compact ? AppSpacing.verticalGapSm : AppSpacing.verticalGapMd;
    final messageStyle = compact
        ? AppTypography.bodySmall
            .copyWith(color: AppColors.secondaryText)
        : AppTypography.body
            .copyWith(color: AppColors.secondaryText);

    return Center(
      child: Padding(
        // Compact mode ไม่ต้อง padding มาก
        padding: compact
            ? AppSpacing.paddingMd
            : AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            // แสดง icon หรือ image
            if (icon != null) ...[
              _buildIcon(),
              verticalGap,
            ] else ...[
              Image.asset(
                imagePath ?? 'assets/images/relax_cat.webp',
                width: compact ? imageSize * 0.6 : imageSize,
                height: compact ? imageSize * 0.6 : imageSize,
              ),
              verticalGap,
            ],

            // ข้อความหลัก
            Text(
              message,
              style: messageStyle,
              textAlign: TextAlign.center,
            ),

            // ข้อความรอง
            if (subMessage != null) ...[
              AppSpacing.verticalGapXs,
              Text(
                subMessage!,
                style: AppTypography.bodySmall.copyWith(
                  color:
                      AppColors.secondaryText.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // ปุ่ม action
            if (action != null) ...[
              verticalGap,
              action!,
            ],
          ],
        ),
      ),
    );
  }

  /// สร้าง icon widget — รองรับทั้ง IconData และ HugeIcons
  Widget _buildIcon() {
    final color = iconColor ?? AppColors.textSecondary;

    // ใส่วงกลมพื้นหลังอ่อนๆ ให้ icon ดูโดดเด่นขึ้น
    return Container(
      width: iconSize * 1.8,
      height: iconSize * 1.8,
      decoration: BoxDecoration(
        // พื้นหลังสีเทาอ่อนมาก
        color: AppColors.background,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: icon is IconData
            ? Icon(icon as IconData, size: iconSize, color: color)
            : HugeIcon(icon: icon, size: iconSize, color: color),
      ),
    );
  }
}
