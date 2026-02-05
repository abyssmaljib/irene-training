import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/user_service.dart';
import '../models/edit_medicine_form_state.dart';
import '../models/medicine_summary.dart';
import '../services/medicine_service.dart';

/// Provider สำหรับ form แก้ไขยาของ resident
/// ใช้ family เพื่อ scope ตาม medicineListId
final editMedicineFormProvider = StateNotifierProvider.family<
    EditMedicineFormNotifier,
    AsyncValue<EditMedicineFormState>,
    int>((ref, medicineListId) {
  return EditMedicineFormNotifier(ref, medicineListId);
});

/// Notifier สำหรับจัดการ state ของ form แก้ไขยาของ resident
///
/// ต่างจาก AddMedicineFormNotifier ตรงที่:
/// - Pre-populate ค่าจาก MedicineSummary ที่มีอยู่
/// - Submit จะ update แทนที่จะ insert
/// - บันทึก history tracking ใน med_history
class EditMedicineFormNotifier
    extends StateNotifier<AsyncValue<EditMedicineFormState>> {
  EditMedicineFormNotifier(Ref ref, this.medicineListId)
      : super(const AsyncValue.loading());

  final int medicineListId;
  final _service = MedicineService.instance;

  /// Initialize form ด้วยข้อมูลจาก MedicineSummary
  /// ต้องเรียก method นี้หลังสร้าง provider
  Future<void> loadFromMedicineSummary(MedicineSummary medicine) async {
    try {
      debugPrint('[EditMedicineForm] Loading from MedicineSummary: ${medicine.displayName}');

      // สร้าง state จาก MedicineSummary
      state = AsyncValue.data(EditMedicineFormState.fromMedicineSummary(medicine));

      debugPrint('[EditMedicineForm] Loaded successfully');
    } catch (e, st) {
      debugPrint('[EditMedicineForm] Error loading: $e');
      state = AsyncValue.error(e, st);
    }
  }

  // ==========================================
  // Dosage & Timing (เหมือน AddMedicineFormNotifier)
  // ==========================================

  /// ตั้งค่าปริมาณยา
  void setTakeTab(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(takeTab: value));
    });
  }

  /// Toggle เวลาที่ให้ยา (BLDB)
  /// [time] = 'เช้า', 'กลางวัน', 'เย็น', 'ก่อนนอน'
  void toggleBldb(String time) {
    state.whenData((data) {
      final newBldb = List<String>.from(data.bldb);
      if (newBldb.contains(time)) {
        newBldb.remove(time);
      } else {
        newBldb.add(time);
      }
      state = AsyncValue.data(data.copyWith(bldb: newBldb));
    });
  }

  /// เลือกเวลาทั้งหมด
  void selectAllBldb() {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(
        bldb: ['เช้า', 'กลางวัน', 'เย็น', 'ก่อนนอน'],
      ));
    });
  }

  /// ล้างเวลาทั้งหมด
  void clearAllBldb() {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(bldb: []));
    });
  }

  /// Toggle ก่อน/หลังอาหาร
  /// [value] = 'ก่อนอาหาร' หรือ 'หลังอาหาร'
  void toggleBeforeAfter(String value) {
    state.whenData((data) {
      final newBeforeAfter = List<String>.from(data.beforeAfter);
      if (newBeforeAfter.contains(value)) {
        newBeforeAfter.remove(value);
      } else {
        // ไม่สามารถเลือกทั้งสองได้ - ล้างก่อนแล้วเพิ่มใหม่
        newBeforeAfter.clear();
        newBeforeAfter.add(value);
      }
      state = AsyncValue.data(data.copyWith(beforeAfter: newBeforeAfter));
    });
  }

  /// ล้าง ก่อน/หลังอาหาร
  void clearBeforeAfter() {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(beforeAfter: []));
    });
  }

  // ==========================================
  // Frequency & PRN
  // ==========================================

  /// ตั้งค่า PRN (ให้เมื่อจำเป็น)
  void setPrn(bool value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(prn: value));
    });
  }

  /// ตั้งค่าความถี่ (ทุก N วัน/สัปดาห์/เดือน)
  void setEveryHr(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(everyHr: value));
    });
  }

  /// ตั้งค่าหน่วยความถี่ ('วัน', 'สัปดาห์', 'เดือน')
  void setTypeOfTime(String value) {
    state.whenData((data) {
      // ถ้าเปลี่ยนเป็นอย่างอื่นที่ไม่ใช่ 'สัปดาห์' ให้ล้าง selectedDays
      state = AsyncValue.data(data.copyWith(
        typeOfTime: value,
        selectedDays: value == 'สัปดาห์' ? data.selectedDays : [],
      ));
    });
  }

  /// Toggle วันที่เลือก (สำหรับรายสัปดาห์)
  /// [day] = 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'
  void toggleDay(String day) {
    state.whenData((data) {
      final newDays = List<String>.from(data.selectedDays);
      if (newDays.contains(day)) {
        newDays.remove(day);
      } else {
        newDays.add(day);
      }
      state = AsyncValue.data(data.copyWith(selectedDays: newDays));
    });
  }

  /// ล้างวันที่เลือกทั้งหมด
  void clearDays() {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(selectedDays: []));
    });
  }

  // ==========================================
  // Date & Duration
  // ==========================================

  /// ตั้งค่าวันที่เริ่มใช้ setting ใหม่
  void setOnDate(DateTime date) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(onDate: date));
    });
  }

  /// ตั้งค่าให้ยาต่อเนื่อง (ไม่มี off date)
  void setIsContinuous(bool value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(
        isContinuous: value,
        clearOffDate: value, // ถ้าเลือกต่อเนื่อง ให้ล้าง offDate
      ));
    });
  }

  /// ตั้งค่าวันที่หยุดให้ยา
  void setOffDate(DateTime? date) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(offDate: date));
    });
  }

  // ==========================================
  // Stock & Notes
  // ==========================================

  /// ตั้งค่าจำนวนยาคงเหลือ (Reconcile)
  void setReconcile(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(reconcile: value));
    });
  }

  /// ตั้งค่าหมายเหตุการแก้ไข (required)
  void setNote(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(note: value));
    });
  }

  // ==========================================
  // Submit
  // ==========================================

  /// บันทึกการแก้ไขยา
  ///
  /// Logic:
  /// 1. Validate form
  /// 2. Update medicine_list
  /// 3. Insert med_history record ใหม่พร้อม new_setting string
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
      // Parse values
      final takeTab = double.tryParse(currentState.takeTab) ?? 1.0;
      final everyHr = currentState.everyHr.isNotEmpty
          ? int.tryParse(currentState.everyHr)
          : null;
      final reconcile = currentState.reconcile.isNotEmpty
          ? double.tryParse(currentState.reconcile)
          : null;
      // ใช้ effectiveUserId เพื่อรองรับ impersonation
      final userId = UserService().effectiveUserId;

      if (userId == null) {
        state = AsyncValue.data(currentState.copyWith(
          isLoading: false,
          errorMessage: 'ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบใหม่',
        ));
        return false;
      }

      // สร้าง new_setting string สำหรับ med_history
      final newSettingString = currentState.newSettingString;

      debugPrint('[EditMedicineForm] Submitting update for medicineListId: $medicineListId');
      debugPrint('[EditMedicineForm] newSettingString: $newSettingString');

      // Update medicine_list + insert med_history
      final success = await _service.updateMedicineListItem(
        medicineListId: medicineListId,
        takeTab: takeTab,
        bldb: currentState.bldb,
        beforeAfter: currentState.beforeAfter,
        everyHr: everyHr,
        typeOfTime: everyHr != null ? currentState.typeOfTime : null,
        daysOfWeek: currentState.selectedDays.isNotEmpty ? currentState.selectedDays : null,
        prn: currentState.prn,
        onDate: currentState.onDate,
        offDate: currentState.isContinuous ? null : currentState.offDate,
        note: currentState.note,
        userId: userId,
        reconcile: reconcile,
        newSetting: newSettingString,
      );

      if (success) {
        debugPrint('[EditMedicineForm] Update successful');
        state = AsyncValue.data(currentState.copyWith(isLoading: false));
        return true;
      } else {
        debugPrint('[EditMedicineForm] Update failed');
        state = AsyncValue.data(currentState.copyWith(
          isLoading: false,
          errorMessage: 'ไม่สามารถบันทึกการแก้ไขได้ กรุณาลองใหม่',
        ));
        return false;
      }
    } catch (e) {
      debugPrint('[EditMedicineForm] Error: $e');
      state = AsyncValue.data(currentState.copyWith(
        isLoading: false,
        errorMessage: 'เกิดข้อผิดพลาด: $e',
      ));
      return false;
    }
  }

  // ==========================================
  // Utilities
  // ==========================================

  /// ล้าง error message
  void clearError() {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(clearErrorMessage: true));
    });
  }
}
