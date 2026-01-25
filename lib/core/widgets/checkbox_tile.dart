import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Checkbox tile widget พร้อมกรอบที่เด่นเมื่อติ๊ก
///
/// ใช้แทน SwitchListTile เพื่อให้ UI ชัดเจนขึ้น:
/// - มีกรอบที่เปลี่ยนสีเมื่อติ๊ก
/// - มี checkbox แทน toggle
/// - รองรับ icon, title, subtitle, และ badge
///
/// Example:
/// ```dart
/// CheckboxTile(
///   value: isHandover,
///   onChanged: (value) => setState(() => isHandover = value),
///   icon: HugeIcons.strokeRoundedArrowLeftRight,
///   title: 'ส่งเวร',
///   subtitle: 'หากมีอาการผิดปกติ...',
///   isRequired: true,
/// )
/// ```
class CheckboxTile extends StatelessWidget {
  /// ค่า checkbox (ติ๊กหรือไม่)
  final bool value;

  /// Callback เมื่อค่าเปลี่ยน (null = disabled)
  final ValueChanged<bool>? onChanged;

  /// Icon แสดงด้านซ้าย (ใช้ HugeIcons)
  final dynamic icon;

  /// หัวข้อหลัก
  final String title;

  /// คำอธิบายเพิ่มเติม (optional)
  final String? subtitle;

  /// สีของ subtitle (default: secondaryText)
  /// ใช้ AppColors.error สำหรับข้อความเตือน
  final Color? subtitleColor;

  /// แสดง badge "จำเป็น" หรือไม่
  final bool isRequired;

  /// Animation duration สำหรับการเปลี่ยนสี
  final Duration animationDuration;

  const CheckboxTile({
    super.key,
    required this.value,
    this.onChanged,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.isRequired = false,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;

    // ใช้ AnimatedContainer เพื่อให้กรอบเปลี่ยนสีแบบ smooth
    return AnimatedContainer(
      duration: animationDuration,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        // กรอบเด่นเมื่อติ๊ก
        border: Border.all(
          color: value ? AppColors.primary : AppColors.alternate,
          width: value ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        // พื้นหลังอ่อนๆ เมื่อติ๊ก
        color: value
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.transparent,
      ),
      child: InkWell(
        onTap: isEnabled ? () => onChanged!(!value) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: isEnabled
                      ? (newValue) => onChanged!(newValue ?? false)
                      : null,
                  activeColor: AppColors.primary,
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: BorderSide(
                    color: value ? AppColors.primary : AppColors.secondaryText,
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              HugeIcon(
                icon: icon,
                size: AppIconSize.lg,
                color: value ? AppColors.primary : AppColors.secondaryText,
              ),
              const SizedBox(width: 8),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTypography.body.copyWith(
                            color: value ? AppColors.primary : AppColors.primaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isRequired) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tagFailedBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'จำเป็น',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.error,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Subtitle
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: subtitleColor ?? AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
