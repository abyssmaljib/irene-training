/// Model สำหรับบันทึกการจัดยา/ให้ยา
/// Based on A_Med_logs table in Supabase
/// รวม QC columns (merged จาก A_Med_Error_Log) เพื่อไม่ต้อง query 2 ตาราง
class MedLog {
  final int? id;
  final int residentId;
  final String meal; // เช่น 'ก่อนอาหารเช้า', 'หลังอาหารกลางวัน', 'จัดยาทั้งวัน'
  final DateTime? createdAt;
  final DateTime? createdDate; // วันที่ (date only)
  final String? picture2CUrl; // รูปตอนจัดยา (กลางคืน)
  final String? picture3CUrl; // รูปตอนเสิร์ฟยา
  final DateTime? timestamp3C;
  final String? userNicknameArrangemed; // ผู้จัดยา
  final String? userNickname2c; // ผู้ถ่ายรูป 2C
  final String? userNickname3c; // ผู้ถ่ายรูป 3C
  final String? userId2c; // user_id ของผู้ถ่ายรูป 2C
  final String? userId3c; // user_id ของผู้ถ่ายรูป 3C
  // QC columns (merged จาก A_Med_Error_Log)
  final int? nursinghomeId; // denormalize จาก residents
  final String? qc2cMark; // ผล QC 2C: 'รูปตรง'/'รูปไม่ตรง'/'ไม่มีรูป'/'ตำแหน่งสลับ'
  final String? qc2cReviewerId; // UUID ใครตรวจ 2C
  final DateTime? qc2cAt; // ตรวจ 2C เมื่อไหร่
  final String? qc2cReviewerNickname; // ชื่อเล่นคนตรวจ 2C (join จาก user_info)
  final String? qc3cMark; // ผล QC 3C
  final String? qc3cReviewerId; // UUID ใครตรวจ 3C
  final DateTime? qc3cAt; // ตรวจ 3C เมื่อไหร่
  final String? qc3cReviewerNickname; // ชื่อเล่นคนตรวจ 3C (join จาก user_info)

  MedLog({
    this.id,
    required this.residentId,
    required this.meal,
    this.createdAt,
    this.createdDate,
    this.picture2CUrl,
    this.picture3CUrl,
    this.timestamp3C,
    this.userNicknameArrangemed,
    this.userNickname2c,
    this.userNickname3c,
    this.userId2c,
    this.userId3c,
    this.nursinghomeId,
    this.qc2cMark,
    this.qc2cReviewerId,
    this.qc2cAt,
    this.qc2cReviewerNickname,
    this.qc3cMark,
    this.qc3cReviewerId,
    this.qc3cAt,
    this.qc3cReviewerNickname,
  });

  factory MedLog.fromJson(Map<String, dynamic> json) {
    // ข้อมูล reviewer จาก join (ถ้ามี)
    // qc_2c_reviewer_info / qc_3c_reviewer_info มาจาก foreign key join
    final reviewer2c = json['qc_2c_reviewer_info'] as Map<String, dynamic>?;
    final reviewer3c = json['qc_3c_reviewer_info'] as Map<String, dynamic>?;

    return MedLog(
      id: json['id'],
      residentId: json['resident_id'] ?? 0,
      meal: json['meal'] ?? '',
      createdAt: _parseDateTime(json['created_at']),
      createdDate: _parseDate(json['Created_Date']),
      // Try multiple field names for picture URLs
      picture2CUrl: json['2C_picture_url'] ?? json['SecondCPictureUrl'],
      picture3CUrl: json['3C_picture_url'] ?? json['ThirdCPictureUrl'],
      timestamp3C: _parseDateTime(json['3C_time_stamps']),
      userNicknameArrangemed: json['user_nickname_arrangemed'],
      userNickname2c: json['user_nickname_2c'],
      userNickname3c: json['user_nickname_3c'],
      userId2c: json['2C_completed_by'],
      userId3c: json['3C_Compleated_by'],
      // QC columns
      nursinghomeId: json['nursinghome_id'],
      qc2cMark: json['qc_2c_mark'],
      qc2cReviewerId: json['qc_2c_reviewer'],
      qc2cAt: _parseDateTime(json['qc_2c_at']),
      qc2cReviewerNickname: reviewer2c?['nickname'] as String?,
      qc3cMark: json['qc_3c_mark'],
      qc3cReviewerId: json['qc_3c_reviewer'],
      qc3cAt: _parseDateTime(json['qc_3c_at']),
      qc3cReviewerNickname: reviewer3c?['nickname'] as String?,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is String) {
      // Supabase timestamptz มาเป็น UTC (มี 'Z' หรือ '+00')
      // ต้องแปลงเป็น local time (Thailand = UTC+7)
      final parsed = DateTime.tryParse(value);
      return parsed?.toLocal();
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      // Handle date-only format: 2024-12-27
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// ตรวจสอบว่ามีรูป 2C หรือไม่
  bool get hasPicture2C =>
      picture2CUrl != null && picture2CUrl!.isNotEmpty;

  /// ตรวจสอบว่ามีรูป 3C หรือไม่ (ให้ยาแล้ว)
  bool get hasPicture3C =>
      picture3CUrl != null && picture3CUrl!.isNotEmpty;

  /// ตรวจสอบว่าเป็น log สำหรับจัดยาทั้งวันหรือไม่
  bool get isDailyArrangement => meal == 'จัดยาทั้งวัน';

  /// อ่าน QC mark ตาม photoType
  /// [is2C] = true → อ่าน qc_2c_mark, false → อ่าน qc_3c_mark
  String? getQcMark({required bool is2C}) =>
      is2C ? qc2cMark : qc3cMark;

  /// อ่าน reviewer nickname ตาม photoType
  String? getQcReviewerNickname({required bool is2C}) =>
      is2C ? qc2cReviewerNickname : qc3cReviewerNickname;

  /// อ่าน NurseMarkStatus ตาม photoType (enum version)
  NurseMarkStatus getQcStatus({required bool is2C}) =>
      NurseMarkStatusExtension.fromString(getQcMark(is2C: is2C));

  @override
  String toString() {
    return 'MedLog(id: $id, residentId: $residentId, meal: $meal, has3C: $hasPicture3C)';
  }
}

/// สถานะการตรวจสอบรูปยา (ย้ายมาจาก med_error_log.dart)
enum NurseMarkStatus {
  correct, // รูปตรง
  incorrect, // รูปไม่ตรง
  noPhoto, // ไม่มีรูป
  swapped, // ตำแหน่งสลับ
  none, // ยังไม่ได้ตรวจสอบ
}

extension NurseMarkStatusExtension on NurseMarkStatus {
  static NurseMarkStatus fromString(String? value) {
    switch (value) {
      case 'รูปตรง':
        return NurseMarkStatus.correct;
      case 'รูปไม่ตรง':
        return NurseMarkStatus.incorrect;
      case 'ไม่มีรูป':
        return NurseMarkStatus.noPhoto;
      case 'ตำแหน่งสลับ':
        return NurseMarkStatus.swapped;
      default:
        return NurseMarkStatus.none;
    }
  }

  /// แปลง enum → string สำหรับเขียนลง database
  String get dbValue {
    switch (this) {
      case NurseMarkStatus.correct:
        return 'รูปตรง';
      case NurseMarkStatus.incorrect:
        return 'รูปไม่ตรง';
      case NurseMarkStatus.noPhoto:
        return 'ไม่มีรูป';
      case NurseMarkStatus.swapped:
        return 'ตำแหน่งสลับ';
      case NurseMarkStatus.none:
        return '';
    }
  }
}
