import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Widget สำหรับเลือกเวลาที่ให้ยา (BLDB)
/// เป็น multi-select chips: เช้า, กลางวัน, เย็น, ก่อนนอน
///
/// ใช้สำหรับเลือกว่าให้ยาในเวลาไหนบ้าง (เลือกได้หลายเวลา)
class TimeSlotChips extends StatelessWidget {
  const TimeSlotChips({
    super.key,
    required this.selectedTimes,
    required this.onToggle,
    this.onSelectAll,
    this.onClearAll,
    this.showSelectAll = true,
    this.enabled = true,
  });

  /// เวลาที่เลือกไว้
  final List<String> selectedTimes;

  /// Callback เมื่อ toggle เวลา
  /// [time] = 'เช้า', 'กลางวัน', 'เย็น', 'ก่อนนอน'
  final void Function(String time) onToggle;

  /// Callback เมื่อกดเลือกทั้งหมด
  final VoidCallback? onSelectAll;

  /// Callback เมื่อกดล้างทั้งหมด
  final VoidCallback? onClearAll;

  /// แสดงปุ่ม "เลือกทั้งหมด" / "ล้าง" หรือไม่
  final bool showSelectAll;

  /// สามารถกดได้หรือไม่
  final bool enabled;

  /// รายการเวลาทั้งหมด
  static const List<String> allTimes = ['เช้า', 'กลางวัน', 'เย็น', 'ก่อนนอน'];

  /// ดึง icon ตามเวลา
  dynamic _getIconForTime(String time) {
    switch (time) {
      case 'เช้า':
        return HugeIcons.strokeRoundedSunrise;
      case 'กลางวัน':
        return HugeIcons.strokeRoundedSun03;
      case 'เย็น':
        return HugeIcons.strokeRoundedSunset;
      case 'ก่อนนอน':
        return HugeIcons.strokeRoundedMoon02;
      default:
        return HugeIcons.strokeRoundedTime01;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header พร้อมปุ่มเลือกทั้งหมด/ล้าง
        if (showSelectAll)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // ปุ่มเลือกทั้งหมด
                if (selectedTimes.length < allTimes.length && onSelectAll != null)
                  _ActionButton(
                    label: 'เลือกทั้งหมด',
                    onTap: enabled ? onSelectAll : null,
                  ),
                // ปุ่มล้าง
                if (selectedTimes.isNotEmpty && onClearAll != null) ...[
                  if (selectedTimes.length < allTimes.length)
                    const SizedBox(width: AppSpacing.sm),
                  _ActionButton(
                    label: 'ล้าง',
                    onTap: enabled ? onClearAll : null,
                  ),
                ],
              ],
            ),
          ),

        // Chips + ปุ่มล้าง
        Row(
          children: [
            // Chips
            Expanded(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: allTimes.map((time) {
                  final isSelected = selectedTimes.contains(time);
                  final icon = _getIconForTime(time);
                  return _TimeChip(
                    label: time,
                    icon: icon,
                    isSelected: isSelected,
                    onTap: enabled ? () => onToggle(time) : null,
                  );
                }).toList(),
              ),
            ),
            // ปุ่มล้าง (แสดงเมื่อมีการเลือก และมี callback)
            if (selectedTimes.isNotEmpty && onClearAll != null)
              GestureDetector(
                onTap: enabled ? onClearAll : null,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(
                    'ล้าง',
                    style: AppTypography.bodySmall.copyWith(
                      color: enabled ? AppColors.primary : AppColors.secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Chip สำหรับแต่ละเวลา (พร้อม icon)
class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final dynamic icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : AppColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.alternate,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              HugeIcon(
                icon: icon,
                color: isSelected ? Colors.white : AppColors.secondaryText,
                size: 18,
              ),
              const SizedBox(width: 6),
              // Label
              Text(
                label,
                style: AppTypography.body.copyWith(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ปุ่ม action เล็กๆ (เลือกทั้งหมด / ล้าง)
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: onTap != null ? AppColors.primary : AppColors.secondaryText,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
