import 'package:flutter/material.dart';
import '../models/new_tag.dart';
import 'resident_picker_widget.dart';
import 'tag_picker_widget.dart';

/// Reusable widget สำหรับแสดง Resident picker และ Tag picker ในแถวเดียวกัน
/// ใช้ร่วมกันได้ทั้งหน้า Create และ Edit post
class ResidentTagPickerRow extends StatelessWidget {
  // Resident state
  final int? selectedResidentId;
  final String? selectedResidentName;
  final void Function(int id, String name) onResidentSelected;
  final VoidCallback onResidentCleared;

  // Tag state
  final NewTag? selectedTag;
  final bool isHandover;
  final ValueChanged<NewTag> onTagSelected;
  final VoidCallback? onTagCleared;
  final ValueChanged<bool> onHandoverChanged;

  // Options
  final bool disabled; // ล็อกทั้ง resident และ tag (เช่น เมื่อมาจาก task)
  final bool isTagRequired; // แสดง * สีแดงที่ tag picker
  final String? originalTagName; // สำหรับ edit mode - ถ้ามี tag เดิมไม่ต้องบังคับ

  const ResidentTagPickerRow({
    super.key,
    // Resident
    required this.selectedResidentId,
    required this.selectedResidentName,
    required this.onResidentSelected,
    required this.onResidentCleared,
    // Tag
    required this.selectedTag,
    required this.isHandover,
    required this.onTagSelected,
    this.onTagCleared,
    required this.onHandoverChanged,
    // Options
    this.disabled = false,
    this.isTagRequired = true,
    this.originalTagName,
  });

  @override
  Widget build(BuildContext context) {
    // คำนวณว่าต้องแสดง required หรือไม่
    // - ถ้า isTagRequired = true และไม่มี originalTagName → แสดง *
    // - ถ้ามี originalTagName → ไม่ต้องแสดง * (มี tag เดิมอยู่แล้ว)
    final showTagRequired = isTagRequired && originalTagName == null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Resident Picker (แสดงก่อน)
        ResidentPickerWidget(
          selectedResidentId: selectedResidentId,
          selectedResidentName: selectedResidentName,
          onResidentSelected: onResidentSelected,
          onResidentCleared: onResidentCleared,
          disabled: disabled,
        ),

        // Tag Picker
        TagPickerCompact(
          selectedTag: selectedTag,
          isHandover: isHandover,
          onTagSelected: onTagSelected,
          onTagCleared: onTagCleared,
          onHandoverChanged: onHandoverChanged,
          disabled: disabled,
          isRequired: showTagRequired,
        ),
      ],
    );
  }
}
