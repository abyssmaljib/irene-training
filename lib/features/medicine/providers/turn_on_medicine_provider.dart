import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/user_service.dart';
import '../models/medicine_summary.dart';
import '../models/turn_on_medicine_form_state.dart';
import '../services/medicine_service.dart';

/// Provider สำหรับ form กลับมาใช้ยา (Off → On)
/// ใช้ family เพื่อ scope ตาม medicineListId
final turnOnMedicineProvider = StateNotifierProvider.family<
    TurnOnMedicineNotifier,
    AsyncValue<TurnOnMedicineFormState>,
    int>((ref, medicineListId) {
  return TurnOnMedicineNotifier(ref, medicineListId);
});

/// Notifier สำหรับจัดการ state ของ form กลับมาใช้ยา
///
/// Flow:
/// 1. User เลือกยาที่หยุดไปแล้วที่ต้องการกลับมาใช้
/// 2. กรอกเหตุผล + จำนวนยาคงเหลือ + วันเริ่ม + ต่อเนื่องหรือกำหนดระยะ
/// 3. Submit → INSERT medicine_list ใหม่ (duplicate) + INSERT med_history record
class TurnOnMedicineNotifier
    extends StateNotifier<AsyncValue<TurnOnMedicineFormState>> {
  TurnOnMedicineNotifier(Ref ref, this.medicineListId)
      : super(const AsyncValue.loading());

  final int medicineListId;
  final _service = MedicineService.instance;

  /// Initialize form จาก MedicineSummary
  void initFromMedicine(MedicineSummary medicine) {
    state = AsyncValue.data(
      TurnOnMedicineFormState.fromMedicine(medicine),
    );
  }

  // ==========================================
  // Form Field Setters
  // ==========================================

  /// ตั้งค่าเหตุผลที่กลับมาใช้ยา (บังคับกรอก)
  void setNote(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(note: value));
    });
  }

  /// ตั้งค่าจำนวนยาคงเหลือ
  void setReconcile(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(reconcile: value));
    });
  }

  /// ตั้งค่าวันที่เริ่มใช้ยาอีกครั้ง
  void setStartDate(DateTime date) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(startDate: date));
    });
  }

  /// ตั้งค่าว่าใช้ต่อเนื่อง (true) หรือกำหนดระยะ (false)
  void setIsContinuous(bool value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(isContinuous: value));
    });
  }

  /// ตั้งค่าจำนวนวันที่ให้ยา (สำหรับกรณีไม่ต่อเนื่อง)
  void setDurationDays(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(durationDays: value));
    });
  }

  // ==========================================
  // Submit
  // ==========================================

  /// บันทึกการกลับมาใช้ยา
  ///
  /// Logic ตาม app เดิม:
  /// 1. Validate form
  /// 2. Duplicate medicine_list (สร้าง row ใหม่ copy ทุก field)
  /// 3. INSERT med_history ใหม่บน medicine_list ใหม่
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

      // Parse reconcile
      final reconcile = currentState.reconcile.isNotEmpty
          ? double.tryParse(currentState.reconcile)
          : null;

      debugPrint('[TurnOnMedicine] Submitting for medicineListId: $medicineListId');
      debugPrint('[TurnOnMedicine] startDate: ${currentState.startDate}, isContinuous: ${currentState.isContinuous}');

      final success = await _service.turnOnMedicine(
        medicineListId: medicineListId,
        startDate: currentState.startDate,
        offDate: currentState.computedOffDate,
        note: currentState.note,
        newSetting: currentState.newSettingString,
        reconcile: reconcile,
        userId: userId,
      );

      if (success) {
        debugPrint('[TurnOnMedicine] Success');
        state = AsyncValue.data(currentState.copyWith(isLoading: false));
        return true;
      } else {
        state = AsyncValue.data(currentState.copyWith(
          isLoading: false,
          errorMessage: 'ไม่สามารถเปิดใช้ยาได้ กรุณาลองใหม่',
        ));
        return false;
      }
    } catch (e) {
      debugPrint('[TurnOnMedicine] Error: $e');
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
