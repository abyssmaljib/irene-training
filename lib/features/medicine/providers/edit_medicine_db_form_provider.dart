import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/edit_medicine_db_form_state.dart';
import '../models/med_db.dart';
import '../services/medicine_service.dart';

/// Provider สำหรับ form แก้ไขยาในฐานข้อมูล (med_DB)
/// ใช้ family เพื่อ scope ตาม medDbId และ autoDispose เพราะไม่ต้องเก็บ state หลังปิด screen
final editMedicineDBFormProvider = StateNotifierProvider.family.autoDispose<
    EditMedicineDBFormNotifier,
    AsyncValue<EditMedicineDBFormState>,
    int>((ref, medDbId) {
  return EditMedicineDBFormNotifier(ref, medDbId);
});

/// Notifier สำหรับจัดการ state ของ form แก้ไขยาในฐานข้อมูล
///
/// Features:
/// - Pre-populate ค่าจาก MedDB ที่มีอยู่
/// - Submit จะ update แทนที่จะ insert
/// - มีปุ่ม "สร้างซ้ำ" (duplicate) สำหรับ copy ยา
class EditMedicineDBFormNotifier
    extends StateNotifier<AsyncValue<EditMedicineDBFormState>> {
  EditMedicineDBFormNotifier(Ref ref, this.medDbId)
      : super(const AsyncValue.loading()) {
    _initialize();
  }

  final int medDbId;
  final _service = MedicineService.instance;
  int? _nursinghomeId;

  /// Initialize form โดย fetch ข้อมูลยาจาก medDbId
  Future<void> _initialize() async {
    try {
      debugPrint('[EditMedicineDBForm] Initializing for medDbId: $medDbId');

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

      // Fetch ข้อมูลยาจาก medDbId
      final medicine = await _service.getMedicineById(medDbId);

      if (medicine == null) {
        state = AsyncValue.error(
          'ไม่พบข้อมูลยา ID: $medDbId',
          StackTrace.current,
        );
        return;
      }

      // สร้าง state จาก MedDB
      state = AsyncValue.data(EditMedicineDBFormState.fromMedDB(medicine));

      debugPrint('[EditMedicineDBForm] Loaded successfully: ${medicine.displayName}');
    } catch (e, st) {
      debugPrint('[EditMedicineDBForm] Error loading: $e');
      state = AsyncValue.error(e, st);
    }
  }

  // ==========================================
  // Field Setters (เหมือน CreateMedicineDBFormNotifier)
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

  /// ตั้งค่า ATC Level 1 (code)
  void setAtcLevel1(String? code) {
    state.whenData((data) {
      state = AsyncValue.data(data.copyWith(
        atcLevel1Code: code,
        // ล้าง Level 2 เมื่อเปลี่ยน Level 1
        clearAtcLevel2: true,
      ));
    });
  }

  /// ตั้งค่า ATC Level 2 (code)
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

  /// ลบรูป (clear URL)
  void clearImage(String imageType) {
    state.whenData((data) {
      switch (imageType) {
        case 'frontFoiled':
          state = AsyncValue.data(data.copyWith(clearFrontFoiledUrl: true));
          break;
        case 'backFoiled':
          state = AsyncValue.data(data.copyWith(clearBackFoiledUrl: true));
          break;
        case 'frontNude':
          state = AsyncValue.data(data.copyWith(clearFrontNudeUrl: true));
          break;
        case 'backNude':
          state = AsyncValue.data(data.copyWith(clearBackNudeUrl: true));
          break;
      }
    });
  }

  // ==========================================
  // Submit (Update)
  // ==========================================

  /// บันทึกการแก้ไขยาลงฐานข้อมูล
  /// Returns MedDB ที่ update แล้ว หรือ null ถ้าล้มเหลว
  Future<MedDB?> submit() async {
    final currentState = state.value;
    if (currentState == null) return null;

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
      debugPrint('[EditMedicineDBForm] Submitting update for medDbId: $medDbId');

      final result = await _service.updateMedicine(
        medDbId: medDbId,
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
        // ใช้ effective URLs (รูปใหม่ หรือ รูปเดิม)
        frontFoiledUrl: currentState.effectiveFrontFoiledUrl,
        backFoiledUrl: currentState.effectiveBackFoiledUrl,
        frontNudeUrl: currentState.effectiveFrontNudeUrl,
        backNudeUrl: currentState.effectiveBackNudeUrl,
        atcLevel1Code: currentState.atcLevel1Code,
        atcLevel2Code: currentState.atcLevel2Code,
        atcLevel3: currentState.atcLevel3.trim().isNotEmpty
            ? currentState.atcLevel3.trim()
            : null,
      );

      if (result != null) {
        debugPrint('[EditMedicineDBForm] Update successful');
        state = AsyncValue.data(currentState.copyWith(isLoading: false));
        return result;
      } else {
        debugPrint('[EditMedicineDBForm] Update failed');
        state = AsyncValue.data(currentState.copyWith(
          isLoading: false,
          errorMessage: 'ไม่สามารถบันทึกยาได้ กรุณาลองใหม่',
        ));
        return null;
      }
    } catch (e) {
      debugPrint('[EditMedicineDBForm] Error: $e');
      state = AsyncValue.data(currentState.copyWith(
        isLoading: false,
        errorMessage: 'เกิดข้อผิดพลาด: $e',
      ));
      return null;
    }
  }

  // ==========================================
  // Duplicate (สร้างซ้ำ)
  // ==========================================

  /// สร้างซ้ำยา (duplicate) จากยาปัจจุบัน
  /// Returns MedDB ใหม่ที่สร้างซ้ำ หรือ null ถ้าล้มเหลว
  Future<MedDB?> duplicate() async {
    final currentState = state.value;
    if (currentState == null || _nursinghomeId == null) return null;

    // Set duplicating state
    state = AsyncValue.data(currentState.copyWith(
      isDuplicating: true,
      clearErrorMessage: true,
    ));

    try {
      debugPrint('[EditMedicineDBForm] Duplicating medDbId: $medDbId');

      final result = await _service.duplicateMedicine(
        sourceMedDbId: medDbId,
        nursinghomeId: _nursinghomeId!,
      );

      if (result != null) {
        debugPrint('[EditMedicineDBForm] Duplicate successful: ${result.displayName}');
        state = AsyncValue.data(currentState.copyWith(isDuplicating: false));
        return result;
      } else {
        debugPrint('[EditMedicineDBForm] Duplicate failed');
        state = AsyncValue.data(currentState.copyWith(
          isDuplicating: false,
          errorMessage: 'ไม่สามารถสร้างซ้ำได้ กรุณาลองใหม่',
        ));
        return null;
      }
    } catch (e) {
      debugPrint('[EditMedicineDBForm] Error duplicating: $e');
      state = AsyncValue.data(currentState.copyWith(
        isDuplicating: false,
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

  /// Reload ข้อมูลจากฐานข้อมูล
  Future<void> reload() async {
    state = const AsyncValue.loading();
    await _initialize();
  }
}
