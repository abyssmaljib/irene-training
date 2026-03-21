// Badge แสดงสถานะ ticket พร้อม emoji
// รองรับ 2 โหมด:
// - ปกติ: แสดง emoji + ข้อความ (เช่น "🔧 กำลังดำเนินการ")
// - compact: แสดงแค่ emoji อย่างเดียว (ใช้ในที่แคบ เช่น list card)
//
// สีแต่ละสถานะออกแบบให้ต่างกันชัดเจน:
// - open (ฟ้า) → ยังไม่เริ่ม
// - inProgress (ส้ม) → กำลังทำ
// - awaitingFollowUp (ม่วง) → รอติดตาม
// - resolved (เขียว) → เสร็จแล้ว
// - cancelled (เทา) → ยกเลิก

import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../models/ticket.dart';

/// Badge แสดงสถานะ ticket
/// ใช้ [compact] = true เพื่อแสดงแค่ emoji (ประหยัดพื้นที่ใน list)
class TicketStatusBadge extends StatelessWidget {
  /// สถานะที่ต้องการแสดง
  final TicketStatus status;

  /// compact = true → แสดงแค่ emoji, false → แสดง emoji + ข้อความ
  final bool compact;

  const TicketStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // ดึง color scheme ตามสถานะ
    final colors = _getStatusColors(status);

    return Container(
      // padding แนวนอนมากกว่าแนวตั้ง เพื่อให้ badge ดูเป็นแคปซูล
      // compact mode ใช้ padding น้อยกว่าเพราะแสดงแค่ emoji
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        // compact mode แสดงแค่ emoji, ปกติแสดง "emoji ข้อความ"
        compact ? status.emoji : '${status.emoji} ${status.displayText}',
        style: AppTypography.label.copyWith(
          color: colors.textColor,
          // compact mode ไม่ต้อง bold เพราะ emoji ก็เห็นชัดอยู่แล้ว
          fontWeight: compact ? FontWeight.w400 : FontWeight.w600,
          // ปรับ fontSize ของ compact ให้เล็กลงนิดหน่อย
          fontSize: compact ? 11 : 12,
        ),
      ),
    );
  }

  /// คืน color pair (background + text) ตามสถานะ
  /// ใช้ Material shade เพื่อให้สีอ่อน-เข้มเข้าคู่กัน
  _StatusColors _getStatusColors(TicketStatus status) {
    switch (status) {
      // ฟ้า — เปิดใหม่ ยังไม่มีคนหยิบ
      case TicketStatus.open:
        return _StatusColors(
          backgroundColor: Colors.blue.shade50,
          textColor: Colors.blue.shade700,
        );
      // ส้ม — กำลังดำเนินการ (ให้ความรู้สึก "active")
      case TicketStatus.inProgress:
        return _StatusColors(
          backgroundColor: Colors.orange.shade50,
          textColor: Colors.orange.shade700,
        );
      // ม่วง — รอติดตาม (ให้ความรู้สึก "pending/waiting")
      case TicketStatus.awaitingFollowUp:
        return _StatusColors(
          backgroundColor: Colors.purple.shade50,
          textColor: Colors.purple.shade700,
        );
      // เขียว — เสร็จสิ้น (สำเร็จ)
      case TicketStatus.resolved:
        return _StatusColors(
          backgroundColor: Colors.green.shade50,
          textColor: Colors.green.shade700,
        );
      // เทา — ยกเลิก (ไม่สำคัญแล้ว จึงใช้สีจืดๆ)
      case TicketStatus.cancelled:
        return _StatusColors(
          backgroundColor: Colors.grey.shade100,
          textColor: Colors.grey.shade600,
        );
    }
  }
}

/// Data class เก็บคู่สี background + text
/// ใช้ภายใน file นี้เท่านั้น ไม่ export ออกไป
class _StatusColors {
  final Color backgroundColor;
  final Color textColor;

  const _StatusColors({
    required this.backgroundColor,
    required this.textColor,
  });
}
