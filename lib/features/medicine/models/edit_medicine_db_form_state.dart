import 'med_db.dart';

/// State สำหรับ form แก้ไขยาในฐานข้อมูล (med_DB)
///
/// คล้าย CreateMedicineDBFormState แต่:
/// - Pre-populate ค่าจาก MedDB ที่มีอยู่
/// - เก็บ original URLs เพื่อใช้รูปเดิมถ้าไม่ได้ upload ใหม่
/// - มี isDuplicating state สำหรับปุ่ม "สร้างซ้ำ"
class EditMedicineDBFormState {
  // ==========================================
  // ID ของยาที่แก้ไข
  // ==========================================

  /// ID ของ med_DB ที่กำลังแก้ไข
  final int medDbId;

  // ==========================================
  // ข้อมูลยา (เหมือน CreateMedicineDBFormState)
  // ==========================================

  /// ชื่อสามัญ
  final String genericName;

  /// ชื่อการค้า
  final String brandName;

  /// ขนาด/ความแรง เช่น "500mg"
  final String strength;

  /// วิธีการให้ เช่น "รับประทาน"
  final String route;

  /// หน่วย เช่น "เม็ด"
  final String unit;

  /// กลุ่มยา (free text)
  final String group;

  /// รายละเอียดเพิ่มเติม
  final String info;

  // ==========================================
  // ATC Classification
  // ==========================================

  /// ATC Level 1 Code (e.g. "A", "B", "C")
  final String? atcLevel1Code;

  /// ATC Level 2 Code (e.g. "A01", "A02")
  final String? atcLevel2Code;

  /// ATC Level 3 (free text)
  final String atcLevel3;

  // ==========================================
  // รูปภาพ - Current URLs
  // ==========================================

  /// URL รูป Front-Foiled (หลัง upload ใหม่ หรือ original)
  final String? frontFoiledUrl;

  /// URL รูป Back-Foiled
  final String? backFoiledUrl;

  /// URL รูป Front-Nude
  final String? frontNudeUrl;

  /// URL รูป Back-Nude
  final String? backNudeUrl;

  // ==========================================
  // รูปภาพ - Original URLs (สำหรับ fallback)
  // ==========================================

  /// URL รูปเดิม Front-Foiled (เก็บไว้กรณีไม่ได้ upload ใหม่)
  final String? originalFrontFoiledUrl;

  /// URL รูปเดิม Back-Foiled
  final String? originalBackFoiledUrl;

  /// URL รูปเดิม Front-Nude
  final String? originalFrontNudeUrl;

  /// URL รูปเดิม Back-Nude
  final String? originalBackNudeUrl;

  // ==========================================
  // Upload State
  // ==========================================

  /// กำลัง upload รูป Front-Foiled
  final bool isUploadingFrontFoiled;

  /// กำลัง upload รูป Back-Foiled
  final bool isUploadingBackFoiled;

  /// กำลัง upload รูป Front-Nude
  final bool isUploadingFrontNude;

  /// กำลัง upload รูป Back-Nude
  final bool isUploadingBackNude;

  // ==========================================
  // UI State
  // ==========================================

  /// กำลังโหลดข้อมูล
  final bool isLoading;

  /// กำลังสร้างซ้ำ (Duplicate)
  final bool isDuplicating;

  /// Error message
  final String? errorMessage;

  // ==========================================
  // Constructor
  // ==========================================

  const EditMedicineDBFormState({
    required this.medDbId,
    this.genericName = '',
    this.brandName = '',
    this.strength = '',
    this.route = 'รับประทาน',
    this.unit = 'เม็ด',
    this.group = '',
    this.info = '',
    this.atcLevel1Code,
    this.atcLevel2Code,
    this.atcLevel3 = '',
    this.frontFoiledUrl,
    this.backFoiledUrl,
    this.frontNudeUrl,
    this.backNudeUrl,
    this.originalFrontFoiledUrl,
    this.originalBackFoiledUrl,
    this.originalFrontNudeUrl,
    this.originalBackNudeUrl,
    this.isUploadingFrontFoiled = false,
    this.isUploadingBackFoiled = false,
    this.isUploadingFrontNude = false,
    this.isUploadingBackNude = false,
    this.isLoading = false,
    this.isDuplicating = false,
    this.errorMessage,
  });

  // ==========================================
  // Factory: สร้างจาก MedDB
  // ==========================================

  /// สร้าง EditMedicineDBFormState จาก MedDB
  /// Pre-populate ค่าทั้งหมดจากยาที่ต้องการแก้ไข
  factory EditMedicineDBFormState.fromMedDB(MedDB medicine) {
    return EditMedicineDBFormState(
      medDbId: medicine.id,
      genericName: medicine.genericName ?? '',
      brandName: medicine.brandName ?? '',
      strength: medicine.str ?? '',
      route: medicine.route ?? 'รับประทาน',
      unit: medicine.unit ?? 'เม็ด',
      group: medicine.group ?? '',
      info: medicine.info ?? '',
      atcLevel1Code: medicine.atcLevel1Id,
      atcLevel2Code: medicine.atcLevel2Id,
      atcLevel3: medicine.atcLevel3 ?? '',
      // Current URLs = Original URLs ตอน init
      frontFoiledUrl: medicine.frontFoiled,
      backFoiledUrl: medicine.backFoiled,
      frontNudeUrl: medicine.frontNude,
      backNudeUrl: medicine.backNude,
      // เก็บ original ไว้ reference
      originalFrontFoiledUrl: medicine.frontFoiled,
      originalBackFoiledUrl: medicine.backFoiled,
      originalFrontNudeUrl: medicine.frontNude,
      originalBackNudeUrl: medicine.backNude,
    );
  }

  // ==========================================
  // Validation Helpers
  // ==========================================

  /// ตรวจสอบว่า form valid หรือไม่
  bool get isValid {
    // ต้องมี generic name หรือ brand name อย่างน้อยอย่างหนึ่ง
    if (genericName.trim().isEmpty && brandName.trim().isEmpty) return false;
    return true;
  }

  /// Error message สำหรับ validation
  String? get validationError {
    if (genericName.trim().isEmpty && brandName.trim().isEmpty) {
      return 'กรุณาระบุชื่อยาอย่างน้อยหนึ่งชื่อ (ชื่อสามัญ หรือ ชื่อการค้า)';
    }
    return null;
  }

  /// ตรวจสอบว่ากำลัง upload รูปอยู่หรือไม่
  bool get isUploading =>
      isUploadingFrontFoiled ||
      isUploadingBackFoiled ||
      isUploadingFrontNude ||
      isUploadingBackNude;

  /// จำนวนรูปที่มี (รวมทั้งเดิมและใหม่)
  int get imageCount {
    int count = 0;
    if (effectiveFrontFoiledUrl != null) count++;
    if (effectiveBackFoiledUrl != null) count++;
    if (effectiveFrontNudeUrl != null) count++;
    if (effectiveBackNudeUrl != null) count++;
    return count;
  }

  // ==========================================
  // Effective URLs (ใช้จริงตอน submit)
  // ==========================================

  /// URL รูป Front-Foiled ที่จะใช้ (ใหม่ หรือ เดิม)
  String? get effectiveFrontFoiledUrl => frontFoiledUrl ?? originalFrontFoiledUrl;

  /// URL รูป Back-Foiled ที่จะใช้
  String? get effectiveBackFoiledUrl => backFoiledUrl ?? originalBackFoiledUrl;

  /// URL รูป Front-Nude ที่จะใช้
  String? get effectiveFrontNudeUrl => frontNudeUrl ?? originalFrontNudeUrl;

  /// URL รูป Back-Nude ที่จะใช้
  String? get effectiveBackNudeUrl => backNudeUrl ?? originalBackNudeUrl;

  // ==========================================
  // copyWith
  // ==========================================

  EditMedicineDBFormState copyWith({
    int? medDbId,
    String? genericName,
    String? brandName,
    String? strength,
    String? route,
    String? unit,
    String? group,
    String? info,
    String? atcLevel1Code,
    String? atcLevel2Code,
    String? atcLevel3,
    String? frontFoiledUrl,
    String? backFoiledUrl,
    String? frontNudeUrl,
    String? backNudeUrl,
    String? originalFrontFoiledUrl,
    String? originalBackFoiledUrl,
    String? originalFrontNudeUrl,
    String? originalBackNudeUrl,
    bool? isUploadingFrontFoiled,
    bool? isUploadingBackFoiled,
    bool? isUploadingFrontNude,
    bool? isUploadingBackNude,
    bool? isLoading,
    bool? isDuplicating,
    String? errorMessage,
    // Special: allow clearing
    bool clearAtcLevel1 = false,
    bool clearAtcLevel2 = false,
    bool clearErrorMessage = false,
    bool clearFrontFoiledUrl = false,
    bool clearBackFoiledUrl = false,
    bool clearFrontNudeUrl = false,
    bool clearBackNudeUrl = false,
  }) {
    return EditMedicineDBFormState(
      medDbId: medDbId ?? this.medDbId,
      genericName: genericName ?? this.genericName,
      brandName: brandName ?? this.brandName,
      strength: strength ?? this.strength,
      route: route ?? this.route,
      unit: unit ?? this.unit,
      group: group ?? this.group,
      info: info ?? this.info,
      atcLevel1Code: clearAtcLevel1 ? null : (atcLevel1Code ?? this.atcLevel1Code),
      atcLevel2Code: clearAtcLevel2 ? null : (atcLevel2Code ?? this.atcLevel2Code),
      atcLevel3: atcLevel3 ?? this.atcLevel3,
      frontFoiledUrl: clearFrontFoiledUrl ? null : (frontFoiledUrl ?? this.frontFoiledUrl),
      backFoiledUrl: clearBackFoiledUrl ? null : (backFoiledUrl ?? this.backFoiledUrl),
      frontNudeUrl: clearFrontNudeUrl ? null : (frontNudeUrl ?? this.frontNudeUrl),
      backNudeUrl: clearBackNudeUrl ? null : (backNudeUrl ?? this.backNudeUrl),
      originalFrontFoiledUrl: originalFrontFoiledUrl ?? this.originalFrontFoiledUrl,
      originalBackFoiledUrl: originalBackFoiledUrl ?? this.originalBackFoiledUrl,
      originalFrontNudeUrl: originalFrontNudeUrl ?? this.originalFrontNudeUrl,
      originalBackNudeUrl: originalBackNudeUrl ?? this.originalBackNudeUrl,
      isUploadingFrontFoiled: isUploadingFrontFoiled ?? this.isUploadingFrontFoiled,
      isUploadingBackFoiled: isUploadingBackFoiled ?? this.isUploadingBackFoiled,
      isUploadingFrontNude: isUploadingFrontNude ?? this.isUploadingFrontNude,
      isUploadingBackNude: isUploadingBackNude ?? this.isUploadingBackNude,
      isLoading: isLoading ?? this.isLoading,
      isDuplicating: isDuplicating ?? this.isDuplicating,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  String toString() =>
      'EditMedicineDBFormState(medDbId: $medDbId, genericName: $genericName, brandName: $brandName)';
}
