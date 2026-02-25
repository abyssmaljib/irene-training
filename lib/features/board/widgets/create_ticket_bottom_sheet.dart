import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/checkbox_tile.dart';
import '../../../core/widgets/input_fields.dart';
import '../../../core/widgets/success_popup.dart';
import '../models/post.dart';
import '../services/ticket_service.dart';

/// แสดง bottom sheet สำหรับสร้างตั๋วจากโพส
///
/// [post] - โพสต้นทาง (จะ pre-fill หัวข้อ, รายละเอียด, ผู้รับบริการ)
/// [onTicketCreated] - callback เมื่อสร้างตั๋วสำเร็จ
void showCreateTicketBottomSheet(
  BuildContext context, {
  required Post post,
  VoidCallback? onTicketCreated,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // ให้ bottom sheet ขยายได้เต็มจอ
    backgroundColor: Colors.transparent,
    builder: (context) => CreateTicketBottomSheet(
      post: post,
      onTicketCreated: onTicketCreated,
    ),
  );
}

/// Bottom sheet สำหรับสร้างตั๋วจากโพส
/// Pre-fill ข้อมูลจากโพสต้นทาง (หัวข้อ, รายละเอียด, ผู้รับบริการ)
class CreateTicketBottomSheet extends ConsumerStatefulWidget {
  /// โพสต้นทางที่จะสร้างตั๋ว
  final Post post;

  /// Callback เมื่อสร้างตั๋วสำเร็จ
  final VoidCallback? onTicketCreated;

  const CreateTicketBottomSheet({
    super.key,
    required this.post,
    this.onTicketCreated,
  });

  @override
  ConsumerState<CreateTicketBottomSheet> createState() =>
      _CreateTicketBottomSheetState();
}

class _CreateTicketBottomSheetState
    extends ConsumerState<CreateTicketBottomSheet> {
  // Controllers สำหรับ text fields
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  // Form state
  bool _isPriority = false;
  bool _isMeetingAgenda = false;
  DateTime? _followUpDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Pre-fill หัวข้อจาก post title หรือ ตัดเนื้อหา 50 ตัวอักษรแรก
    final post = widget.post;
    final defaultTitle = post.title ??
        (post.text != null
            ? post.text!.substring(0, min(50, post.text!.length))
            : '');
    _titleController = TextEditingController(text: defaultTitle);

    // Pre-fill รายละเอียดจากเนื้อหาโพส
    _descriptionController = TextEditingController(text: post.text ?? '');

    // ตั้ง follow-up date เป็นพรุ่งนี้
    _followUpDate = DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// สร้างตั๋วจากข้อมูลในฟอร์ม
  Future<void> _submitTicket() async {
    // Validate: หัวข้อต้องไม่ว่าง
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกหัวข้อตั๋ว')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // เรียก TicketService สร้างตั๋ว
    final ticketId = await TicketService.instance.createTicketFromPost(
      postId: widget.post.id,
      title: title,
      description: _descriptionController.text.trim(),
      residentId: widget.post.residentId,
      priority: _isPriority,
      followUpDate: _followUpDate,
      meetingAgenda: _isMeetingAgenda,
    );

    if (!mounted) return;

    if (ticketId != null) {
      // สำเร็จ: ปิด bottom sheet แล้วแสดง popup
      Navigator.of(context).pop();
      widget.onTicketCreated?.call();
      SuccessPopup.show(context, message: 'สร้างตั๋ว #$ticketId แล้ว');
    } else {
      // ล้มเหลว: แสดง error
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สร้างตั๋วไม่สำเร็จ กรุณาลองใหม่')),
      );
    }
  }

  /// เปิด date picker สำหรับเลือกวันติดตาม
  Future<void> _pickFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'เลือกวันติดตาม',
      cancelText: 'ยกเลิก',
      confirmText: 'ตกลง',
    );
    if (picked != null) {
      setState(() => _followUpDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // คำนวณ padding สำหรับ keyboard
    // ใช้ viewInsetsOf/sizeOf แทน .of() เพื่อ subscribe เฉพาะสิ่งที่ต้องการ
    // ลดการ rebuild ทุก MediaQuery change ตอน keyboard animation
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      // จำกัดความสูงไม่เกิน 85% ของหน้าจอ
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar (ขีดลากด้านบน)
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
          _buildHeader(),

          const Divider(height: 1, color: AppColors.alternate),

          // Form content (scrollable)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. หัวข้อตั๋ว
                  AppTextField(
                    label: 'หัวข้อ *',
                    controller: _titleController,
                    hintText: 'สรุปสั้นๆ เกี่ยวกับตั๋ว',
                    enabled: !_isSubmitting,
                    fillColor: AppColors.background,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. รายละเอียด
                  AppTextField(
                    label: 'รายละเอียด',
                    controller: _descriptionController,
                    hintText: 'อธิบายรายละเอียดของตั๋ว...',
                    maxLines: 4,
                    enabled: !_isSubmitting,
                    fillColor: AppColors.background,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. ข้อมูลผู้รับบริการ (read-only, แสดงถ้ามี)
                  if (widget.post.residentId != null &&
                      widget.post.residentId! > 0)
                    _buildResidentInfo(),

                  // 4. Priority toggle + วันติดตาม
                  Row(
                    children: [
                      // Priority
                      Expanded(child: _buildPriorityToggle()),
                      const SizedBox(width: AppSpacing.md),
                      // วันติดตาม
                      Expanded(child: _buildFollowUpDate()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 5. เข้าวาระประชุม
                  CheckboxTile(
                    value: _isMeetingAgenda,
                    onChanged: _isSubmitting
                        ? null
                        : (value) =>
                            setState(() => _isMeetingAgenda = value),
                    icon: HugeIcons.strokeRoundedCalendar03,
                    title: 'เข้าวาระประชุม',
                    subtitle: 'นำตั๋วนี้เข้าวาระประชุม',
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 6. ปุ่มสร้างตั๋ว
                  PrimaryButton(
                    text: _isSubmitting ? 'กำลังสร้าง...' : 'สร้างตั๋ว',
                    onPressed: _isSubmitting ? null : _submitTicket,
                    isLoading: _isSubmitting,
                    icon: HugeIcons.strokeRoundedTicket02,
                    width: double.infinity,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Header ของ bottom sheet
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent1,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedTicket02,
                size: 24,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('สร้างตั๋ว', style: AppTypography.heading3),
                Text(
                  'สร้างตั๋วติดตามงานจากโพสนี้',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          // ปุ่มปิด
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              size: 24,
              color: AppColors.secondaryText,
            ),
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// แสดงข้อมูลผู้รับบริการ (read-only chip)
  Widget _buildResidentInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ผู้รับบริการ',
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accent1,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedUser,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                widget.post.residentName ?? 'ผู้รับบริการ #${widget.post.residentId}',
                style: AppTypography.body.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  /// ปุ่ม toggle priority (ปกติ/สำคัญ)
  Widget _buildPriorityToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ความสำคัญ',
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 4),
        // ปุ่ม toggle เปลี่ยนสีเมื่อกด (ตาม pattern ของ admin)
        GestureDetector(
          onTap: _isSubmitting
              ? null
              : () => setState(() => _isPriority = !_isPriority),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _isPriority ? AppColors.tagFailedBg : AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isPriority ? AppColors.error : AppColors.alternate,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isPriority ? '🔴 สำคัญ' : 'ปกติ',
                  style: AppTypography.body.copyWith(
                    color: _isPriority ? AppColors.error : AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// วันติดตาม (กดเพื่อเปิด date picker)
  Widget _buildFollowUpDate() {
    // Format วันที่ แบบง่ายๆ (dd/MM/yyyy)
    String dateText = 'เลือกวัน';
    if (_followUpDate != null) {
      final d = _followUpDate!;
      dateText =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'วันติดตาม',
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _isSubmitting ? null : _pickFollowUpDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.alternate),
            ),
            child: Row(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  size: 16,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateText,
                    style: AppTypography.body.copyWith(
                      color: _followUpDate != null
                          ? AppColors.primaryText
                          : AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
