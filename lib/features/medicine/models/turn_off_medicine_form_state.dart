import 'medicine_summary.dart';

/// State สำหรับ form หยุดยา (On → Off)
///
/// เมื่อ user ต้องการหยุดยาตัวใดตัวหนึ่ง:
/// - กรอกเหตุผล/คำสั่งแพทย์
/// - เลือกว่า off ทันที หรือกำหนดวันสุดท้าย
/// - ระบบจะ INSERT med_history record ใหม่พร้อม off_date
class TurnOffMedicineFormState {
  // ==========================================
  // ข้อมูลยาที่จะหยุด (read-only)
  // ==========================================

  /// ข้อมูลยาจาก medicine_summary view
  final MedicineSummary medicine;

  // ==========================================
  // ข้อมูลที่ user กรอก
  // ==========================================

  /// เหตุผลหรือคำสั่งแพทย์ที่หยุดยา (optional แต่แนะนำให้กรอก)
  final String note;

  /// true = หยุดทันที (off_date = วันนี้ - 1)
  /// false = กำหนดวันสุดท้ายที่ให้ยา
  final bool isContinuous;

  /// วันสุดท้ายที่ให้ยา (ใช้เมื่อ isContinuous = false)
  /// ระบบจะบันทึก off_date = lastDay - 1 ตาม convention ของ app เดิม
  final DateTime? lastDay;

  /// จำนวนวันที่ให้ยาต่อ (ทางเลือกแทน lastDay)
  /// ถ้ากรอก → คำนวณ lastDay = วันนี้ + durationDays
  final String durationDays;

  // ==========================================
  // UI State
  // ==========================================

  final bool isLoading;
  final String? errorMessage;

  // ==========================================
  // Constructor
  // ==========================================

  TurnOffMedicineFormState({
    required this.medicine,
    this.note = '',
    this.isContinuous = true,
    this.lastDay,
    this.durationDays = '',
    this.isLoading = false,
    this.errorMessage,
  });

  // ==========================================
  // Factory
  // ==========================================

  /// สร้างจาก MedicineSummary - ค่า default ตาม app เดิม
  factory TurnOffMedicineFormState.fromMedicine(MedicineSummary medicine) {
    // ตรวจสอบว่ายาตัวนี้เป็นแบบต่อเนื่องหรือไม่
    // ถ้า lastMedHistoryOffDate เป็น null = ยาต่อเนื่อง → default off ทันที
    // ถ้ามี offDate อยู่แล้ว = ยามีกำหนด → default ให้กำหนดวัน
    final isContinuous = medicine.lastMedHistoryOffDate == null;

    return TurnOffMedicineFormState(
      medicine: medicine,
      isContinuous: isContinuous,
    );
  }

  // ==========================================
  // Computed Properties
  // ==========================================

  /// คำนวณ off_date ที่จะบันทึกลง DB
  /// ตาม convention ของ app เดิม: off_date = วันสุดท้าย - 1 วัน (offDateIsYesterday)
  DateTime get computedOffDate {
    if (isContinuous) {
      // Off ทันที → off_date = วันนี้ - 1 วัน
      return DateTime.now().subtract(const Duration(days: 1));
    }

    // กำหนดวันสุดท้าย
    if (lastDay != null) {
      return lastDay!.subtract(const Duration(days: 1));
    }

    // คำนวณจาก durationDays
    final days = int.tryParse(durationDays);
    if (days != null && days > 0) {
      final endDay = DateTime.now().add(Duration(days: days));
      return endDay.subtract(const Duration(days: 1));
    }

    // Fallback: off ทันที
    return DateTime.now().subtract(const Duration(days: 1));
  }

  /// สร้าง new_setting string สำหรับ med_history
  /// Format เดียวกับ app เดิม: "${route} ${takeTab} ${unit} ${beforeAfter} ${bldb}"
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
    // บังคับกรอกเหตุผล
    if (note.trim().isEmpty) return false;

    // ถ้าไม่ต่อเนื่อง ต้องมี lastDay หรือ durationDays
    if (!isContinuous) {
      if (lastDay == null) {
        final days = int.tryParse(durationDays);
        if (days == null || days <= 0) return false;
      }
    }
    return true;
  }

  /// Error message สำหรับ validation
  String? get validationError {
    if (note.trim().isEmpty) {
      return 'กรุณาระบุเหตุผลที่หยุดยา';
    }
    if (!isContinuous && lastDay == null) {
      final days = int.tryParse(durationDays);
      if (days == null || days <= 0) {
        return 'กรุณาเลือกวันสุดท้ายหรือระบุจำนวนวัน';
      }
    }
    return null;
  }

  // ==========================================
  // copyWith
  // ==========================================

  TurnOffMedicineFormState copyWith({
    MedicineSummary? medicine,
    String? note,
    bool? isContinuous,
    DateTime? lastDay,
    String? durationDays,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool clearLastDay = false,
  }) {
    return TurnOffMedicineFormState(
      medicine: medicine ?? this.medicine,
      note: note ?? this.note,
      isContinuous: isContinuous ?? this.isContinuous,
      lastDay: clearLastDay ? null : (lastDay ?? this.lastDay),
      durationDays: durationDays ?? this.durationDays,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  String toString() =>
      'TurnOffMedicineFormState(medListId: ${medicine.medicineListId}, isContinuous: $isContinuous)';
}
