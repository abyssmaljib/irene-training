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
import '../providers/turn_on_medicine_provider.dart';
import '../screens/edit_medicine_db_screen.dart';
import 'medicine_info_card.dart';

/// Bottom Sheet สำหรับกลับมาใช้ยา (Off → On)
///
/// แสดง:
/// 1. ข้อมูลยาที่จะกลับมาใช้ (MedicineInfoCard)
/// 2. ช่องกรอกเหตุผล (บังคับ)
/// 3. จำนวนยาคงเหลือ (pre-fill จาก lastMedHistoryReconcile)
/// 4. Date picker สำหรับวันเริ่ม
/// 5. Checkbox ต่อเนื่อง
/// 6. จำนวนวัน (ถ้าไม่ต่อเนื่อง)
/// 7. ปุ่ม "เริ่มใช้ยาอีกครั้ง" (สีเขียว/primary)
class TurnOnMedicineSheet extends ConsumerStatefulWidget {
  final MedicineSummary medicine;

  const TurnOnMedicineSheet({super.key, required this.medicine});

  /// แสดง bottom sheet และ return true ถ้าเปิดใช้ยาสำเร็จ
  static Future<bool?> show(
    BuildContext context, {
    required MedicineSummary medicine,
  }) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TurnOnMedicineSheet(medicine: medicine),
    );
  }

  @override
  ConsumerState<TurnOnMedicineSheet> createState() =>
      _TurnOnMedicineSheetState();
}

class _TurnOnMedicineSheetState extends ConsumerState<TurnOnMedicineSheet> {
  final _noteController = TextEditingController();
  final _reconcileController = TextEditingController();
  final _daysController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize provider ด้วยข้อมูลยา
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(turnOnMedicineProvider(widget.medicine.medicineListId).notifier)
          .initFromMedicine(widget.medicine);

      // Pre-fill reconcile controller จาก lastMedHistoryReconcile
      if (widget.medicine.lastMedHistoryReconcile != null) {
        final reconcileVal = widget.medicine.lastMedHistoryReconcile!;
        // แสดงเป็นจำนวนเต็มถ้าเป็นจำนวนเต็ม
        _reconcileController.text = reconcileVal == reconcileVal.toInt()
            ? reconcileVal.toInt().toString()
            : reconcileVal.toString();
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _reconcileController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  /// เลือกวันเริ่มใช้ยา
  Future<void> _pickStartDate(DateTime currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      locale: const Locale('th'),
    );
    if (picked != null) {
      ref
          .read(
              turnOnMedicineProvider(widget.medicine.medicineListId).notifier)
          .setStartDate(picked);
    }
  }

  /// Submit กลับมาใช้ยา
  Future<void> _handleSubmit() async {
    final notifier = ref.read(
        turnOnMedicineProvider(widget.medicine.medicineListId).notifier);

    // Sync controllers กับ provider
    notifier.setNote(_noteController.text);
    notifier.setReconcile(_reconcileController.text);
    notifier.setDurationDays(_daysController.text);

    final success = await notifier.submit();

    if (success && mounted) {
      await SuccessPopup.show(
          context, emoji: '💊', message: 'เริ่มใช้ยาอีกครั้ง');
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(
        turnOnMedicineProvider(widget.medicine.medicineListId));

    // คำนวณ padding สำหรับ keyboard
    // ใช้ viewInsetsOf/sizeOf แทน .of() เพื่อลดการ rebuild ตอน keyboard animation
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
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
                      // Toggle on icon (สีเขียว)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedToggleOn,
                            color: AppColors.success,
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
                              'กลับมาใช้ยาตัวนี้?',
                              style: AppTypography.heading3
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'ระบบจะสร้างรายการยาใหม่ กรุณาระบุเหตุผล',
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

                  // เหตุผลที่กลับมาใช้ยา (บังคับ)
                  _buildLabel('เหตุผลที่กลับมาใช้ยา', isRequired: true),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _noteController,
                    maxLines: null,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      hintText: 'ระบุเหตุผลที่กลับมาใช้ยา...',
                    ),
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // จำนวนยาคงเหลือ (optional, pre-fill)
                  _buildLabel('จำนวนยาคงเหลือ'),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _reconcileController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration(
                      hintText: 'จำนวนยาที่ได้รับ',
                      suffixText: widget.medicine.unit ?? 'เม็ด',
                    ),
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Date picker: วันเริ่มใช้ยา
                  _buildStartDatePicker(state.startDate),
                  const SizedBox(height: AppSpacing.md),

                  // Checkbox: ต่อเนื่อง
                  _buildContinuousCheckbox(state.isContinuous),

                  // จำนวนวัน (ถ้าไม่ต่อเนื่อง)
                  if (!state.isContinuous) ...[
                    const SizedBox(height: AppSpacing.md),
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

                  // ปุ่มเริ่มใช้ยาอีกครั้ง (สี primary)
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: 'เริ่มใช้ยาอีกครั้ง',
                      onPressed: state.isLoading ? null : _handleSubmit,
                      isLoading: state.isLoading,
                      icon: HugeIcons.strokeRoundedToggleOn,
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

  /// Label สำหรับ field
  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.secondaryText),
        ),
        if (isRequired) ...[
          const SizedBox(width: 2),
          Text(
            '*',
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  /// Date picker สำหรับวันเริ่มใช้ยา
  Widget _buildStartDatePicker(DateTime startDate) {
    final dateFormat = DateFormat('d/M/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('เริ่มวันที่'),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: () => _pickStartDate(startDate),
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
                  dateFormat.format(startDate),
                  style: AppTypography.body,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Checkbox สำหรับเลือก "ต่อเนื่อง"
  Widget _buildContinuousCheckbox(bool isContinuous) {
    return InkWell(
      onTap: () {
        ref
            .read(turnOnMedicineProvider(widget.medicine.medicineListId)
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
              color:
                  isContinuous ? AppColors.primary : AppColors.secondaryText,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ต่อเนื่อง (continue)',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isContinuous
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'ใช้ยาต่อเนื่องไม่มีกำหนดหยุด',
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

  /// Field จำนวนวัน (ถ้าไม่ต่อเนื่อง)
  Widget _buildDurationDaysField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('ให้เป็นเวลา'),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _daysController,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration(
            hintText: 'จำนวนวัน',
            suffixText: 'วัน',
          ),
          style: AppTypography.body,
          onChanged: (value) {
            ref
                .read(turnOnMedicineProvider(widget.medicine.medicineListId)
                    .notifier)
                .setDurationDays(value);
          },
        ),
      ],
    );
  }

  /// InputDecoration ที่ใช้ร่วมกัน
  InputDecoration _inputDecoration({
    String? hintText,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      suffixText: suffixText,
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
    );
  }
}
