import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../services/ticket_service.dart';

/// แสดง bottom sheet รายละเอียดตั๋วที่สร้างจากโพสนี้
///
/// [ticket] - ข้อมูลตั๋วแบบย่อ (จาก TicketService.getTicketForPost)
/// [onStockStatusChanged] - callback เมื่อเปลี่ยน stock_status สำเร็จ
void showTicketDetailBottomSheet(
  BuildContext context, {
  required TicketSummary ticket,
  ValueChanged<String>? onStockStatusChanged,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => TicketDetailBottomSheet(
      ticket: ticket,
      onStockStatusChanged: onStockStatusChanged,
    ),
  );
}

/// ลำดับ stock_status ทั้งหมดใน workflow ของการ restock ยา
/// เรียงตามขั้นตอนจริง: pending → ... → completed
const _stockStatusOptions = [
  ('pending', '🟡', 'รอแจ้งญาติ'),
  ('notified', '📞', 'แจ้งญาติแล้ว'),
  ('waiting_relative', '🚗', 'รอญาตินำยามา'),
  ('waiting_appointment', '🏥', 'รอไปพบแพทย์'),
  ('added_to_appointment', '📅', 'เพิ่มในนัดหมายแล้ว'),
  ('staff_purchase', '🛒', 'ญาติให้เราซื้อให้'),
  ('purchasing', '🔄', 'กำลังจัดซื้อ'),
  ('waiting_delivery', '📦', 'รอยามาส่ง'),
  ('completed', '✅', 'ได้รับยาแล้ว - เสร็จสิ้น'),
];

/// Bottom sheet แสดงรายละเอียดตั๋ว + เปลี่ยน stock_status ได้
class TicketDetailBottomSheet extends StatefulWidget {
  final TicketSummary ticket;
  final ValueChanged<String>? onStockStatusChanged;

  const TicketDetailBottomSheet({
    super.key,
    required this.ticket,
    this.onStockStatusChanged,
  });

  @override
  State<TicketDetailBottomSheet> createState() =>
      _TicketDetailBottomSheetState();
}

class _TicketDetailBottomSheetState extends State<TicketDetailBottomSheet> {
  late String _currentStockStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    // ใช้ stockStatus จาก ticket ถ้ามี, ไม่งั้น default เป็น 'pending'
    _currentStockStatus = widget.ticket.stockStatus ?? 'pending';
  }

  /// อัพเดท stock_status ไปยัง Supabase
  Future<void> _updateStockStatus(String newStatus) async {
    if (newStatus == _currentStockStatus || _isUpdating) return;

    setState(() => _isUpdating = true);

    final success = await TicketService.instance
        .updateStockStatus(widget.ticket.id, newStatus);

    if (!mounted) return;

    if (success) {
      setState(() {
        _currentStockStatus = newStatus;
        _isUpdating = false;
      });
      widget.onStockStatusChanged?.call(newStatus);
    } else {
      setState(() => _isUpdating = false);
      // แสดง error ถ้าอัพเดทไม่สำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('อัพเดทสถานะไม่สำเร็จ'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

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

          // Content — scrollable เพราะ stock_status list อาจยาว
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // สถานะ ticket + priority
                  _buildStatusRow(),
                  const SizedBox(height: AppSpacing.md),

                  // หัวข้อตั๋ว
                  Text(widget.ticket.title, style: AppTypography.heading3),
                  const SizedBox(height: AppSpacing.sm),

                  // รายละเอียด
                  if (widget.ticket.description != null &&
                      widget.ticket.description!.isNotEmpty) ...[
                    Text(
                      widget.ticket.description!,
                      style: AppTypography.body
                          .copyWith(color: AppColors.secondaryText),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // ข้อมูลเพิ่มเติม (metadata)
                  _buildMetadata(),
                  const SizedBox(height: AppSpacing.lg),

                  // === Stock Status Selector ===
                  // ให้ user เปลี่ยนสถานะ stock ได้ตรงนี้เลย
                  _buildStockStatusSection(),

                  const SizedBox(height: AppSpacing.md),
                ],
              ),
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
                Text('ตั๋ว #${widget.ticket.id}',
                    style: AppTypography.heading3),
                Text(
                  'สร้างโดย ${widget.ticket.createdByNickname ?? 'ไม่ทราบ'}',
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
            '${widget.ticket.statusEmoji} ${widget.ticket.statusLabel}',
            style: AppTypography.bodySmall.copyWith(
              color: _statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Priority badge (ถ้าสำคัญ)
        if (widget.ticket.priority)
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
        if (widget.ticket.meetingAgenda)
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
            value: _formatDate(widget.ticket.createdAt),
          ),
          // วันติดตาม (ถ้ามี)
          if (widget.ticket.followUpDate != null) ...[
            const SizedBox(height: 8),
            _buildMetadataRow(
              icon: HugeIcons.strokeRoundedAlarmClock,
              label: 'วันติดตาม',
              value: _formatDate(widget.ticket.followUpDate!),
            ),
          ],
        ],
      ),
    );
  }

  /// === Stock Status Section ===
  /// แสดง stock_status ปัจจุบัน + ให้เลือกเปลี่ยนได้
  Widget _buildStockStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'สถานะ Stock',
          style: AppTypography.heading3.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Stock status options — แสดงเป็น list ให้กดเลือก
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.alternate),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _stockStatusOptions.length; i++) ...[
                // Divider ระหว่าง items (ยกเว้น item แรก)
                if (i > 0)
                  const Divider(height: 1, color: AppColors.alternate),
                _buildStockStatusOption(_stockStatusOptions[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// แต่ละ option ใน stock_status list
  Widget _buildStockStatusOption(
    (String key, String emoji, String label) option,
  ) {
    final (key, emoji, label) = option;
    final isSelected = key == _currentStockStatus;

    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: _isUpdating ? null : () => _updateStockStatus(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Emoji
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              // Label
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.primaryText,
                  ),
                ),
              ),
              // Check icon ถ้าเลือกอยู่
              if (isSelected)
                _isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                        size: 22,
                        color: AppColors.primary,
                      ),
            ],
          ),
        ),
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
    switch (widget.ticket.status) {
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
    switch (widget.ticket.status) {
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
