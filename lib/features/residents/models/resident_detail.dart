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
  });

  /// สร้างจาก JSON (Supabase response)
  factory ResidentDetail.fromJson(Map<String, dynamic> json) {
    // คำนวณอายุจาก i_DOB
    int? age;
    DateTime? dob;
    final dobStr = json['i_DOB'] as String?;
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

    // Parse zone data
    final zoneData = json['nursinghome_zone'] as Map<String, dynamic>?;

    // Parse contract date
    DateTime? contractDate;
    final contractDateStr = json['s_contract_date'] as String?;
    if (contractDateStr != null) {
      try {
        contractDate = DateTime.parse(contractDateStr);
      } catch (_) {}
    }

    // Parse underlying diseases
    final underlyingDiseaseList =
        (json['underlying_disease_list'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return ResidentDetail(
      id: json['id'] as int,
      name: json['i_Name_Surname'] as String? ?? '-',
      gender: json['i_gender'] as String?,
      age: age,
      dob: dob,
      imageUrl: json['i_picture_url'] as String?,
      zoneId: zoneData?['id'] as int? ?? json['s_zone'] as int? ?? 0,
      zoneName: zoneData?['zone'] as String? ?? '-',
      bed: json['s_bed'] as String?,
      status: json['s_status'] as String?,
      specialStatus: json['s_special_status'] as String?,
      underlyingDiseases: underlyingDiseaseList,
      foodDrugAllergy: json['m_fooddrug_allergy'] as String?,
      dietary: json['m_dietary'] as String?,
      pastHistory: json['m_past_history'] as String?,
      contractDate: contractDate,
      nationalId: json['i_National_ID_num'] as String?,
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

  /// แสดงอายุเป็นข้อความ
  String get ageDisplay => age != null ? '$age ปี' : '-';

  /// แสดงวันเกิดเป็นข้อความภาษาไทย
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
    final buddhistYear = dob!.year + 543;
    return '${dob!.day} ${thaiMonths[dob!.month - 1]} $buddhistYear';
  }

  /// แสดงวันที่เข้าพักเป็นข้อความภาษาไทย
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
    final buddhistYear = contractDate!.year + 543;
    return '${contractDate!.day} ${thaiMonths[contractDate!.month - 1]} $buddhistYear';
  }

  /// แสดงโรคประจำตัวเป็นข้อความ
  String get underlyingDiseasesDisplay {
    if (underlyingDiseases.isEmpty) return '-';
    return underlyingDiseases.join(', ');
  }
}
