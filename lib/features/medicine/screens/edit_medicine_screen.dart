import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/success_popup.dart';
import '../models/medicine_summary.dart';
import '../providers/edit_medicine_form_provider.dart';
import '../widgets/time_slot_chips.dart';
import '../widgets/before_after_chips.dart';
import '../widgets/medicine_info_card.dart';
import '../widgets/turn_off_medicine_sheet.dart';
import '../widgets/turn_on_medicine_sheet.dart';
import 'edit_medicine_db_screen.dart';

/// หน้าแก้ไขยาของ Resident
///
/// ต่างจาก AddMedicineToResidentScreen ตรงที่:
/// - ไม่มีการค้นหา/เลือกยา (ยาถูกเลือกไว้แล้ว)
/// - Pre-populate ค่าจาก MedicineSummary
/// - บังคับใส่หมายเหตุการแก้ไข
/// - บันทึก history tracking ใน med_history
class EditMedicineScreen extends ConsumerStatefulWidget {
  const EditMedicineScreen({
    super.key,
    required this.medicine,
    this.residentName,
  });

  /// ข้อมูลยาที่ต้องการแก้ไข
  final MedicineSummary medicine;

  /// ชื่อ Resident (สำหรับแสดงใน title)
  final String? residentName;

  @override
  ConsumerState<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends ConsumerState<EditMedicineScreen> {
  // Controllers
  late final TextEditingController _takeTabController;
  late final TextEditingController _everyHrController;
  final _noteController = TextEditingController();

  // Form key
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    // Pre-populate controllers จาก medicine เดิม
    _takeTabController = TextEditingController(
      text: widget.medicine.takeTab?.toString() ?? '1',
    );
    _everyHrController = TextEditingController(
      text: widget.medicine.everyHr?.toString() ?? '1',
    );

    // Load medicine data เข้า provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(editMedicineFormProvider(widget.medicine.medicineListId).notifier)
          .loadFromMedicineSummary(widget.medicine);
    });

    // Sync controllers กับ provider
    _takeTabController.addListener(_onTakeTabChanged);
  }

  void _onTakeTabChanged() {
    ref
        .read(editMedicineFormProvider(widget.medicine.medicineListId).notifier)
        .setTakeTab(_takeTabController.text);
  }

  @override
  void dispose() {
    _takeTabController.removeListener(_onTakeTabChanged);
    _takeTabController.dispose();
    _everyHrController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// บันทึก
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(editMedicineFormProvider(widget.medicine.medicineListId).notifier);

    // Sync ค่าจาก controllers ทั้งหมดก่อน submit
    // ⚠️ ต้อง sync takeTab ด้วย เพราะ listener จะ fire เฉพาะเมื่อ user เปลี่ยนค่า
    // ถ้า user ไม่ได้แก้ dose → listener ไม่ fire → provider อาจมีค่าเก่าจาก session ก่อน
    notifier.setTakeTab(_takeTabController.text);
    notifier.setEveryHr(_everyHrController.text);
    notifier.setNote(_noteController.text);

    final success = await notifier.submit();

    if (success && mounted) {
      await SuccessPopup.show(context, emoji: '💊', message: 'แก้ไขยาสำเร็จ');
      if (mounted) Navigator.pop(context, true);
    }
  }

  /// เปิดหน้าแก้ไขยาในฐานข้อมูล (med_DB)
  Future<void> _openEditMedicineDB() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMedicineDBScreen(
          medDbId: widget.medicine.medDbId!,
        ),
      ),
    );

    // ถ้าแก้ไขสำเร็จ → pop กลับไปหน้า list พร้อม refresh
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  /// เปิด bottom sheet หยุดยา (On → Off)
  Future<void> _showTurnOffSheet() async {
    final result = await TurnOffMedicineSheet.show(
      context,
      medicine: widget.medicine,
    );
    // ถ้าหยุดยาสำเร็จ → กลับไปหน้า list พร้อม refresh
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  /// เปิด bottom sheet กลับมาใช้ยา (Off → On)
  Future<void> _showTurnOnSheet() async {
    final result = await TurnOnMedicineSheet.show(
      context,
      medicine: widget.medicine,
    );
    // ถ้าเปิดใช้ยาสำเร็จ → กลับไปหน้า list พร้อม refresh
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ฟัง form state
    final formState = ref.watch(editMedicineFormProvider(widget.medicine.medicineListId));

    return Scaffold(
      // ใช้ IreneSecondaryAppBar แทน AppBar เพื่อ consistency ทั้งแอป
      appBar: IreneSecondaryAppBar(
        title: 'แก้ไขยา ${widget.medicine.displayName}',
      ),
      body: formState.when(
        // กำลังโหลด
        loading: () => const Center(child: CircularProgressIndicator()),
        // Error
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('เกิดข้อผิดพลาด', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.xs),
              Text(
                error.toString(),
                style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // โหลดเสร็จ - แสดง form
        data: (state) => Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // Section 1: ข้อมูลยา (read-only)
                // ==========================================
                _SectionHeader(
                  icon: HugeIcons.strokeRoundedMedicine01,
                  title: 'ข้อมูลยา',
                ),
                const SizedBox(height: AppSpacing.md),

                // แสดงข้อมูลยาที่กำลังแก้ไข (กดเพื่อไปแก้ไขข้อมูลใน DB ได้)
                MedicineInfoCard(
                  medicine: widget.medicine,
                  onTapEdit: widget.medicine.medDbId != null
                      ? () => _openEditMedicineDB()
                      : null,
                ),

                const SizedBox(height: AppSpacing.lg),

                // ==========================================
                // Section 2: ปริมาณและเวลา
                // ==========================================
                _SectionHeader(
                  icon: HugeIcons.strokeRoundedTime01,
                  title: 'ปริมาณและเวลา',
                  isRequired: true,
                ),
                const SizedBox(height: AppSpacing.md),

                // ปริมาณยา
                _LabeledField(
                  label: 'ปริมาณที่ให้ (${widget.medicine.unit ?? 'เม็ด'})',
                  child: TextFormField(
                    controller: _takeTabController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration(hintText: 'เช่น 1, 0.5, 2'),
                    style: AppTypography.body,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'กรุณาระบุปริมาณ';
                      final num = double.tryParse(value);
                      if (num == null || num <= 0) return 'ปริมาณต้องเป็นตัวเลขที่มากกว่า 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ก่อน/หลังอาหาร
                _LabeledField(
                  label: 'ก่อน/หลังอาหาร',
                  child: BeforeAfterChips(
                    selectedValues: state.beforeAfter,
                    onToggle: (value) => ref
                        .read(editMedicineFormProvider(widget.medicine.medicineListId).notifier)
                        .toggleBeforeAfter(value),
                    onClear: () => ref
                        .read(editMedicineFormProvider(widget.medicine.medicineListId).notifier)
                        .clearBeforeAfter(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // เวลาที่ให้ยา (BLDB)
                _LabeledField(
                  label: 'เวลาที่ให้ยา',
                  child: TimeSlotChips(
                    selectedTimes: state.bldb,
                    onToggle: (time) => ref
                        .read(editMedicineFormProvider(widget.medicine.medicineListId).notifier)
                        .toggleBldb(time),
                    onClearAll: () => ref
                        .read(editMedicineFormProvider(widget.medicine.medicineListId).notifier)
                        .clearAllBldb(),
                    showSelectAll: false,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ==========================================
                // Section 3: PRN และความถี่
                // ==========================================
                _SectionHeader(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  title: 'ความถี่และ PRN',
                ),
                const SizedBox(height: AppSpacing.md),

                // PRN Switch
                SwitchListTile(
                  value: state.prn,
                  onChanged: (value) => ref
                      .read(editMedicineFormProvider(widget.medicine.medicineListId).notifier)
                      .setPrn(value),
                  title: Text(
                    'PRN (ให้เมื่อจำเป็น)',
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'ให้ยาเฉพาะเมื่อมีอาการ ไม่ใช่ยาประจำ',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
                  ),
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                  activeThumbColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: state.prn ? AppColors.primary : AppColors.alternate,
                      width: state.prn ? 2 : 1,
                    ),
                  ),
                  tileColor: state.prn ? AppColors.accent1 : AppColors.background,
                ),
                const SizedBox(height: AppSpacing.md),

                // ความถี่
                _LabeledField(
                  label: 'ความถี่ (ถ้าไม่ใช่ทุกวัน)',
                  child: Row(
                    children: [
                      Text('ทุก', style: AppTypography.body),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _everyHrController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: _inputDecoration(hintText: '-'),
                          style: AppTypography.body,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('typeOfTime_${state.typeOfTime}'),
                          initialValue: state.typeOfTime,
                          decoration: _inputDecoration(),
                          items: const [
                            DropdownMenuItem(value: 'วัน', child: Text('วัน')),
                            DropdownMenuItem(value: 'สัปดาห์', child: Text('สัปดาห์')),
                            DropdownMenuItem(value: 'เดือน', child: Text('เดือน')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              ref
                                  .read(editMedicineFormProvider(widget.medicine.medicineListId).notifier)
                                  .setTypeOfTime(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ตัวเลือกวัน (แสดงเมื่อเลือก "สัปดาห์")
                if (state.typeOfTime == 'สัปดาห์') ...[
                  const SizedBox(height: AppSpacing.md),
                  _LabeledField(
                    label: 'เลือกวัน',
                    child: _DayOfWeekSelector(
                      selectedDays: state.selectedDays,
                      onToggle: (day) => ref
                          .read(editMedicineFormProvider(widget.medicine.medicineListId).notifier)
                          .toggleDay(day),
                      onClear: state.selectedDays.isNotEmpty
                          ? () => ref
                              .read(editMedicineFormProvider(widget.medicine.medicineListId).notifier)
                              .clearDays()
                          : null,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                // ==========================================
                // Section 4: หมายเหตุการแก้ไข (required)
                // ==========================================
                _SectionHeader(
                  icon: HugeIcons.strokeRoundedNote01,
                  title: 'หมายเหตุการแก้ไข',
                  isRequired: true,
                ),
                const SizedBox(height: AppSpacing.md),

                _LabeledField(
                  label: 'เหตุผลในการแก้ไข (บังคับ)',
                  child: TextFormField(
                    controller: _noteController,
                    maxLines: null,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(hintText: 'ระบุเหตุผลในการแก้ไข...'),
                    style: AppTypography.body,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณาระบุเหตุผลในการแก้ไข';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ==========================================
                // Section 5: เปลี่ยนสถานะยา (On/Off)
                // ==========================================
                _SectionHeader(
                  icon: widget.medicine.isActive
                      ? HugeIcons.strokeRoundedToggleOff
                      : HugeIcons.strokeRoundedToggleOn,
                  title: 'เปลี่ยนสถานะยา',
                ),
                const SizedBox(height: AppSpacing.md),

                // Container แยกชัดเจน ป้องกันกดผิด
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: widget.medicine.isActive
                        ? AppColors.error.withValues(alpha: 0.05)
                        : AppColors.success.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.medicine.isActive
                          ? AppColors.error.withValues(alpha: 0.2)
                          : AppColors.success.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // คำอธิบาย
                      Text(
                        widget.medicine.isActive
                            ? 'หยุดใช้ยาตัวนี้ ระบบจะบันทึกเหตุผลและวันที่หยุด'
                            : 'กลับมาใช้ยาตัวนี้อีกครั้ง ระบบจะสร้างรายการยาใหม่',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ปุ่ม On/Off
                      if (widget.medicine.isActive)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: state.isLoading ? null : _showTurnOffSheet,
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedToggleOff,
                              color: AppColors.error,
                              size: 20,
                            ),
                            label: Text('หยุดยาตัวนี้'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: state.isLoading ? null : _showTurnOnSheet,
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedToggleOn,
                              color: AppColors.success,
                              size: 20,
                            ),
                            label: Text('เริ่มใช้ยาอีกครั้ง'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.success,
                              side: BorderSide(color: AppColors.success),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ==========================================
                // Error message & Submit button (ล่างสุด)
                // ==========================================
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
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.tagFailedText,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            color: AppColors.tagFailedText,
                            size: 16,
                          ),
                          onPressed: () => ref
                              .read(editMedicineFormProvider(widget.medicine.medicineListId).notifier)
                              .clearError(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'บันทึกการแก้ไข',
                    onPressed: state.isLoading ? null : _submit,
                    isLoading: state.isLoading,
                    icon: HugeIcons.strokeRoundedFloppyDisk,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// สร้าง InputDecoration ที่ใช้ร่วมกัน
  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
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

// ==========================================
// Helper Widgets
// ==========================================

/// Section Header with icon
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.isRequired = false,
  });

  final dynamic icon;
  final String title;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Center(
          child: HugeIcon(
            icon: icon,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: AppTypography.heading3.copyWith(fontWeight: FontWeight.w600),
        ),
        if (isRequired) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            '*',
            style: AppTypography.heading3.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

/// Labeled Field wrapper
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

/// Widget สำหรับเลือกวันในสัปดาห์
class _DayOfWeekSelector extends StatelessWidget {
  const _DayOfWeekSelector({
    required this.selectedDays,
    required this.onToggle,
    this.onClear,
  });

  final List<String> selectedDays;
  final void Function(String day) onToggle;
  final VoidCallback? onClear;

  /// value = ชื่อเต็มที่เก็บลง DB (ตรงกับ admin app DAYS_OF_WEEK_OPTIONS)
  /// label = ชื่อย่อสำหรับแสดงบนปุ่มกลม
  static const List<_DayInfo> _days = [
    _DayInfo('จ', 'จันทร์', Color(0xFFE1BC29)),
    _DayInfo('อ', 'อังคาร', Color(0xFFF991CC)),
    _DayInfo('พ', 'พุธ', Color(0xFF1B998B)),
    _DayInfo('พฤ', 'พฤหัสบดี', Color(0xFFEB8258)),
    _DayInfo('ศ', 'ศุกร์', Color(0xFF648DE5)),
    _DayInfo('ส', 'เสาร์', Color(0xFF8A4F7D)),
    _DayInfo('อา', 'อาทิตย์', Color(0xFFC92828)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: _days.map((dayInfo) {
              final isSelected = selectedDays.contains(dayInfo.value);
              return _DayCircleButton(
                label: dayInfo.label,
                color: dayInfo.color,
                isSelected: isSelected,
                onTap: () => onToggle(dayInfo.value),
              );
            }).toList(),
          ),
        ),
        if (selectedDays.isNotEmpty && onClear != null)
          GestureDetector(
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Text(
                'ล้าง',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayInfo {
  const _DayInfo(this.label, this.value, this.color);
  final String label; // ชื่อย่อแสดงบนปุ่ม: 'พฤ'
  final String value; // ชื่อเต็มเก็บ DB: 'พฤหัสบดี'
  final Color color;
}

class _DayCircleButton extends StatelessWidget {
  const _DayCircleButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const double size = 40;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: isSelected ? null : Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
