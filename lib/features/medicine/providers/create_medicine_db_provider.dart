import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/add_medicine_form_state.dart';
import '../models/med_db.dart';
import '../models/med_atc_level.dart';
import '../services/medicine_service.dart';

/// Provider สำหรับ form สร้างยาใหม่ลงฐานข้อมูล
/// ใช้ autoDispose เพราะไม่จำเป็นต้องเก็บ state หลังปิด screen
final createMedicineDBFormProvider = StateNotifierProvider.autoDispose<
    CreateMedicineDBFormNotifier,
    AsyncValue<CreateMedicineDBFormState>>((ref) {
  return CreateMedicineDBFormNotifier(ref);
});

/// Provider สำหรับ ATC Level 1 list
final atcLevel1ListProvider = FutureProvider<List<MedAtcLevel1>>((ref) async {
  return MedicineService.instance.getAtcLevel1List();
});

/// Provider สำหรับ ATC Level 2 list ตาม Level 1 code
final atcLevel2ListProvider =
    FutureProvider.family<List<MedAtcLevel2>, String>((ref, level1Code) async {
  return MedicineService.instance.getAtcLevel2ByLevel1(level1Code);
});

/// Notifier สำหรับจัดการ state ของ form สร้างยาใหม่
class CreateMedicineDBFormNotifier
    extends StateNotifier<AsyncValue<CreateMedicineDBFormState>> {
  CreateMedicineDBFormNotifier(Ref ref)
      : super(const AsyncValue.loading()) {
    _initialize();
  }

  final _service = MedicineService.instance;
  int? _nursinghomeId;

  /// Initialize form
  Future<void> _initialize() async {
    try {
      // ดึง nursinghomeId จาก user profile
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final userInfo = await Supabase.instance.client
            .from('user_info')
            .select('nursinghome_id')
            .eq('id', userId)
            .maybeSingle();
        _nursinghomeId = userInfo?['nursinghome_id'] as int?;
      }

      // Set initial state with defaults
      state = const AsyncValue.data(CreateMedicineDBFormState(
        route: 'รับประทาน',
        unit: 'เม็ด',
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ==========================================
  // Field Setters
  // ==========================================

  /// ตั้งค่าชื่อสามัญ (Generic Name)
  void setGenericName(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(genericName: value));
    });
  }

  /// ตั้งค่าชื่อการค้า (Brand Name)
  void setBrandName(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(brandName: value));
    });
  }

  /// ตั้งค่าขนาด/ความแรง (Strength)
  void setStrength(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(strength: value));
    });
  }

  /// ตั้งค่าวิธีการให้ (Route)
  void setRoute(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(route: value));
    });
  }

  /// ตั้งค่าหน่วย (Unit)
  void setUnit(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(unit: value));
    });
  }

  /// ตั้งค่ากลุ่มยา (Group)
  void setGroup(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(group: value));
    });
  }

  /// ตั้งค่าข้อมูลเพิ่มเติม (Info)
  void setInfo(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(info: value));
    });
  }

  // ==========================================
  // ATC Classification
  // ==========================================

  /// ตั้งค่า ATC Level 1 (ใช้ code แทน id เพราะ table ใช้ code เป็น primary key)
  void setAtcLevel1(String? code) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(
        atcLevel1Code: code,
        // ล้าง Level 2 เมื่อเปลี่ยน Level 1
        clearAtcLevel2: true,
      ));
    });
  }

  /// ตั้งค่า ATC Level 2 (ใช้ code แทน id)
  void setAtcLevel2(String? code) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(atcLevel2Code: code));
    });
  }

  /// ตั้งค่า ATC Level 3 (free text)
  void setAtcLevel3(String value) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(atcLevel3: value));
    });
  }

  // ==========================================
  // Image Upload
  // ==========================================

  /// ตั้งค่า URL รูป Front-Foiled หลัง upload
  void setFrontFoiledUrl(String? url) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(
        frontFoiledUrl: url,
        isUploadingFrontFoiled: false,
      ));
    });
  }

  /// ตั้งค่า URL รูป Back-Foiled หลัง upload
  void setBackFoiledUrl(String? url) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(
        backFoiledUrl: url,
        isUploadingBackFoiled: false,
      ));
    });
  }

  /// ตั้งค่า URL รูป Front-Nude หลัง upload
  void setFrontNudeUrl(String? url) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(
        frontNudeUrl: url,
        isUploadingFrontNude: false,
      ));
    });
  }

  /// ตั้งค่า URL รูป Back-Nude หลัง upload
  void setBackNudeUrl(String? url) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(
        backNudeUrl: url,
        isUploadingBackNude: false,
      ));
    });
  }

  /// ตั้งสถานะกำลัง upload รูป
  void setUploading({
    bool? frontFoiled,
    bool? backFoiled,
    bool? frontNude,
    bool? backNude,
  }) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(
        isUploadingFrontFoiled: frontFoiled ?? data.isUploadingFrontFoiled,
        isUploadingBackFoiled: backFoiled ?? data.isUploadingBackFoiled,
        isUploadingFrontNude: frontNude ?? data.isUploadingFrontNude,
        isUploadingBackNude: backNude ?? data.isUploadingBackNude,
      ));
    });
  }

  // ==========================================
  // Submit
  // ==========================================

  /// บันทึกยาใหม่ลงฐานข้อมูล
  /// Returns MedDB ที่สร้างใหม่ หรือ null ถ้าล้มเหลว
  Future<MedDB?> submit() async {
    final currentState = state.value;
    if (currentState == null || _nursinghomeId == null) return null;

    // Validate
    final validationError = currentState.validationError;
    if (validationError != null) {
      state = AsyncValue.data(currentState.copyWith(
        errorMessage: validationError,
      ));
      return null;
    }

    // ตรวจสอบว่ากำลัง upload รูปอยู่
    if (currentState.isUploading) {
      state = AsyncValue.data(currentState.copyWith(
        errorMessage: 'กรุณารอให้ upload รูปเสร็จก่อน',
      ));
      return null;
    }

    // Set loading
    state = AsyncValue.data(currentState.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    ));

    try {
      final result = await _service.createMedicine(
        nursinghomeId: _nursinghomeId!,
        genericName: currentState.genericName.trim().isNotEmpty
            ? currentState.genericName.trim()
            : null,
        brandName: currentState.brandName.trim().isNotEmpty
            ? currentState.brandName.trim()
            : null,
        strength: currentState.strength.trim().isNotEmpty
            ? currentState.strength.trim()
            : null,
        route: currentState.route.trim().isNotEmpty
            ? currentState.route.trim()
            : null,
        unit: currentState.unit.trim().isNotEmpty
            ? currentState.unit.trim()
            : null,
        group: currentState.group.trim().isNotEmpty
            ? currentState.group.trim()
            : null,
        info: currentState.info.trim().isNotEmpty
            ? currentState.info.trim()
            : null,
        frontFoiledUrl: currentState.frontFoiledUrl,
        backFoiledUrl: currentState.backFoiledUrl,
        frontNudeUrl: currentState.frontNudeUrl,
        backNudeUrl: currentState.backNudeUrl,
        atcLevel1Code: currentState.atcLevel1Code,
        atcLevel2Code: currentState.atcLevel2Code,
        atcLevel3: currentState.atcLevel3.trim().isNotEmpty
            ? currentState.atcLevel3.trim()
            : null,
      );

      if (result != null) {
        state = AsyncValue.data(currentState.copyWith(isLoading: false));
        return result;
      } else {
        state = AsyncValue.data(currentState.copyWith(
          isLoading: false,
          errorMessage: 'ไม่สามารถบันทึกยาได้ กรุณาลองใหม่',
        ));
        return null;
      }
    } catch (e) {
      state = AsyncValue.data(currentState.copyWith(
        isLoading: false,
        errorMessage: 'เกิดข้อผิดพลาด: $e',
      ));
      return null;
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

  /// รีเซ็ต form
  void reset() {
    state = const AsyncValue.data(CreateMedicineDBFormState(
      route: 'รับประทาน',
      unit: 'เม็ด',
    ));
  }

  /// Pre-fill brand name (จากการค้นหาที่ไม่เจอ)
  void prefillBrandName(String name) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(brandName: name));
    });
  }
}
