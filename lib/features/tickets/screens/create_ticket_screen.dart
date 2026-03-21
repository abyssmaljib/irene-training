// หน้าสร้างตั๋วใหม่ (Create Ticket Screen)
//
// Full-page form สำหรับสร้าง ticket ใหม่ในระบบ
// ประกอบด้วย:
// 1. เลือกหมวดหมู่ (ChoiceChip)
// 2. กรอกหัวข้อ (TextField - required)
// 3. กรอกรายละเอียด (MentionTextField - รองรับ @mention)
// 4. Toggle สำคัญ/ไม่สำคัญ (SwitchListTile)
// 5. เลือกวันติดตาม (DatePicker)
// 6. Toggle วาระประชุม (SwitchListTile)
// 7. ปุ่มสร้างตั๋ว (ElevatedButton)
//
// Pattern:
// - ConsumerStatefulWidget + Riverpod สำหรับดึง staff list
// - ValueListenableBuilder สำหรับ enable/disable ปุ่มสร้าง (performance)
// - Navigator.pop(context, true) เพื่อ trigger refresh ในหน้า list

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/user_service.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';
import '../services/ticket_feature_service.dart';
import '../widgets/mention_text_field.dart';

/// หน้าสร้างตั๋วใหม่ — ใช้ ConsumerStatefulWidget เพราะต้องอ่าน staff list จาก provider
class CreateTicketScreen extends ConsumerStatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  // ── Controllers ──────────────────────────────────────────────
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // ── Form state ──────────────────────────────────────────────
  /// หมวดหมู่ที่เลือก — default เป็น general
  TicketCategory _selectedCategory = TicketCategory.general;

  /// ตั๋วสำคัญหรือไม่ (แสดง priority badge)
  bool _priority = false;

  /// เข้าวาระประชุมหรือไม่
  bool _meetingAgenda = false;

  /// วันที่ต้องติดตาม (nullable — ไม่บังคับกรอก)
  DateTime? _followUpDate;

  /// flag บอกว่ากำลังส่งข้อมูลอยู่ — ใช้ disable ปุ่มและแสดง loading
  bool _isSubmitting = false;

  /// รายการ UUID ของคนที่ถูก @mention ใน description
  /// อัพเดตผ่าน onMentionsChange callback จาก MentionTextField
  List<String> _mentionedUserIds = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  // Action Methods
  // ════════════════════════════════════════════════════════════

  /// เปิด DatePicker สำหรับเลือกวันติดตาม
  /// เริ่มจากวันนี้ ไม่ให้เลือกวันในอดีต (firstDate = today)
  Future<void> _pickFollowUpDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? now,
      firstDate: now, // ไม่ให้เลือกวันก่อนวันนี้
      lastDate: now.add(const Duration(days: 365)), // สูงสุด 1 ปีข้างหน้า
      locale: const Locale('th', 'TH'),
      builder: (context, child) {
        // Theme DatePicker ให้เข้ากับ design system ของ app
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _followUpDate = picked);
    }
  }

  /// Submit form — สร้างตั๋วใหม่และส่ง mention notification
  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    // Validate: หัวข้อห้ามว่าง
    if (title.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      // 1. ดึง nursinghome_id ของ user ปัจจุบัน
      final nursinghomeId = await UserService().getNursinghomeId();
      if (nursinghomeId == null) throw Exception('ไม่พบข้อมูลบ้าน');

      // 2. สร้างตั๋วใหม่ผ่าน service
      final description = _descriptionController.text.trim();
      final ticketId = await TicketFeatureService.instance.createTicket(
        title: title,
        description: description.isEmpty ? null : description,
        category: _selectedCategory.value,
        nursinghomeId: nursinghomeId,
        priority: _priority,
        followUpDate: _followUpDate,
        meetingAgenda: _meetingAgenda,
        mentionedUsers: _mentionedUserIds,
      );

      // 3. ส่ง notification ให้คนที่ถูก @mention (ถ้ามี)
      if (_mentionedUserIds.isNotEmpty) {
        final senderName = await UserService().getUserName() ?? 'ไม่ทราบชื่อ';
        // ไม่ await เพราะไม่อยาก block UI — noti ส่งเบื้องหลังได้
        TicketFeatureService.instance.sendMentionNotifications(
          userIds: _mentionedUserIds,
          ticketId: ticketId,
          content: description,
          senderNickname: senderName,
        );
      }

      // 4. แสดง toast สำเร็จ แล้วกลับหน้า list
      if (mounted) {
        AppToast.success(context, 'สร้างตั๋วแล้ว');
        Navigator.pop(context, true); // return true เพื่อ trigger refresh ในหน้า list
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'สร้างตั๋วไม่สำเร็จ: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // Build
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'สร้างตั๋วใหม่',
          style: AppTypography.heading3.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. Category Selection (ChoiceChips) ───────────
            _buildSectionLabel('ประเภท'),
            AppSpacing.verticalGapSm,
            _buildCategoryChips(),
            AppSpacing.verticalGapLg,

            // ─── 2. Title (required) ───────────────────────────
            _buildSectionLabel('หัวข้อ *'),
            AppSpacing.verticalGapSm,
            _buildTitleField(),
            AppSpacing.verticalGapLg,

            // ─── 3. Description (MentionTextField) ─────────────
            _buildSectionLabel('รายละเอียด'),
            AppSpacing.verticalGapSm,
            _buildDescriptionField(),
            AppSpacing.verticalGapLg,

            // ─── 4. Priority Toggle ────────────────────────────
            _buildPriorityToggle(),
            const Divider(height: 1),

            // ─── 5. Follow-up Date ─────────────────────────────
            _buildFollowUpDateTile(),
            const Divider(height: 1),

            // ─── 6. Meeting Agenda Toggle ──────────────────────
            _buildMeetingAgendaToggle(),

            AppSpacing.verticalGapXl,

            // ─── 7. Submit Button ──────────────────────────────
            _buildSubmitButton(),

            // เว้นที่ด้านล่างสำหรับ safe area
            AppSpacing.verticalGapLg,
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Widget Builders — แยกออกมาเพื่อให้ build method อ่านง่าย
  // ════════════════════════════════════════════════════════════

  /// Label หัวข้อของแต่ละ section — bold, สี primary text
  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: AppTypography.title.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// ChoiceChips สำหรับเลือกหมวดหมู่ ticket
  /// แสดง emoji + ข้อความ สำหรับแต่ละหมวด
  Widget _buildCategoryChips() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: TicketCategory.values.map((category) {
        final isSelected = _selectedCategory == category;
        return ChoiceChip(
          label: Text(
            '${category.emoji} ${category.displayText}',
            style: AppTypography.body.copyWith(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedCategory = category),
          // สีเมื่อเลือก — ใช้ primary color ให้เข้ากับ theme
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.inputBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
        );
      }).toList(),
    );
  }

  /// TextField สำหรับกรอกหัวข้อตั๋ว (required field)
  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      style: AppTypography.body,
      maxLength: 200, // จำกัดความยาวหัวข้อ
      decoration: InputDecoration(
        hintText: 'กรอกหัวข้อตั๋ว',
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
        contentPadding: AppSpacing.inputPadding,
        counterText: '', // ซ่อน counter (ไม่ต้องแสดง 0/200)
      ),
    );
  }

  /// MentionTextField สำหรับกรอกรายละเอียด — รองรับ @mention staff
  /// ใช้ Consumer เพื่อดึง staff list จาก ticketStaffListProvider
  Widget _buildDescriptionField() {
    return Consumer(
      builder: (context, ref, _) {
        final staffAsync = ref.watch(ticketStaffListProvider);
        // ดึง staff list จาก AsyncValue — ถ้ายังโหลดไม่เสร็จใช้ list ว่าง
        final staffList = staffAsync.value ?? [];

        return MentionTextField(
          controller: _descriptionController,
          staffList: staffList,
          hintText: 'อธิบายรายละเอียด (พิมพ์ @ เพื่อแท็กเพื่อนร่วมงาน)',
          maxLines: 5,
          // Callback เมื่อ mention list เปลี่ยน — เก็บไว้ส่ง notification ตอน submit
          onMentionsChange: (ids) {
            _mentionedUserIds = ids;
          },
        );
      },
    );
  }

  /// SwitchListTile สำหรับ toggle priority (สำคัญ/ไม่สำคัญ)
  Widget _buildPriorityToggle() {
    return SwitchListTile(
      title: Row(
        children: [
          // ใช้ HugeIcons สำหรับ icon สำคัญ (ดาวสีส้ม)
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: AppIconSize.lg,
            color: _priority ? AppColors.warning : AppColors.textSecondary,
          ),
          AppSpacing.horizontalGapSm,
          Text(
            'สำคัญ',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      subtitle: Text(
        'ตั๋วจะถูกแสดงด้วยป้ายสีแดง',
        style: AppTypography.caption,
      ),
      value: _priority,
      onChanged: (value) => setState(() => _priority = value),
      activeThumbColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    );
  }

  /// ListTile สำหรับเลือกวันติดตาม — กดแล้วเปิด DatePicker
  Widget _buildFollowUpDateTile() {
    // Format วันที่เป็นภาษาไทย (เช่น "17 มี.ค. 2569")
    final dateText = _followUpDate != null
        ? DateFormat('d MMM yyyy', 'th').format(_followUpDate!)
        : 'ไม่ได้กำหนด';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      leading: HugeIcon(
        icon: HugeIcons.strokeRoundedCalendar03,
        size: AppIconSize.lg,
        color: _followUpDate != null
            ? AppColors.primary
            : AppColors.textSecondary,
      ),
      title: Text(
        'วันติดตาม',
        style: AppTypography.body.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        dateText,
        style: AppTypography.caption.copyWith(
          color: _followUpDate != null
              ? AppColors.primary
              : AppColors.textSecondary,
        ),
      ),
      trailing: _followUpDate != null
          // ถ้ามีวันที่แล้ว แสดงปุ่ม X สำหรับลบ
          ? IconButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                size: AppIconSize.md,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _followUpDate = null),
            )
          : const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: AppIconSize.md,
              color: AppColors.textSecondary,
            ),
      onTap: _pickFollowUpDate,
    );
  }

  /// SwitchListTile สำหรับ toggle meeting agenda (วาระประชุม)
  Widget _buildMeetingAgendaToggle() {
    return SwitchListTile(
      title: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedMeetingRoom,
            size: AppIconSize.lg,
            color:
                _meetingAgenda ? AppColors.primary : AppColors.textSecondary,
          ),
          AppSpacing.horizontalGapSm,
          Text(
            'วาระประชุม',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      subtitle: Text(
        'เพิ่มเข้าวาระประชุมครั้งถัดไป',
        style: AppTypography.caption,
      ),
      value: _meetingAgenda,
      onChanged: (value) => setState(() => _meetingAgenda = value),
      activeThumbColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    );
  }

  /// ปุ่มสร้างตั๋ว — ใช้ ValueListenableBuilder เพื่อ enable/disable
  /// ตาม state ของ title controller (ว่างหรือไม่) + isSubmitting
  /// ไม่ใช้ setState ทั้งหน้าเพื่อ performance ที่ดีกว่า
  Widget _buildSubmitButton() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _titleController,
      builder: (context, value, _) {
        // ปุ่มใช้ได้เมื่อ: หัวข้อไม่ว่าง + ไม่ได้กำลัง submit
        final canSubmit = value.text.trim().isNotEmpty && !_isSubmitting;

        return SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: ElevatedButton(
            onPressed: canSubmit ? _handleSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primaryDisabled,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                // แสดง loading spinner เมื่อกำลังสร้างตั๋ว
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    'สร้างตั๋ว',
                    style: AppTypography.button.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
