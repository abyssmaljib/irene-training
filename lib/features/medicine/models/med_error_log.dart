/// Model สำหรับ A_Med_error_log - บันทึกการตรวจสอบรูปยาโดยหัวหน้าเวร
class MedErrorLog {
  final int id;
  final int? residentId;
  final String? meal; // เช่น "หลังเช้า", "ก่อนกลางวัน" - format: "${beforeAfter}${bldb}"
  final DateTime? calendarDate;
  final bool? field2CPicture; // ตรวจสอบรูป 2C (จัดยา)
  final bool? field3CPicture; // ตรวจสอบรูป 3C (เสิร์ฟยา)
  final String? replyNurseMark; // "รูปตรง", "รูปไม่ตรง", "ไม่มีรูป", "ตำแหน่งสลับ"
  final DateTime? createdAt;

  MedErrorLog({
    required this.id,
    this.residentId,
    this.meal,
    this.calendarDate,
    this.field2CPicture,
    this.field3CPicture,
    this.replyNurseMark,
    this.createdAt,
  });

  factory MedErrorLog.fromJson(Map<String, dynamic> json) {
    return MedErrorLog(
      id: json['id'] as int,
      residentId: json['resident_id'] as int?,
      meal: json['meal'] as String?,
      // Database column is CalendarDate (camelCase)
      calendarDate: json['CalendarDate'] != null
          ? DateTime.tryParse(json['CalendarDate'] as String)
          : null,
      // Database column is 2CPicture (no underscore)
      field2CPicture: json['2CPicture'] as bool?,
      // Database column is 3CPicture (no underscore)
      field3CPicture: json['3CPicture'] as bool?,
      // Database column is reply_nurseMark (mixed case)
      replyNurseMark: json['reply_nurseMark'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// สถานะการตรวจสอบรูปยา
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
}
