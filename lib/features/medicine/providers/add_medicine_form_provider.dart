import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/user_service.dart';
import '../models/add_medicine_form_state.dart';
import '../models/med_db.dart';
import '../services/medicine_service.dart';

/// Provider สำหรับ MedicineService
final medicineServiceProvider = Provider<MedicineService>((ref) {
  return MedicineService.instance;
});

/// Provider สำหรับ form เพิ่มยาให้ resident
/// ใช้ family เพื่อ scope ตาม residentId
final addMedicineFormProvider = StateNotifierProvider.family<
    AddMedicineFormNotifier,
    AsyncValue<AddMedicineFormState>,
    int>((ref, residentId) {
  return AddMedicineFormNotifier(ref, residentId);
});

/// Notifier สำหรับจัดการ state ของ form เพิ่มยาให้ resident
class AddMedicineFormNotifier
    extends StateNotifier<AsyncValue<AddMedicineFormState>> {
  AddMedicineFormNotifier(Ref ref, this.residentId)
      : super(const AsyncValue.loading()) {
    _initialize();
  }

  final int residentId;
  final _service = MedicineService.instance;

  // Nursing home ID (ดึงจาก user profile)
  int? _nursinghomeId;

  // Flag บอกว่า initialize เสร็จหรือยัง
  bool _isInitialized = false;

  /// เก็บ med_history ID ล่าสุดที่สร้างจาก addMedicineToResident
  /// ใช้สำหรับ link กับ post ภายหลัง (UPDATE post_id ใน med_history)
  int? _lastMedHistoryId;
  int? get lastMedHistoryId => _lastMedHistoryId;

  /// Initialize form ด้วย default values
  Future<void> _initialize() async {
    try {
      // ดึง nursinghomeId จาก UserService (รองรับ impersonation)
      _nursinghomeId = await UserService().getNursinghomeId();
      debugPrint('[AddMedicineForm] nursinghomeId: $_nursinghomeId');

      // Pre-load medicines cache (ถ้ามี nursinghomeId)
      if (_nursinghomeId != null) {
        final medicines = await _service.getAllMedicinesFromDB(_nursinghomeId!);
        debugPrint('[AddMedicineForm] Pre-loaded ${medicines.length} medicines from med_DB');
      }

      // Mark as initialized
      _isInitialized = true;

      // Set initial state
      state = AsyncValue.data(AddMedicineFormState(
        onDate: DateTime.now(),
      ));
    } catch (e, st) {
      debugPrint('[AddMedicineForm] Error initializing: $e');
      _isInitialized = true; // ถึงจะ error ก็ถือว่า initialize เสร็จ
      state = AsyncValue.error(e, st);
    }
  }

  // ==========================================
  // Medicine Selection
  // ==========================================

  /// ค้นหายาจากฐานข้อมูล
  Future<void> searchMedicines(String query) async {
    debugPrint('[AddMedicineForm] searchMedicines called with query: "$query"');

    // รอให้ initialize เสร็จก่อน (สูงสุด 5 วินาที)
    int waitCount = 0;
    while (!_isInitialized && waitCount < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }
    debugPrint('[AddMedicineForm] After wait: _isInitialized=$_isInitialized, _nursinghomeId=$_nursinghomeId');

    final currentState = state.value;
    // ถ้ายังไม่มี nursinghomeId ให้แสดง error แทนที่จะ return เฉยๆ
    if (currentState == null) {
      debugPrint('[AddMedicineForm] currentState is null, returning');
      return;
    }
    if (_nursinghomeId == null) {
      debugPrint('[AddMedicineForm] nursinghomeId is null, showing error');
      state = AsyncValue.data(currentState.copyWith(
        isSearching: false,
        errorMessage: 'ไม่สามารถค้นหายาได้: ไม่พบข้อมูล nursing home',
      ));
      return;
    }

    state = AsyncValue.data(currentState.copyWith(
      searchQuery: query,
      isSearching: true,
    ));

    try {
      debugPrint('[AddMedicineForm] Calling searchMedicinesFromDB...');
      final results = await _service.searchMedicinesFromDB(
        query,
        _nursinghomeId!,
        limit: 10,
      );
      debugPrint('[AddMedicineForm] Search returned ${results.length} results');

      // อัพเดต state ถ้า query ยังตรงกัน (กรณี user พิมพ์เร็ว)
      if (state.value?.searchQuery == query) {
        state = AsyncValue.data(currentState.copyWith(
          searchQuery: query,
          searchResults: results,
          isSearching: false,
        ));
      }
    } catch (e) {
      debugPrint('[AddMedicineForm] Search error: $e');
      state = AsyncValue.data(currentState.copyWith(
        isSearching: false,
        errorMessage: 'ไม่สามารถค้นหายาได้: $e',
      ));
    }
  }

  /// เลือกยาจากรายการ
  void selectMedicine(MedDB medicine) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(
        selectedMedicine: medicine,
        selectedMedDbId: medicine.id,
        searchQuery: '',
        searchResults: [],
        clearErrorMessage: true,
      ));
    });
  }

  /// ล้างยาที่เลือก
  void clearSelectedMedicine() {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(
        clearSelectedMedicine: true,
        searchQuery: '',
        searchResults: [],
      ));
    });
  }

  // ==========================================
  // Dosage & Timing
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
        // ถ้าเลือก ก่อนอาหาร จะลบ หลังอาหาร ออก และในทางกลับกัน
        // (ไม่สามารถเลือกทั้งสองได้)
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
      // ถ้าเปลี่ยนเป็น 'สัปดาห์' ให้เก็บ selectedDays ไว้
      // ถ้าเปลี่ยนเป็นอย่างอื่นให้ล้าง selectedDays
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

  /// ตั้งค่าวันที่เริ่มให้ยา
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

  /// ตั้งค่าหมายเหตุ
  void setNote(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(note: value));
    });
  }

  // ==========================================
  // Submit
  // ==========================================

  /// บันทึกยาให้ resident
  Future<bool> submit() async {
    final currentState = state.value;
    if (currentState == null) return false;

    // Validate — ใช้ validationErrorWithField เพื่อได้ทั้ง message และ field name
    // field name ใช้ให้ UI highlight ช่อง input ที่ต้องแก้ไข
    final validation = currentState.validationErrorWithField;
    if (validation != null) {
      state = AsyncValue.data(currentState.copyWith(
        errorMessage: validation.message,
        errorField: validation.field,
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

      // สร้าง new_setting string — บันทึก setting เริ่มต้นตอนเพิ่มยา
      // ให้ดูย้อนหลังได้ว่าตอนเริ่มยา ตั้ง dose ไว้ยังไง
      // ลำดับ: dose → ก่อน/หลังอาหาร → เวลาให้ยา (เรียงตามเวลา) → ความถี่ → PRN
      final settingParts = <String>[];
      final unitStr = currentState.selectedMedicine?.unit ?? 'เม็ด';
      settingParts.add('${currentState.takeTab} $unitStr');
      // ก่อน/หลังอาหาร — ใส่ก่อนเวลาให้ยาเพื่อให้อ่านเป็นธรรมชาติ
      if (currentState.beforeAfter.isNotEmpty) {
        settingParts.add(currentState.beforeAfter.join(','));
      }
      // เวลาให้ยา — เรียงตามลำดับเวลา: เช้า → กลางวัน → เย็น → ก่อนนอน
      if (currentState.bldb.isNotEmpty) {
        const bldbOrder = ['เช้า', 'กลางวัน', 'เย็น', 'ก่อนนอน'];
        final sortedBldb = List<String>.from(currentState.bldb)
          ..sort((a, b) => bldbOrder.indexOf(a).compareTo(bldbOrder.indexOf(b)));
        settingParts.add(sortedBldb.join(','));
      }
      final freq = int.tryParse(currentState.everyHr) ?? 1;
      if (freq != 1 || currentState.typeOfTime != 'วัน') {
        settingParts.add('ทุก ${currentState.everyHr} ${currentState.typeOfTime}');
      }
      if (currentState.prn) {
        settingParts.add('PRN');
      }
      final newSetting = settingParts.join(' | ');

      // Insert medicine
      final result = await _service.addMedicineToResident(
        medDbId: currentState.selectedMedDbId!,
        residentId: residentId,
        takeTab: takeTab,
        bldb: currentState.bldb,
        beforeAfter: currentState.beforeAfter,
        everyHr: everyHr,
        typeOfTime: everyHr != null ? currentState.typeOfTime : null,
        prn: currentState.prn,
        onDate: currentState.onDate,
        offDate: currentState.isContinuous ? null : currentState.offDate,
        note: currentState.note.isNotEmpty ? currentState.note : null,
        userId: userId,
        reconcile: reconcile,
        newSetting: newSetting,
      );

      // เก็บ medHistoryId ไว้ให้ caller ดึงไปใช้ link กับ post
      // result อาจเป็น null ได้ (type signature) แต่ปกติจะ throw แทน
      _lastMedHistoryId = result?.medHistoryId;
      state = AsyncValue.data(currentState.copyWith(isLoading: false));
      return true;
    } catch (e) {
      // แสดง error message ที่ชัดเจน (service จะ throw พร้อมรายละเอียดแล้ว)
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      state = AsyncValue.data(currentState.copyWith(
        isLoading: false,
        errorMessage: errorMsg,
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

  /// รีเซ็ต form เป็นค่าเริ่มต้น
  void reset() {
    state = AsyncValue.data(AddMedicineFormState(
      onDate: DateTime.now(),
    ));
  }

  /// Refresh ข้อมูลยาที่เลือกอยู่ (หลังจากแก้ไขยาใน med_DB)
  /// เรียกใช้เมื่อ user แก้ไขยาใน EditMedicineDBScreen แล้วกลับมา
  Future<void> refreshSelectedMedicine() async {
    final currentState = state.value;
    if (currentState == null || currentState.selectedMedDbId == null) return;

    try {
      // Fetch ข้อมูลยาล่าสุดจาก database
      final refreshedMedicine = await _service.getMedicineById(
        currentState.selectedMedDbId!,
      );

      if (refreshedMedicine != null) {
        state = AsyncValue.data(currentState.copyWith(
          selectedMedicine: refreshedMedicine,
        ));
        debugPrint('[AddMedicineForm] Refreshed medicine: ${refreshedMedicine.displayName}');
      }
    } catch (e) {
      debugPrint('[AddMedicineForm] Error refreshing medicine: $e');
      // ไม่ต้องแสดง error - เก็บยาเดิมไว้
    }
  }

  /// ได้รับ nursinghomeId
  int? get nursinghomeId => _nursinghomeId;
}
