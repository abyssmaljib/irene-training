import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/widgets/success_popup.dart';
import '../../../core/services/user_service.dart';
import '../../checklist/models/system_role.dart';
import '../models/med_db.dart';
import '../providers/add_medicine_form_provider.dart';
import '../widgets/medicine_search_dropdown.dart';
import '../widgets/time_slot_chips.dart';
import '../widgets/before_after_chips.dart';
import 'create_medicine_db_screen.dart';
import 'edit_medicine_db_screen.dart';
import '../../../core/widgets/shimmer_loading.dart';

/// หน้าเพิ่มยาให้ Resident
///
/// ประกอบด้วย:
/// - ค้นหาและเลือกยาจากฐานข้อมูล (med_DB)
/// - กำหนดปริมาณยา (take_tab)
/// - เลือกเวลาที่ให้ยา (BLDB chips)
/// - เลือกก่อน/หลังอาหาร
/// - กำหนด PRN (ให้เมื่อจำเป็น)
/// - กำหนดความถี่ (ทุก N วัน/สัปดาห์/เดือน)
/// - วันที่เริ่ม/หยุดให้ยา
/// - จำนวนยาคงเหลือ (reconcile)
/// - หมายเหตุ
class AddMedicineToResidentScreen extends ConsumerStatefulWidget {
  const AddMedicineToResidentScreen({
    super.key,
    required this.residentId,
    this.residentName,
  });

  /// ID ของ Resident ที่ต้องการเพิ่มยา
  final int residentId;

  /// ชื่อ Resident (สำหรับแสดงใน title)
  final String? residentName;

  @override
  ConsumerState<AddMedicineToResidentScreen> createState() =>
      _AddMedicineToResidentScreenState();
}

class _AddMedicineToResidentScreenState
    extends ConsumerState<AddMedicineToResidentScreen> {
  // Controllers
  final _takeTabController = TextEditingController(text: '1');
  final _everyHrController = TextEditingController(text: '1');
  final _reconcileController = TextEditingController();
  final _daysController = TextEditingController();  // จำนวนวันที่ให้ยา (เมื่อไม่ต่อเนื่อง)
  final _noteController = TextEditingController();

  // Form key
  final _formKey = GlobalKey<FormState>();

  // System role ของ user ปัจจุบัน (สำหรับตรวจสิทธิ์เพิ่มยาใหม่ลงฐานข้อมูล)
  // ต้องเป็นหัวหน้าเวรขึ้นไป (canQC) ถึงจะเห็นปุ่มเพิ่มยาใหม่
  SystemRole? _systemRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    // Sync controller กับ provider (ให้ UI update real-time)
    _takeTabController.addListener(() {
      ref
          .read(addMedicineFormProvider(widget.residentId).notifier)
          .setTakeTab(_takeTabController.text);
    });
    // Sync reconcile เพื่อให้ _MedicineSummaryRow คำนวณได้ real-time
    _reconcileController.addListener(() {
      ref
          .read(addMedicineFormProvider(widget.residentId).notifier)
          .setReconcile(_reconcileController.text);
    });
  }

  @override
  void dispose() {
    _takeTabController.dispose();
    _everyHrController.dispose();
    _reconcileController.dispose();
    _daysController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// โหลด system role ของ user ปัจจุบัน (สำหรับตรวจสิทธิ์เพิ่มยาใหม่)
  Future<void> _loadUserRole() async {
    final systemRole = await UserService().getSystemRole();
    if (mounted) {
      setState(() => _systemRole = systemRole);
    }
  }

  /// เปิดหน้าสร้างยาใหม่
  Future<void> _openCreateMedicineScreen(String prefillName) async {
    final result = await Navigator.push<MedDB>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMedicineDBScreen(
          prefillBrandName: prefillName,
        ),
      ),
    );

    // ถ้าสร้างยาใหม่สำเร็จ ให้เลือกยานั้นเลย
    if (result != null && mounted) {
      ref
          .read(addMedicineFormProvider(widget.residentId).notifier)
          .selectMedicine(result);
    }
  }

  /// เปิดหน้าแก้ไขยาในฐานข้อมูล
  /// ใช้สำหรับปุ่ม edit ใน MedicineSearchDropdown
  Future<void> _openEditMedicineDBScreen(MedDB medicine) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMedicineDBScreen(
          medDbId: medicine.id,
        ),
      ),
    );

    // ถ้าแก้ไขสำเร็จ (result = true) หรือสร้างซ้ำสำเร็จ (result = MedDB)
    // ให้ reload ข้อมูลยาที่เลือกอยู่ หรือเลือกยาใหม่
    if (result != null && mounted) {
      if (result is MedDB) {
        // ถ้าเป็น MedDB ใหม่ (จาก duplicate) ให้เลือกยาใหม่
        ref
            .read(addMedicineFormProvider(widget.residentId).notifier)
            .selectMedicine(result);
      } else if (result == true) {
        // ถ้าแก้ไขสำเร็จ ให้ refresh ข้อมูลยาเดิม
        // (reload จาก database โดยการค้นหาใหม่)
        ref
            .read(addMedicineFormProvider(widget.residentId).notifier)
            .refreshSelectedMedicine();
      }
    }
  }

  /// เลือกวันที่
  Future<void> _selectDate(bool isOnDate) async {
    final formState = ref.read(addMedicineFormProvider(widget.residentId)).value;
    if (formState == null) return;

    final initialDate = isOnDate ? formState.onDate : (formState.offDate ?? DateTime.now());

    // ไม่ใส่ locale เพราะต้อง setup MaterialLocalizations delegate ก่อน
    // แต่แสดงผลเป็นปี พ.ศ. ใน UI ของเราเองแทน
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (selectedDate != null) {
      final notifier = ref.read(addMedicineFormProvider(widget.residentId).notifier);
      if (isOnDate) {
        notifier.setOnDate(selectedDate);
      } else {
        notifier.setOffDate(selectedDate);
      }
    }
  }

  /// บันทึก
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(addMedicineFormProvider(widget.residentId).notifier);

    // Sync values ก่อน submit
    notifier.setEveryHr(_everyHrController.text);
    notifier.setReconcile(_reconcileController.text);
    notifier.setNote(_noteController.text);

    final success = await notifier.submit();

    if (success && mounted) {
      await SuccessPopup.show(context, emoji: '💊', message: 'เพิ่มยาให้คนไข้สำเร็จ');
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ฟัง form state
    final formState = ref.watch(addMedicineFormProvider(widget.residentId));

    return Scaffold(
      // ใช้ IreneSecondaryAppBar แทน AppBar เพื่อ consistency ทั้งแอป
      appBar: IreneSecondaryAppBar(
        title: widget.residentName != null
            ? 'เพิ่มยาให้คุณ${widget.residentName}'
            : 'เพิ่มยาให้คนไข้',
      ),
      body: formState.when(
        // กำลังโหลด
        loading: () => ShimmerWrapper(
          isLoading: true,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: List.generate(3, (_) => const SkeletonListItem()),
            ),
          ),
        ),
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
              Text(
                'เกิดข้อผิดพลาด',
                style: AppTypography.heading3,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                error.toString(),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.secondaryText,
                ),
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
                // Section 1: เลือกยา
                // ==========================================
                _SectionHeader(
                  icon: HugeIcons.strokeRoundedMedicine01,
                  title: 'เลือกยา',
                  isRequired: true,
                ),
                const SizedBox(height: AppSpacing.md),

                // Medicine Search Dropdown
                // ปุ่ม "เพิ่มยาใหม่ลงฐานข้อมูล" แสดงเฉพาะหัวหน้าเวรขึ้นไป
                MedicineSearchDropdown(
                  onSearch: (query) => ref
                      .read(addMedicineFormProvider(widget.residentId).notifier)
                      .searchMedicines(query),
                  onSelect: (medicine) => ref
                      .read(addMedicineFormProvider(widget.residentId).notifier)
                      .selectMedicine(medicine),
                  onAddNew: _openCreateMedicineScreen,
                  searchResults: state.searchResults,
                  isSearching: state.isSearching,
                  selectedMedicine: state.selectedMedicine,
                  onClear: () => ref
                      .read(addMedicineFormProvider(widget.residentId).notifier)
                      .clearSelectedMedicine(),
                  // ปุ่ม edit ยาที่เลือก - เปิดหน้าแก้ไขยาในฐานข้อมูล
                  // แสดงเฉพาะหัวหน้าเวรขึ้นไป (canQC = level >= 30)
                  onEditMedicine: (_systemRole?.canQC ?? false)
                      ? _openEditMedicineDBScreen
                      : null,
                  // แสดงปุ่มเพิ่มยาใหม่เฉพาะหัวหน้าเวรขึ้นไป (canQC = level >= 30)
                  showAddNewButton: _systemRole?.canQC ?? false,
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
                  label: 'ปริมาณที่ให้ (${state.selectedMedicine?.unit ?? 'เม็ด'})',
                  child: TextFormField(
                    controller: _takeTabController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'เช่น 1, 0.5, 2',
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
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'กรุณาระบุปริมาณ';
                      final num = double.tryParse(value);
                      if (num == null || num <= 0) return 'ปริมาณต้องเป็นตัวเลขที่มากกว่า 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ก่อน/หลังอาหาร (อยู่ด้านบน)
                _LabeledField(
                  label: 'ก่อน/หลังอาหาร',
                  child: BeforeAfterChips(
                    selectedValues: state.beforeAfter,
                    onToggle: (value) => ref
                        .read(addMedicineFormProvider(widget.residentId).notifier)
                        .toggleBeforeAfter(value),
                    onClear: () => ref
                        .read(addMedicineFormProvider(widget.residentId).notifier)
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
                        .read(addMedicineFormProvider(widget.residentId).notifier)
                        .toggleBldb(time),
                    // ปุ่มล้างจะแสดงเมื่อมีการเลือก
                    onClearAll: () => ref
                        .read(addMedicineFormProvider(widget.residentId).notifier)
                        .clearAllBldb(),
                    // ไม่แสดงปุ่ม "เลือกทั้งหมด"
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

                // PRN Switch (ใช้ SwitchListTile)
                SwitchListTile(
                  value: state.prn,
                  onChanged: (value) => ref
                      .read(addMedicineFormProvider(widget.residentId).notifier)
                      .setPrn(value),
                  title: Text(
                    'PRN (ให้เมื่อจำเป็น)',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'ให้ยาเฉพาะเมื่อมีอาการ ไม่ใช่ยาประจำ',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.secondaryText,
                    ),
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

                // ความถี่ (ถ้าไม่ใช่ทุกวัน)
                // Layout: "ทุก" [input จำนวน] [dropdown หน่วย]
                // ใช้ Expanded พร้อม flex เพื่อให้สมดุลกัน
                _LabeledField(
                  label: 'ความถี่ (ถ้าไม่ใช่ทุกวัน)',
                  child: Row(
                    children: [
                      // คำว่า "ทุก"
                      Text(
                        'ทุก',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // จำนวน (flex: 1 = 1 ส่วน)
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _everyHrController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: '-',
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                          style: AppTypography.body,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // หน่วย dropdown (flex: 2 = 2 ส่วน เพื่อรองรับ "สัปดาห์" ที่ยาวกว่า)
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('typeOfTime_${state.typeOfTime}'),
                          initialValue: state.typeOfTime,
                          decoration: InputDecoration(
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'วัน', child: Text('วัน')),
                            DropdownMenuItem(value: 'สัปดาห์', child: Text('สัปดาห์')),
                            DropdownMenuItem(value: 'เดือน', child: Text('เดือน')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              ref
                                  .read(addMedicineFormProvider(widget.residentId).notifier)
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
                          .read(addMedicineFormProvider(widget.residentId).notifier)
                          .toggleDay(day),
                      onClear: state.selectedDays.isNotEmpty
                          ? () => ref
                              .read(addMedicineFormProvider(widget.residentId).notifier)
                              .clearDays()
                          : null,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                // ==========================================
                // Section 4: Stock (ได้รับยาเข้า)
                // ==========================================
                _SectionHeader(
                  icon: HugeIcons.strokeRoundedPackageReceive,
                  title: 'จำนวนยาที่รับเข้า',
                ),
                const SizedBox(height: AppSpacing.md),

                // ได้รับยาเข้าเป็นจำนวน ... เม็ด (แบบ Row)
                Row(
                  children: [
                    // Text label
                    Expanded(
                      flex: 2,
                      child: Text(
                        'ได้รับยาเข้าเป็นจำนวน',
                        textAlign: TextAlign.end,
                        style: AppTypography.body,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Input จำนวน
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _reconcileController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'จำนวน',
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        style: AppTypography.body,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // หน่วย
                    Expanded(
                      flex: 1,
                      child: Text(
                        state.selectedMedicine?.unit ?? 'เม็ด',
                        style: AppTypography.body,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // ==========================================
                // Section 5: ระยะเวลาให้ยา
                // ==========================================
                _SectionHeader(
                  icon: HugeIcons.strokeRoundedCalendarCheckIn01,
                  title: 'ระยะเวลาให้ยา',
                ),
                const SizedBox(height: AppSpacing.md),

                // วันที่เริ่ม (แบบ Tappable Container)
                _DatePickerField(
                  date: state.onDate,
                  onTap: () => _selectDate(true),
                  prefixText: 'เริ่มวันที่: ',
                ),
                const SizedBox(height: AppSpacing.md),

                // สรุปการคำนวณ (แสดงเมื่อมีข้อมูลครบ + กรอกจำนวนยาแล้ว)
                // ใช้ state.reconcile แทน controller เพื่อให้ update real-time
                if (state.selectedMedicine != null &&
                    state.bldb.isNotEmpty &&
                    state.reconcile.isNotEmpty) ...[
                  _MedicineSummaryRow(
                    route: state.selectedMedicine?.route ?? 'รับประทาน',
                    takeTab: state.takeTab,
                    bldb: state.bldb,
                    unit: state.selectedMedicine?.unit ?? 'เม็ด',
                    everyHr: state.everyHr,
                    typeOfTime: state.typeOfTime,
                    reconcile: state.reconcile,
                    onDate: state.onDate,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ต่อเนื่อง (CheckboxListTile)
                Container(
                  decoration: BoxDecoration(
                    color: state.isContinuous ? AppColors.accent1 : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CheckboxListTile(
                    value: state.isContinuous,
                    onChanged: (value) => ref
                        .read(addMedicineFormProvider(widget.residentId).notifier)
                        .setIsContinuous(value ?? true),
                    title: Text(
                      'ต่อเนื่อง (continue)',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    activeColor: AppColors.primary,
                    checkColor: AppColors.surface,
                    controlAffinity: ListTileControlAffinity.leading,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                ),

                // ให้เป็นเวลา ... วัน (แสดงเมื่อไม่ต่อเนื่อง)
                if (!state.isContinuous) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      // Text label
                      Expanded(
                        flex: 1,
                        child: Text(
                          'ให้เป็นเวลา',
                          textAlign: TextAlign.end,
                          style: AppTypography.body,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Input จำนวนวัน
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _daysController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onChanged: (value) {
                            // คำนวณ offDate จาก onDate + days
                            final days = int.tryParse(value);
                            if (days != null && days > 0) {
                              final offDate = state.onDate.add(Duration(days: days));
                              ref
                                  .read(addMedicineFormProvider(widget.residentId).notifier)
                                  .setOffDate(offDate);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'จำนวน',
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                          style: AppTypography.body,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // หน่วย "วัน"
                      Expanded(
                        flex: 1,
                        child: Text(
                          'วัน',
                          style: AppTypography.body,
                        ),
                      ),
                    ],
                  ),
                  // แสดง "ถึงวันที่: X" (เมื่อมี offDate)
                  if (state.offDate != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ถึงวันที่: ${state.offDate!.day}/${state.offDate!.month}/${state.offDate!.year}',
                        style: AppTypography.body.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: AppSpacing.lg),

                // ==========================================
                // Section 6: หมายเหตุ
                // ==========================================
                _SectionHeader(
                  icon: HugeIcons.strokeRoundedNote01,
                  title: 'หมายเหตุ',
                ),
                const SizedBox(height: AppSpacing.md),

                // หมายเหตุ (ขยายได้อัตโนมัติตามเนื้อหา)
                _LabeledField(
                  label: 'หมายเหตุ',
                  child: TextField(
                    controller: _noteController,
                    maxLines: null,  // ขยายได้ไม่จำกัด
                    minLines: 1,     // เริ่มต้น 1 บรรทัด
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'ข้อมูลเพิ่มเติม...',
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    style: AppTypography.body,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ==========================================
                // Summary Card (แสดงเมื่อเลือกยาแล้ว)
                // อยู่ก่อนปุ่ม submit เพื่อให้ user เห็นสรุปก่อนกดบันทึก
                // ==========================================
                if (state.selectedMedicine != null) ...[
                  _MedicineSummaryCard(
                    medicine: state.selectedMedicine!,
                    takeTab: state.takeTab,
                    bldb: state.bldb,
                    beforeAfter: state.beforeAfter,
                    prn: state.prn,
                    everyHr: state.everyHr,
                    typeOfTime: state.typeOfTime,
                    onDate: state.onDate,
                    offDate: state.offDate,
                    isContinuous: state.isContinuous,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ==========================================
                // ปุ่มบันทึก
                // ==========================================

                // Error message (ถ้ามี) - แสดงเหนือปุ่มบันทึกเพื่อให้ user เห็นชัดเจน
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
                              .read(addMedicineFormProvider(widget.residentId).notifier)
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
                    text: 'เพิ่มยาให้คนไข้',
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
        // Wrap HugeIcon ด้วย Center เพื่อให้ icon อยู่ตรงกลาง
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
          style: AppTypography.heading3.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            '*',
            style: AppTypography.heading3.copyWith(
              color: AppColors.error,
            ),
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
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

/// Date Picker Field
///
/// แสดงวันที่ที่เลือก พร้อม prefix text (ถ้ามี)
/// เช่น "เริ่มวันที่: 7/1/2026"
class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.onTap,
    this.date,
    this.prefixText,  // เช่น "เริ่มวันที่: "
  });

  final DateTime? date;
  final VoidCallback onTap;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    // ถ้ามี prefixText ให้แสดง prefix + วันที่
    // แสดงปี ค.ศ. (ตามที่ใช้ในแอพเก่า)
    final dateStr = date != null
        ? '${date!.day}/${date!.month}/${date!.year}'
        : 'เลือกวันที่';
    final displayText = prefixText != null ? '$prefixText$dateStr' : dateStr;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.alternate, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                style: AppTypography.body.copyWith(
                  color: date != null
                      ? AppColors.textPrimary
                      : AppColors.secondaryText,
                ),
              ),
            ),
            // Wrap HugeIcon ด้วย Center เพื่อให้ icon อยู่ตรงกลาง
            Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar01,
                color: AppColors.secondaryText,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary Card สำหรับแสดงข้อมูลยาที่กำลังจะเพิ่ม
///
/// แสดง:
/// - รูปยา (ถ้ามี)
/// - ชื่อยา (generic + brand name)
/// - ขนาด, วิธีการให้, หน่วย
/// - ปริมาณที่ให้
/// - เวลาที่ให้ (BLDB)
/// - ก่อน/หลังอาหาร
/// - PRN badge (ถ้าเปิด)
/// - ความถี่ (ถ้ากำหนด)
class _MedicineSummaryCard extends StatelessWidget {
  const _MedicineSummaryCard({
    required this.medicine,
    required this.takeTab,
    required this.bldb,
    required this.beforeAfter,
    required this.prn,
    required this.everyHr,
    required this.typeOfTime,
    required this.onDate,
    required this.offDate,
    required this.isContinuous,
  });

  final MedDB medicine;
  final String takeTab;
  final List<String> bldb;
  final List<String> beforeAfter;
  final bool prn;
  final String everyHr;
  final String typeOfTime;
  final DateTime onDate;
  final DateTime? offDate;
  final bool isContinuous;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        // Gradient สีเขียวอ่อนๆ เพื่อให้ดูโดดเด่น
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent1,
            AppColors.primary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: รูปยา + ชื่อยา
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // รูปยา (ถ้ามี)
              _buildMedicineImage(),
              const SizedBox(width: AppSpacing.md),
              // ชื่อยา + ขนาด
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Generic name
                    if (medicine.genericName != null &&
                        medicine.genericName!.isNotEmpty)
                      Text(
                        medicine.genericName!,
                        style: AppTypography.heading3.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    // Brand name
                    if (medicine.brandName != null &&
                        medicine.brandName!.isNotEmpty)
                      Text(
                        medicine.brandName!,
                        style: AppTypography.body.copyWith(
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    // Strength
                    if (medicine.str != null && medicine.str!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        medicine.str!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),

          // Row 2: วิธีการให้ + ปริมาณ + หน่วย
          Row(
            children: [
              // วิธีการให้ (route)
              if (medicine.route != null && medicine.route!.isNotEmpty) ...[
                _buildInfoChip(
                  icon: HugeIcons.strokeRoundedMedicine01,
                  label: medicine.route!,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              // ปริมาณ + หน่วย
              if (takeTab.isNotEmpty) ...[
                _buildInfoChip(
                  icon: HugeIcons.strokeRoundedDashboardSquare01,
                  label: '$takeTab ${medicine.unit ?? 'เม็ด'}',
                  color: AppColors.secondary,
                ),
              ],
            ],
          ),

          // Row 3: ก่อน/หลังอาหาร + PRN
          if (beforeAfter.isNotEmpty || prn) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                // ก่อน/หลังอาหาร (พร้อม icon)
                ...beforeAfter.map((ba) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: _buildSmallBadgeWithIcon(
                        label: ba,
                        // ArrowLeftDouble = ก่อนอาหาร, ArrowRightDouble = หลังอาหาร
                        icon: ba == 'ก่อนอาหาร'
                            ? HugeIcons.strokeRoundedArrowLeftDouble
                            : HugeIcons.strokeRoundedArrowRightDouble,
                        bgColor: ba == 'ก่อนอาหาร'
                            ? AppColors.tagReadBg
                            : AppColors.tagReviewBg,
                        textColor: ba == 'ก่อนอาหาร'
                            ? AppColors.tagReadText
                            : AppColors.tagReviewText,
                      ),
                    )),
                // PRN badge
                if (prn)
                  _buildSmallBadge(
                    label: 'PRN',
                    bgColor: AppColors.tagUpdateBg,
                    textColor: AppColors.tagUpdateText,
                  ),
              ],
            ),
          ],

          // Row 4: เวลาที่ให้ (BLDB) พร้อม icon
          if (bldb.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: bldb.map((time) {
                // กำหนดสีและ icon ตาม time slot
                final (bgColor, textColor, icon) = _getTimeSlotStyle(time);
                return _buildSmallBadgeWithIcon(
                  label: time,
                  icon: icon,
                  bgColor: bgColor,
                  textColor: textColor,
                );
              }).toList(),
            ),
          ],

          // Row 5: ความถี่ (ถ้ากำหนด)
          if (everyHr.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedRepeat,
                  color: AppColors.secondaryText,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'ทุก $everyHr $typeOfTime',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ],

          // Row 6: ระยะเวลา
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar01,
                color: AppColors.secondaryText,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _formatDateRange(),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// สร้าง widget รูปยา (ใช้ frontFoiled เหมือน card ตอนเลือกยา)
  Widget _buildMedicineImage() {
    // ใช้ frontFoiled เหมือนกับ _SelectedMedicineCard
    final imageUrl = medicine.frontFoiled;

    // รูปยา - ใช้ IreneNetworkImage ที่มี timeout และ retry
    if (medicine.hasAnyImage && imageUrl != null && imageUrl.isNotEmpty) {
      return IreneNetworkImage(
        imageUrl: imageUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        memCacheWidth: 200,
        borderRadius: BorderRadius.circular(12),
        compact: true,
        errorPlaceholder: _buildPlaceholderImage(),
      );
    }

    return _buildPlaceholderImage();
  }

  /// Placeholder รูปยา (ใช้ Medicine02 icon)
  Widget _buildPlaceholderImage() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alternate),
      ),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedMedicine02,
          color: AppColors.secondaryText,
          size: 32,
        ),
      ),
    );
  }

  /// Info chip แบบเล็ก (สำหรับวิธีการให้, ปริมาณ)
  Widget _buildInfoChip({
    required dynamic icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Small badge สำหรับ BLDB, PRN (ไม่มี icon)
  Widget _buildSmallBadge({
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Small badge พร้อม icon สำหรับ ก่อน/หลังอาหาร
  Widget _buildSmallBadgeWithIcon({
    required String label,
    required dynamic icon,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            color: textColor,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// กำหนดสีและ icon ตาม time slot (BLDB)
  /// Returns (bgColor, textColor, icon)
  (Color bgColor, Color textColor, dynamic icon) _getTimeSlotStyle(String time) {
    switch (time) {
      case 'เช้า':
        // สีส้มอ่อน + Sunrise icon
        return (
          AppColors.pastelOrange1,
          const Color(0xFFBF6E40),
          HugeIcons.strokeRoundedSunrise,
        );
      case 'กลางวัน':
        // สีเหลืองอ่อน + Sun03 icon
        return (
          AppColors.pastelYellow1,
          const Color(0xFF9A7B38),
          HugeIcons.strokeRoundedSun03,
        );
      case 'เย็น':
        // สีม่วงอ่อน + Sunset icon
        return (
          AppColors.pastelPurple,
          const Color(0xFF6B4C8A),
          HugeIcons.strokeRoundedSunset,
        );
      case 'ก่อนนอน':
        // สี teal อ่อน + Moon02 icon
        return (
          AppColors.tagReadBg,
          AppColors.tagReadText,
          HugeIcons.strokeRoundedMoon02,
        );
      default:
        return (
          AppColors.tagNeutralBg,
          AppColors.tagNeutralText,
          HugeIcons.strokeRoundedTime01,
        );
    }
  }

  /// Format date range string
  String _formatDateRange() {
    final onDateStr = '${onDate.day}/${onDate.month}/${onDate.year}';

    if (isContinuous) {
      return 'เริ่ม $onDateStr - ต่อเนื่อง';
    }

    if (offDate != null) {
      final offDateStr = '${offDate!.day}/${offDate!.month}/${offDate!.year}';
      return '$onDateStr - $offDateStr';
    }

    return 'เริ่ม $onDateStr';
  }
}

/// Widget สำหรับเลือกวันในสัปดาห์ (จ, อ, พ, พฤ, ศ, ส, อา)
/// แสดงเป็นปุ่มกลมๆ พร้อมสีที่แตกต่างกันในแต่ละวัน
class _DayOfWeekSelector extends StatelessWidget {
  const _DayOfWeekSelector({
    required this.selectedDays,
    required this.onToggle,
    this.onClear,
  });

  /// วันที่เลือกไว้
  final List<String> selectedDays;

  /// Callback เมื่อกดเลือก/ยกเลิกวัน
  final void Function(String day) onToggle;

  /// Callback เมื่อกดล้าง
  final VoidCallback? onClear;

  /// รายการวันทั้งหมด พร้อมสีประจำวัน
  /// สีตาม FlutterFlow example ที่ user ให้มา
  static const List<_DayInfo> _days = [
    _DayInfo('จ', Color(0xFFE1BC29)),   // จันทร์ - เหลือง
    _DayInfo('อ', Color(0xFFF991CC)),   // อังคาร - ชมพู
    _DayInfo('พ', Color(0xFF1B998B)),   // พุธ - เขียว teal
    _DayInfo('พฤ', Color(0xFFEB8258)),  // พฤหัส - ส้ม
    _DayInfo('ศ', Color(0xFF648DE5)),   // ศุกร์ - ฟ้า
    _DayInfo('ส', Color(0xFF8A4F7D)),   // เสาร์ - ม่วง
    _DayInfo('อา', Color(0xFFC92828)),  // อาทิตย์ - แดง
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ปุ่มวันทั้ง 7 วัน (เพิ่ม spacing ให้กดง่าย)
        Expanded(
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: _days.map((dayInfo) {
              final isSelected = selectedDays.contains(dayInfo.label);
              return _DayCircleButton(
                label: dayInfo.label,
                color: dayInfo.color,
                isSelected: isSelected,
                onTap: () => onToggle(dayInfo.label),
              );
            }).toList(),
          ),
        ),
        // ปุ่มล้าง (แสดงเมื่อมีการเลือก)
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

/// ข้อมูลวัน (label + สี)
class _DayInfo {
  const _DayInfo(this.label, this.color);
  final String label;
  final Color color;
}

/// ปุ่มกลมสำหรับเลือกวัน
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
    // ขนาดปุ่ม
    const double size = 40;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          // เมื่อเลือก: สีเต็ม, ไม่เลือก: สีจางๆ
          color: isSelected ? color : color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          // เมื่อเลือก: ไม่มี border, ไม่เลือก: border สีจาง
          border: isSelected
              ? null
              : Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              // เมื่อเลือก: สีขาว, ไม่เลือก: สีประจำวัน
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget แสดงสรุปการคำนวณยา
/// แสดง: "วันละ X เม็ด", "เป็นเวลา X วัน", "น่าจะหมดในวันที่ X"
class _MedicineSummaryRow extends StatelessWidget {
  const _MedicineSummaryRow({
    required this.route,
    required this.takeTab,
    required this.bldb,
    required this.unit,
    required this.everyHr,
    required this.typeOfTime,
    required this.reconcile,
    required this.onDate,
  });

  final String route;
  final String takeTab;
  final List<String> bldb;
  final String unit;
  final String everyHr;
  final String typeOfTime;
  final String reconcile;
  final DateTime onDate;

  @override
  Widget build(BuildContext context) {
    // คำนวณจำนวนยาต่อวัน
    final dosage = double.tryParse(takeTab) ?? 1;
    final timesPerDay = bldb.length;
    final medPerDay = dosage * timesPerDay;

    // คำนวณจำนวนวันที่ยาจะหมด (ถ้ามีจำนวนยาที่รับเข้า)
    final totalMedicine = double.tryParse(reconcile) ?? 0;
    int? howManyDays;
    DateTime? endDate;

    if (totalMedicine > 0 && medPerDay > 0) {
      // คิดตามความถี่ด้วย
      final every = int.tryParse(everyHr) ?? 1;
      double actualMedPerDay = medPerDay;

      // ถ้าไม่ใช่ทุกวัน ให้หารด้วยความถี่
      if (typeOfTime == 'สัปดาห์') {
        actualMedPerDay = medPerDay / 7 * every;
      } else if (typeOfTime == 'เดือน') {
        actualMedPerDay = medPerDay / 30 * every;
      }

      if (actualMedPerDay > 0) {
        howManyDays = (totalMedicine / actualMedPerDay).ceil();
        endDate = onDate.add(Duration(days: howManyDays));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.tagNeutralBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          // วันละ X เม็ด
          Text(
            '$route วันละ ${medPerDay.toStringAsFixed(medPerDay.truncateToDouble() == medPerDay ? 0 : 1)} $unit',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          // เป็นเวลา X วัน (ถ้าคำนวณได้)
          if (howManyDays != null)
            Text(
              'เป็นเวลา $howManyDays วัน',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          // น่าจะหมดในวันที่ X (ถ้าคำนวณได้)
          if (endDate != null)
            Text(
              'น่าจะหมดในวันที่ ${endDate.day}/${endDate.month}/${endDate.year}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
