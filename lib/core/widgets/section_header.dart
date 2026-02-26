import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// SectionHeader — หัวข้อ section ที่ใช้ซ้ำได้ทั้ง app
/// ใช้สำหรับแบ่ง section ใน list หรือ page
///
/// layout: [icon] [title] [count badge] .............. [action button]
///
/// ตัวอย่างการใช้งาน:
/// ```dart
/// // แบบพื้นฐาน — แค่ title
/// SectionHeader(title: 'รายการงาน')
///
/// // แบบเต็ม — icon + count + action
/// SectionHeader(
///   title: 'ผู้พักอาศัย',
///   icon: HugeIcons.strokeRoundedUser,
///   count: 12,
///   actionText: 'ดูทั้งหมด',
///   onActionTap: () => navigateToAll(),
/// )
///
/// // แบบ custom action widget
/// SectionHeader(
///   title: 'ตั้งค่า',
///   action: Switch(value: isEnabled, onChanged: toggle),
/// )
/// ```
class SectionHeader extends StatelessWidget {
  /// ข้อความหัวข้อ
  final String title;

  /// Icon ด้านซ้ายของ title (optional)
  /// รองรับทั้ง IconData และ HugeIcons
  final dynamic icon;

  /// สี icon (default: AppColors.primary)
  final Color? iconColor;

  /// ขนาด icon (default: AppIconSize.md)
  final double? iconSize;

  /// จำนวน items — แสดงเป็น badge ตัวเลขข้างๆ title
  final int? count;

  /// Custom action widget ด้านขวา (เช่น Switch, IconButton)
  /// ถ้าระบุ [action] จะไม่ใช้ [actionText] + [onActionTap]
  final Widget? action;

  /// Text สำหรับ action button ด้านขวา (เช่น "ดูทั้งหมด")
  /// ใช้คู่กับ [onActionTap]
  final String? actionText;

  /// Callback เมื่อกดปุ่ม action
  final VoidCallback? onActionTap;

  /// Padding รอบ header (default: horizontal 16)
  final EdgeInsets? padding;

  /// Style สำหรับ title (default: AppTypography.title)
  final TextStyle? titleStyle;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.iconSize,
    this.count,
    this.action,
    this.actionText,
    this.onActionTap,
    this.padding,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? AppSpacing.paddingHorizontalMd,
      child: Row(
        children: [
          // Icon ด้านซ้าย
          if (icon != null) ...[
            _buildIcon(),
            AppSpacing.horizontalGapSm,
          ],

          // Title text
          Text(
            title,
            style: titleStyle ?? AppTypography.title,
          ),

          // Count badge — วงกลมเล็กแสดงจำนวน
          if (count != null) ...[
            AppSpacing.horizontalGapSm,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent1,
                borderRadius: AppRadius.fullRadius,
              ),
              child: Text(
                '$count',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          // Spacer — ดัน action ไปขวาสุด
          const Spacer(),

          // Action button หรือ custom widget
          if (action != null)
            action!
          else if (actionText != null)
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                actionText!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// สร้าง icon widget — รองรับทั้ง IconData และ HugeIcons
  Widget _buildIcon() {
    final color = iconColor ?? AppColors.primary;
    final size = iconSize ?? AppIconSize.md;

    if (icon is IconData) {
      return Icon(icon as IconData, size: size, color: color);
    }
    return HugeIcon(icon: icon, size: size, color: color);
  }
}
