// Widget สำหรับเลือกสถานะ stock ของ ticket ยา
// แสดงสถานะปัจจุบันเป็นปุ่ม เมื่อกดจะเปิด bottom sheet ให้เลือกสถานะใหม่
//
// สถานะทั้งหมด (ตาม flow ของ ticket ยา):
// pending → notified → continue_until_finished / waiting_relative →
// waiting_appointment → added_to_appointment / staff_purchase →
// purchasing → waiting_delivery → received → completed
//
// ใช้ emoji + label ภาษาไทย เพื่อให้ user อ่านง่ายและเข้าใจสถานะได้ทันที

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';

/// Widget สำหรับเลือกสถานะ stock ของ ticket ยา
/// แสดงสถานะปัจจุบันเป็นปุ่ม เมื่อกดจะเปิด bottom sheet ให้เลือก
class StockStatusSelector extends StatelessWidget {
  /// สถานะ stock ปัจจุบัน (ค่าจาก DB เช่น 'pending', 'notified')
  /// ถ้าเป็น null จะแสดง "ยังไม่ระบุ"
  final String? currentStatus;

  /// Callback เมื่อ user เลือกสถานะใหม่
  /// ส่งค่า DB value กลับมา (เช่น 'notified', 'completed')
  final ValueChanged<String> onStatusChanged;

  const StockStatusSelector({
    super.key,
    required this.currentStatus,
    required this.onStatusChanged,
  });

  // ===== รายการสถานะ stock ทั้งหมด =====
  // (db_value, label_ภาษาไทย, emoji)
  // เรียงตาม flow จริงที่ใช้ในการจัดการ ticket ยา
  static const List<(String, String, String)> _stockStatuses = [
    ('pending', 'รอดำเนินการ', '\u23F3'), // hourglass
    ('notified', 'แจ้งญาติแล้ว', '\uD83D\uDCDE'), // telephone
    ('continue_until_finished', 'ทานต่อจนหมด', '\uD83D\uDC8A'), // pill
    ('waiting_relative', 'รอญาตินำยามา', '\uD83D\uDC68\u200D\uD83D\uDC69\u200D\uD83D\uDC66'), // family
    ('waiting_appointment', 'รอไปพบแพทย์ตามนัด', '\uD83C\uDFE5'), // hospital
    ('added_to_appointment', 'เพิ่มยาในนัดหมายแล้ว', '\u2705'), // check
    ('staff_purchase', 'ญาติให้เราซื้อให้', '\uD83D\uDED2'), // cart
    ('purchasing', 'กำลังจัดซื้อ', '\uD83D\uDCE6'), // package
    ('waiting_delivery', 'รอยามาส่ง', '\uD83D\uDE9A'), // truck
    ('received', 'ได้รับยาแล้ว', '\uD83D\uDCE5'), // inbox
    ('completed', 'เสร็จสิ้น', '\u2705'), // check
  ];

  @override
  Widget build(BuildContext context) {
    // หาข้อมูลสถานะปัจจุบัน จาก list ข้างบน
    // ถ้าค่า currentStatus ไม่ตรงกับอะไรเลย จะแสดง "ยังไม่ระบุ"
    final currentEntry = _findStatusEntry(currentStatus);
    final displayLabel = currentEntry?.$2 ?? 'ยังไม่ระบุ';
    final displayEmoji = currentEntry?.$3 ?? '\u2753'; // เครื่องหมายคำถาม

    return InkWell(
      onTap: () => _showStatusPicker(context),
      borderRadius: AppRadius.smallRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          // พื้นหลังสีตามสถานะ (เขียวถ้าเสร็จ, เหลืองถ้ากำลังทำ, เทาถ้ายังไม่ระบุ)
          color: _getStatusBackgroundColor(currentStatus),
          borderRadius: AppRadius.smallRadius,
          border: Border.all(
            color: _getStatusBorderColor(currentStatus),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji ของสถานะ
            Text(
              displayEmoji,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),

            // Label ภาษาไทย
            Flexible(
              child: Text(
                displayLabel,
                style: AppTypography.label.copyWith(
                  color: _getStatusTextColor(currentStatus),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),

            // ลูกศรลง บอกว่ากดเลือกได้
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowDown01,
              size: AppIconSize.sm,
              color: _getStatusTextColor(currentStatus),
            ),
          ],
        ),
      ),
    );
  }

  /// เปิด bottom sheet ให้เลือกสถานะ stock
  void _showStatusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      // ให้ bottom sheet ปรับขนาดตามเนื้อหา
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== Handle bar ด้านบน (ให้รู้ว่าปัดลงปิดได้) =====
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.alternate,
                  borderRadius: AppRadius.fullRadius,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ===== หัวข้อ "สถานะ stock" =====
              Padding(
                padding: AppSpacing.paddingHorizontalMd,
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedPackage,
                      size: AppIconSize.lg,
                      color: AppColors.textPrimary,
                    ),
                    AppSpacing.horizontalGapSm,
                    Text(
                      'เลือกสถานะ stock',
                      style: AppTypography.title,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // ===== รายการสถานะให้เลือก =====
              // ใช้ ConstrainedBox จำกัดความสูงไม่เกิน 60% ของหน้าจอ
              // กรณีที่มีสถานะเยอะจะ scroll ได้
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _stockStatuses.length,
                  itemBuilder: (context, index) {
                    final status = _stockStatuses[index];
                    final isSelected = status.$1 == currentStatus;

                    return ListTile(
                      // Emoji ด้านหน้า
                      leading: Text(
                        status.$3,
                        style: const TextStyle(fontSize: 20),
                      ),
                      // Label ภาษาไทย
                      title: Text(
                        status.$2,
                        style: AppTypography.body.copyWith(
                          // ถ้าเป็นสถานะที่เลือกอยู่ ให้ bold + สี primary
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      // แสดง check icon ถ้าเป็นสถานะที่เลือกอยู่
                      trailing: isSelected
                          ? HugeIcon(
                              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                              size: AppIconSize.lg,
                              color: AppColors.primary,
                            )
                          : null,
                      // Highlight พื้นหลังถ้าเป็นสถานะที่เลือกอยู่
                      selected: isSelected,
                      selectedTileColor: AppColors.accent1,
                      onTap: () {
                        // ปิด bottom sheet แล้วส่งค่าสถานะกลับไป
                        Navigator.pop(context);
                        onStatusChanged(status.$1);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Helper methods
  // ===========================================================================

  /// หา entry ของสถานะจาก list
  /// คืน null ถ้าไม่เจอ (กรณี currentStatus เป็น null หรือค่าที่ไม่รู้จัก)
  static (String, String, String)? _findStatusEntry(String? status) {
    if (status == null) return null;
    try {
      return _stockStatuses.firstWhere((s) => s.$1 == status);
    } catch (_) {
      // ไม่เจอสถานะที่ตรงกัน — คืน null ไปแสดง "ยังไม่ระบุ"
      return null;
    }
  }

  /// สีพื้นหลังตามกลุ่มสถานะ
  /// - completed/received → เขียวอ่อน (สำเร็จ)
  /// - pending/null → เทาอ่อน (ยังไม่เริ่ม)
  /// - อื่นๆ → เหลืองอ่อน (กำลังดำเนินการ)
  static Color _getStatusBackgroundColor(String? status) {
    switch (status) {
      case 'completed':
      case 'received':
        return AppColors.tagPassedBg;
      case null:
      case 'pending':
        return AppColors.tagNeutralBg;
      default:
        // สถานะที่กำลังดำเนินการ (notified, waiting, purchasing ฯลฯ)
        return AppColors.tagPendingBg;
    }
  }

  /// สีขอบตามกลุ่มสถานะ (เข้มกว่าพื้นหลังเล็กน้อย)
  static Color _getStatusBorderColor(String? status) {
    switch (status) {
      case 'completed':
      case 'received':
        return const Color(0xFFC8E6C9); // เขียวอ่อน
      case null:
      case 'pending':
        return AppColors.alternate;
      default:
        return const Color(0xFFFFE0B2); // ส้มอ่อน
    }
  }

  /// สีข้อความตามกลุ่มสถานะ
  static Color _getStatusTextColor(String? status) {
    switch (status) {
      case 'completed':
      case 'received':
        return AppColors.tagPassedText;
      case null:
      case 'pending':
        return AppColors.tagNeutralText;
      default:
        return AppColors.tagPendingText;
    }
  }
}
