import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../services/ticket_service.dart';

/// แสดง bottom sheet รายละเอียดตั๋วที่สร้างจากโพสนี้
///
/// [ticket] - ข้อมูลตั๋วแบบย่อ (จาก TicketService.getTicketForPost)
void showTicketDetailBottomSheet(
  BuildContext context, {
  required TicketSummary ticket,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => TicketDetailBottomSheet(ticket: ticket),
  );
}

/// Bottom sheet แสดงรายละเอียดตั๋ว (read-only)
/// หัวหน้าเวรกดจากหน้า post detail เพื่อดูสถานะตั๋วที่สร้างไว้
class TicketDetailBottomSheet extends StatelessWidget {
  final TicketSummary ticket;

  const TicketDetailBottomSheet({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.alternate,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          _buildHeader(context),
          const Divider(height: 1, color: AppColors.alternate),

          // Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // สถานะ + priority
                _buildStatusRow(),
                const SizedBox(height: AppSpacing.md),

                // หัวข้อตั๋ว
                Text(ticket.title, style: AppTypography.heading3),
                const SizedBox(height: AppSpacing.sm),

                // รายละเอียด
                if (ticket.description != null &&
                    ticket.description!.isNotEmpty) ...[
                  Text(
                    ticket.description!,
                    style: AppTypography.body
                        .copyWith(color: AppColors.secondaryText),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ข้อมูลเพิ่มเติม (metadata)
                _buildMetadata(),

                const SizedBox(height: AppSpacing.md),

                // หมายเหตุ: จัดการผ่าน admin
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'จัดการตั๋วนี้ได้ที่หน้า Admin',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.secondary),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Header: icon + title + ปุ่มปิด
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Icon ตั๋ว พร้อมสีตามสถานะ
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _statusBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedTicket02,
                size: 24,
                color: _statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ตั๋ว #${ticket.id}', style: AppTypography.heading3),
                Text(
                  'สร้างโดย ${ticket.createdByNickname ?? 'ไม่ทราบ'}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              size: 24,
              color: AppColors.secondaryText,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// แถวสถานะ + priority badge
  Widget _buildStatusRow() {
    return Row(
      children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _statusBgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${ticket.statusEmoji} ${ticket.statusLabel}',
            style: AppTypography.bodySmall.copyWith(
              color: _statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Priority badge (ถ้าสำคัญ)
        if (ticket.priority)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.tagFailedBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '🔴 สำคัญ',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(width: 8),
        // Meeting agenda badge
        if (ticket.meetingAgenda)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '📋 วาระประชุม',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// Metadata: วันสร้าง, วันติดตาม
  Widget _buildMetadata() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // วันที่สร้าง
          _buildMetadataRow(
            icon: HugeIcons.strokeRoundedCalendar03,
            label: 'สร้างเมื่อ',
            value: _formatDate(ticket.createdAt),
          ),
          // วันติดตาม (ถ้ามี)
          if (ticket.followUpDate != null) ...[
            const SizedBox(height: 8),
            _buildMetadataRow(
              icon: HugeIcons.strokeRoundedAlarmClock,
              label: 'วันติดตาม',
              value: _formatDate(ticket.followUpDate!),
            ),
          ],
        ],
      ),
    );
  }

  /// แถวข้อมูล metadata แต่ละรายการ
  Widget _buildMetadataRow({
    required dynamic icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 16, color: AppColors.secondaryText),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.secondaryText),
        ),
        Text(
          value,
          style: AppTypography.bodySmall
              .copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  /// Format DateTime เป็น dd/MM/yyyy
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// สีพื้นหลังตามสถานะ
  Color get _statusBgColor {
    switch (ticket.status) {
      case 'open':
        return AppColors.tagPendingBg;
      case 'in_progress':
        return AppColors.accent2;
      case 'completed':
      case 'closed':
        return AppColors.tagPassedBg;
      case 'cancelled':
        return AppColors.tagNeutralBg;
      default:
        return AppColors.tagNeutralBg;
    }
  }

  /// สีตัวอักษรตามสถานะ
  Color get _statusColor {
    switch (ticket.status) {
      case 'open':
        return AppColors.tagPendingText;
      case 'in_progress':
        return AppColors.secondary;
      case 'completed':
      case 'closed':
        return AppColors.tagPassedText;
      case 'cancelled':
        return AppColors.tagNeutralText;
      default:
        return AppColors.tagNeutralText;
    }
  }
}
