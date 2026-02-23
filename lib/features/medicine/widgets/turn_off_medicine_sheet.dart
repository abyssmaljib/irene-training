import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/success_popup.dart';
import '../models/medicine_summary.dart';
import '../providers/turn_off_medicine_provider.dart';
import '../screens/edit_medicine_db_screen.dart';
import 'medicine_info_card.dart';

/// Bottom Sheet สำหรับหยุดยา (On → Off)
///
/// แสดง:
/// 1. ข้อมูลยาที่จะหยุด (MedicineInfoCard)
/// 2. ช่องกรอกเหตุผล
/// 3. Checkbox ต่อเนื่อง (off ทันที vs กำหนดวัน)
/// 4. Date picker + จำนวนวัน (ถ้าไม่ต่อเนื่อง)
/// 5. ปุ่ม "หยุดยา" (สีแดง)
class TurnOffMedicineSheet extends ConsumerStatefulWidget {
  final MedicineSummary medicine;

  const TurnOffMedicineSheet({super.key, required this.medicine});

  /// แสดง bottom sheet และ return true ถ้าหยุดยาสำเร็จ
  static Future<bool?> show(
    BuildContext context, {
    required MedicineSummary medicine,
  }) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TurnOffMedicineSheet(medicine: medicine),
    );
  }

  @override
  ConsumerState<TurnOffMedicineSheet> createState() =>
      _TurnOffMedicineSheetState();
}

class _TurnOffMedicineSheetState extends ConsumerState<TurnOffMedicineSheet> {
  final _noteController = TextEditingController();
  final _daysController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize provider ด้วยข้อมูลยา
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(turnOffMedicineProvider(widget.medicine.medicineListId).notifier)
          .initFromMedicine(widget.medicine);
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  /// เลือกวันสุดท้ายที่ให้ยา
  Future<void> _pickLastDay(DateTime? currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2050),
      locale: const Locale('th'),
    );
    if (picked != null) {
      ref
          .read(
              turnOffMedicineProvider(widget.medicine.medicineListId).notifier)
          .setLastDay(picked);
    }
  }

  /// Submit หยุดยา
  Future<void> _handleSubmit() async {
    final notifier = ref.read(
        turnOffMedicineProvider(widget.medicine.medicineListId).notifier);

    // Sync note จาก controller
    notifier.setNote(_noteController.text);

    // Sync durationDays จาก controller
    notifier.setDurationDays(_daysController.text);

    final success = await notifier.submit();

    if (success && mounted) {
      await SuccessPopup.show(context, emoji: '💊', message: 'หยุดยาเรียบร้อย');
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(
        turnOffMedicineProvider(widget.medicine.medicineListId));

    // คำนวณ padding สำหรับ keyboard
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      // จำกัดความสูงไม่ให้เกิน 85% ของหน้าจอ
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: formState.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 200,
            child: Center(child: Text('เกิดข้อผิดพลาด: $e')),
          ),
          data: (state) => SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.alternate,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Header: icon + title
                  Row(
                    children: [
                      // Toggle off icon (สีแดง)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedToggleOff,
                            color: AppColors.error,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'หยุดยาตัวนี้?',
                              style: AppTypography.heading3
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'กรุณาระบุเหตุผลหรือคำสั่งจากแพทย์',
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Medicine info card (กดเพื่อไปแก้ไขยาใน DB ได้)
                  MedicineInfoCard(
                    medicine: widget.medicine,
                    onTapEdit: widget.medicine.medDbId != null
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditMedicineDBScreen(
                                  medDbId: widget.medicine.medDbId!,
                                ),
                              ),
                            )
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // เหตุผล/คำสั่งแพทย์ (บังคับกรอก)
                  Row(
                    children: [
                      Text(
                        'เหตุผล/คำสั่งแพทย์',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.secondaryText),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '*',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.error),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _noteController,
                    maxLines: null,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'ระบุเหตุผลที่หยุดยา...',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.alternate, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Checkbox: ต่อเนื่อง (off ทันที)
                  _buildContinuousCheckbox(state.isContinuous),

                  // แสดง date picker + days field ถ้าไม่ต่อเนื่อง
                  if (!state.isContinuous) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildLastDayPicker(state.lastDay),
                    const SizedBox(height: AppSpacing.sm),
                    _buildDurationDaysField(),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Error message
                  if (state.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.tagFailedBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedAlert02,
                            color: AppColors.tagFailedText,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.tagFailedText),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // ปุ่มหยุดยา (สีแดง)
                  SizedBox(
                    width: double.infinity,
                    child: DangerButton(
                      text: state.isContinuous
                          ? 'หยุดยาทันที'
                          : 'กำหนดวันหยุดยา',
                      onPressed: state.isLoading ? null : _handleSubmit,
                      isLoading: state.isLoading,
                      icon: HugeIcons.strokeRoundedToggleOff,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Checkbox สำหรับเลือก "ต่อเนื่อง" (off ทันที)
  Widget _buildContinuousCheckbox(bool isContinuous) {
    return InkWell(
      onTap: () {
        ref
            .read(turnOffMedicineProvider(widget.medicine.medicineListId)
                .notifier)
            .setIsContinuous(!isContinuous);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isContinuous ? AppColors.accent1 : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isContinuous ? AppColors.primary : AppColors.alternate,
            width: isContinuous ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: isContinuous
                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                  : HugeIcons.strokeRoundedCircle,
              color: isContinuous ? AppColors.primary : AppColors.secondaryText,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'หยุดยาทันที',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isContinuous
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Off ยาตัวนี้ตั้งแต่วันนี้',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Date picker สำหรับเลือกวันสุดท้ายที่ให้ยา
  Widget _buildLastDayPicker(DateTime? lastDay) {
    final dateFormat = DateFormat('d/M/yyyy');
    final displayDate =
        lastDay != null ? dateFormat.format(lastDay) : 'เลือกวันที่';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'วันสุดท้ายที่ให้ยา',
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.secondaryText),
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: () => _pickLastDay(lastDay),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.alternate, width: 1),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  displayDate,
                  style: AppTypography.body.copyWith(
                    color: lastDay != null
                        ? AppColors.textPrimary
                        : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Field สำหรับกรอกจำนวนวัน
  Widget _buildDurationDaysField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'หรือระบุจำนวนวัน',
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.secondaryText),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _daysController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'จำนวนวัน',
            suffixText: 'วัน',
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.alternate, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          style: AppTypography.body,
          onChanged: (value) {
            ref
                .read(turnOffMedicineProvider(widget.medicine.medicineListId)
                    .notifier)
                .setDurationDays(value);
          },
        ),
      ],
    );
  }
}
