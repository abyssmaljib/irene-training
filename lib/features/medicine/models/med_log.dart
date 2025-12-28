/// Model สำหรับบันทึกการจัดยา/ให้ยา
/// Based on med_logs_with_nickname view in Supabase
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
  });

  factory MedLog.fromJson(Map<String, dynamic> json) {
    // Debug: print all keys to check field names
    // debugPrint('MedLog keys: ${json.keys.toList()}');
    // debugPrint('MedLog 3C fields: 3C_picture_url=${json['3C_picture_url']}, ThirdCPictureUrl=${json['ThirdCPictureUrl']}');

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

  @override
  String toString() {
    return 'MedLog(id: $id, residentId: $residentId, meal: $meal, has3C: $hasPicture3C)';
  }
}
