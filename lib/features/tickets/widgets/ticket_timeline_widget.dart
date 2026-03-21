// Timeline widget สำหรับแสดงประวัติ comment, การเปลี่ยนสถานะ, และคำสั่งแพทย์
// ใน ticket detail page
//
// รองรับ 4 ประเภท event:
// 1. comment — ความคิดเห็นปกติ พร้อม @mention highlighting
// 2. statusChange — เปลี่ยนสถานะ (แสดงเป็นแถบสีเทา)
// 3. doctorOrder — คำสั่งแพทย์ (แสดงเป็นกล่องสีเหลือง/amber)
// 4. created — สร้างตั๋วใหม่ (แสดงเป็นแถบสี primary)
//
// มี timeline line ด้านซ้ายเชื่อมแต่ละ entry เข้าด้วยกัน

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/network_image.dart';
import '../models/ticket.dart';
import '../models/ticket_comment.dart';

/// Widget แสดง timeline ของ ticket
/// ใช้ใน ticket detail page เพื่อแสดงลำดับเหตุการณ์ทั้งหมด
class TicketTimelineWidget extends StatelessWidget {
  /// รายการ comment/event ที่จะแสดงใน timeline
  /// ควรเรียงตาม createdAt จากเก่าไปใหม่
  final List<TicketComment> comments;

  const TicketTimelineWidget({super.key, required this.comments});

  @override
  Widget build(BuildContext context) {
    // ถ้าไม่มี comment ไม่ต้องแสดงอะไร
    if (comments.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      // ใช้ shrinkWrap เพราะ timeline มักอยู่ใน ScrollView อื่น
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final comment = comments[index];
        // isLast ใช้เพื่อไม่ต้องวาดเส้น timeline ต่อลงมาจาก entry สุดท้าย
        final isLast = index == comments.length - 1;

        return _buildTimelineEntry(comment, isLast: isLast);
      },
    );
  }

  /// สร้าง entry แต่ละอันใน timeline
  /// มีเส้น timeline ด้านซ้ายเชื่อมแต่ละ entry
  Widget _buildTimelineEntry(TicketComment comment, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== เส้น timeline ด้านซ้าย =====
          // ใช้ Column วาดจุดกลม + เส้นเชื่อมลงมา
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 6),
                // จุดกลมบน timeline — สีต่างกันตามประเภท event
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _getTimelineDotColor(comment.eventType),
                    shape: BoxShape.circle,
                  ),
                ),
                // เส้นเชื่อมลงไปยัง entry ถัดไป (ไม่แสดงที่ entry สุดท้าย)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.alternate,
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.horizontalGapSm,

          // ===== เนื้อหาของแต่ละ event =====
          Expanded(
            child: Padding(
              // เว้นด้านล่างเพื่อแยก entry แต่ละอัน
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildEventContent(comment),
            ),
          ),
        ],
      ),
    );
  }

  /// สีของจุด timeline ตามประเภท event
  /// - comment: สีเทา (เป็น event ทั่วไป)
  /// - statusChange: สีฟ้า (เปลี่ยนสถานะ)
  /// - doctorOrder: สี amber (คำสั่งแพทย์)
  /// - created: สี primary/teal (สร้างตั๋ว)
  Color _getTimelineDotColor(CommentEventType eventType) {
    switch (eventType) {
      case CommentEventType.comment:
        return AppColors.textSecondary;
      case CommentEventType.statusChange:
        return Colors.blue.shade400;
      case CommentEventType.doctorOrder:
        return Colors.amber.shade600;
      case CommentEventType.created:
        return AppColors.primary;
    }
  }

  /// เลือก widget ที่จะแสดงตามประเภท event
  Widget _buildEventContent(TicketComment comment) {
    switch (comment.eventType) {
      case CommentEventType.comment:
        return _buildCommentEvent(comment);
      case CommentEventType.statusChange:
        return _buildStatusChangeEvent(comment);
      case CommentEventType.doctorOrder:
        return _buildDoctorOrderEvent(comment);
      case CommentEventType.created:
        return _buildCreatedEvent(comment);
    }
  }

  // ===========================================================================
  // Comment Event — ความคิดเห็นปกติ
  // ===========================================================================

  /// แสดง comment ปกติ: avatar + ชื่อ + เวลา + เนื้อหา (พร้อม @mention)
  Widget _buildCommentEvent(TicketComment comment) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar ของผู้ comment
        IreneNetworkAvatar(
          imageUrl: comment.creatorPhotoUrl,
          radius: 16,
        ),
        AppSpacing.horizontalGapSm,

        // ชื่อ + เวลา + เนื้อหา
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // แถวแรก: ชื่อเล่น + เวลาสัมพัทธ์
              Row(
                children: [
                  // ชื่อเล่นของผู้ comment (bold)
                  Text(
                    comment.creatorNickname ?? 'ไม่ทราบชื่อ',
                    style: AppTypography.subtitle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // เวลาสัมพัทธ์ (เช่น "5 นาทีที่แล้ว")
                  Flexible(
                    child: Text(
                      comment.relativeTime,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              AppSpacing.verticalGapXs,

              // เนื้อหา comment — รองรับ @mention highlighting
              if (comment.content != null && comment.content!.isNotEmpty)
                _buildMentionText(comment.content!),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Status Change Event — เปลี่ยนสถานะ
  // ===========================================================================

  /// แสดง event การเปลี่ยนสถานะ: icon ลูกศร + "เปลี่ยนสถานะ: X → Y" + เวลา
  Widget _buildStatusChangeEvent(TicketComment comment) {
    // แปลง string สถานะเก่า/ใหม่เป็นข้อความภาษาไทย
    // ใช้ TicketStatus.fromString() เพื่อ backward compat (เช่น 'completed' → 'เสร็จสิ้น')
    final oldStatusDisplay =
        TicketStatus.fromString(comment.oldStatus).displayText;
    final newStatusDisplay =
        TicketStatus.fromString(comment.newStatus).displayText;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        // พื้นหลังสีเทาอ่อนเพื่อแยกจาก comment ปกติ
        color: AppColors.tagNeutralBg,
        borderRadius: AppRadius.smallRadius,
      ),
      child: Row(
        children: [
          // Icon ลูกศรบอกว่าเป็นการเปลี่ยนสถานะ
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            size: AppIconSize.md,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),

          // ข้อความ "เปลี่ยนสถานะ: X → Y"
          Expanded(
            child: Text(
              'เปลี่ยนสถานะ: $oldStatusDisplay → $newStatusDisplay',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // เวลาสัมพัทธ์
          Text(
            comment.relativeTime,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Doctor Order Event — คำสั่งแพทย์
  // ===========================================================================

  /// แสดง event คำสั่งแพทย์: กล่องสี amber พร้อม icon stethoscope
  Widget _buildDoctorOrderEvent(TicketComment comment) {
    return Container(
      padding: AppSpacing.paddingSm,
      decoration: BoxDecoration(
        // พื้นหลังสี amber อ่อน ให้รู้ว่าเป็นคำสั่งจากแพทย์
        color: Colors.amber.shade50,
        borderRadius: AppRadius.smallRadius,
        border: Border.all(
          color: Colors.amber.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // แถวหัวข้อ: icon stethoscope + "คำสั่งแพทย์"
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedStethoscope,
                size: AppIconSize.md,
                color: Colors.amber.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'คำสั่งแพทย์',
                style: AppTypography.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),

          // ชื่อแพทย์ (ถ้ามี)
          if (comment.doctorName != null &&
              comment.doctorName!.isNotEmpty) ...[
            AppSpacing.verticalGapXs,
            Text(
              'แพทย์: ${comment.doctorName}',
              style: AppTypography.bodySmall.copyWith(
                color: Colors.amber.shade800,
              ),
            ),
          ],

          // เนื้อหาคำสั่งแพทย์
          if (comment.content != null && comment.content!.isNotEmpty) ...[
            AppSpacing.verticalGapXs,
            Text(
              comment.content!,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],

          // เวลาสัมพัทธ์ (มุมล่างขวา)
          AppSpacing.verticalGapXs,
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              comment.relativeTime,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Created Event — สร้างตั๋ว
  // ===========================================================================

  /// แสดง event การสร้างตั๋ว: กล่องสี primary อ่อน + icon add
  Widget _buildCreatedEvent(TicketComment comment) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        // พื้นหลังสี primary อ่อน (teal อ่อน)
        color: AppColors.accent1,
        borderRadius: AppRadius.smallRadius,
      ),
      child: Row(
        children: [
          // Icon + (add)
          HugeIcon(
            icon: HugeIcons.strokeRoundedAdd01,
            size: AppIconSize.md,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),

          // ข้อความ "สร้างตั๋ว"
          Text(
            'สร้างตั๋ว',
            style: AppTypography.subtitle.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),

          // เวลาสัมพัทธ์
          Text(
            comment.relativeTime,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // @Mention Highlighting
  // ===========================================================================

  /// แสดงข้อความ comment พร้อม highlight @mention
  ///
  /// ตรวจจับ pattern @ชื่อ ใน text แล้วแสดงเป็น bold + สี primary
  /// เช่น "ส่งยาให้ @สมชาย ด้วยนะ" → "@สมชาย" จะเป็นสี teal + bold
  Widget _buildMentionText(String text) {
    // Regex จับ @ตามด้วยตัวอักษรที่ไม่ใช่ space (รองรับภาษาไทย + อังกฤษ)
    final mentionRegex = RegExp(r'@(\S+)');
    final matches = mentionRegex.allMatches(text);

    // ถ้าไม่มี @mention แสดง text ธรรมดา
    if (matches.isEmpty) {
      return Text(
        text,
        style: AppTypography.body,
      );
    }

    // สร้าง TextSpan list โดยแยกส่วนที่เป็น @mention ออกมา highlight
    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final match in matches) {
      // เพิ่มข้อความก่อน @mention (ถ้ามี)
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
        ));
      }

      // เพิ่ม @mention ที่ highlight แล้ว (bold + สี primary)
      spans.add(TextSpan(
        text: match.group(0), // เช่น "@สมชาย"
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ));

      currentIndex = match.end;
    }

    // เพิ่มข้อความที่เหลือหลัง @mention สุดท้าย
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
      ));
    }

    return Text.rich(
      TextSpan(
        style: AppTypography.body,
        children: spans,
      ),
    );
  }
}
