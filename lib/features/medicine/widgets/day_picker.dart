import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Day Picker - เลือกวัน 3 วัน (เลื่อนตาม selectedDate)
/// มีปุ่มเลือกวันจาก calendar และปุ่มกลับวันนี้
class DayPicker extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const DayPicker({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  // Thai month names - สำหรับแสดงเดือน
  static const _thaiMonths = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน',
    'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม',
    'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  // Thai short month names - สำหรับแสดงวันที่
  static const _thaiShortMonths = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];

  // Thai day names
  static const _thaiDays = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัส', 'ศุกร์', 'เสาร์', 'อาทิตย์'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final prevDay = selectedDate.subtract(Duration(days: 1));
    final nextDay = selectedDate.add(Duration(days: 1));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // แถวบน: ปุ่มเลือกวัน + ปุ่มวันนี้
        Row(
          children: [
            // ปุ่มเลือกวันจาก calendar
            Expanded(
              child: _buildCalendarButton(context),
            ),
            SizedBox(width: 8),
            // ปุ่มกลับวันนี้
            Expanded(
              child: _buildTodayButton(context, today),
            ),
          ],
        ),
        SizedBox(height: 8),
        // แถวล่าง: 3 วัน
        Row(
          children: [
            // วันก่อนหน้า
            Expanded(
              child: _buildDayButton(
                context: context,
                date: prevDay,
                isSelected: false,
                isToday: _isSameDay(prevDay, today),
                showArrow: true,
                isLeftArrow: true,
              ),
            ),
            SizedBox(width: 8),
            // วันที่เลือก (ตรงกลาง)
            Expanded(
              child: _buildDayButton(
                context: context,
                date: selectedDate,
                isSelected: true,
                isToday: _isSameDay(selectedDate, today),
              ),
            ),
            SizedBox(width: 8),
            // วันถัดไป
            Expanded(
              child: _buildDayButton(
                context: context,
                date: nextDay,
                isSelected: false,
                isToday: _isSameDay(nextDay, today),
                showArrow: true,
                isLeftArrow: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ปุ่มเลือกวันจาก calendar
  Widget _buildCalendarButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDatePicker(context),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          border: Border.all(color: AppColors.accent1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.calendar_1,
              size: 18,
              color: AppColors.textSecondary,
            ),
            SizedBox(width: 8),
            Text(
              _formatMonthYear(selectedDate),
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ปุ่มกลับวันนี้
  Widget _buildTodayButton(BuildContext context, DateTime today) {
    final isToday = _isSameDay(selectedDate, today);

    return GestureDetector(
      onTap: isToday ? null : () => onDateChanged(today),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isToday ? AppColors.accent1 : AppColors.secondaryBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          border: Border.all(
            color: isToday ? AppColors.primary : AppColors.accent1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.calendar_tick,
              size: 18,
              color: isToday ? AppColors.primary : AppColors.textSecondary,
            ),
            SizedBox(width: 8),
            Text(
              'วันนี้',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
                color: isToday ? AppColors.primary : AppColors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.secondaryBackground,
              onSurface: AppColors.primaryText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onDateChanged(picked);
    }
  }

  Widget _buildDayButton({
    required BuildContext context,
    required DateTime date,
    required bool isSelected,
    required bool isToday,
    bool showArrow = false,
    bool isLeftArrow = false,
  }) {
    final isSunday = date.weekday == DateTime.sunday;
    final dayOfWeek = _getDayOfWeek(date);
    final label = _getRelativeLabel(date);

    return GestureDetector(
      onTap: () => onDateChanged(date),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isToday
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.inputBorder,
            width: isToday && !isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Left arrow
            if (showArrow && isLeftArrow)
              Icon(
                Iconsax.arrow_left_2,
                size: 12,
                color: isToday ? AppColors.primary : AppColors.textSecondary,
              ),

            // Content
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ชื่อวัน (อาทิตย์ สีแดง)
                  Text(
                    dayOfWeek,
                    style: AppTypography.caption.copyWith(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : isSunday
                              ? const Color(0xFFEF4444)
                              : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 1),
                  // วันที่
                  Text(
                    _formatDate(date),
                    style: AppTypography.bodySmall.copyWith(
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? AppColors.primary
                              : AppColors.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // label (วันนี้/เมื่อวาน/พรุ่งนี้)
                  if (label.isNotEmpty) ...[
                    SizedBox(height: 1),
                    Text(
                      label,
                      style: AppTypography.caption.copyWith(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : isToday
                                ? AppColors.primary
                                : AppColors.textSecondary,
                        fontSize: 9,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            // Right arrow
            if (showArrow && !isLeftArrow)
              Icon(
                Iconsax.arrow_right_3,
                size: 12,
                color: isToday ? AppColors.primary : AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  String _formatMonthYear(DateTime date) {
    final buddhistYear = date.year + 543;
    return '${_thaiMonths[date.month - 1]} $buddhistYear';
  }

  String _getRelativeLabel(DateTime date) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final diff = dateOnly.difference(todayOnly).inDays;

    switch (diff) {
      case -1:
        return 'เมื่อวาน';
      case 0:
        return 'วันนี้';
      case 1:
        return 'พรุ่งนี้';
      default:
        return '';
    }
  }

  String _getDayOfWeek(DateTime date) {
    return _thaiDays[date.weekday - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_thaiShortMonths[date.month - 1]}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
