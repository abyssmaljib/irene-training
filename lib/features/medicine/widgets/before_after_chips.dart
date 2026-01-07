import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Widget สำหรับเลือก ก่อน/หลังอาหาร
/// เป็น single-select chips: ก่อนอาหาร, หลังอาหาร
///
/// ใช้สำหรับระบุว่าให้ยาก่อนหรือหลังอาหาร (เลือกได้อันเดียว หรือไม่เลือกเลยก็ได้)
class BeforeAfterChips extends StatelessWidget {
  const BeforeAfterChips({
    super.key,
    required this.selectedValues,
    required this.onToggle,
    this.onClear,
    this.enabled = true,
  });

  /// ค่าที่เลือกไว้ (ปกติจะมีแค่ 0 หรือ 1 ค่า)
  final List<String> selectedValues;

  /// Callback เมื่อ toggle
  /// [value] = 'ก่อนอาหาร' หรือ 'หลังอาหาร'
  final void Function(String value) onToggle;

  /// Callback เมื่อต้องการล้างค่า
  final VoidCallback? onClear;

  /// สามารถกดได้หรือไม่
  final bool enabled;

  /// ตัวเลือกทั้งหมด
  static const List<String> options = ['ก่อนอาหาร', 'หลังอาหาร'];

  /// ดึง icon ตาม option
  dynamic _getIconForOption(String option) {
    switch (option) {
      case 'ก่อนอาหาร':
        return HugeIcons.strokeRoundedArrowLeftDouble;
      case 'หลังอาหาร':
        return HugeIcons.strokeRoundedArrowRightDouble;
      default:
        return HugeIcons.strokeRoundedClock01;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chips
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: options.map((option) {
                  final isSelected = selectedValues.contains(option);
                  final icon = _getIconForOption(option);
                  return _BeforeAfterChip(
                    label: option,
                    icon: icon,
                    isSelected: isSelected,
                    onTap: enabled ? () => onToggle(option) : null,
                  );
                }).toList(),
              ),
            ),
            // ปุ่มล้าง (ถ้ามีการเลือก)
            if (selectedValues.isNotEmpty && onClear != null)
              GestureDetector(
                onTap: enabled ? onClear : null,
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

/// Chip สำหรับ ก่อน/หลังอาหาร (พร้อม icon)
class _BeforeAfterChip extends StatelessWidget {
  const _BeforeAfterChip({
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
    // ใช้สีต่างกันสำหรับ ก่อน/หลัง
    // - ก่อนอาหาร: สีส้ม (pastelOrange) - สื่อถึงช่วงก่อนมื้ออาหาร
    // - หลังอาหาร: สีเขียว (pastelDarkGreen1) - สื่อถึงช่วงหลังมื้ออาหาร
    final Color selectedColor = label == 'ก่อนอาหาร'
        ? AppColors.pastelOrange   // สีส้มสำหรับก่อนอาหาร
        : AppColors.pastelDarkGreen1;   // สีเขียวสำหรับหลังอาหาร

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
            color: isSelected ? selectedColor : AppColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? selectedColor : AppColors.alternate,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              HugeIcon(
                icon: icon,
                color: isSelected
                    ? (label == 'ก่อนอาหาร'
                        ? AppColors.tagUpdateText  // น้ำตาลส้มเข้ม
                        : AppColors.tagPassedText) // เขียวเข้ม
                    : AppColors.secondaryText,
                size: 18,
              ),
              const SizedBox(width: 6),
              // Label
              Text(
                label,
                style: AppTypography.body.copyWith(
                  // เมื่อเลือก: ใช้สีเข้มที่ contrast กับ background pastel ได้ดี
                  // - ก่อนอาหาร (สีส้ม): ใช้ text สีน้ำตาลเข้ม
                  // - หลังอาหาร (สีเขียว): ใช้ text สีเขียวเข้ม
                  color: isSelected
                      ? (label == 'ก่อนอาหาร'
                          ? AppColors.tagUpdateText  // น้ำตาลส้มเข้ม
                          : AppColors.tagPassedText) // เขียวเข้ม
                      : AppColors.textPrimary,
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
