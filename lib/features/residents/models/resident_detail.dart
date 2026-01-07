/// Helper function เพื่อ parse int จาก dynamic (รองรับ "-" หรือ null)
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String && value != '-' && value.isNotEmpty) {
    return int.tryParse(value);
  }
  return null;
}

/// Model สำหรับข้อมูลญาติ
class RelativeInfo {
  final int id;
  final String nameSurname;
  final String? nickname;
  final String? phone;
  final String? detail;
  final bool isKeyPerson;
  final String? lineUserId;

  RelativeInfo({
    required this.id,
    required this.nameSurname,
    this.nickname,
    this.phone,
    this.detail,
    this.isKeyPerson = false,
    this.lineUserId,
  });

  factory RelativeInfo.fromJson(Map<String, dynamic> json) {
    return RelativeInfo(
      id: json['id'] as int? ?? 0,
      nameSurname: json['name_surname'] as String? ?? '-',
      nickname: json['nickname'] as String?,
      phone: json['phone'] as String?,
      detail: json['detail'] as String?,
      isKeyPerson: json['key_person'] as bool? ?? false,
      lineUserId: json['line_user_id'] as String?,
    );
  }

  /// แสดงชื่อพร้อมชื่อเล่น
  String get displayName {
    if (nickname != null && nickname!.isNotEmpty) {
      return '$nameSurname ($nickname)';
    }
    return nameSurname;
  }
}

/// Model สำหรับข้อมูล Resident แบบละเอียด
/// ใช้ในหน้า Resident Detail
class ResidentDetail {
  final int id;
  final String name;
  final String? gender;
  final int? age;
  final DateTime? dob;
  final String? imageUrl;
  final int zoneId;
  final String zoneName;
  final String? bed;
  final String? status; // Stay/Discharged
  final String? specialStatus; // Fall Risk, NPO, etc.
  final List<String> underlyingDiseases;
  final String? foodDrugAllergy;
  final String? dietary;
  final String? pastHistory;
  final DateTime? contractDate;
  final String? nationalId;
  final String? reasonBeingHere;
  final List<String> programs;
  final List<String> programColors;
  final List<RelativeInfo> relatives;
  final String? lineGroupId;
  final String? stayPeriod;

  ResidentDetail({
    required this.id,
    required this.name,
    this.gender,
    this.age,
    this.dob,
    this.imageUrl,
    required this.zoneId,
    required this.zoneName,
    this.bed,
    this.status,
    this.specialStatus,
    this.underlyingDiseases = const [],
    this.foodDrugAllergy,
    this.dietary,
    this.pastHistory,
    this.contractDate,
    this.nationalId,
    this.reasonBeingHere,
    this.programs = const [],
    this.programColors = const [],
    this.relatives = const [],
    this.lineGroupId,
    this.stayPeriod,
  });

  /// สร้างจาก JSON (Supabase response)
  /// รองรับทั้ง residents table และ combined_resident_details_view
  factory ResidentDetail.fromJson(Map<String, dynamic> json) {
    // คำนวณอายุจาก i_DOB หรือ i_dob_datetime
    int? age;
    DateTime? dob;
    final dobStr =
        json['i_dob_datetime'] as String? ?? json['i_DOB'] as String?;
    if (dobStr != null) {
      try {
        dob = DateTime.parse(dobStr);
        final now = DateTime.now();
        age = now.year - dob.year;
        if (now.month < dob.month ||
            (now.month == dob.month && now.day < dob.day)) {
          age--;
        }
      } catch (_) {}
    }

    // Parse zone data (รองรับทั้ง 2 แบบ)
    final zoneData = json['nursinghome_zone'] as Map<String, dynamic>?;
    final zoneId = _parseInt(json['zone_id']) ??
        _parseInt(zoneData?['id']) ??
        _parseInt(json['s_zone']) ??
        0;
    final zoneNameRaw = json['s_zone'];
    final zoneName = (zoneNameRaw is String && zoneNameRaw != '-')
        ? zoneNameRaw
        : zoneData?['zone'] as String? ?? '-';

    // Parse contract date (รองรับทั้ง 2 แบบ)
    DateTime? contractDate;
    final contractDateStr = json['s_contract_date_datetime'] as String? ??
        json['s_contract_date'] as String?;
    if (contractDateStr != null) {
      try {
        contractDate = DateTime.parse(contractDateStr);
      } catch (_) {}
    }

    // Parse underlying diseases (รองรับทั้ง 2 แบบ)
    final underlyingDiseaseList = (json['underlying_diseases_list']
                as List<dynamic>? ??
            json['underlying_disease_list'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ??
        [];

    return ResidentDetail(
      id: json['resident_id'] as int? ?? json['id'] as int,
      name: json['i_Name_Surname'] as String? ?? '-',
      gender: json['i_gender'] as String?,
      age: age,
      dob: dob,
      imageUrl: json['i_picture_url'] as String?,
      zoneId: zoneId,
      zoneName: zoneName,
      bed: json['s_bed'] as String?,
      status: json['s_status'] as String?,
      specialStatus: json['s_special_status'] as String?,
      underlyingDiseases: underlyingDiseaseList,
      foodDrugAllergy: json['m_fooddrug_allergy'] as String?,
      dietary: json['m_dietary'] as String?,
      pastHistory: json['m_past_history'] as String?,
      contractDate: contractDate,
      nationalId: json['i_National_ID_num'] as String?,
      reasonBeingHere: json['s_reason_being_here'] as String?,
      programs: (json['programs_list'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      programColors: (json['program_pastel_color_list'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      relatives: (json['relatives_list'] as List<dynamic>?)
              ?.map((e) => RelativeInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lineGroupId: json['line_group_id'] as String?,
      stayPeriod: json['s_stay_period'] as String?,
    );
  }

  /// ตรวจสอบว่ามี special status หรือไม่
  bool get hasSpecialStatus =>
      specialStatus != null && specialStatus!.isNotEmpty;

  /// ตรวจสอบว่าเป็น Fall Risk หรือไม่
  bool get isFallRisk =>
      specialStatus?.toLowerCase().contains('fall') ?? false;

  /// ตรวจสอบว่าเป็น NPO หรือไม่
  bool get isNPO => specialStatus?.toLowerCase().contains('npo') ?? false;

  /// ตรวจสอบว่าเชื่อมต่อ Line แล้วหรือไม่
  bool get isLineConnected =>
      lineGroupId != null && lineGroupId!.isNotEmpty && lineGroupId != '-';

  /// แสดงอายุเป็นข้อความ
  String get ageDisplay => age != null ? '$age ปี' : '-';

  /// แสดงวันเกิดเป็นข้อความภาษาไทย (ปี ค.ศ.)
  String get dobDisplay {
    if (dob == null) return '-';
    final thaiMonths = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    // แสดงปี ค.ศ. (Christian Era)
    return '${dob!.day} ${thaiMonths[dob!.month - 1]} ${dob!.year}';
  }

  /// แสดงวันที่เข้าพักเป็นข้อความภาษาไทย (ปี ค.ศ.)
  String get contractDateDisplay {
    if (contractDate == null) return '-';
    final thaiMonths = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    // แสดงปี ค.ศ. (Christian Era)
    return '${contractDate!.day} ${thaiMonths[contractDate!.month - 1]} ${contractDate!.year}';
  }

  /// แสดงโรคประจำตัวเป็นข้อความ
  String get underlyingDiseasesDisplay {
    if (underlyingDiseases.isEmpty) return '-';
    return underlyingDiseases.join(', ');
  }
}
