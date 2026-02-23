import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/user_service.dart';
import '../models/medicine_summary.dart';
import '../models/turn_off_medicine_form_state.dart';
import '../services/medicine_service.dart';

/// Provider สำหรับ form หยุดยา (On → Off)
/// ใช้ family เพื่อ scope ตาม medicineListId
final turnOffMedicineProvider = StateNotifierProvider.family<
    TurnOffMedicineNotifier,
    AsyncValue<TurnOffMedicineFormState>,
    int>((ref, medicineListId) {
  return TurnOffMedicineNotifier(ref, medicineListId);
});

/// Notifier สำหรับจัดการ state ของ form หยุดยา
///
/// Flow:
/// 1. User เลือกยาที่ต้องการหยุด
/// 2. กรอกเหตุผล + เลือกว่า off ทันที หรือกำหนดวัน
/// 3. Submit → INSERT med_history record ใหม่พร้อม off_date
class TurnOffMedicineNotifier
    extends StateNotifier<AsyncValue<TurnOffMedicineFormState>> {
  TurnOffMedicineNotifier(Ref ref, this.medicineListId)
      : super(const AsyncValue.loading());

  final int medicineListId;
  final _service = MedicineService.instance;

  /// Initialize form จาก MedicineSummary
  void initFromMedicine(MedicineSummary medicine) {
    state = AsyncValue.data(
      TurnOffMedicineFormState.fromMedicine(medicine),
    );
  }

  // ==========================================
  // Form Field Setters
  // ==========================================

  /// ตั้งค่าเหตุผลที่หยุดยา
  void setNote(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(note: value));
    });
  }

  /// ตั้งค่าว่า off ทันที (true) หรือกำหนดวัน (false)
  void setIsContinuous(bool value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(
        isContinuous: value,
        // ถ้าเปลี่ยนเป็น off ทันที → ล้าง lastDay
        clearLastDay: value,
      ));
    });
  }

  /// ตั้งค่าวันสุดท้ายที่ให้ยา
  void setLastDay(DateTime? date) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(lastDay: date));
    });
  }

  /// ตั้งค่าจำนวนวันที่ให้ยาต่อ
  void setDurationDays(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(durationDays: value));
    });
  }

  // ==========================================
  // Submit
  // ==========================================

  /// บันทึกการหยุดยา
  ///
  /// Logic:
  /// 1. Validate form
  /// 2. คำนวณ off_date ตาม convention (offDateIsYesterday)
  /// 3. INSERT med_history record ใหม่
  Future<bool> submit() async {
    final currentState = state.value;
    if (currentState == null) return false;

    // Validate
    final validationError = currentState.validationError;
    if (validationError != null) {
      state = AsyncValue.data(currentState.copyWith(
        errorMessage: validationError,
      ));
      return false;
    }

    // Set loading
    state = AsyncValue.data(currentState.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    ));

    try {
      // ใช้ effectiveUserId เพื่อรองรับ impersonation
      final userId = UserService().effectiveUserId;

      if (userId == null) {
        state = AsyncValue.data(currentState.copyWith(
          isLoading: false,
          errorMessage: 'ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบใหม่',
        ));
        return false;
      }

      // คำนวณ on_date จาก medicine (วันที่เริ่มให้ยาเดิม)
      final onDate = currentState.medicine.firstMedHistoryOnDate ?? DateTime.now();

      // คำนวณ off_date ตาม convention offDateIsYesterday
      final offDate = currentState.computedOffDate;

      debugPrint('[TurnOffMedicine] Submitting for medicineListId: $medicineListId');
      debugPrint('[TurnOffMedicine] off_date: $offDate, isContinuous: ${currentState.isContinuous}');

      final success = await _service.turnOffMedicine(
        medicineListId: medicineListId,
        onDate: onDate,
        offDate: offDate,
        note: currentState.note.isNotEmpty ? currentState.note : null,
        newSetting: currentState.newSettingString,
        reconcile: currentState.medicine.lastMedHistoryReconcile,
        userId: userId,
      );

      if (success) {
        debugPrint('[TurnOffMedicine] Success');
        state = AsyncValue.data(currentState.copyWith(isLoading: false));
        return true;
      } else {
        state = AsyncValue.data(currentState.copyWith(
          isLoading: false,
          errorMessage: 'ไม่สามารถหยุดยาได้ กรุณาลองใหม่',
        ));
        return false;
      }
    } catch (e) {
      debugPrint('[TurnOffMedicine] Error: $e');
      state = AsyncValue.data(currentState.copyWith(
        isLoading: false,
        errorMessage: 'เกิดข้อผิดพลาด: $e',
      ));
      return false;
    }
  }

  /// ล้าง error message
  void clearError() {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(clearErrorMessage: true));
    });
  }
}
