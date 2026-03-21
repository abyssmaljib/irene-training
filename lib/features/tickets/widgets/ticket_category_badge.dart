// Badge แสดงหมวดหมู่ ticket พร้อม emoji
// ใช้แยกให้เห็นว่า ticket นี้เกี่ยวกับเรื่องอะไร:
// - general (เทา) → เรื่องทั่วไป
// - medicine (แดง) → เรื่องยา
// - task (ฟ้า) → เรื่องงาน/ภารกิจ
//
// Layout เหมือน TicketStatusBadge: Container กลมมน + emoji + ข้อความ

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/ticket.dart';

/// Badge แสดงหมวดหมู่ ticket (ทั่วไป / ยา / งาน)
/// ใช้ใน list card เพื่อให้ user แยกแยะประเภท ticket ได้เร็ว
class TicketCategoryBadge extends StatelessWidget {
  /// หมวดหมู่ที่ต้องการแสดง
  final TicketCategory category;

  const TicketCategoryBadge({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    // ดึง color scheme ตามหมวดหมู่
    final colors = _getCategoryColors(category);

    return Container(
      // padding เหมือน status badge เพื่อความสม่ำเสมอ
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        // แสดง "emoji ข้อความ" เช่น "💊 ยา"
        '${category.emoji} ${category.displayText}',
        style: AppTypography.label.copyWith(
          color: colors.textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// คืน color pair ตามหมวดหมู่
  /// - general ใช้สีเทากลางๆ (ไม่โดดเด่น เพราะเป็นหมวดทั่วไป)
  /// - medicine ใช้สีแดง (เกี่ยวกับยา = ต้องระวัง)
  /// - task ใช้สีฟ้า (เกี่ยวกับงาน = action item)
  _CategoryColors _getCategoryColors(TicketCategory category) {
    switch (category) {
      // เทา — ทั่วไป ไม่ได้เข้าหมวดเฉพาะ
      case TicketCategory.general:
        return _CategoryColors(
          backgroundColor: AppColors.background,
          textColor: Colors.grey.shade700,
        );
      // แดง — เรื่องยา ใช้สีแดงให้รู้ว่าเกี่ยวกับสุขภาพ
      case TicketCategory.medicine:
        return _CategoryColors(
          backgroundColor: Colors.red.shade50,
          textColor: Colors.red.shade700,
        );
      // ฟ้า — เรื่องงาน/task
      case TicketCategory.task:
        return _CategoryColors(
          backgroundColor: Colors.blue.shade50,
          textColor: Colors.blue.shade700,
        );
    }
  }
}

/// Data class เก็บคู่สี background + text สำหรับ category
class _CategoryColors {
  final Color backgroundColor;
  final Color textColor;

  const _CategoryColors({
    required this.backgroundColor,
    required this.textColor,
  });
}
