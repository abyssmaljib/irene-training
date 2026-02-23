import 'medicine_summary.dart';

/// State สำหรับ form กลับมาใช้ยา (Off → On)
///
/// เมื่อ user ต้องการเปิดใช้ยาตัวที่หยุดไปแล้ว:
/// - กรอกเหตุผลที่กลับมาใช้ (บังคับ)
/// - ระบุจำนวนยาคงเหลือ (pre-fill จาก lastMedHistoryReconcile)
/// - เลือกวันเริ่ม + ต่อเนื่องหรือกำหนดระยะ
/// - ระบบจะ:
///   1. INSERT medicine_list ใหม่ (duplicate จากของเดิม)
///   2. INSERT med_history record ใหม่
class TurnOnMedicineFormState {
  // ==========================================
  // ข้อมูลยาที่จะกลับมาใช้ (read-only)
  // ==========================================

  /// ข้อมูลยาจาก medicine_summary view
  final MedicineSummary medicine;

  // ==========================================
  // ข้อมูลที่ user กรอก
  // ==========================================

  /// เหตุผลที่กลับมาใช้ยา (บังคับกรอก)
  final String note;

  /// จำนวนยาคงเหลือ (pre-fill จาก medicine.lastMedHistoryReconcile)
  final String reconcile;

  /// วันที่เริ่มใช้ยาอีกครั้ง (default = วันนี้)
  final DateTime startDate;

  /// true = ใช้ต่อเนื่อง (ไม่มี off_date)
  /// false = กำหนดระยะเวลา
  final bool isContinuous;

  /// จำนวนวันที่ให้ยา (ใช้เมื่อ isContinuous = false)
  /// คำนวณ off_date = startDate + durationDays - 1
  final String durationDays;

  // ==========================================
  // UI State
  // ==========================================

  final bool isLoading;
  final String? errorMessage;

  // ==========================================
  // Constructor
  // ==========================================

  TurnOnMedicineFormState({
    required this.medicine,
    this.note = '',
    this.reconcile = '',
    DateTime? startDate,
    this.isContinuous = true,
    this.durationDays = '',
    this.isLoading = false,
    this.errorMessage,
  }) : startDate = startDate ?? DateTime.now();

  // ==========================================
  // Factory
  // ==========================================

  /// สร้างจาก MedicineSummary - pre-fill ค่าจาก history ล่าสุด
  factory TurnOnMedicineFormState.fromMedicine(MedicineSummary medicine) {
    return TurnOnMedicineFormState(
      medicine: medicine,
      // Pre-fill จำนวนยาคงเหลือจาก record ล่าสุด
      reconcile: medicine.lastMedHistoryReconcile?.toString() ?? '',
      startDate: DateTime.now(),
      isContinuous: true,
    );
  }

  // ==========================================
  // Computed Properties
  // ==========================================

  /// คำนวณ off_date สำหรับกรณีไม่ต่อเนื่อง
  /// off_date = startDate + durationDays - 1
  DateTime? get computedOffDate {
    if (isContinuous) return null;

    final days = int.tryParse(durationDays);
    if (days != null && days > 0) {
      return startDate.add(Duration(days: days - 1));
    }
    return null;
  }

  /// สร้าง new_setting string (เหมือน TurnOffMedicineFormState)
  String get newSettingString {
    final parts = <String>[];

    if (medicine.route != null && medicine.route!.isNotEmpty) {
      parts.add(medicine.route!);
    }

    if (medicine.takeTab != null) {
      final tabStr = medicine.takeTab! % 1 == 0
          ? medicine.takeTab!.toInt().toString()
          : medicine.takeTab.toString();
      parts.add(tabStr);
    }

    if (medicine.unit != null && medicine.unit!.isNotEmpty) {
      parts.add(medicine.unit!);
    }

    if (medicine.beforeAfter.isNotEmpty) {
      parts.add(medicine.beforeAfter.join(','));
    }

    if (medicine.bldb.isNotEmpty) {
      parts.add(medicine.bldb.join(','));
    }

    if (medicine.prn == true) {
      parts.add('เมื่อมีอาการ');
    }

    return parts.join(' ');
  }

  // ==========================================
  // Validation
  // ==========================================

  /// ตรวจสอบว่า form valid หรือไม่
  bool get isValid {
    // ต้องกรอกเหตุผล (บังคับสำหรับ On flow)
    if (note.trim().isEmpty) return false;

    // ถ้าไม่ต่อเนื่อง ต้องระบุจำนวนวัน
    if (!isContinuous) {
      final days = int.tryParse(durationDays);
      if (days == null || days <= 0) return false;
    }

    return true;
  }

  /// Error message สำหรับ validation
  String? get validationError {
    if (note.trim().isEmpty) {
      return 'กรุณาระบุเหตุผลที่กลับมาใช้ยา';
    }
    if (!isContinuous) {
      final days = int.tryParse(durationDays);
      if (days == null || days <= 0) {
        return 'กรุณาระบุจำนวนวันที่ให้ยา';
      }
    }
    return null;
  }

  // ==========================================
  // copyWith
  // ==========================================

  TurnOnMedicineFormState copyWith({
    MedicineSummary? medicine,
    String? note,
    String? reconcile,
    DateTime? startDate,
    bool? isContinuous,
    String? durationDays,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return TurnOnMedicineFormState(
      medicine: medicine ?? this.medicine,
      note: note ?? this.note,
      reconcile: reconcile ?? this.reconcile,
      startDate: startDate ?? this.startDate,
      isContinuous: isContinuous ?? this.isContinuous,
      durationDays: durationDays ?? this.durationDays,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  String toString() =>
      'TurnOnMedicineFormState(medListId: ${medicine.medicineListId}, isContinuous: $isContinuous)';
}
