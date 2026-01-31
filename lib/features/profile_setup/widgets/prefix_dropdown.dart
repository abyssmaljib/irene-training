import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// รายการคำนำหน้าชื่อภาษาไทย
const List<String> thaiPrefixes = [
  'นาย',
  'นาง',
  'นางสาว',
  'ดร.',
  'ศ.',
  'รศ.',
  'ผศ.',
  'นพ.',
  'พญ.',
  'ทพ.',
  'ทพญ.',
  'ภก.',
  'ภญ.',
  'พว.',
  'กภ.',
  'นภ.',
];

/// Dropdown สำหรับเลือกคำนำหน้าชื่อ
/// มี style ตรงกับ design system ของแอป
class PrefixDropdown extends StatelessWidget {
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

  const PrefixDropdown({
    super.key,
    this.value,
    required this.onChanged,
    this.label,
    this.hintText = 'เลือกคำนำหน้า',
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
              hint: Text(
                hintText,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
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
              onChanged: enabled ? onChanged : null,
              items: thaiPrefixes.map((prefix) {
                return DropdownMenuItem<String>(
                  value: prefix,
                  child: Text(prefix),
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
