import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/checkbox_tile.dart';
import '../models/new_tag.dart';

/// Reusable widget สำหรับ "ส่งเวร" toggle
/// รวม logic ทั้งหมดไว้ในที่เดียว:
/// - ตรวจสอบ tag mode (force/optional)
/// - ตรวจสอบ noResident = บังคับส่งเวร (เรื่องส่วนกลาง)
/// - Focus ไปที่ description field เมื่อติ๊ก (ถ้า description ว่าง)
class HandoverToggleWidget extends StatelessWidget {
  /// Tag ที่เลือกอยู่ (ใช้ตรวจสอบ handover mode)
  final NewTag? selectedTag;

  /// ค่า isHandover ปัจจุบัน
  final bool isHandover;

  /// ID ของ resident ที่เลือก (null = เรื่องส่วนกลาง)
  final int? selectedResidentId;

  /// Callback เมื่อเปลี่ยนค่า handover
  final ValueChanged<bool> onHandoverChanged;

  /// FocusNode ของ description field (ใช้สำหรับ focus เมื่อติ๊กส่งเวร)
  final FocusNode? descriptionFocusNode;

  /// Text ใน description field (ใช้ตรวจสอบว่าว่างหรือไม่)
  final String? descriptionText;

  /// Callback สำหรับ auto-enable handover เมื่อไม่มี resident
  /// (เรียกใน addPostFrameCallback)
  final VoidCallback? onAutoEnableHandover;

  /// บังคับส่งเวรเมื่อไม่มี resident (เรื่องส่วนกลาง)
  /// - true = สำหรับ Create Post (บังคับส่งเวรเมื่อไม่เลือก resident)
  /// - false = สำหรับ Edit Post (ไม่บังคับ เพราะโพสเก่าอาจไม่มี resident ตั้งแต่แรก)
  final bool forceHandoverWhenNoResident;

  const HandoverToggleWidget({
    super.key,
    required this.selectedTag,
    required this.isHandover,
    required this.selectedResidentId,
    required this.onHandoverChanged,
    this.descriptionFocusNode,
    this.descriptionText,
    this.onAutoEnableHandover,
    this.forceHandoverWhenNoResident = true, // default = true สำหรับ create
  });

  @override
  Widget build(BuildContext context) {
    // คำนวณ states ต่างๆ
    // ถ้าไม่มี tag = toggle ได้อิสระ (สำหรับ edit mode ที่อาจไม่มี tag)
    final canToggle = selectedTag == null ||
        (selectedTag?.isOptionalHandover ?? false);
    final isForce = selectedTag?.isForceHandover ?? false;
    final noResident = selectedResidentId == null;
    // บังคับส่งเวรเมื่อไม่มี resident (เฉพาะ create mode)
    final isForceByNoResident =
        forceHandoverWhenNoResident && noResident && !isForce;

    // ถ้าไม่มี resident และยังไม่ได้ติ๊ก → auto enable (เฉพาะ create mode)
    // เรียก callback ผ่าน addPostFrameCallback เพื่อไม่ให้ setState ระหว่าง build
    if (isForceByNoResident && !isHandover && onAutoEnableHandover != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onAutoEnableHandover!();
      });
    }

    return CheckboxTile(
      // ถ้าบังคับเมื่อไม่มี resident → แสดง true
      value: isForceByNoResident ? true : isHandover,
      // disable ถ้า force หรือ บังคับเมื่อไม่มี resident
      onChanged: (canToggle && !isForceByNoResident)
          ? (value) {
              onHandoverChanged(value);
              // ถ้าติ๊กส่งเวร (value = true) และ description ว่าง → focus ไปที่ช่อง description
              // เพื่อให้ user รู้ว่าต้องกรอกรายละเอียดด้วย
              if (value &&
                  descriptionFocusNode != null &&
                  (descriptionText?.trim().isEmpty ?? true)) {
                descriptionFocusNode!.requestFocus();
              }
            }
          : null,
      icon: HugeIcons.strokeRoundedArrowLeftRight,
      title: 'ส่งเวร',
      subtitle: _getSubtitle(isForce, isForceByNoResident),
      subtitleColor: AppColors.error,
      isRequired: isForce || isForceByNoResident,
    );
  }

  /// สร้าง subtitle ตาม state
  String _getSubtitle(bool isForce, bool isForceByNoResident) {
    if (isForce) {
      return 'จำเป็นต้องส่งเวรสำหรับหัวข้อนี้';
    } else if (isForceByNoResident) {
      return 'ไม่ได้เลือกผู้พักอาศัย = เรื่องส่วนกลาง จำเป็นต้องส่งเวร';
    } else {
      return 'หากมีอาการผิดปกติ ผิดแปลกไปจากเดิม หรือเป็นเรื่องที่สำคัญ';
    }
  }
}
