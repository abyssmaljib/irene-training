import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// StatusBadge - Widget สำหรับแสดง badge/tag ที่ใช้ซ้ำได้ทั้ง app
/// รองรับทั้งแบบ text-only และ icon + text
///
/// ตัวอย่างการใช้งาน:
/// ```dart
/// // แบบ text-only
/// StatusBadge(
///   label: 'Zone A',
///   backgroundColor: AppColors.accent1,
///   textColor: AppColors.primary,
/// )
///
/// // แบบ icon + text
/// StatusBadge(
///   label: 'พนักงาน',
///   icon: HugeIcons.strokeRoundedUserAccount,
///   backgroundColor: Color(0xFFE8DEF8),
///   textColor: Color(0xFF6750A4),
/// )
///
/// // แบบ hashtag
/// StatusBadge.hashtag(label: 'สุขภาพ')
/// ```
class StatusBadge extends StatelessWidget {
  /// ข้อความที่แสดงใน badge
  final String label;

  /// สีพื้นหลัง
  final Color backgroundColor;

  /// สีตัวอักษรและ icon
  final Color textColor;

  /// Icon ที่แสดงด้านหน้า label (optional)
  /// รองรับทั้ง IconData และ HugeIcon widget
  final dynamic icon;

  /// ขนาดตัวอักษร (default: 10)
  final double fontSize;

  /// Padding แนวนอน (default: 6)
  final double horizontalPadding;

  /// Padding แนวตั้ง (default: 2)
  final double verticalPadding;

  /// Border radius (default: 4)
  final double borderRadius;

  /// Font weight (default: normal)
  final FontWeight? fontWeight;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    this.fontSize = 10,
    this.horizontalPadding = 6,
    this.verticalPadding = 2,
    this.borderRadius = 4,
    this.fontWeight,
  });

  /// Factory สำหรับ hashtag style (#tag)
  /// ใช้สี primary โดยอัตโนมัติ
  factory StatusBadge.hashtag({
    required String label,
    double fontSize = 10,
  }) {
    return StatusBadge(
      label: '#$label',
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      textColor: AppColors.primary,
      fontSize: fontSize,
      horizontalPadding: 8,
      verticalPadding: 4,
      fontWeight: FontWeight.w500,
    );
  }

  /// Factory สำหรับ zone badge
  factory StatusBadge.zone({required String zoneName}) {
    return StatusBadge(
      label: zoneName,
      backgroundColor: AppColors.accent1,
      textColor: AppColors.primary,
    );
  }

  /// Factory สำหรับ role badge
  factory StatusBadge.role({
    required String roleName,
    dynamic icon,
  }) {
    return StatusBadge(
      label: roleName,
      icon: icon,
      backgroundColor: const Color(0xFFE8DEF8), // สีม่วงอ่อน pastel
      textColor: const Color(0xFF6750A4), // สีม่วงเข้ม
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: icon != null ? _buildWithIcon() : _buildTextOnly(),
    );
  }

  Widget _buildTextOnly() {
    return Text(
      label,
      style: AppTypography.caption.copyWith(
        color: textColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }

  Widget _buildWithIcon() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // รองรับทั้ง IconData และ Widget (เช่น HugeIcon)
        if (icon is IconData)
          Icon(icon as IconData, size: fontSize + 2, color: textColor)
        else if (icon is Widget)
          icon as Widget,
        const SizedBox(width: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: textColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }
}
