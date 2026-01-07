import 'medicine_summary.dart';

/// State สำหรับ form แก้ไขยาของ resident
///
/// เก็บข้อมูลเดิมจาก MedicineSummary และข้อมูลที่แก้ไขใหม่
/// รวมถึง logic สำหรับ validation และ comparison
class EditMedicineFormState {
  // ==========================================
  // ข้อมูลเดิม (read-only reference)
  // ==========================================

  /// ID ของ medicine_list ที่แก้ไข
  final int medicineListId;

  /// ID ของยาใน med_DB (ไม่สามารถเปลี่ยนได้)
  final int medDbId;

  /// ข้อมูลยาเดิมสำหรับเปรียบเทียบและแสดงผล
  final MedicineSummary? originalMedicine;

  // ==========================================
  // ข้อมูลที่แก้ไขได้
  // ==========================================

  /// ปริมาณที่ให้ (เป็น string เพื่อรองรับ 0.5, 1, 2)
  final String takeTab;

  /// เวลาที่ให้: ['เช้า', 'กลางวัน', 'เย็น', 'ก่อนนอน']
  final List<String> bldb;

  /// ก่อน/หลังอาหาร: ['ก่อนอาหาร'] หรือ ['หลังอาหาร']
  final List<String> beforeAfter;

  /// ให้เมื่อจำเป็น (PRN)
  final bool prn;

  /// ทุก N (วัน/สัปดาห์/เดือน)
  final String everyHr;

  /// หน่วยความถี่: 'วัน', 'สัปดาห์', 'เดือน'
  final String typeOfTime;

  /// วันที่เลือก (สำหรับรายสัปดาห์): ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา']
  final List<String> selectedDays;

  // ==========================================
  // วันที่ (สำหรับ med_history ใหม่)
  // ==========================================

  /// วันที่เริ่มใช้ setting ใหม่
  final DateTime onDate;

  /// ให้ยาต่อเนื่อง (ไม่มี off date)
  final bool isContinuous;

  /// วันที่หยุดให้ยา (ถ้าไม่ continuous)
  final DateTime? offDate;

  // ==========================================
  // Stock & Note
  // ==========================================

  /// จำนวนยาคงเหลือ
  final String reconcile;

  /// หมายเหตุการแก้ไข (required สำหรับ edit)
  final String note;

  // ==========================================
  // UI State
  // ==========================================

  final bool isLoading;
  final String? errorMessage;

  // ==========================================
  // Constructor
  // ==========================================

  EditMedicineFormState({
    required this.medicineListId,
    required this.medDbId,
    this.originalMedicine,
    this.takeTab = '1',
    this.bldb = const [],
    this.beforeAfter = const [],
    this.prn = false,
    this.everyHr = '1',
    this.typeOfTime = 'วัน',
    this.selectedDays = const [],
    DateTime? onDate,
    this.isContinuous = true,
    this.offDate,
    this.reconcile = '',
    this.note = '',
    this.isLoading = false,
    this.errorMessage,
  }) : onDate = onDate ?? DateTime.now();

  // ==========================================
  // Factory: สร้างจาก MedicineSummary
  // ==========================================

  /// สร้าง EditMedicineFormState จาก MedicineSummary
  /// Pre-populate ค่าเดิมทั้งหมดจากยาที่ต้องการแก้ไข
  factory EditMedicineFormState.fromMedicineSummary(MedicineSummary medicine) {
    return EditMedicineFormState(
      medicineListId: medicine.medicineListId,
      medDbId: 0, // จะต้อง query เพิ่มถ้าต้องการ
      originalMedicine: medicine,
      // Pre-populate จากข้อมูลเดิม
      takeTab: medicine.takeTab?.toString() ?? '1',
      bldb: List<String>.from(medicine.bldb),
      beforeAfter: List<String>.from(medicine.beforeAfter),
      prn: medicine.prn ?? false,
      everyHr: medicine.everyHr?.toString() ?? '1',
      typeOfTime: medicine.typeOfTime ?? 'วัน',
      selectedDays: List<String>.from(medicine.daysOfWeek),
      // วันที่เริ่มใหม่ = วันนี้ (ไม่ใช่วันที่เริ่มเดิม)
      onDate: DateTime.now(),
      isContinuous: medicine.lastMedHistoryOffDate == null,
      offDate: medicine.lastMedHistoryOffDate,
    );
  }

  // ==========================================
  // Validation Helpers
  // ==========================================

  /// ตรวจสอบว่า form valid หรือไม่
  bool get isValid {
    // ต้องระบุปริมาณ
    if (takeTab.isEmpty) return false;
    final dosage = double.tryParse(takeTab);
    if (dosage == null || dosage <= 0) return false;

    // ต้องเลือกเวลาอย่างน้อย 1 เวลา (ยกเว้น PRN)
    if (!prn && bldb.isEmpty) return false;

    // ต้องใส่หมายเหตุการแก้ไข (required สำหรับ edit)
    if (note.trim().isEmpty) return false;

    return true;
  }

  /// Error message สำหรับ validation
  String? get validationError {
    if (takeTab.isEmpty) return 'กรุณาระบุปริมาณยา';
    final dosage = double.tryParse(takeTab);
    if (dosage == null || dosage <= 0) {
      return 'ปริมาณยาต้องเป็นตัวเลขที่มากกว่า 0';
    }
    if (!prn && bldb.isEmpty) {
      return 'กรุณาเลือกเวลาที่ให้ยาอย่างน้อย 1 เวลา';
    }
    if (note.trim().isEmpty) {
      return 'กรุณาระบุหมายเหตุการแก้ไข';
    }
    return null;
  }

  // ==========================================
  // Comparison Helpers
  // ==========================================

  /// ตรวจสอบว่ามีการเปลี่ยนแปลงจากข้อมูลเดิมหรือไม่
  bool get hasChanges {
    if (originalMedicine == null) return true;

    final original = originalMedicine!;

    // เปรียบเทียบทีละ field
    if (_parseDouble(takeTab) != original.takeTab) return true;
    if (!_listEquals(bldb, original.bldb)) return true;
    if (!_listEquals(beforeAfter, original.beforeAfter)) return true;
    if (prn != (original.prn ?? false)) return true;
    if (_parseInt(everyHr) != original.everyHr) return true;
    if (typeOfTime != (original.typeOfTime ?? 'วัน')) return true;
    if (!_listEquals(selectedDays, original.daysOfWeek)) return true;

    return false;
  }

  /// Helper: parse double safely
  double? _parseDouble(String value) {
    return double.tryParse(value);
  }

  /// Helper: parse int safely
  int? _parseInt(String value) {
    return int.tryParse(value);
  }

  /// Helper: compare two lists
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!b.contains(a[i])) return false;
    }
    return true;
  }

  // ==========================================
  // new_setting String Builder
  // ==========================================

  /// สร้าง new_setting string สำหรับบันทึกใน med_history
  /// Format: "ปริมาณ หน่วย | เวลา | ก่อน/หลังอาหาร | ความถี่ | PRN"
  ///
  /// ตัวอย่าง:
  /// - "1 เม็ด | เช้า,กลางวัน,เย็น | หลังอาหาร"
  /// - "0.5 เม็ด | ก่อนนอน | PRN"
  /// - "2 เม็ด | เช้า | ก่อนอาหาร | ทุก 2 วัน"
  String get newSettingString {
    final parts = <String>[];

    // ปริมาณ + หน่วย
    final unitStr = originalMedicine?.unit ?? 'เม็ด';
    parts.add('$takeTab $unitStr');

    // เวลา
    if (bldb.isNotEmpty) {
      parts.add(bldb.join(','));
    }

    // ก่อน/หลังอาหาร
    if (beforeAfter.isNotEmpty) {
      parts.add(beforeAfter.join(','));
    }

    // ความถี่ (ถ้าไม่ใช่ทุกวัน)
    final freq = int.tryParse(everyHr) ?? 1;
    if (freq != 1 || typeOfTime != 'วัน') {
      parts.add('ทุก $everyHr $typeOfTime');
    }

    // PRN
    if (prn) {
      parts.add('PRN');
    }

    return parts.join(' | ');
  }

  // ==========================================
  // copyWith
  // ==========================================

  EditMedicineFormState copyWith({
    int? medicineListId,
    int? medDbId,
    MedicineSummary? originalMedicine,
    String? takeTab,
    List<String>? bldb,
    List<String>? beforeAfter,
    bool? prn,
    String? everyHr,
    String? typeOfTime,
    List<String>? selectedDays,
    DateTime? onDate,
    bool? isContinuous,
    DateTime? offDate,
    String? reconcile,
    String? note,
    bool? isLoading,
    String? errorMessage,
    // Special: allow clearing
    bool clearErrorMessage = false,
    bool clearOffDate = false,
  }) {
    return EditMedicineFormState(
      medicineListId: medicineListId ?? this.medicineListId,
      medDbId: medDbId ?? this.medDbId,
      originalMedicine: originalMedicine ?? this.originalMedicine,
      takeTab: takeTab ?? this.takeTab,
      bldb: bldb ?? this.bldb,
      beforeAfter: beforeAfter ?? this.beforeAfter,
      prn: prn ?? this.prn,
      everyHr: everyHr ?? this.everyHr,
      typeOfTime: typeOfTime ?? this.typeOfTime,
      selectedDays: selectedDays ?? this.selectedDays,
      onDate: onDate ?? this.onDate,
      isContinuous: isContinuous ?? this.isContinuous,
      offDate: clearOffDate ? null : (offDate ?? this.offDate),
      reconcile: reconcile ?? this.reconcile,
      note: note ?? this.note,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  String toString() =>
      'EditMedicineFormState(medicineListId: $medicineListId, takeTab: $takeTab, bldb: $bldb, hasChanges: $hasChanges)';
}
