/// Model สำหรับ reconciliation warning ของยา
/// ใช้แสดง badge เตือนบน MedicineCard เมื่อยามีประเด็น
/// (ยาซ้ำซ้อน, กลุ่มเดียวกัน, ยาอันตรายสูง)
class MedicineWarning {
  final int id;
  final int triggerMedDbId;
  final int? conflictingMedDbId;
  final String warningType; // duplicate_generic, same_atc_class, high_alert_drug
  final String severity; // info, warning, critical
  final String message;
  final String status; // pending, acknowledged, resolved, dismissed

  // ข้อมูลยาคู่กรณี (ใช้แสดงใน popup)
  final String? triggerBrandName;
  final String? triggerGenericName;
  final String? conflictBrandName;
  final String? conflictGenericName;

  MedicineWarning({
    required this.id,
    required this.triggerMedDbId,
    this.conflictingMedDbId,
    required this.warningType,
    required this.severity,
    required this.message,
    required this.status,
    this.triggerBrandName,
    this.triggerGenericName,
    this.conflictBrandName,
    this.conflictGenericName,
  });

  /// สร้างจาก JSON response ของ Supabase
  /// join กับ med_DB เพื่อดึงชื่อยา trigger + conflict
  factory MedicineWarning.fromJson(Map<String, dynamic> json) {
    // ดึงชื่อจาก nested join (ถ้ามี) หรือจาก flat field
    final trigger = json['trigger_med'] as Map<String, dynamic>?;
    final conflict = json['conflict_med'] as Map<String, dynamic>?;

    return MedicineWarning(
      id: json['id'] as int,
      triggerMedDbId: json['trigger_med_db_id'] as int,
      conflictingMedDbId: json['conflicting_med_db_id'] as int?,
      warningType: json['warning_type'] as String,
      severity: json['severity'] as String? ?? 'info',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      // ชื่อยาจาก nested join
      triggerBrandName: trigger?['brand_name'] as String?,
      triggerGenericName: trigger?['generic_name'] as String?,
      conflictBrandName: conflict?['brand_name'] as String?,
      conflictGenericName: conflict?['generic_name'] as String?,
    );
  }

  /// ตรวจว่าเป็นยาอันตรายสูง
  bool get isCritical => severity == 'critical';

  /// ตรวจว่าเป็นยาซ้ำซ้อน
  bool get isDuplicate => warningType == 'duplicate_generic';

  /// ตรวจว่าเป็นยากลุ่มเดียวกัน
  bool get isSameClass => warningType == 'same_atc_class';

  /// ตรวจว่าเป็น high alert drug
  bool get isHighAlert => warningType == 'high_alert_drug';

  /// ชื่อยาคู่กรณี (ฝั่งตรงข้าม) — ใช้แสดงใน popup
  String? get conflictDrugName =>
      conflictBrandName ?? conflictGenericName;

  /// ชื่อยาที่ trigger warning
  String? get triggerDrugName =>
      triggerBrandName ?? triggerGenericName;

  /// ข้อความอธิบายเป็นภาษาไทยง่ายๆ สำหรับผู้ช่วยพยาบาล
  /// ตรวจ null ทุกจุดเพื่อไม่แสดง "null" ให้ user เห็น
  String get displayMessage {
    if (isHighAlert) {
      return 'ยาตัวนี้ต้องระวังเป็นพิเศษ\nตรวจสอบขนาดยาให้ถูกต้อง และแจ้งพยาบาลทุกครั้งก่อนให้ยา';
    }
    // ชื่อยาคู่กรณี — ใช้ trigger หรือ conflict ขึ้นกับฝั่งที่ดู
    final pairName = conflictDrugName ?? triggerDrugName;
    if (isDuplicate && pairName != null) {
      return 'ยาตัวนี้เป็นตัวยาเดียวกับ $pairName\nอาจได้รับยาซ้ำ — แจ้งพยาบาลก่อนให้ยา';
    }
    if (isSameClass && pairName != null) {
      return 'ยาตัวนี้อยู่กลุ่มเดียวกับ $pairName\nอาจมีฤทธิ์ซ้ำกัน — ตรวจสอบกับพยาบาล';
    }
    // fallback — ใช้ message จาก DB (อาจเป็นภาษาเทคนิค)
    if (message.isNotEmpty) return message;
    return 'มีประเด็นที่ต้องตรวจสอบ — แจ้งพยาบาล';
  }

  /// label สั้นสำหรับ badge
  String get badgeLabel {
    if (isCritical) return 'ยาอันตรายสูง';
    if (isDuplicate) return 'ยาซ้ำ';
    if (isSameClass) return 'กลุ่มเดียวกัน';
    return 'ประเด็นยา';
  }
}
