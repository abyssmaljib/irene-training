/// Model สำหรับยาของผู้พักอาศัย (medicine_list table)
///
/// เก็บข้อมูลการสั่งยาให้ resident รวมถึง:
/// - ยาที่สั่ง (FK to med_DB)
/// - ปริมาณและเวลาที่ให้
/// - ความถี่และเงื่อนไขพิเศษ
class MedicineListItem {
  final int id;
  final DateTime createdAt;

  // Foreign Keys
  final int medDbId;        // FK to med_DB - ยาที่เลือก
  final int residentId;     // FK to residents - ผู้พักอาศัย

  // ข้อมูลการให้ยา
  final double takeTab;     // ปริมาณที่ให้ (เช่น 1, 0.5, 2)

  /// เวลาที่ให้ยา - BLDB (Before/Lunch/Dinner/Bedtime)
  /// ค่าที่เป็นไปได้: ['เช้า', 'กลางวัน', 'เย็น', 'ก่อนนอน']
  final List<String> bldb;

  /// ก่อน/หลังอาหาร
  /// ค่าที่เป็นไปได้: ['ก่อนอาหาร', 'หลังอาหาร']
  final List<String> beforeAfter;

  // ความถี่
  final int? everyHr;           // ทุก N (วัน/สัปดาห์/เดือน/ชั่วโมง)
  final String? typeOfTime;     // หน่วยความถี่: 'วัน', 'สัปดาห์', 'เดือน', 'ชั่วโมง'
  final List<String>? daysOfWeek; // วันที่ให้ยา (ถ้ากำหนดเฉพาะวัน)

  // เงื่อนไขพิเศษ
  final bool prn;               // PRN = ให้เมื่อจำเป็น (Pro Re Nata)
  final List<String>? underlyingDiseaseTag; // โรคประจำตัวที่เกี่ยวข้อง

  // ข้อมูลเพิ่มเติม
  final int? medString;         // ID สำหรับ grouping
  final String? medAmountStatus; // สถานะปริมาณยา

  const MedicineListItem({
    required this.id,
    required this.createdAt,
    required this.medDbId,
    required this.residentId,
    required this.takeTab,
    required this.bldb,
    required this.beforeAfter,
    this.everyHr,
    this.typeOfTime,
    this.daysOfWeek,
    this.prn = false,
    this.underlyingDiseaseTag,
    this.medString,
    this.medAmountStatus,
  });

  /// สร้างจาก JSON (Supabase response)
  factory MedicineListItem.fromJson(Map<String, dynamic> json) {
    // Helper function แปลง dynamic list เป็น List<String>
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    return MedicineListItem(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      medDbId: json['med_DB_id'] as int,
      residentId: json['resident_id'] as int,
      takeTab: (json['take_tab'] as num?)?.toDouble() ?? 0.0,
      bldb: parseStringList(json['BLDB']),
      beforeAfter: parseStringList(json['BeforeAfter']),
      everyHr: json['every_hr'] as int?,
      typeOfTime: json['typeOfTime'] as String?,
      daysOfWeek: parseStringList(json['DaysOfWeek']),
      prn: json['prn'] as bool? ?? false,
      underlyingDiseaseTag: parseStringList(json['underlying_disease_tag']),
      medString: json['MedString'] as int?,
      medAmountStatus: json['med_amout_status'] as String?,
    );
  }

  /// แปลงเป็น JSON สำหรับส่งไป Supabase
  Map<String, dynamic> toJson() {
    return {
      'med_DB_id': medDbId,
      'resident_id': residentId,
      'take_tab': takeTab,
      'BLDB': bldb,
      'BeforeAfter': beforeAfter,
      if (everyHr != null) 'every_hr': everyHr,
      if (typeOfTime != null) 'typeOfTime': typeOfTime,
      if (daysOfWeek != null && daysOfWeek!.isNotEmpty) 'DaysOfWeek': daysOfWeek,
      'prn': prn,
      if (underlyingDiseaseTag != null && underlyingDiseaseTag!.isNotEmpty)
        'underlying_disease_tag': underlyingDiseaseTag,
      if (medString != null) 'MedString': medString,
      if (medAmountStatus != null) 'med_amout_status': medAmountStatus,
    };
  }

  // ==========================================
  // Helper Getters
  // ==========================================

  /// จำนวนครั้งต่อวันที่ให้ยา
  int get timesPerDay => bldb.length;

  /// ข้อความแสดงเวลาที่ให้ยา: "เช้า, กลางวัน, เย็น"
  String get bldbDisplayText => bldb.isEmpty ? 'ไม่ระบุ' : bldb.join(', ');

  /// ข้อความแสดงก่อน/หลังอาหาร
  String get beforeAfterDisplayText =>
      beforeAfter.isEmpty ? '' : beforeAfter.join(', ');

  /// ข้อความแสดงความถี่: "ทุก 2 วัน" หรือ "ทุกวัน"
  String get frequencyDisplayText {
    if (everyHr == null || everyHr == 1) {
      return 'ทุกวัน';
    }
    return 'ทุก $everyHr ${typeOfTime ?? 'วัน'}';
  }

  /// ข้อความแสดงปริมาณ: "1 เม็ด" หรือ "0.5 เม็ด"
  String dosageText(String? unit) {
    // แสดงเป็นจำนวนเต็มถ้าเป็นจำนวนเต็ม
    final dosage = takeTab == takeTab.toInt() ? takeTab.toInt() : takeTab;
    return '$dosage ${unit ?? 'เม็ด'}';
  }

  /// ตรวจสอบว่าเป็นยา PRN หรือไม่
  bool get isPrn => prn;

  /// ข้อความสรุปการให้ยา
  /// เช่น: "1 เม็ด เช้า,เย็น หลังอาหาร"
  String summaryText(String? unit) {
    final parts = <String>[dosageText(unit)];
    if (bldb.isNotEmpty) parts.add(bldbDisplayText);
    if (beforeAfter.isNotEmpty) parts.add(beforeAfterDisplayText);
    if (prn) parts.add('(PRN)');
    return parts.join(' ');
  }

  /// copyWith สำหรับสร้าง instance ใหม่
  MedicineListItem copyWith({
    int? id,
    DateTime? createdAt,
    int? medDbId,
    int? residentId,
    double? takeTab,
    List<String>? bldb,
    List<String>? beforeAfter,
    int? everyHr,
    String? typeOfTime,
    List<String>? daysOfWeek,
    bool? prn,
    List<String>? underlyingDiseaseTag,
    int? medString,
    String? medAmountStatus,
  }) {
    return MedicineListItem(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      medDbId: medDbId ?? this.medDbId,
      residentId: residentId ?? this.residentId,
      takeTab: takeTab ?? this.takeTab,
      bldb: bldb ?? this.bldb,
      beforeAfter: beforeAfter ?? this.beforeAfter,
      everyHr: everyHr ?? this.everyHr,
      typeOfTime: typeOfTime ?? this.typeOfTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      prn: prn ?? this.prn,
      underlyingDiseaseTag: underlyingDiseaseTag ?? this.underlyingDiseaseTag,
      medString: medString ?? this.medString,
      medAmountStatus: medAmountStatus ?? this.medAmountStatus,
    );
  }

  @override
  String toString() =>
      'MedicineListItem(id: $id, medDbId: $medDbId, takeTab: $takeTab, bldb: $bldb)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineListItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
