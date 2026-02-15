/// Model สำหรับข้อมูลยาของ Resident
/// Based on medicine_summary view in Supabase
class MedicineSummary {
  final int medicineListId;
  final int residentId;
  final String? genericName;
  final String? brandName;
  final String? group;
  final String? status; // 'on', 'off', 'waiting'
  final String? statusInfo;
  final List<String> beforeAfter; // Array: ['ก่อนอาหาร'], ['หลังอาหาร'], or both
  final List<String> bldb; // Array: ['เช้า', 'กลางวัน', 'เย็น', 'ก่อนนอน']
  final String? typeOfTime; // 'วัน', 'สัปดาห์', 'เดือน', 'ชั่วโมง'
  final List<String> daysOfWeek;
  final int? everyHr; // ความถี่ (ทุก X วัน/สัปดาห์)
  final DateTime? firstMedHistoryOnDate;
  final DateTime? lastMedHistoryOffDate;
  final String? dosageFrequency;
  final double? takeTab;
  final String? str; // strength
  final String? route;
  final String? unit;
  final bool? prn; // ยาตามอาการ

  // ATC Classification
  final String? atcLevel1Code;
  final String? atcLevel1NameTh;
  final String? atcLevel2Code;
  final String? atcLevel2NameTh;

  // รูปยา (จาก med_DB)
  final String? frontFoiled; // รูปแผง ด้านหน้า → ใช้ตอน 2C
  final String? backFoiled; // รูปแผง ด้านหลัง
  final String? frontNude; // รูปเม็ดยา ด้านหน้า → ใช้ตอน 3C
  final String? backNude; // รูปเม็ดยา ด้านหลัง

  MedicineSummary({
    required this.medicineListId,
    required this.residentId,
    this.genericName,
    this.brandName,
    this.group,
    this.status,
    this.statusInfo,
    this.beforeAfter = const [],
    this.bldb = const [],
    this.typeOfTime,
    this.daysOfWeek = const [],
    this.everyHr,
    this.firstMedHistoryOnDate,
    this.lastMedHistoryOffDate,
    this.dosageFrequency,
    this.takeTab,
    this.str,
    this.route,
    this.unit,
    this.prn,
    this.atcLevel1Code,
    this.atcLevel1NameTh,
    this.atcLevel2Code,
    this.atcLevel2NameTh,
    this.frontFoiled,
    this.backFoiled,
    this.frontNude,
    this.backNude,
  });

  factory MedicineSummary.fromJson(Map<String, dynamic> json) {
    return MedicineSummary(
      medicineListId: json['medicine_list_id'] ?? 0,
      residentId: json['resident_id'] ?? 0,
      genericName: json['generic_name'],
      brandName: json['brand_name'],
      group: json['group'],
      status: json['status'],
      statusInfo: json['status_info'],
      beforeAfter: _parseStringList(json['BeforeAfter']),
      bldb: _parseStringList(json['BLDB']),
      typeOfTime: json['typeOfTime'],
      daysOfWeek: _parseStringList(json['DaysOfWeek']),
      everyHr: json['every_hr'],
      firstMedHistoryOnDate: _parseDateTime(json['first_med_history_on_date']),
      lastMedHistoryOffDate: _parseDateTime(json['last_med_history_off_date']),
      dosageFrequency: json['dosage_frequency'],
      takeTab: _parseDouble(json['take_tab']),
      str: json['str'],
      route: json['route'],
      unit: json['unit'],
      prn: json['prn'] as bool?,
      atcLevel1Code: json['atc_level1_code'],
      atcLevel1NameTh: json['atc_level1_name_th'],
      atcLevel2Code: json['atc_level2_code'],
      atcLevel2NameTh: json['atc_level2_name_th'],
      frontFoiled: json['Front-Foiled'] ?? json['front_foiled'] ?? json['frontFoiled'],
      backFoiled: json['Back-Foiled'] ?? json['back_foiled'] ?? json['backFoiled'],
      frontNude: json['Front-Nude'] ?? json['front_nude'] ?? json['frontNude'],
      backNude: json['Back-Nude'] ?? json['back_nude'] ?? json['backNude'],
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      // Handle PostgreSQL array format: {value1,value2}
      if (value.startsWith('{') && value.endsWith('}')) {
        final inner = value.substring(1, value.length - 1);
        if (inner.isEmpty) return [];
        return inner.split(',').map((e) => e.trim()).toList();
      }
      return value.split(',').map((e) => e.trim()).toList();
    }
    return [];
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// ตรวจสอบว่ายานี้ active อยู่หรือไม่
  bool get isActive => status?.toLowerCase() == 'on';

  /// แสดงชื่อยาสำหรับ display
  String get displayName => genericName ?? brandName ?? 'ไม่ระบุชื่อ';

  /// แสดงชื่อแบรนด์
  String get displayBrand => brandName ?? '';

  /// แสดงประเภทยา (ใช้ ATC Level 2 เป็นหลัก)
  String get displayGroup => atcLevel2NameTh ?? group ?? 'ไม่ระบุประเภท';

  /// แสดงประเภทยาหลัก (ATC Level 1)
  String get displayCategory => atcLevel1NameTh ?? 'ไม่ระบุหมวด';

  /// ตรวจสอบว่ายานี้ต้องกินในมื้อที่กำหนดหรือไม่
  /// beforeAfterValue: 'ก่อนอาหาร' หรือ 'หลังอาหาร' หรือ '' (สำหรับก่อนนอน)
  /// bldbValue: 'เช้า', 'กลางวัน', 'เย็น', 'ก่อนนอน'
  bool matchesMeal(String beforeAfterValue, String bldbValue) {
    // ก่อนนอนไม่มี before/after
    if (bldbValue == 'ก่อนนอน') {
      return bldb.contains('ก่อนนอน');
    }

    // ตรวจสอบว่ายานี้ต้องกินใน bldb นี้
    final matchBldb = bldb.contains(bldbValue);
    if (!matchBldb) return false;

    // ตรวจสอบ before/after
    if (beforeAfterValue.isEmpty) {
      // ไม่ระบุ before/after = match ทั้งหมด
      return true;
    }
    return beforeAfter.contains(beforeAfterValue);
  }

  /// ตรวจสอบว่าเป็นยาก่อนอาหารหรือไม่
  bool get isBeforeFood => beforeAfter.contains('ก่อนอาหาร');

  /// ตรวจสอบว่าเป็นยาหลังอาหารหรือไม่
  bool get isAfterFood => beforeAfter.contains('หลังอาหาร');

  /// ตรวจสอบว่าเป็นยามื้อเช้าหรือไม่
  bool get isMorning => bldb.contains('เช้า');

  /// ตรวจสอบว่าเป็นยามื้อกลางวันหรือไม่
  bool get isNoon => bldb.contains('กลางวัน');

  /// ตรวจสอบว่าเป็นยามื้อเย็นหรือไม่
  bool get isEvening => bldb.contains('เย็น');

  /// ตรวจสอบว่าเป็นยาก่อนนอนหรือไม่
  bool get isBedtime => bldb.contains('ก่อนนอน');

  /// รูปสำหรับ 2C (รูปแผง)
  String? get photo2C => frontFoiled;

  /// รูปสำหรับ 3C (รูปเม็ดยา)
  String? get photo3C => frontNude;

  /// มีรูปสำหรับ 2C หรือไม่
  bool get hasPhoto2C => frontFoiled != null && frontFoiled!.isNotEmpty;

  /// มีรูปสำหรับ 3C หรือไม่
  bool get hasPhoto3C => frontNude != null && frontNude!.isNotEmpty;

  /// แสดงจำนวนยา
  String get displayDosage {
    if (takeTab == null) return '';
    final tabStr =
        takeTab! % 1 == 0 ? takeTab!.toInt().toString() : takeTab.toString();
    final unitStr = unit ?? 'เม็ด';
    return '$tabStr $unitStr';
  }

  @override
  String toString() {
    return 'MedicineSummary(id: $medicineListId, name: $displayName, bldb: $bldb, beforeAfter: $beforeAfter, status: $status)';
  }

  /// ตรวจสอบว่ายานี้ต้องกินในวันที่กำหนดหรือไม่
  /// คำนวณตาม typeOfTime, everyHr, daysOfWeek และช่วงวันที่ active
  ///
  /// [selectedDate] - วันที่ต้องการตรวจสอบ
  /// [filterBeforeAfter] - กรองตาม ก่อน/หลัง อาหาร (optional)
  /// [filterBldb] - กรองตามมื้อ (optional)
  /// [filterPrn] - กรองยาตามอาการ (optional, null = ไม่กรอง)
  bool shouldTakeOnDate({
    required DateTime selectedDate,
    String? filterBeforeAfter,
    String? filterBldb,
    bool? filterPrn,
  }) {
    // ตรวจสอบ PRN
    if (filterPrn != null && prn != filterPrn) {
      return false;
    }

    // แปลงเป็น local time ก่อนดึงวัน เพราะ DateTime จาก Supabase
    // อาจเป็น UTC (เช่น 06:45+07 → 23:45Z วันก่อน) ทำให้ .day ผิดวัน
    // ถ้า selectedDate เป็น local อยู่แล้ว .toLocal() จะไม่มีผลกระทบ
    final localDate = selectedDate.toLocal();
    final checkDate = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    // ถ้า firstMedHistoryOnDate เป็น null = ใช้ checkDate เป็น startDate (ยา active ตลอด)
    final startDate = firstMedHistoryOnDate != null
        ? DateTime(
            firstMedHistoryOnDate!.year,
            firstMedHistoryOnDate!.month,
            firstMedHistoryOnDate!.day,
          )
        : checkDate;

    // ตรวจสอบว่าวันที่เลือกไม่ก่อนวันเริ่มต้น (ถ้ามี firstMedHistoryOnDate)
    if (firstMedHistoryOnDate != null && checkDate.isBefore(startDate)) {
      return false;
    }

    // วันที่เลือกต้องไม่หลังวันสิ้นสุด (ถ้ามี)
    if (lastMedHistoryOffDate != null) {
      final endDate = DateTime(
        lastMedHistoryOffDate!.year,
        lastMedHistoryOffDate!.month,
        lastMedHistoryOffDate!.day,
      );
      if (checkDate.isAfter(endDate)) {
        return false;
      }
    }

    // ตรวจสอบ beforeAfter
    if (filterBeforeAfter != null && filterBeforeAfter.isNotEmpty) {
      if (!beforeAfter.contains(filterBeforeAfter)) {
        return false;
      }
    }

    // ตรวจสอบ bldb
    if (filterBldb != null && filterBldb.isNotEmpty) {
      if (!bldb.contains(filterBldb)) {
        return false;
      }
    }

    // ตรวจสอบความถี่ตาม typeOfTime
    final effectiveTypeOfTime = typeOfTime ?? 'วัน';
    final effectiveFrequency = everyHr ?? 1;

    switch (effectiveTypeOfTime) {
      case 'ชั่วโมง':
        // ยาทุกชั่วโมง - แสดงทุกวัน
        return true;

      case 'วัน':
        // ยาทุก X วัน
        final daysSinceStart = checkDate.difference(startDate).inDays;
        return daysSinceStart % effectiveFrequency == 0;

      case 'สัปดาห์':
        // ยาทุก X สัปดาห์ ตาม daysOfWeek
        if (daysOfWeek.isEmpty) {
          return true;
        }

        // แปลงวันในสัปดาห์เป็นภาษาอังกฤษ
        const dayMapping = {
          'จันทร์': 'Monday',
          'อังคาร': 'Tuesday',
          'พุธ': 'Wednesday',
          'พฤหัส': 'Thursday',
          'ศุกร์': 'Friday',
          'เสาร์': 'Saturday',
          'อาทิตย์': 'Sunday',
        };

        // หาชื่อวันของ selectedDate
        final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        final selectedDayName = dayNames[checkDate.weekday - 1];

        // แปลง daysOfWeek เป็นภาษาอังกฤษ
        final translatedDays = daysOfWeek
            .map((day) => dayMapping[day] ?? day)
            .toList();

        // ตรวจสอบว่าตรงวันในสัปดาห์
        if (!translatedDays.contains(selectedDayName)) {
          return false;
        }

        // ตรวจสอบว่าตรงสัปดาห์ที่ถูกต้อง
        final daysSinceStart = checkDate.difference(startDate).inDays;
        final weeksSinceStart = daysSinceStart ~/ 7;
        return weeksSinceStart % effectiveFrequency == 0;

      case 'เดือน':
        // ยาทุก X เดือน - simplified: ตรวจสอบว่าตรงวันที่หรือไม่
        // ถ้าไม่มี firstMedHistoryOnDate = ให้ยาทุกวัน
        if (firstMedHistoryOnDate == null) return true;
        return startDate.day == checkDate.day;

      default:
        return true;
    }
  }

  /// Static method สำหรับกรองรายการยาตามวันที่และเงื่อนไข
  /// เทียบเท่ากับ specDayonWeekReturnListModify7 ใน FlutterFlow
  static List<MedicineSummary> filterByDate({
    required List<MedicineSummary> medicines,
    required DateTime selectedDate,
    String? beforeAfter,
    String? bldb,
    bool? prn,
  }) {
    return medicines.where((med) {
      return med.shouldTakeOnDate(
        selectedDate: selectedDate,
        filterBeforeAfter: beforeAfter,
        filterBldb: bldb,
        filterPrn: prn,
      );
    }).toList();
  }
}
