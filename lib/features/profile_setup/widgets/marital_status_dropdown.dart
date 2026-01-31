import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// รายการสถานภาพสมรส
const List<String> maritalStatuses = [
  'โสด',
  'แต่งงาน',
  'หย่าร้าง',
];

/// Dropdown สำหรับเลือกสถานภาพสมรส
/// มี style ตรงกับ design system ของแอป
class MaritalStatusDropdown extends StatelessWidget {
  /// ค่าที่เลือกอยู่
  final String? value;

  /// Callback เมื่อเลือกค่าใหม่
  final ValueChanged<String?> onChanged;

  /// Label แสดงด้านบน
  final String? label;

  /// Hint text เมื่อยังไม่เลือก
  final String hintText;

  /// มี error หรือไม่
  final bool hasError;

  /// Error message
  final String? errorText;

  /// Disabled state
  final bool enabled;

  const MaritalStatusDropdown({
    super.key,
    this.value,
    required this.onChanged,
    this.label,
    this.hintText = 'เลือกสถานภาพ',
    this.hasError = false,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.label.copyWith(
              color: hasError ? AppColors.error : AppColors.primaryText,
            ),
          ),
          AppSpacing.verticalGapXs,
        ],

        // Dropdown
        Container(
          decoration: BoxDecoration(
            color: enabled ? AppColors.primaryBackground : AppColors.alternate,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError
                  ? AppColors.error
                  : (enabled ? Colors.transparent : AppColors.alternate),
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedUserLove02,
                    color: AppColors.secondaryText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    hintText,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              isExpanded: true,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                color: enabled ? AppColors.secondaryText : AppColors.alternate,
                size: 20,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Colors.white,
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 14,
              ),
              // แสดง icon + label เมื่อเลือกแล้ว
              selectedItemBuilder: (context) {
                return maritalStatuses.map((status) {
                  return Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedUserLove02,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        status,
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
              onChanged: enabled ? onChanged : null,
              items: maritalStatuses.map((status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
            ),
          ),
        ),

        // Error text
        if (errorText != null && hasError) ...[
          AppSpacing.verticalGapXs,
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlertCircle,
                color: AppColors.error,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
