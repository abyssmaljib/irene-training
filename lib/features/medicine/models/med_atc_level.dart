/// Model สำหรับ ATC Classification Level 1
///
/// ATC (Anatomical Therapeutic Chemical) Classification System
/// เป็นระบบจำแนกประเภทยาตามมาตรฐานสากล WHO
///
/// Level 1 = หมวดหลัก (14 หมวด) เช่น:
/// - A: ระบบทางเดินอาหารและเมตาบอลิซึม
/// - B: เลือดและอวัยวะสร้างเลือด
/// - C: ระบบหัวใจและหลอดเลือด
/// - N: ระบบประสาท
class MedAtcLevel1 {
  final String code;        // รหัส เช่น "A", "B", "C" - เป็น primary key
  final String nameEn;      // ชื่อภาษาอังกฤษ
  final String nameTh;      // ชื่อภาษาไทย

  const MedAtcLevel1({
    required this.code,
    required this.nameEn,
    required this.nameTh,
  });

  /// สร้างจาก JSON (Supabase response)
  /// Note: table ใช้ code เป็น primary key (ไม่มี id)
  factory MedAtcLevel1.fromJson(Map<String, dynamic> json) {
    return MedAtcLevel1(
      code: json['code'] as String,
      nameEn: json['name_en'] as String? ?? '',
      nameTh: json['name_th'] as String? ?? '',
    );
  }

  /// แปลงเป็น JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name_en': nameEn,
      'name_th': nameTh,
    };
  }

  /// ชื่อที่ใช้แสดงใน dropdown: "A - ระบบทางเดินอาหาร"
  String get displayName => '$code - $nameTh';

  /// ชื่อแบบเต็ม (EN/TH)
  String get fullName => '$code - $nameTh ($nameEn)';

  @override
  String toString() => 'MedAtcLevel1(code: $code, nameTh: $nameTh)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedAtcLevel1 && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Model สำหรับ ATC Classification Level 2
///
/// Level 2 = หมวดย่อยของ Level 1 เช่น:
/// - A01: Stomatological preparations (ยาสำหรับช่องปาก)
/// - A02: Drugs for acid related disorders (ยาลดกรด)
/// - C01: Cardiac therapy (ยาหัวใจ)
/// - N02: Analgesics (ยาแก้ปวด)
class MedAtcLevel2 {
  final String code;        // รหัส เช่น "A01", "A02", "C01" - เป็น primary key
  final String level1Code;  // รหัส Level 1 ที่เป็น parent (เช่น "A")
  final String nameEn;      // ชื่อภาษาอังกฤษ
  final String nameTh;      // ชื่อภาษาไทย

  const MedAtcLevel2({
    required this.code,
    required this.level1Code,
    required this.nameEn,
    required this.nameTh,
  });

  /// สร้างจาก JSON (Supabase response)
  /// Note: table ใช้ code เป็น primary key และ level1_code เป็น FK
  factory MedAtcLevel2.fromJson(Map<String, dynamic> json) {
    return MedAtcLevel2(
      code: json['code'] as String,
      level1Code: json['level1_code'] as String,
      nameEn: json['name_en'] as String? ?? '',
      nameTh: json['name_th'] as String? ?? '',
    );
  }

  /// แปลงเป็น JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'level1_code': level1Code,
      'name_en': nameEn,
      'name_th': nameTh,
    };
  }

  /// ชื่อที่ใช้แสดงใน dropdown: "A02 - ยาลดกรด"
  String get displayName => '$code - $nameTh';

  /// ชื่อแบบเต็ม (EN/TH)
  String get fullName => '$code - $nameTh ($nameEn)';

  @override
  String toString() => 'MedAtcLevel2(code: $code, nameTh: $nameTh)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedAtcLevel2 && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}
