import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Stacked horizontal progress bar แสดงสัดส่วนความตรงเวลา + dead air
///
/// แสดง 4 ส่วน:
/// - เขียว: ตรงเวลา
/// - เหลือง: สายนิดหน่อย
/// - แดง: สายมาก
/// - เทา: อู้งาน (dead air)
class StackedProgressBar extends StatelessWidget {
  final double onTimePercent; // เขียว
  final double slightlyLatePercent; // เหลือง
  final double veryLatePercent; // แดง
  final double deadAirPercent; // เทา (อู้งาน)
  final double height;
  final double borderRadius;

  const StackedProgressBar({
    super.key,
    required this.onTimePercent,
    required this.slightlyLatePercent,
    required this.veryLatePercent,
    required this.deadAirPercent,
    this.height = 12,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    // คำนวณ normalized percentages สำหรับ stacked bar
    // รวม task percentages เท่านั้น (ไม่รวม dead air ใน task bar)
    final taskTotal = onTimePercent + slightlyLatePercent + veryLatePercent;

    // ถ้าไม่มี tasks เลย แสดง empty bar
    if (taskTotal == 0 && deadAirPercent == 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.alternate.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    // แบ่ง bar เป็น 2 ส่วน: tasks (100% - deadAir%) และ deadAir%
    // แต่ถ้า dead air > 100% ก็ cap ไว้
    final effectiveDeadAirPercent = deadAirPercent.clamp(0, 100);
    final taskBarPercent = 100 - effectiveDeadAirPercent;

    // Calculate flex values for task segments within task bar
    final onTimeFlex = (taskTotal > 0) ? (onTimePercent / taskTotal * taskBarPercent) : 0.0;
    final slightlyLateFlex = (taskTotal > 0) ? (slightlyLatePercent / taskTotal * taskBarPercent) : 0.0;
    final veryLateFlex = (taskTotal > 0) ? (veryLatePercent / taskTotal * taskBarPercent) : 0.0;

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: AppColors.alternate.withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          // On Time (Soft Teal)
          if (onTimeFlex > 0)
            Flexible(
              flex: (onTimeFlex * 100).round(),
              child: Container(
                color: AppColors.progressOnTime,
              ),
            ),

          // Slightly Late (Soft Amber)
          if (slightlyLateFlex > 0)
            Flexible(
              flex: (slightlyLateFlex * 100).round(),
              child: Container(
                color: AppColors.progressSlightlyLate,
              ),
            ),

          // Very Late (Soft Red)
          if (veryLateFlex > 0)
            Flexible(
              flex: (veryLateFlex * 100).round(),
              child: Container(
                color: AppColors.progressVeryLate,
              ),
            ),

          // Dead Air (Gray)
          if (effectiveDeadAirPercent > 0)
            Flexible(
              flex: (effectiveDeadAirPercent * 100).round(),
              child: Container(
                color: AppColors.alternate,
              ),
            ),
        ],
      ),
    );
  }
}

/// Legend item สำหรับแสดงคำอธิบายสี
class StackedBarLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const StackedBarLegendItem({
    super.key,
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}
