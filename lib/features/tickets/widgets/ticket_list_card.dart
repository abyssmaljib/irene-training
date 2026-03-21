// Card สำหรับแสดง ticket 1 ใบในหน้า list
//
// Layout:
// ┌─────────────────────────────────────────────┐
// │ [CategoryBadge]          [StatusBadge] [⭐]  │
// │                                              │
// │ หัวข้อ ticket (bold, 1 บรรทัด)               │
// │                                              │
// │ 👤 ชื่อผู้พัก  |  🏠 โซน     📅 วันติดตาม    │
// │                                              │
// │ 💬 คอมเมนต์ล่าสุด... (1 บรรทัด, สีเทา)     │
// │                                              │
// │ [📋 วาระประชุม]  (ถ้า meetingAgenda = true)  │
// └─────────────────────────────────────────────┘
//
// Card ใช้ InkWell เพื่อให้กดได้ + มี ripple effect
// ใช้ AppShadows.cardShadow เพื่อให้ดู float เหนือพื้นหลัง

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/ticket.dart';
import 'ticket_status_badge.dart';
import 'ticket_category_badge.dart';

/// Card แสดง ticket ในหน้า list
/// กดแล้วเรียก [onTap] เพื่อเปิดหน้ารายละเอียด
class TicketListCard extends StatelessWidget {
  /// ข้อมูล ticket ที่จะแสดง
  final Ticket ticket;

  /// callback เมื่อกดที่ card (เปิดหน้ารายละเอียด)
  final VoidCallback? onTap;

  const TicketListCard({
    super.key,
    required this.ticket,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // margin แนวนอน 16 เพื่อให้ห่างจากขอบจอ
      // แนวตั้ง 4 เพื่อให้ card เรียงชิดกันแต่ไม่ติดกัน
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface, // พื้นหลังขาว
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.cardShadow, // เงาอ่อนๆ
      ),
      child: Material(
        // Material + InkWell เพื่อให้มี ripple effect ตอนกด
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== แถวบนสุด: หมวดหมู่ (ซ้าย) + สถานะ & ดาว (ขวา) =====
                _buildHeaderRow(),

                const SizedBox(height: AppSpacing.sm),

                // ===== หัวข้อ ticket =====
                _buildTitleText(),

                const SizedBox(height: AppSpacing.xs),

                // ===== แถว metadata: ผู้พัก, โซน, วันติดตาม =====
                _buildMetadataRow(),

                // ===== คอมเมนต์ล่าสุด (แสดงเฉพาะเมื่อมี) =====
                if (ticket.hasComment) ...[
                  const SizedBox(height: 6),
                  _buildLastComment(),
                ],

                // ===== chip วาระประชุม (แสดงเฉพาะเมื่อ meetingAgenda = true) =====
                if (ticket.meetingAgenda) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildMeetingAgendaChip(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// แถวบนสุด: [CategoryBadge] ... [StatusBadge] [⭐]
  /// ใช้ Spacer เพื่อดัน status badge ไปชิดขวา
  Widget _buildHeaderRow() {
    return Row(
      children: [
        // Badge หมวดหมู่ (เช่น "💊 ยา")
        TicketCategoryBadge(category: ticket.category),

        const Spacer(),

        // Badge สถานะแบบ compact (แสดงแค่ emoji เช่น "🔧")
        // ใช้ compact เพราะแถวนี้มีข้อมูลเยอะ ไม่ต้องแสดงข้อความซ้ำ
        TicketStatusBadge(status: ticket.status, compact: true),

        // ดาวสำหรับ ticket ด่วน (priority)
        if (ticket.priority) ...[
          const SizedBox(width: 6),
          HugeIcon(
            icon: HugeIcons.strokeRoundedStar,
            color: Colors.amber.shade600,
            size: AppIconSize.md,
          ),
        ],
      ],
    );
  }

  /// หัวข้อ ticket — bold, ตัดข้อความเป็น 1 บรรทัด
  /// ถ้าไม่มีหัวข้อแสดง "ไม่มีหัวข้อ" เป็นสีเทา
  Widget _buildTitleText() {
    final hasTitle = ticket.title != null && ticket.title!.isNotEmpty;

    return Text(
      hasTitle ? ticket.title! : 'ไม่มีหัวข้อ',
      style: AppTypography.title.copyWith(
        // ถ้าไม่มีหัวข้อ ใช้สีเทาเพื่อบอกว่าเป็น placeholder
        color: hasTitle ? AppColors.textPrimary : AppColors.textSecondary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// แถว metadata: ชื่อผู้พัก | ชื่อโซน | วันติดตาม
  /// แต่ละข้อมูลจะแสดงเฉพาะเมื่อมีค่า (nullable fields จาก LEFT JOIN)
  Widget _buildMetadataRow() {
    // รวม metadata items ที่มีค่า
    final items = <Widget>[];

    // ชื่อผู้พักอาศัย (ถ้ามี)
    if (ticket.residentName != null) {
      items.add(_buildMetadataItem(
        icon: HugeIcons.strokeRoundedUser,
        text: ticket.residentName!,
      ));
    }

    // ชื่อโซน (ถ้ามี) — เพิ่ม separator ก่อนถ้ามี item ก่อนหน้า
    if (ticket.zoneName != null) {
      if (items.isNotEmpty) {
        items.add(_buildMetadataSeparator());
      }
      items.add(_buildMetadataItem(
        icon: HugeIcons.strokeRoundedHome09,
        text: ticket.zoneName!,
      ));
    }

    // Spacer ดัน follow-up date ไปชิดขวา
    if (items.isNotEmpty) {
      items.add(const Spacer());
    }

    // วันติดตาม (ถ้ามี)
    if (ticket.hasFollowUpDate) {
      // ถ้ามี items อยู่แล้วไม่ต้องเพิ่ม Spacer ซ้ำ
      if (items.isEmpty) {
        items.add(const Spacer());
      }
      items.add(_buildFollowUpDate());
    }

    // ถ้าไม่มี metadata เลย ไม่ต้อง render row
    if (items.isEmpty) return const SizedBox.shrink();

    return Row(
      children: items,
    );
  }

  /// สร้าง metadata item: icon + text (เช่น "👤 คุณยาย")
  Widget _buildMetadataItem({
    required dynamic icon,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: icon,
          color: AppColors.textSecondary,
          size: AppIconSize.sm,
        ),
        const SizedBox(width: 4),
        // ConstrainedBox จำกัดความกว้างไม่ให้ชื่อยาว overflow
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Text(
            text,
            style: AppTypography.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// จุดคั่นระหว่าง metadata items
  Widget _buildMetadataSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// แสดงวันติดตาม + badge "เลยกำหนด" ถ้า overdue
  Widget _buildFollowUpDate() {
    // format วันที่เป็นแบบไทย (เช่น "17 มี.ค.")
    final formattedDate = _formatThaiDate(ticket.followUpDate!);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ไอคอนปฏิทิน
        HugeIcon(
          icon: HugeIcons.strokeRoundedCalendar03,
          color: ticket.isOverdue
              ? Colors.red.shade600
              : AppColors.textSecondary,
          size: AppIconSize.sm,
        ),
        const SizedBox(width: 4),
        // วันที่
        Text(
          formattedDate,
          style: AppTypography.caption.copyWith(
            color: ticket.isOverdue
                ? Colors.red.shade600
                : AppColors.textSecondary,
          ),
        ),
        // badge "เลยกำหนด" ถ้า overdue
        if (ticket.isOverdue) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'เลยกำหนด',
              style: AppTypography.caption.copyWith(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// แสดงคอมเมนต์ล่าสุด — 1 บรรทัด สีเทา
  /// format: "nickname: เนื้อหา" หรือแค่ "เนื้อหา" ถ้าไม่มี nickname
  Widget _buildLastComment() {
    // สร้างข้อความแสดง: ถ้ามี nickname ใส่หน้าเนื้อหา
    final commentText = ticket.lastCommentNickname != null
        ? '${ticket.lastCommentNickname}: ${ticket.lastCommentContent}'
        : ticket.lastCommentContent ?? '';

    return Row(
      children: [
        // ไอคอนคอมเมนต์
        HugeIcon(
          icon: HugeIcons.strokeRoundedComment01,
          color: AppColors.textSecondary,
          size: AppIconSize.sm,
        ),
        const SizedBox(width: 6),
        // เนื้อหาคอมเมนต์ (ตัด 1 บรรทัด)
        Expanded(
          child: Text(
            commentText,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Chip แสดงว่า ticket นี้อยู่ในวาระประชุม
  /// ใช้สี teal อ่อน (เข้ากับ primary color ของแอป)
  Widget _buildMeetingAgendaChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // ใช้ primary color จางๆ เพราะ meeting agenda เป็นข้อมูลเสริม
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedMeetingRoom,
            color: AppColors.primary,
            size: AppIconSize.sm,
          ),
          const SizedBox(width: 4),
          Text(
            'วาระประชุม',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Format วันที่เป็นแบบสั้นภาษาไทย
  /// เช่น "17 มี.ค." สำหรับ 17 March
  /// ใช้ intl package สำหรับ format
  String _formatThaiDate(DateTime date) {
    // ใช้ 'd MMM' format + locale th
    // จะได้ "17 มี.ค." แทน "17 Mar"
    try {
      return DateFormat('d MMM', 'th').format(date);
    } catch (_) {
      // Fallback ถ้า locale th ไม่พร้อม
      return DateFormat('d MMM').format(date);
    }
  }
}
