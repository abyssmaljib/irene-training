// Widget สำหรับให้ user เลือก Core Values ในขั้นตอนถอดบทเรียน
// แสดงเป็น cards ที่กดเลือกได้หลายตัว พร้อมปุ่มยืนยัน

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../services/ai_chat_service.dart' show AvailableCoreValue;

/// Widget สำหรับเลือก Core Values
/// แสดงเป็น grid ของ cards ที่กดเลือกได้หลายตัว
class CoreValuePicker extends StatefulWidget {
  /// รายการ Core Values ที่สามารถเลือกได้
  final List<AvailableCoreValue> coreValues;

  /// Callback เมื่อกดปุ่มยืนยัน
  /// ส่ง list ของ Core Value names ที่เลือก
  final void Function(List<String> selectedValues) onConfirm;

  /// กำลังส่งข้อมูลอยู่หรือไม่ (disable ปุ่มยืนยัน)
  final bool isLoading;

  const CoreValuePicker({
    super.key,
    required this.coreValues,
    required this.onConfirm,
    this.isLoading = false,
  });

  @override
  State<CoreValuePicker> createState() => _CoreValuePickerState();
}

class _CoreValuePickerState extends State<CoreValuePicker> {
  /// Set ของ Core Value IDs ที่ถูกเลือก
  final Set<int> _selectedIds = {};

  /// Icon สำหรับแต่ละ Core Value (ใช้ตาม keyword ในชื่อ)
  dynamic _getIconForCoreValue(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('speak') || lowerName.contains('พูด')) {
      return HugeIcons.strokeRoundedMegaphone01;
    } else if (lowerName.contains('service') || lowerName.contains('บริการ')) {
      return HugeIcons.strokeRoundedCustomerService01;
    } else if (lowerName.contains('system') || lowerName.contains('ระบบ')) {
      return HugeIcons.strokeRoundedSettings02;
    } else if (lowerName.contains('integrity') || lowerName.contains('ซื่อสัตย์')) {
      return HugeIcons.strokeRoundedAward01; // ใช้ award แทน honour
    } else if (lowerName.contains('learning') || lowerName.contains('เรียนรู้')) {
      return HugeIcons.strokeRoundedBook02;
    } else if (lowerName.contains('teamwork') || lowerName.contains('ทีม')) {
      return HugeIcons.strokeRoundedUserGroup;
    }
    // Default icon
    return HugeIcons.strokeRoundedStar;
  }

  /// สีสำหรับแต่ละ Core Value
  Color _getColorForCoreValue(String name, bool isSelected) {
    if (!isSelected) return AppColors.secondaryText;

    final lowerName = name.toLowerCase();
    if (lowerName.contains('speak') || lowerName.contains('พูด')) {
      return const Color(0xFF3B82F6); // Blue
    } else if (lowerName.contains('service') || lowerName.contains('บริการ')) {
      return const Color(0xFFEC4899); // Pink
    } else if (lowerName.contains('system') || lowerName.contains('ระบบ')) {
      return const Color(0xFF8B5CF6); // Purple
    } else if (lowerName.contains('integrity') || lowerName.contains('ซื่อสัตย์')) {
      return const Color(0xFF10B981); // Green
    } else if (lowerName.contains('learning') || lowerName.contains('เรียนรู้')) {
      return const Color(0xFFF59E0B); // Amber
    } else if (lowerName.contains('teamwork') || lowerName.contains('ทีม')) {
      return const Color(0xFF06B6D4); // Cyan
    }
    return AppColors.primary;
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _handleConfirm() {
    // หา Core Value names ที่ถูกเลือก
    final selectedNames = widget.coreValues
        .where((cv) => _selectedIds.contains(cv.id))
        .map((cv) => cv.name)
        .toList();

    widget.onConfirm(selectedNames);
  }

  @override
  Widget build(BuildContext context) {
    // แสดงเป็น card แบบ inline ใน chat (ไม่ใช่ fixed ด้านล่าง)
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder, width: 1),
        // เพิ่ม shadow เล็กน้อยให้ดูเป็น card
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedDiamond01,
                color: AppColors.primary,
                size: 20,
              ),
              AppSpacing.horizontalGapSm,
              Expanded(
                child: Text(
                  'เลือก Core Values ที่เกี่ยวข้อง',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              // แสดงจำนวนที่เลือก
              if (_selectedIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedIds.length} รายการ',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),

          AppSpacing.verticalGapMd,

          // List ของ Core Value cards (ใช้ Column แทน ListView เพราะอยู่ใน chat's ListView แล้ว)
          ...widget.coreValues.asMap().entries.map((entry) {
            final index = entry.key;
            final coreValue = entry.value;
            final isSelected = _selectedIds.contains(coreValue.id);
            final iconColor = _getColorForCoreValue(coreValue.name, isSelected);

            return Padding(
              // เพิ่ม spacing ระหว่าง cards (ยกเว้นตัวแรก)
              padding: EdgeInsets.only(top: index > 0 ? 8 : 0),
              child: _CoreValueCard(
                coreValue: coreValue,
                isSelected: isSelected,
                icon: _getIconForCoreValue(coreValue.name),
                iconColor: iconColor,
                onTap: () => _toggleSelection(coreValue.id),
              ),
            );
          }),

          AppSpacing.verticalGapMd,

          // ปุ่มยืนยัน - ใช้ PrimaryButton จาก core widgets
          PrimaryButton(
            text: _selectedIds.isEmpty
                ? 'กรุณาเลือกอย่างน้อย 1 รายการ'
                : 'ยืนยัน (${_selectedIds.length} รายการ)',
            onPressed: _selectedIds.isEmpty ? null : _handleConfirm,
            isLoading: widget.isLoading,
            isDisabled: _selectedIds.isEmpty,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}

/// Card สำหรับแสดง Core Value แต่ละตัว
/// เปลี่ยนเป็น horizontal layout เพื่อแสดงข้อความครบถ้วน
class _CoreValueCard extends StatelessWidget {
  final AvailableCoreValue coreValue;
  final bool isSelected;
  final dynamic icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _CoreValueCard({
    required this.coreValue,
    required this.isSelected,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  /// แยกชื่อ Thai และ English จาก format "English (Thai)"
  /// เช่น "Speak Up (กล้าพูด กล้าสื่อสาร)" -> ["Speak Up", "กล้าพูด กล้าสื่อสาร"]
  List<String> _parseDisplayName(String name) {
    final regex = RegExp(r'^(.+?)\s*\((.+)\)$');
    final match = regex.firstMatch(name);
    if (match != null) {
      return [match.group(1)!, match.group(2)!];
    }
    // ถ้าไม่มี () ให้ return ชื่อเดิม
    return [name, ''];
  }

  @override
  Widget build(BuildContext context) {
    final nameParts = _parseDisplayName(coreValue.name);
    final englishName = nameParts[0];
    final thaiName = nameParts[1];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? iconColor.withValues(alpha: 0.1)
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? iconColor : AppColors.inputBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          // เปลี่ยนเป็น Row layout เพื่อแสดงข้อความครบ
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon ด้านซ้าย
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
              ),

              AppSpacing.horizontalGapMd,

              // ข้อความตรงกลาง (ขยายเต็มพื้นที่)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ชื่อ English (แสดงครบไม่ตัด)
                    Text(
                      englishName,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? iconColor : AppColors.primaryText,
                      ),
                    ),

                    // ชื่อ Thai (ถ้ามี - แสดงครบไม่ตัด)
                    if (thaiName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        thaiName,
                        style: AppTypography.bodySmall.copyWith(
                          color: isSelected
                              ? iconColor.withValues(alpha: 0.8)
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],

                    // Description (ถ้ามี - แสดงครบไม่ตัด)
                    if (coreValue.description != null &&
                        coreValue.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        coreValue.description!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              AppSpacing.horizontalGapSm,

              // Checkbox ด้านขวา
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? iconColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? iconColor : AppColors.inputBorder,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
