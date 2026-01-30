import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// DayBadges - Widget สำหรับแสดง badges วันในสัปดาห์หรือวันที่ในเดือน
/// ใช้แทน pattern ที่ซ้ำกันใน task_card.dart และ medicine_card.dart
///
/// ตัวอย่างการใช้งาน:
/// ```dart
/// // แสดงวันในสัปดาห์
/// DayBadges.weekdays(
///   selectedDays: ['จันทร์', 'พุธ', 'ศุกร์'],
/// )
///
/// // แสดงวันที่ในเดือน
/// DayBadges.dates(
///   selectedDates: [1, 15, 30],
/// )
/// ```
class DayBadges extends StatelessWidget {
  /// รายการ labels ที่จะแสดง
  final List<String> labels;

  /// รายการสีสำหรับแต่ละ label
  final List<Color> colors;

  /// ขนาด badge (default: 22)
  final double size;

  /// ระยะห่างระหว่าง badges (default: 4)
  final double spacing;

  const DayBadges._({
    required this.labels,
    required this.colors,
    this.size = 22,
    this.spacing = 4,
  });

  /// Factory สำหรับแสดงวันในสัปดาห์ (จันทร์-อาทิตย์)
  /// แต่ละวันมีสีเฉพาะตัว
  factory DayBadges.weekdays({
    required List<String> selectedDays,
    double size = 22,
    double spacing = 4,
  }) {
    // สีสำหรับแต่ละวัน
    const dayColors = {
      'จันทร์': Color(0xFFF1EF99), // เหลือง
      'อังคาร': Color(0xFFFFB6C1), // ชมพู
      'พุธ': Color(0xFF90EE90), // เขียว
      'พฤหัสบดี': Color(0xFFFFD4B2), // ส้ม
      'ศุกร์': Color(0xFFADD8E6), // ฟ้า
      'เสาร์': Color(0xFFDDA0DD), // ม่วง
      'อาทิตย์': Color(0xFFFF6B6B), // แดง
    };

    // ตัวย่อสำหรับแต่ละวัน
    const dayAbbr = {
      'จันทร์': 'จ',
      'อังคาร': 'อ',
      'พุธ': 'พ',
      'พฤหัสบดี': 'พฤ',
      'ศุกร์': 'ศ',
      'เสาร์': 'ส',
      'อาทิตย์': 'อา',
    };

    final labelList = selectedDays
        .map((day) => dayAbbr[day] ?? day.substring(0, 1))
        .toList();
    final colorList = selectedDays
        .map((day) => dayColors[day] ?? AppColors.accent1)
        .toList();

    return DayBadges._(
      labels: labelList,
      colors: colorList,
      size: size,
      spacing: spacing,
    );
  }

  /// Factory สำหรับแสดงวันที่ในเดือน (1-31)
  /// ใช้สี tagPassedBg (เขียวอ่อน) สำหรับทุกวัน
  factory DayBadges.dates({
    required List<int> selectedDates,
    Color? badgeColor,
    double size = 22,
    double spacing = 4,
  }) {
    final color = badgeColor ?? AppColors.tagPassedBg;
    final labelList = selectedDates.map((date) => date.toString()).toList();
    final colorList = List.filled(selectedDates.length, color);

    return DayBadges._(
      labels: labelList,
      colors: colorList,
      size: size,
      spacing: spacing,
    );
  }

  /// Factory สำหรับแสดง custom badges
  factory DayBadges.custom({
    required List<String> labels,
    required List<Color> colors,
    double size = 22,
    double spacing = 4,
  }) {
    assert(labels.length == colors.length);
    return DayBadges._(
      labels: labels,
      colors: colors,
      size: size,
      spacing: spacing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(labels.length, (index) {
        return Container(
          margin: EdgeInsets.only(right: spacing),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colors[index],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              labels[index],
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontSize: size * 0.4, // ปรับขนาด font ตาม size
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }
}
