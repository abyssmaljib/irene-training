// หน้า Detail สำหรับดูและจัดการ Ticket รายตัว
//
// แสดง:
// - ข้อมูลหลัก (หมวดหมู่, สถานะ, หัวข้อ, คำอธิบาย)
// - Metadata (ผู้สร้าง, วันที่, ผู้รับบริการ, โซน, วันติดตาม)
// - ข้อมูลยา (ถ้าเป็น ticket ยา)
// - สถานะ stock (ถ้าเป็น ticket ยา)
// - Timeline (ประวัติ comment, เปลี่ยนสถานะ, คำสั่งแพทย์)
// - ช่องพิมพ์ comment ด้านล่าง
//
// Pattern เดียวกับ IncidentChatScreen:
// - ConsumerStatefulWidget + Riverpod providers
// - Optimistic update ด้วย copyWith
// - ValueListenableBuilder สำหรับ send button (performance)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/services/user_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/network_image.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';
import '../services/ticket_feature_service.dart';
import '../widgets/mention_text_field.dart';
import '../widgets/ticket_category_badge.dart';
import '../widgets/ticket_status_badge.dart';
import '../widgets/ticket_timeline_widget.dart';
import '../widgets/stock_status_selector.dart';

/// หน้า Detail สำหรับดูรายละเอียดตั๋วและโต้ตอบ (comment, เปลี่ยนสถานะ)
class TicketDetailScreen extends ConsumerStatefulWidget {
  /// ข้อมูล ticket เริ่มต้น (จาก list screen)
  /// ใช้เป็นค่าเริ่มต้นก่อน fetch ข้อมูลล่าสุดจาก server
  final Ticket ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  ConsumerState<TicketDetailScreen> createState() =>
      _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  /// Controller สำหรับช่อง comment — ใช้ ValueListenableBuilder ดักฟัง
  /// เพื่อ enable/disable ปุ่มส่งโดยไม่ต้อง setState ทั้งหน้า (performance)
  final _commentController = TextEditingController();

  /// flag บอกว่ากำลังส่ง comment อยู่หรือไม่ — ใช้ disable ปุ่มส่ง
  bool _isSending = false;

  /// รายการ UUID ของคนที่ถูก @mention ใน comment
  /// อัพเดตผ่าน onMentionsChange callback จาก MentionTextField
  List<String> _mentionedUserIds = [];

  /// สำเนาข้อมูล ticket ที่ mutable — ใช้สำหรับ optimistic update
  /// เช่น เปลี่ยนสถานะแล้วอัปเดต UI ทันที ก่อนรอ server ตอบ
  late Ticket _ticket;

  @override
  void initState() {
    super.initState();
    // คัดลอก ticket จาก parameter เป็น mutable state
    _ticket = widget.ticket;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Action Methods
  // ===========================================================================

  /// เปลี่ยนสถานะ ticket ผ่าน popup menu
  /// บันทึก status_change event ใน timeline ด้วย
  Future<void> _handleStatusChange(TicketStatus newStatus) async {
    final oldStatus = _ticket.status;
    try {
      // เรียก service เพื่อเปลี่ยนสถานะใน DB
      await TicketFeatureService.instance.changeStatus(
        _ticket.id,
        newStatus.value,
        oldStatus: oldStatus.value,
      );

      // Optimistic update — อัปเดต UI ทันทีหลัง server ตอบสำเร็จ
      setState(() {
        _ticket = _ticket.copyWith(status: newStatus);
      });

      // Refresh timeline เพื่อแสดง status_change event ใหม่
      ref.invalidate(ticketTimelineProvider(_ticket.id));

      if (mounted) {
        AppToast.success(
          context,
          'เปลี่ยนสถานะเป็น ${newStatus.displayText}',
        );
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'เปลี่ยนสถานะไม่สำเร็จ');
    }
  }

  /// ส่ง comment ใหม่ใน timeline
  /// หลังส่งสำเร็จจะ clear input, refresh timeline,
  /// และ refresh detail (เผื่อ auto-transition เปลี่ยนสถานะ)
  /// ถ้ามี @mention จะส่ง notification ให้คนที่ถูก mention ด้วย
  Future<void> _handleSendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    // เก็บ mentionedUserIds ก่อน clear (เพราะ clear จะ reset mentions)
    final mentionIds = List<String>.from(_mentionedUserIds);

    setState(() => _isSending = true);
    try {
      // เรียก service เพื่อบันทึก comment ลง DB (พร้อม mentioned_users)
      await TicketFeatureService.instance.addComment(
        _ticket.id,
        content,
        mentionedUsers: mentionIds.isNotEmpty ? mentionIds : null,
      );

      // Clear input หลังส่งสำเร็จ
      _commentController.clear();
      _mentionedUserIds = [];

      // ส่ง notification ให้คนที่ถูก @mention (ไม่ block UI)
      if (mentionIds.isNotEmpty) {
        final senderName = await UserService().getUserName() ?? 'ไม่ทราบชื่อ';
        // ไม่ await — noti ส่งเบื้องหลังได้
        TicketFeatureService.instance.sendMentionNotifications(
          userIds: mentionIds,
          ticketId: _ticket.id,
          content: content,
          senderNickname: senderName,
        );
      }

      // Refresh timeline เพื่อแสดง comment ใหม่
      ref.invalidate(ticketTimelineProvider(_ticket.id));

      // C2: Auto-transition อาจเปลี่ยนสถานะ ticket ได้ → refresh detail ด้วย
      ref.invalidate(ticketDetailProvider(_ticket.id));
    } catch (e) {
      if (mounted) AppToast.error(context, 'ส่งความคิดเห็นไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// เปลี่ยนสถานะ stock สำหรับ ticket ยา
  /// ใช้ optimistic update เพื่อ UI ตอบสนองทันที
  Future<void> _handleStockStatusChange(String newStatus) async {
    try {
      await TicketFeatureService.instance
          .updateStockStatus(_ticket.id, newStatus);

      // Optimistic update
      setState(() {
        _ticket = _ticket.copyWith(stockStatus: newStatus);
      });

      if (mounted) AppToast.success(context, 'อัปเดตสถานะสต๊อกแล้ว');
    } catch (e) {
      if (mounted) AppToast.error(context, 'อัปเดตไม่สำเร็จ');
    }
  }

  /// Toggle วาระประชุม — optimistic update + revert on failure
  /// อัปเดต UI ทันที แล้วค่อยส่งไป server
  /// ถ้า server fail จะ revert กลับค่าเดิม (C10 pattern)
  Future<void> _handleMeetingAgendaToggle() async {
    final newValue = !_ticket.meetingAgenda;

    // Optimistic update — เปลี่ยน UI ทันที
    setState(() {
      _ticket = _ticket.copyWith(meetingAgenda: newValue);
    });

    try {
      await TicketFeatureService.instance
          .toggleMeetingAgenda(_ticket.id, newValue);
    } catch (e) {
      // C10: Revert on failure — กลับค่าเดิมถ้า server fail
      setState(() {
        _ticket = _ticket.copyWith(meetingAgenda: !newValue);
      });
      if (mounted) AppToast.error(context, 'อัปเดตไม่สำเร็จ');
    }
  }

  /// Toggle สำคัญ (priority) — optimistic update + revert on failure
  /// Pattern เดียวกับ meeting agenda toggle
  Future<void> _handlePriorityToggle() async {
    final newValue = !_ticket.priority;

    // Optimistic update
    setState(() {
      _ticket = _ticket.copyWith(priority: newValue);
    });

    try {
      await TicketFeatureService.instance.togglePriority(_ticket.id, newValue);
    } catch (e) {
      // Revert on failure (C10 pattern)
      setState(() {
        _ticket = _ticket.copyWith(priority: !newValue);
      });
      if (mounted) AppToast.error(context, 'อัปเดตไม่สำเร็จ');
    }
  }

  /// เปิด DatePicker เพื่อเลือกวันติดตาม
  /// หลังเลือกจะอัปเดตลง DB ทันที
  Future<void> _handleFollowUpDatePick() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      // เริ่มจากวันติดตามปัจจุบัน (ถ้ายังไม่ผ่าน) หรือวันนี้
      // ถ้า followUpDate อยู่ในอดีต → ใช้ today แทน (เพราะ firstDate = today)
      initialDate: (_ticket.followUpDate != null &&
              !_ticket.followUpDate!.isBefore(now))
          ? _ticket.followUpDate!
          : now,
      firstDate: now, // ไม่ให้เลือกวันในอดีต (consistent กับ create screen)
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'เลือกวันติดตาม',
      cancelText: 'ยกเลิก',
      confirmText: 'ตกลง',
    );

    if (picked == null) return; // user กดยกเลิก

    try {
      await TicketFeatureService.instance
          .updateFollowUpDate(_ticket.id, picked);

      // อัปเดต UI
      setState(() {
        _ticket = _ticket.copyWith(followUpDate: picked);
      });

      if (mounted) AppToast.success(context, 'อัปเดตวันติดตามแล้ว');
    } catch (e) {
      if (mounted) AppToast.error(context, 'อัปเดตไม่สำเร็จ');
    }
  }

  /// Pull-to-refresh — refresh ทั้ง detail และ timeline
  /// ตรวจสอบว่า ticket ยังอยู่ (S6: ถ้าถูกลบแล้วให้ pop กลับ)
  Future<void> _refresh() async {
    // เรียก refresh provider ที่ invalidate ทั้ง detail + timeline + list
    await ref.read(refreshTicketDetailProvider(_ticket.id))();

    // S6: ตรวจสอบว่า ticket ยังอยู่หรือถูกลบไปแล้ว
    final refreshedTicket =
        await ref.read(ticketDetailProvider(_ticket.id).future);

    if (refreshedTicket == null) {
      // Ticket ถูกลบแล้ว — แจ้ง user แล้ว pop กลับ
      if (mounted) {
        AppToast.info(context, 'ตั๋วนี้ถูกลบแล้ว');
        Navigator.of(context).pop();
      }
      return;
    }

    // อัปเดต local state ด้วยข้อมูลล่าสุดจาก server
    if (mounted) {
      setState(() {
        _ticket = refreshedTicket;
      });
    }
  }

  // ===========================================================================
  // Build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'ตั๋ว #${_ticket.id}',
          style: AppTypography.title,
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          // Dropdown สำหรับเปลี่ยนสถานะ ticket
          PopupMenuButton<TicketStatus>(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowDown01,
              color: AppColors.textPrimary,
              size: AppIconSize.lg,
            ),
            tooltip: 'เปลี่ยนสถานะ',
            itemBuilder: (_) => TicketStatus.values
                // ซ่อนสถานะปัจจุบัน — ไม่ให้เลือกสถานะเดิมซ้ำ
                .where((s) => s != _ticket.status)
                .map(
                  (s) => PopupMenuItem<TicketStatus>(
                    value: s,
                    child: Text('${s.emoji} ${s.displayText}'),
                  ),
                )
                .toList(),
            onSelected: _handleStatusChange,
          ),
        ],
      ),
      body: Column(
        children: [
          // ===== Scrollable content area =====
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: SingleChildScrollView(
                // AlwaysScrollable เพื่อให้ pull-to-refresh ทำงานได้เสมอ
                // แม้เนื้อหาจะไม่เต็มจอ
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ข้อมูลหลัก: หมวดหมู่ + สถานะ + หัวข้อ + คำอธิบาย + toggles
                    _buildInfoSection(),
                    AppSpacing.verticalGapMd,

                    // Metadata: ผู้สร้าง, วันที่, ผู้รับบริการ, โซน, วันติดตาม
                    _buildMetadataSection(),

                    // การ์ดข้อมูลยา (แสดงเฉพาะ ticket ที่เชื่อมกับรายการยา)
                    if (_ticket.medListId != null) ...[
                      AppSpacing.verticalGapMd,
                      _buildMedicineCard(),
                    ],

                    // สถานะ stock (แสดงเฉพาะ ticket ยา)
                    if (_ticket.category == TicketCategory.medicine ||
                        _ticket.medListId != null) ...[
                      AppSpacing.verticalGapMd,
                      _buildStockStatusSection(),
                    ],

                    // Timeline: ประวัติ comment, สถานะ, คำสั่งแพทย์
                    AppSpacing.verticalGapMd,
                    _buildTimelineSection(),
                  ],
                ),
              ),
            ),
          ),

          // ===== Bottom comment input bar =====
          _buildCommentInput(),
        ],
      ),
    );
  }

  // ===========================================================================
  // Info Section — หมวดหมู่, สถานะ, หัวข้อ, คำอธิบาย, toggles
  // ===========================================================================

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // แถวแรก: badge หมวดหมู่ + badge สถานะ
        Row(
          children: [
            TicketCategoryBadge(category: _ticket.category),
            AppSpacing.horizontalGapSm,
            TicketStatusBadge(status: _ticket.status),
          ],
        ),
        AppSpacing.verticalGapSm,

        // หัวข้อ ticket (bold 18px)
        if (_ticket.title != null && _ticket.title!.isNotEmpty)
          Text(
            _ticket.title!,
            style: AppTypography.heading3,
          ),
        AppSpacing.verticalGapXs,

        // คำอธิบาย ticket (สีเทา)
        if (_ticket.description != null && _ticket.description!.isNotEmpty)
          Text(
            _ticket.description!,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        AppSpacing.verticalGapSm,

        // แถว toggles: สำคัญ + วาระประชุม
        Row(
          children: [
            // ปุ่ม "สำคัญ" — กดเพื่อ toggle priority
            _buildToggleChip(
              icon: HugeIcons.strokeRoundedStar,
              label: 'สำคัญ',
              isActive: _ticket.priority,
              activeColor: Colors.amber.shade700,
              onTap: _handlePriorityToggle,
            ),
            AppSpacing.horizontalGapSm,

            // ปุ่ม "วาระประชุม" — กดเพื่อ toggle meeting agenda
            _buildToggleChip(
              icon: HugeIcons.strokeRoundedCalendar03,
              label: 'วาระประชุม',
              isActive: _ticket.meetingAgenda,
              activeColor: AppColors.primary,
              onTap: _handleMeetingAgendaToggle,
            ),
          ],
        ),
      ],
    );
  }

  /// สร้าง chip ที่กดได้สำหรับ toggle feature flags (priority, meeting agenda)
  /// [isActive] = true → แสดงสีสด, false → แสดงสีเทา
  Widget _buildToggleChip({
    required dynamic icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          // พื้นหลังเปลี่ยนตาม active state
          color: isActive
              ? activeColor.withValues(alpha: 0.1)
              : AppColors.tagNeutralBg,
          borderRadius: AppRadius.fullRadius,
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.3)
                : AppColors.alternate,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: icon,
              size: AppIconSize.sm,
              color: isActive ? activeColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: isActive ? activeColor : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Metadata Section — ผู้สร้าง, วันที่, ผู้รับบริการ, โซน, วันติดตาม
  // ===========================================================================

  Widget _buildMetadataSection() {
    return Container(
      padding: AppSpacing.paddingSm + const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.tagNeutralBg,
        borderRadius: AppRadius.smallRadius,
      ),
      child: Column(
        children: [
          // ผู้สร้าง
          _metadataRow(
            icon: HugeIcons.strokeRoundedUser,
            label: 'สร้างโดย',
            value: _ticket.createdByNickname ?? 'ไม่ทราบ',
          ),
          AppSpacing.verticalGapXs,

          // วันที่สร้าง
          _metadataRow(
            icon: HugeIcons.strokeRoundedCalendar03,
            label: 'สร้างเมื่อ',
            value: _formatDateTime(_ticket.createdAt),
          ),

          // ผู้รับบริการ (แสดงเฉพาะเมื่อมี)
          if (_ticket.residentName != null) ...[
            AppSpacing.verticalGapXs,
            _metadataRow(
              icon: HugeIcons.strokeRoundedHospital02,
              label: 'ผู้รับบริการ',
              value: _ticket.residentName!,
            ),
          ],

          // โซน (แสดงเฉพาะเมื่อมี)
          if (_ticket.zoneName != null) ...[
            AppSpacing.verticalGapXs,
            _metadataRow(
              icon: HugeIcons.strokeRoundedLocation01,
              label: 'โซน',
              value: _ticket.zoneName!,
            ),
          ],

          AppSpacing.verticalGapXs,

          // วันติดตาม — กดเพื่อเปิด DatePicker เลือกวันใหม่
          GestureDetector(
            onTap: _handleFollowUpDatePick,
            child: _metadataRow(
              icon: HugeIcons.strokeRoundedClock01,
              label: 'ติดตาม',
              value: _ticket.followUpDate != null
                  ? _formatDate(_ticket.followUpDate!)
                  : 'ไม่ได้กำหนด',
              // แสดงลูกศรบอกว่ากดเลือกได้
              trailing: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: AppIconSize.sm,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// แถว metadata แต่ละรายการ: icon + label + value
  Widget _metadataRow({
    required dynamic icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Icon ด้านหน้า
          HugeIcon(
            icon: icon,
            size: AppIconSize.md,
            color: AppColors.textSecondary,
          ),
          AppSpacing.horizontalGapSm,

          // Label (เช่น "สร้างโดย")
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.horizontalGapSm,

          // Value (เช่น "สมชาย")
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Icon trailing (ถ้ามี เช่น ลูกศรสำหรับ date picker)
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing,
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Medicine Card — แสดงข้อมูลยาที่เกี่ยวข้อง
  // ===========================================================================

  Widget _buildMedicineCard() {
    return Container(
      padding: AppSpacing.paddingSm + const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smallRadius,
        border: Border.all(color: AppColors.alternate, width: 1),
      ),
      child: Row(
        children: [
          // รูปเม็ดยา (ถ้ามี)
          if (_ticket.medPillpicUrl != null &&
              _ticket.medPillpicUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: AppRadius.smallRadius,
              child: IreneNetworkImage(
                imageUrl: _ticket.medPillpicUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                memCacheWidth: 96, // 2x สำหรับ high DPI
                compact: true,
              ),
            ),
            AppSpacing.horizontalGapSm,
          ],

          // ชื่อยา (brand + generic)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ชื่อการค้า (bold)
                if (_ticket.medBrandName != null)
                  Text(
                    _ticket.medBrandName!,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                // ชื่อสามัญ (เทาเล็ก)
                if (_ticket.medGenericName != null)
                  Text(
                    _ticket.medGenericName!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Stock Status Section — สถานะ stock สำหรับ ticket ยา
  // ===========================================================================

  Widget _buildStockStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'สถานะสต๊อก',
          style: AppTypography.title,
        ),
        AppSpacing.verticalGapSm,
        // Widget ให้เลือกสถานะ stock (เปิด bottom sheet)
        StockStatusSelector(
          currentStatus: _ticket.stockStatus,
          onStatusChanged: _handleStockStatusChange,
        ),
      ],
    );
  }

  // ===========================================================================
  // Timeline Section — ประวัติ comment, สถานะ, คำสั่งแพทย์
  // ===========================================================================

  Widget _buildTimelineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ไทม์ไลน์',
          style: AppTypography.title,
        ),
        AppSpacing.verticalGapSm,

        // ใช้ Consumer เพื่อ watch เฉพาะ timeline provider
        // ไม่ rebuild ทั้งหน้าเมื่อ timeline เปลี่ยน
        Consumer(
          builder: (context, ref, child) {
            final timelineAsync =
                ref.watch(ticketTimelineProvider(_ticket.id));

            return timelineAsync.when(
              // แสดง timeline เมื่อโหลดสำเร็จ
              data: (comments) {
                if (comments.isEmpty) {
                  return Padding(
                    padding: AppSpacing.paddingVerticalMd,
                    child: Center(
                      child: Text(
                        'ยังไม่มีกิจกรรม',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }
                return TicketTimelineWidget(comments: comments);
              },
              // แสดง loading indicator ระหว่างโหลด
              loading: () => const Padding(
                padding: AppSpacing.paddingVerticalMd,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              ),
              // แสดง error message ถ้าโหลดไม่ได้
              error: (e, _) => Padding(
                padding: AppSpacing.paddingVerticalMd,
                child: Center(
                  child: Text(
                    'โหลดไทม์ไลน์ไม่สำเร็จ',
                    style: AppTypography.body.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // Comment Input Bar — ช่องพิมพ์ comment ด้านล่างจอ
  // ===========================================================================

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        // เงาด้านบนเพื่อแยก input bar ออกจาก content
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        // ไม่ต้อง SafeArea ด้านบน (มี AppBar แล้ว)
        top: false,
        child: Row(
          children: [
            // ===== ช่อง input — รองรับ @mention =====
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  // ดึง staff list สำหรับ @mention autocomplete
                  final staffAsync = ref.watch(ticketStaffListProvider);
                  final staffList = staffAsync.value ?? [];

                  return MentionTextField(
                    controller: _commentController,
                    staffList: staffList,
                    hintText: 'เขียนความคิดเห็น... (พิมพ์ @ เพื่อแท็ก)',
                    maxLines: 3,
                    // เก็บ UUID ของคนที่ถูก mention ไว้ส่ง notification ตอน submit
                    onMentionsChange: (ids) {
                      _mentionedUserIds = ids;
                    },
                  );
                },
              ),
            ),
            AppSpacing.horizontalGapSm,

            // ===== ปุ่มส่ง =====
            // ใช้ ValueListenableBuilder เพื่อ rebuild เฉพาะปุ่ม
            // ไม่ rebuild ทั้งหน้าเมื่อพิมพ์ (performance guideline)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _commentController,
              builder: (_, value, _) {
                // ส่งได้เมื่อ: มีข้อความ + ไม่ได้กำลังส่งอยู่
                final canSend =
                    value.text.trim().isNotEmpty && !_isSending;

                return IconButton(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedSent,
                    color: canSend ? AppColors.primary : AppColors.alternate,
                    size: AppIconSize.lg,
                  ),
                  // C9: validate ว่าไม่ว่าง ก่อนให้กด
                  onPressed: canSend ? _handleSendComment : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Format Helpers
  // ===========================================================================

  /// Format DateTime เป็น "d MMM yyyy HH:mm" (ภาษาไทย)
  /// เช่น "17 มี.ค. 2026 10:30"
  String _formatDateTime(DateTime dateTime) {
    try {
      return DateFormat('d MMM yyyy HH:mm', 'th').format(dateTime.toLocal());
    } catch (_) {
      // Fallback กรณี locale ไม่พร้อม
      return DateFormat('d MMM yyyy HH:mm').format(dateTime.toLocal());
    }
  }

  /// Format Date เป็น "d MMM yyyy" (ภาษาไทย)
  /// เช่น "17 มี.ค. 2026"
  String _formatDate(DateTime date) {
    try {
      return DateFormat('d MMM yyyy', 'th').format(date);
    } catch (_) {
      return DateFormat('d MMM yyyy').format(date);
    }
  }
}
