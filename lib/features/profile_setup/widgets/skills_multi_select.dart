import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tags_badges.dart';

/// รายการทักษะด้านการบริบาลทั้งหมด
/// ตรงกับ Google Form สำหรับสมัครงาน (22 ทักษะ)
const List<String> careSkills = [
  'ทำแผลผ่าตัดสะอาด',
  'ทำแผลเจาะคอ',
  'ให้อาหารทางสายยาง',
  'ใส่สายยางให้อาหาร',
  'ป้อนอาหาร',
  'ฟอกไตผ่านทางหน้าท้อง',
  'ใส่สายสวนปัสสาวะ',
  'ดูดเสมหะ',
  'ให้ออกซิเจน/พ่นยา',
  'พลิกตะแคงตัวแบบถูกวิธี',
  'ทำกายภาพกันข้อติดเบื้องต้นถูกวิธี',
  'วัดสัญญาณชีพ',
  'ดูแลแผลขับถ่ายทางหน้าท้องและถุงหน้าท้อง',
  'อาบน้ำ/สระผมให้ผู้ป่วย',
  'เจาะน้ำตาล/ฉีดอินซูลิน',
  'ฉีดยา',
  'ทำแผลกดทับขนาดเล็ก',
  'ทำแผลกดทับขนาดใหญ่',
  'เจาะเลือด',
  'ล้างกระเพาะปัสสาวะด้วยเบตาดีน',
  'ทำอาหารปั่นตามสูตรสำหรับคนไข้ให้อาหารทางสายยาง',
  'ไม่มีที่กล่าวมาข้างต้น',
];

/// Widget สำหรับเลือกหลายทักษะพร้อมกัน
/// ใช้ Wrap + CategoryChip pattern
class SkillsMultiSelect extends StatelessWidget {
  /// รายการทักษะที่เลือกอยู่
  final Set<String> selectedSkills;

  /// Callback เมื่อเปลี่ยนการเลือก
  final ValueChanged<Set<String>> onChanged;

  /// Label แสดงด้านบน
  final String? label;

  /// มี error หรือไม่
  final bool hasError;

  /// Error message
  final String? errorText;

  /// แสดง required asterisk (*) หรือไม่
  final bool isRequired;

  /// Disabled state
  final bool enabled;

  const SkillsMultiSelect({
    super.key,
    required this.selectedSkills,
    required this.onChanged,
    this.label,
    this.hasError = false,
    this.errorText,
    this.isRequired = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label พร้อม required asterisk และจำนวนที่เลือก
        if (label != null) ...[
          Row(
            children: [
              Text(
                label!,
                style: AppTypography.label.copyWith(
                  color: hasError ? AppColors.error : AppColors.primaryText,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: AppTypography.label.copyWith(
                    color: AppColors.error,
                  ),
                ),
              const Spacer(),
              // แสดงจำนวนที่เลือก
              if (selectedSkills.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'เลือกแล้ว ${selectedSkills.length}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.verticalGapXs,
        ],

        // Quick actions: เลือกทั้งหมด / ยกเลิกทั้งหมด
        if (enabled) ...[
          Row(
            children: [
              _QuickActionButton(
                label: 'เลือกทั้งหมด',
                icon: HugeIcons.strokeRoundedCheckList,
                onTap: () {
                  // เลือกทั้งหมดยกเว้น "ไม่มีที่กล่าวมาข้างต้น"
                  final allExceptNone = careSkills
                      .where((s) => s != 'ไม่มีที่กล่าวมาข้างต้น')
                      .toSet();
                  onChanged(allExceptNone);
                },
              ),
              AppSpacing.horizontalGapSm,
              _QuickActionButton(
                label: 'ยกเลิกทั้งหมด',
                icon: HugeIcons.strokeRoundedCancel01,
                onTap: () => onChanged({}),
              ),
            ],
          ),
          AppSpacing.verticalGapSm,
        ],

        // Skills chips container
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingSm,
          decoration: BoxDecoration(
            color: AppColors.primaryBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? AppColors.error : AppColors.alternate,
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: careSkills.map((skill) {
              final isSelected = selectedSkills.contains(skill);
              // ถ้าเลือก "ไม่มีที่กล่าวมาข้างต้น" จะไม่สามารถเลือกอื่นได้
              final isNoneOption = skill == 'ไม่มีที่กล่าวมาข้างต้น';
              final hasSelectedNone =
                  selectedSkills.contains('ไม่มีที่กล่าวมาข้างต้น');

              // ถ้า disabled หรือ (เลือก none แล้วแต่ไม่ใช่ none option)
              final chipDisabled =
                  !enabled || (hasSelectedNone && !isNoneOption && !isSelected);

              return Opacity(
                opacity: chipDisabled ? 0.5 : 1.0,
                child: CategoryChip(
                  label: skill,
                  isSelected: isSelected,
                  onTap: chipDisabled
                      ? null
                      : () => _toggleSkill(skill, isNoneOption),
                ),
              );
            }).toList(),
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
              Expanded(
                child: Text(
                  errorText!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Toggle เลือก/ยกเลิก skill
  void _toggleSkill(String skill, bool isNoneOption) {
    final newSet = Set<String>.from(selectedSkills);

    if (newSet.contains(skill)) {
      // ยกเลิกการเลือก
      newSet.remove(skill);
    } else {
      // เลือกใหม่
      if (isNoneOption) {
        // ถ้าเลือก "ไม่มี" ให้ล้างทั้งหมดแล้วเลือกแค่ "ไม่มี"
        newSet.clear();
        newSet.add(skill);
      } else {
        // ถ้าเลือกทักษะอื่น ให้ลบ "ไม่มี" ออก (ถ้ามี)
        newSet.remove('ไม่มีที่กล่าวมาข้างต้น');
        newSet.add(skill);
      }
    }

    onChanged(newSet);
  }
}

/// ปุ่ม Quick Action (เลือกทั้งหมด/ยกเลิกทั้งหมด)
class _QuickActionButton extends StatelessWidget {
  final String label;
  final dynamic icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.alternate),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: icon,
                color: AppColors.secondaryText,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function เพื่อ convert JSON List จาก DB เป็น Set of String
Set<String> skillsFromJson(dynamic json) {
  if (json == null) return {};
  if (json is List) {
    return json.map((e) => e.toString()).toSet();
  }
  return {};
}

/// Helper function เพื่อ convert Set of String เป็น List สำหรับ save ลง DB
List<String> skillsToJson(Set<String> skills) {
  return skills.toList();
}
