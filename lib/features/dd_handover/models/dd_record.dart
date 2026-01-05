import 'package:intl/intl.dart';

/// Model สำหรับข้อมูล DD Record (เวรพาคนไข้ไปหาหมอ)
class DDRecord {
  final int ddId;
  final DateTime? createdAt;
  final String? userId;
  final String? ddUserName;
  final String? ddUserNickname;
  final String? ddUserPhoto;
  final String? aprooverId;
  final int? calendarAppointmentId;
  final int? calendarBillId;
  final String? appointmentTitle;
  final String? appointmentDescription;
  final String? appointmentType;
  final DateTime? appointmentDatetime;
  final int? appointmentNursinghomeId;
  final int? appointmentResidentId;
  final String? appointmentResidentName;
  final String? appointmentCreatorId;
  final String? appointmentCreatorName;
  final String? appointmentHospital;
  final bool? appointmentIsNpo;
  final bool? appointmentIsRelativePaidIn;
  final DateTime? appointmentRelativePaidDate;
  final bool? appointmentIsDocumentPrepared;
  final bool? appointmentIsPostOnBoardAfter;
  final String? billTitle;
  final String? billType;
  final DateTime? billDatetime;
  final String? billResidentName;
  final int? postId;
  final String? postTitle;

  DDRecord({
    required this.ddId,
    this.createdAt,
    this.userId,
    this.ddUserName,
    this.ddUserNickname,
    this.ddUserPhoto,
    this.aprooverId,
    this.calendarAppointmentId,
    this.calendarBillId,
    this.appointmentTitle,
    this.appointmentDescription,
    this.appointmentType,
    this.appointmentDatetime,
    this.appointmentNursinghomeId,
    this.appointmentResidentId,
    this.appointmentResidentName,
    this.appointmentCreatorId,
    this.appointmentCreatorName,
    this.appointmentHospital,
    this.appointmentIsNpo,
    this.appointmentIsRelativePaidIn,
    this.appointmentRelativePaidDate,
    this.appointmentIsDocumentPrepared,
    this.appointmentIsPostOnBoardAfter,
    this.billTitle,
    this.billType,
    this.billDatetime,
    this.billResidentName,
    this.postId,
    this.postTitle,
  });

  /// ส่งเวรแล้วหรือยัง (มี post_id = ส่งแล้ว)
  bool get isCompleted => postId != null;

  /// แสดงวันเวลานัด (สำหรับ DD Card)
  /// รูปแบบ: จ. 6 ม.ค. 69 09:00
  String get formattedDatetime {
    if (appointmentDatetime == null) return '-';
    final dt = appointmentDatetime!.toLocal();

    final thaiDaysShort = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
    final thaiMonths = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];

    final dayName = thaiDaysShort[dt.weekday - 1];
    final day = dt.day;
    final month = thaiMonths[dt.month];
    final yearShort = (dt.year + 543) % 100; // เอาแค่ 2 หลักท้าย เช่น 69
    final time = DateFormat('HH:mm').format(dt);

    return '$dayName $day $month $yearShort $time';
  }

  /// แสดงวันที่นัด (แบบเต็ม)
  String get formattedDate {
    if (appointmentDatetime == null) return '-';
    final dt = appointmentDatetime!;
    final thaiMonths = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    return '${dt.day} ${thaiMonths[dt.month]} ${dt.year + 543}';
  }

  /// แสดงเวลานัด
  String get formattedTime {
    if (appointmentDatetime == null) return '-';
    return DateFormat('HH:mm').format(appointmentDatetime!);
  }

  /// หัวข้อ template สำหรับ post title
  String get templateTitle => '📋 รายงานการไปพบแพทย์';

  /// สร้าง template text สำหรับ post body (ไม่รวมหัวข้อ)
  String get templateText {
    String formattedDateStr = '';
    String formattedTimeStr = '';
    if (appointmentDatetime != null) {
      final dt = appointmentDatetime!.toLocal();
      final thaiMonths = [
        '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
        'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
      ];
      formattedDateStr = '${dt.day} ${thaiMonths[dt.month]} ${dt.year + 543}';
      formattedTimeStr = DateFormat('HH:mm').format(dt);
    }
    final patientName = appointmentResidentName ?? '';
    final title = appointmentTitle ?? '';
    final description = appointmentDescription ?? '';

    return '''📅 วันที่: $formattedDateStr
⏰ เวลา: $formattedTimeStr
👤 ผู้ป่วย: $patientName

📌 $title
$description

🚨 สาเหตุ:
🏥 โรงพยาบาล: ${appointmentHospital ?? ''}
🩺 พบแพทย์แผนก:
👩🏼‍⚕️ ชื่อแพทย์:
📝 คำสั่งแพทย์:
✍️ แพทย์วินิจฉัย:

📌 ปรับยา
จากที่เคยทาน:
ปรับมาทานเป็น:
ได้มาเพิ่มจำนวน:

📌 มีนัดครั้งถัดไป วันที่
(NPO มั้ย? มีเจาะเลือดมั้ย?)
''';
  }

  factory DDRecord.fromJson(Map<String, dynamic> json) {
    return DDRecord(
      ddId: json['dd_id'] as int,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      userId: json['user_id'] as String?,
      ddUserName: json['dd_user_name'] as String?,
      ddUserNickname: json['dd_user_nickname'] as String?,
      ddUserPhoto: json['dd_user_photo'] as String?,
      aprooverId: json['aproover_id'] as String?,
      calendarAppointmentId: json['calendar_appointment_id'] as int?,
      calendarBillId: json['calendar_bill_id'] as int?,
      appointmentTitle: json['appointment_title'] as String?,
      appointmentDescription: json['appointment_description'] as String?,
      appointmentType: json['appointment_type'] as String?,
      appointmentDatetime: json['appointment_datetime'] != null
          ? DateTime.parse(json['appointment_datetime'] as String)
          : null,
      appointmentNursinghomeId: json['appointment_nursinghome_id'] as int?,
      appointmentResidentId: json['appointment_resident_id'] as int?,
      appointmentResidentName: json['appointment_resident_name'] as String?,
      appointmentCreatorId: json['appointment_creator_id'] as String?,
      appointmentCreatorName: json['appointment_creator_name'] as String?,
      appointmentHospital: json['appointment_hospital'] as String?,
      appointmentIsNpo: json['appointment_isnpo'] as bool?,
      appointmentIsRelativePaidIn: json['appointment_isrelativepaidin'] as bool?,
      appointmentRelativePaidDate: json['appointment_relativepaiddate'] != null
          ? DateTime.parse(json['appointment_relativepaiddate'] as String)
          : null,
      appointmentIsDocumentPrepared:
          json['appointment_isdocumentprepared'] as bool?,
      appointmentIsPostOnBoardAfter:
          json['appointment_ispostonboardafter'] as bool?,
      billTitle: json['bill_title'] as String?,
      billType: json['bill_type'] as String?,
      billDatetime: json['bill_datetime'] != null
          ? DateTime.parse(json['bill_datetime'] as String)
          : null,
      billResidentName: json['bill_resident_name'] as String?,
      postId: json['post_id'] as int?,
      postTitle: json['post_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dd_id': ddId,
      'created_at': createdAt?.toIso8601String(),
      'user_id': userId,
      'dd_user_name': ddUserName,
      'dd_user_nickname': ddUserNickname,
      'dd_user_photo': ddUserPhoto,
      'aproover_id': aprooverId,
      'calendar_appointment_id': calendarAppointmentId,
      'calendar_bill_id': calendarBillId,
      'appointment_title': appointmentTitle,
      'appointment_description': appointmentDescription,
      'appointment_type': appointmentType,
      'appointment_datetime': appointmentDatetime?.toIso8601String(),
      'appointment_nursinghome_id': appointmentNursinghomeId,
      'appointment_resident_id': appointmentResidentId,
      'appointment_resident_name': appointmentResidentName,
      'appointment_creator_id': appointmentCreatorId,
      'appointment_creator_name': appointmentCreatorName,
      'appointment_hospital': appointmentHospital,
      'appointment_isnpo': appointmentIsNpo,
      'appointment_isrelativepaidin': appointmentIsRelativePaidIn,
      'appointment_relativepaiddate': appointmentRelativePaidDate?.toIso8601String(),
      'appointment_isdocumentprepared': appointmentIsDocumentPrepared,
      'appointment_ispostonboardafter': appointmentIsPostOnBoardAfter,
      'bill_title': billTitle,
      'bill_type': billType,
      'bill_datetime': billDatetime?.toIso8601String(),
      'bill_resident_name': billResidentName,
      'post_id': postId,
      'post_title': postTitle,
    };
  }
}
