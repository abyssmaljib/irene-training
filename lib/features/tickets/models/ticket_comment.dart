// โมเดลสำหรับ comment/event ใน timeline ของ ticket
// map กับตาราง B_Ticket_Comments JOIN user_info
//
// ใช้ CommentEventType เพื่อแยกประเภทของ event ใน timeline:
// - comment: ความคิดเห็นปกติ
// - status_change: เปลี่ยนสถานะตั๋ว (เช่น open → in_progress)
// - created: สร้างตั๋วใหม่
// - doctor_order: คำสั่งแพทย์ (ใช้ร่วมกับ isDoctorOrder flag)

// ---------------------------------------------------------------------------
// CommentEventType — ประเภทของ event ใน timeline
// ---------------------------------------------------------------------------

/// enum สำหรับแยกประเภท event ใน timeline ของ ticket
/// แต่ละค่ามี:
/// - [value]       → ค่าที่เก็บใน DB (snake_case)
/// - [displayText] → ข้อความแสดงผลภาษาไทย
enum CommentEventType {
  comment(value: 'comment', displayText: 'ความคิดเห็น'),
  statusChange(value: 'status_change', displayText: 'เปลี่ยนสถานะ'),
  created(value: 'created', displayText: 'สร้างตั๋ว'),
  doctorOrder(value: 'doctor_order', displayText: 'คำสั่งแพทย์');

  final String value;
  final String displayText;

  const CommentEventType({
    required this.value,
    required this.displayText,
  });

  /// แปลง string จาก DB เป็น enum
  /// ถ้าไม่ตรงกับค่าไหนเลย จะ fallback เป็น [comment]
  /// เพื่อป้องกัน crash กรณีที่ DB มีค่าใหม่ที่ app ยังไม่รู้จัก
  static CommentEventType fromString(String? value) {
    return CommentEventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CommentEventType.comment,
    );
  }
}

// ---------------------------------------------------------------------------
// TicketComment — โมเดลหลักของ comment/event ใน timeline
// ---------------------------------------------------------------------------

/// โมเดลสำหรับ comment หรือ event ใน timeline ของ ticket
///
/// Supabase query pattern:
/// ```dart
/// .from('B_Ticket_Comments')
/// .select('*, user_info!created_by(nickname, photo_url)')
/// .eq('ticket_id', ticketId)
/// .order('created_at')
/// ```
///
/// JSON response จะมี nested object `user_info` ที่มี nickname และ photo_url
/// ของผู้สร้าง comment (JOIN ผ่าน foreign key created_by → user_info.id)
class TicketComment {
  final int id;

  /// FK ไปยัง B_Ticket (ตั๋วที่ comment นี้สังกัด)
  final int ticketId;

  /// เนื้อหาของ comment — อาจเป็น null สำหรับ status_change event
  /// ที่ไม่มีข้อความประกอบ (แค่บันทึกว่าเปลี่ยนสถานะ)
  final String? content;

  /// uuid ของผู้สร้าง comment (FK ไปยัง user_info.id)
  final String? createdBy;

  /// วันเวลาที่สร้าง comment
  final DateTime createdAt;

  /// ประเภทของ event — ใช้แยกการแสดงผลใน timeline
  /// เช่น comment แสดงเป็นข้อความ, status_change แสดงเป็น badge
  final CommentEventType eventType;

  /// flag บอกว่าเป็นคำสั่งแพทย์หรือไม่
  /// ใช้ร่วมกับ eventType == doctorOrder เพื่อแสดง UI พิเศษ
  final bool isDoctorOrder;

  /// ชื่อแพทย์ (ถ้าเป็นคำสั่งแพทย์)
  final String? doctorName;

  /// สถานะเดิมก่อนเปลี่ยน — ใช้เฉพาะ eventType == statusChange
  final String? oldStatus;

  /// สถานะใหม่หลังเปลี่ยน — ใช้เฉพาะ eventType == statusChange
  final String? newStatus;

  /// รายชื่อ uuid ของ users ที่ถูก @mention ใน comment นี้
  /// เก็บเป็น uuid[] ใน DB — ใช้สำหรับส่ง notification ให้คนที่ถูก mention
  final List<String> mentionedUsers;

  // --- ข้อมูลจาก user_info (JOIN) ---

  /// ชื่อเล่นของผู้สร้าง comment (จาก user_info.nickname)
  final String? creatorNickname;

  /// URL รูปโปรไฟล์ของผู้สร้าง comment (จาก user_info.photo_url)
  final String? creatorPhotoUrl;

  const TicketComment({
    required this.id,
    required this.ticketId,
    this.content,
    this.createdBy,
    required this.createdAt,
    this.eventType = CommentEventType.comment,
    this.isDoctorOrder = false,
    this.doctorName,
    this.oldStatus,
    this.newStatus,
    this.mentionedUsers = const [],
    this.creatorNickname,
    this.creatorPhotoUrl,
  });

  /// สร้าง TicketComment จาก JSON ที่ได้จาก Supabase
  ///
  /// JSON structure:
  /// ```json
  /// {
  ///   "id": 1,
  ///   "ticket_id": 5,
  ///   "content": "some text",
  ///   "created_by": "uuid-here",
  ///   "created_at": "2026-03-17T10:00:00Z",
  ///   "event_type": "comment",
  ///   "is_doctor_order": false,
  ///   "doctor_name": null,
  ///   "old_status": null,
  ///   "new_status": null,
  ///   "mentioned_users": ["uuid1", "uuid2"],
  ///   "user_info": {
  ///     "nickname": "สมชาย",
  ///     "photo_url": "https://..."
  ///   }
  /// }
  /// ```
  factory TicketComment.fromJson(Map<String, dynamic> json) {
    // user_info เป็น nested object ที่ได้จาก Supabase JOIN
    // ใช้ select('*, user_info!created_by(nickname, photo_url)')
    // ถ้า created_by เป็น null จะไม่มี user_info กลับมา
    final userInfo = json['user_info'] as Map<String, dynamic>?;

    return TicketComment(
      id: json['id'] as int,
      ticketId: json['ticket_id'] as int,
      content: json['content'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      eventType: CommentEventType.fromString(json['event_type'] as String?),
      isDoctorOrder: json['is_doctor_order'] as bool? ?? false,
      doctorName: json['doctor_name'] as String?,
      oldStatus: json['old_status'] as String?,
      newStatus: json['new_status'] as String?,
      // mentioned_users เป็น uuid[] ใน DB — Supabase ส่งกลับมาเป็น List<dynamic>
      // ใช้ .toString() เพื่อแปลงแต่ละ element เป็น String อย่างปลอดภัย
      mentionedUsers: (json['mentioned_users'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      // ดึง nickname และ photo_url จาก nested user_info object
      creatorNickname: userInfo?['nickname'] as String?,
      creatorPhotoUrl: userInfo?['photo_url'] as String?,
    );
  }

  /// ข้อความแสดงเวลาสัมพัทธ์ (เช่น "5 นาทีที่แล้ว")
  /// ใช้ pattern เดียวกับ AppNotification.relativeTime
  /// เพื่อให้แสดงผลเวลาเป็นภาษาไทยสม่ำเสมอทั้งแอป
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'เมื่อสักครู่';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} วันที่แล้ว';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks สัปดาห์ที่แล้ว';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months เดือนที่แล้ว';
    }
  }
}
