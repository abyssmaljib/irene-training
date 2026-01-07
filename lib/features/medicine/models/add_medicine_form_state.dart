import 'med_db.dart';

/// State สำหรับ form เพิ่มยาให้ resident
///
/// เก็บข้อมูลทั้งหมดที่จำเป็นสำหรับการเพิ่มยาใหม่ให้ผู้พักอาศัย
/// รวมถึง selected medicine, dosage, timing, และ stock information
class AddMedicineFormState {
  // ยาที่เลือก
  final MedDB? selectedMedicine;
  final int? selectedMedDbId;

  // ปริมาณและเวลา
  final String takeTab;           // ปริมาณที่ให้ (เป็น string เพื่อรองรับ 0.5, 1, 2)
  final List<String> bldb;        // เวลาที่ให้: ['เช้า', 'กลางวัน', 'เย็น', 'ก่อนนอน']
  final List<String> beforeAfter; // ก่อน/หลังอาหาร: ['ก่อนอาหาร'] หรือ ['หลังอาหาร']

  // ความถี่
  final bool prn;                 // ให้เมื่อจำเป็น
  final String everyHr;           // ทุก N (วัน/สัปดาห์/เดือน)
  final String typeOfTime;        // หน่วยความถี่: 'วัน', 'สัปดาห์', 'เดือน'
  final List<String> selectedDays; // วันที่เลือก (สำหรับรายสัปดาห์): ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา']

  // วันที่
  final DateTime onDate;          // วันที่เริ่มให้ยา
  final bool isContinuous;        // ให้ยาต่อเนื่อง (ไม่มี off date)
  final DateTime? offDate;        // วันที่หยุดให้ยา (ถ้าไม่ continuous)

  // Stock tracking
  final String reconcile;         // จำนวนยาคงเหลือ

  // หมายเหตุ
  final String note;

  // UI State
  final bool isLoading;
  final String? errorMessage;

  // Search state
  final String searchQuery;
  final List<MedDB> searchResults;
  final bool isSearching;

  // ใช้ factory constructor เพื่อให้ onDate default เป็น DateTime.now()
  // (ไม่สามารถใช้ const constructor ได้เพราะ DateTime.now() ไม่ใช่ const)
  AddMedicineFormState({
    this.selectedMedicine,
    this.selectedMedDbId,
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
    this.searchQuery = '',
    this.searchResults = const [],
    this.isSearching = false,
  }) : onDate = onDate ?? DateTime.now();

  // ==========================================
  // Validation Helpers
  // ==========================================

  /// ตรวจสอบว่า form valid หรือไม่
  bool get isValid {
    // ต้องเลือกยา
    if (selectedMedDbId == null) return false;
    // ต้องระบุปริมาณ
    if (takeTab.isEmpty) return false;
    final dosage = double.tryParse(takeTab);
    if (dosage == null || dosage <= 0) return false;
    // ต้องเลือกเวลาอย่างน้อย 1 เวลา (ยกเว้น PRN)
    if (!prn && bldb.isEmpty) return false;
    return true;
  }

  /// Error message สำหรับ validation
  String? get validationError {
    if (selectedMedDbId == null) return 'กรุณาเลือกยา';
    if (takeTab.isEmpty) return 'กรุณาระบุปริมาณยา';
    final dosage = double.tryParse(takeTab);
    if (dosage == null || dosage <= 0) return 'ปริมาณยาต้องเป็นตัวเลขที่มากกว่า 0';
    if (!prn && bldb.isEmpty) return 'กรุณาเลือกเวลาที่ให้ยาอย่างน้อย 1 เวลา';
    return null;
  }

  // ==========================================
  // copyWith
  // ==========================================

  AddMedicineFormState copyWith({
    MedDB? selectedMedicine,
    int? selectedMedDbId,
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
    String? searchQuery,
    List<MedDB>? searchResults,
    bool? isSearching,
    // Special: allow clearing selected medicine
    bool clearSelectedMedicine = false,
    bool clearErrorMessage = false,
    bool clearOffDate = false,
  }) {
    return AddMedicineFormState(
      selectedMedicine: clearSelectedMedicine ? null : (selectedMedicine ?? this.selectedMedicine),
      selectedMedDbId: clearSelectedMedicine ? null : (selectedMedDbId ?? this.selectedMedDbId),
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
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  @override
  String toString() =>
      'AddMedicineFormState(selectedMedDbId: $selectedMedDbId, takeTab: $takeTab, bldb: $bldb)';
}

/// State สำหรับ form เพิ่มยาใหม่ลงฐานข้อมูล
///
/// เก็บข้อมูลสำหรับสร้าง med_DB record ใหม่
class CreateMedicineDBFormState {
  // ข้อมูลยา
  final String genericName;     // ชื่อสามัญ (required)
  final String brandName;       // ชื่อการค้า
  final String strength;        // ขนาด เช่น "500mg"
  final String route;           // วิธีการให้ เช่น "รับประทาน"
  final String unit;            // หน่วย เช่น "เม็ด"
  final String group;           // กลุ่มยา (free text)
  final String info;            // รายละเอียดเพิ่มเติม

  // ATC Classification (ใช้ String เพราะ table ใช้ code เป็น primary key)
  final String? atcLevel1Code;
  final String? atcLevel2Code;
  final String atcLevel3;

  // รูปภาพ (URLs หลัง upload)
  final String? frontFoiledUrl;
  final String? backFoiledUrl;
  final String? frontNudeUrl;
  final String? backNudeUrl;

  // Upload state (local files before upload)
  final bool isUploadingFrontFoiled;
  final bool isUploadingBackFoiled;
  final bool isUploadingFrontNude;
  final bool isUploadingBackNude;

  // UI State
  final bool isLoading;
  final String? errorMessage;

  const CreateMedicineDBFormState({
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
    this.isUploadingFrontFoiled = false,
    this.isUploadingBackFoiled = false,
    this.isUploadingFrontNude = false,
    this.isUploadingBackNude = false,
    this.isLoading = false,
    this.errorMessage,
  });

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

  /// จำนวนรูปที่ upload แล้ว
  int get uploadedImageCount {
    int count = 0;
    if (frontFoiledUrl != null && frontFoiledUrl!.isNotEmpty) count++;
    if (backFoiledUrl != null && backFoiledUrl!.isNotEmpty) count++;
    if (frontNudeUrl != null && frontNudeUrl!.isNotEmpty) count++;
    if (backNudeUrl != null && backNudeUrl!.isNotEmpty) count++;
    return count;
  }

  // ==========================================
  // copyWith
  // ==========================================

  CreateMedicineDBFormState copyWith({
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
    bool? isUploadingFrontFoiled,
    bool? isUploadingBackFoiled,
    bool? isUploadingFrontNude,
    bool? isUploadingBackNude,
    bool? isLoading,
    String? errorMessage,
    // Special: allow clearing
    bool clearAtcLevel1 = false,
    bool clearAtcLevel2 = false,
    bool clearErrorMessage = false,
  }) {
    return CreateMedicineDBFormState(
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
      frontFoiledUrl: frontFoiledUrl ?? this.frontFoiledUrl,
      backFoiledUrl: backFoiledUrl ?? this.backFoiledUrl,
      frontNudeUrl: frontNudeUrl ?? this.frontNudeUrl,
      backNudeUrl: backNudeUrl ?? this.backNudeUrl,
      isUploadingFrontFoiled: isUploadingFrontFoiled ?? this.isUploadingFrontFoiled,
      isUploadingBackFoiled: isUploadingBackFoiled ?? this.isUploadingBackFoiled,
      isUploadingFrontNude: isUploadingFrontNude ?? this.isUploadingFrontNude,
      isUploadingBackNude: isUploadingBackNude ?? this.isUploadingBackNude,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  String toString() =>
      'CreateMedicineDBFormState(genericName: $genericName, brandName: $brandName)';
}
