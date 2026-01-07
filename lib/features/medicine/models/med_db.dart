/// Model สำหรับข้อมูลยาในฐานข้อมูล (med_DB table)
///
/// เก็บข้อมูลยาทั้งหมดของ nursing home รวมถึง:
/// - ชื่อยา (generic/brand name)
/// - ขนาดและหน่วย (strength, unit)
/// - วิธีการให้ยา (route)
/// - รูปภาพยา (4 แบบ: Front/Back Foiled/Nude)
/// - การจำแนกประเภทยา (ATC classification)
class MedDB {
  final int id;
  final DateTime createdAt;
  final int? nursinghomeId;

  // ข้อมูลชื่อยา
  final String? brandName;     // ชื่อการค้า เช่น "Tylenol"
  final String? genericName;   // ชื่อสามัญ เช่น "Paracetamol"

  // ข้อมูลขนาดและวิธีการให้
  final String? str;           // ความแรง/ขนาด เช่น "500mg"
  final String? route;         // วิธีการให้ เช่น "รับประทาน", "ฉีด"
  final String? unit;          // หน่วย เช่น "เม็ด", "ml"

  // ข้อมูลเพิ่มเติม
  final String? info;          // รายละเอียดเพิ่มเติม
  final String? group;         // กลุ่มยา (free text)

  // รูปภาพยา
  final String? pillpicUrl;    // รูปยาทั่วไป
  final String? frontFoiled;   // รูปด้านหน้า (มีฟอยล์) - ใช้ตรวจสอบ 2C
  final String? backFoiled;    // รูปด้านหลัง (มีฟอยล์)
  final String? frontNude;     // รูปด้านหน้า (ไม่มีฟอยล์) - ใช้ตรวจสอบ 3C
  final String? backNude;      // รูปด้านหลัง (ไม่มีฟอยล์)

  // ATC Classification (Anatomical Therapeutic Chemical)
  // Note: ในฐานข้อมูลเก็บเป็น String (code) เช่น "J", "A01"
  final String? atcLevel1Id;   // FK to med_atc_level1 (หมวดหลัก) - เก็บ code เช่น "A", "J"
  final String? atcLevel2Id;   // FK to med_atc_level2 (หมวดย่อย) - เก็บ code เช่น "A01", "J01"
  final String? atcLevel3;     // หมวดรายละเอียด (free text)

  const MedDB({
    required this.id,
    required this.createdAt,
    this.nursinghomeId,
    this.brandName,
    this.genericName,
    this.str,
    this.route,
    this.unit,
    this.info,
    this.group,
    this.pillpicUrl,
    this.frontFoiled,
    this.backFoiled,
    this.frontNude,
    this.backNude,
    this.atcLevel1Id,
    this.atcLevel2Id,
    this.atcLevel3,
  });

  /// สร้าง MedDB จาก JSON (Supabase response)
  factory MedDB.fromJson(Map<String, dynamic> json) {
    return MedDB(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      nursinghomeId: json['nursinghome_id'] as int?,
      brandName: json['brand_name'] as String?,
      genericName: json['generic_name'] as String?,
      str: json['str'] as String?,
      route: json['route'] as String?,
      unit: json['unit'] as String?,
      info: json['info'] as String?,
      group: json['group'] as String?,
      pillpicUrl: json['pillpic_url'] as String?,
      // Note: Supabase column names have dashes, not underscores
      frontFoiled: json['Front-Foiled'] as String?,
      backFoiled: json['Back-Foiled'] as String?,
      frontNude: json['Front-Nude'] as String?,
      backNude: json['Back-Nude'] as String?,
      atcLevel1Id: json['atc_level1_id']?.toString(),
      atcLevel2Id: json['atc_level2_id']?.toString(),
      atcLevel3: json['atc_level3'] as String?,
    );
  }

  /// แปลงเป็น JSON สำหรับส่งไป Supabase
  Map<String, dynamic> toJson() {
    return {
      if (nursinghomeId != null) 'nursinghome_id': nursinghomeId,
      if (brandName != null) 'brand_name': brandName,
      if (genericName != null) 'generic_name': genericName,
      if (str != null) 'str': str,
      if (route != null) 'route': route,
      if (unit != null) 'unit': unit,
      if (info != null) 'info': info,
      if (group != null) 'group': group,
      if (pillpicUrl != null) 'pillpic_url': pillpicUrl,
      if (frontFoiled != null) 'Front-Foiled': frontFoiled,
      if (backFoiled != null) 'Back-Foiled': backFoiled,
      if (frontNude != null) 'Front-Nude': frontNude,
      if (backNude != null) 'Back-Nude': backNude,
      if (atcLevel1Id != null) 'atc_level1_id': atcLevel1Id,
      if (atcLevel2Id != null) 'atc_level2_id': atcLevel2Id,
      if (atcLevel3 != null) 'atc_level3': atcLevel3,
    };
  }

  // ==========================================
  // Helper Getters
  // ==========================================

  /// ชื่อยาที่ใช้แสดง (ใช้ brand name ก่อน ถ้าไม่มีใช้ generic name)
  String get displayName => brandName ?? genericName ?? 'ไม่ระบุชื่อยา';

  /// ชื่อยาแบบเต็ม: "Generic Name (Brand Name)"
  String get fullName {
    if (genericName == null && brandName == null) return 'ไม่ระบุชื่อยา';
    if (genericName == null) return brandName!;
    if (brandName == null) return genericName!;
    return '$genericName ($brandName)';
  }

  /// ข้อมูลยาแบบย่อ: "ชื่อยา ขนาด หน่วย"
  /// เช่น "Paracetamol 500mg เม็ด"
  String get shortDescription {
    final parts = <String>[displayName];
    if (str != null && str!.isNotEmpty) parts.add(str!);
    if (unit != null && unit!.isNotEmpty) parts.add(unit!);
    return parts.join(' ');
  }

  /// ข้อมูลวิธีการให้ยา: "วิธีการ • หน่วย"
  /// เช่น "รับประทาน • เม็ด"
  String get routeAndUnit {
    final parts = <String>[];
    if (route != null && route!.isNotEmpty) parts.add(route!);
    if (unit != null && unit!.isNotEmpty) parts.add(unit!);
    return parts.join(' • ');
  }

  /// ตรวจสอบว่ามีรูปยาหรือไม่
  bool get hasAnyImage =>
      (pillpicUrl != null && pillpicUrl!.isNotEmpty) ||
      (frontFoiled != null && frontFoiled!.isNotEmpty) ||
      (backFoiled != null && backFoiled!.isNotEmpty) ||
      (frontNude != null && frontNude!.isNotEmpty) ||
      (backNude != null && backNude!.isNotEmpty);

  /// รูปยาหลักที่ใช้แสดง (เลือกรูปแรกที่มี)
  String? get primaryImageUrl =>
      pillpicUrl ?? frontFoiled ?? frontNude ?? backFoiled ?? backNude;

  /// copyWith สำหรับสร้าง instance ใหม่ที่มีการเปลี่ยนแปลงบางส่วน
  MedDB copyWith({
    int? id,
    DateTime? createdAt,
    int? nursinghomeId,
    String? brandName,
    String? genericName,
    String? str,
    String? route,
    String? unit,
    String? info,
    String? group,
    String? pillpicUrl,
    String? frontFoiled,
    String? backFoiled,
    String? frontNude,
    String? backNude,
    String? atcLevel1Id,
    String? atcLevel2Id,
    String? atcLevel3,
  }) {
    return MedDB(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      nursinghomeId: nursinghomeId ?? this.nursinghomeId,
      brandName: brandName ?? this.brandName,
      genericName: genericName ?? this.genericName,
      str: str ?? this.str,
      route: route ?? this.route,
      unit: unit ?? this.unit,
      info: info ?? this.info,
      group: group ?? this.group,
      pillpicUrl: pillpicUrl ?? this.pillpicUrl,
      frontFoiled: frontFoiled ?? this.frontFoiled,
      backFoiled: backFoiled ?? this.backFoiled,
      frontNude: frontNude ?? this.frontNude,
      backNude: backNude ?? this.backNude,
      atcLevel1Id: atcLevel1Id ?? this.atcLevel1Id,
      atcLevel2Id: atcLevel2Id ?? this.atcLevel2Id,
      atcLevel3: atcLevel3 ?? this.atcLevel3,
    );
  }

  @override
  String toString() => 'MedDB(id: $id, name: $fullName, str: $str)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedDB && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
