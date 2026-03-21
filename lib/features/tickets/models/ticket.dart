// Ticket model สำหรับระบบ ticket (แจ้งปัญหา/ติดตามงาน)
// Map จาก v_tickets_dashboard Supabase view
// View นี้ JOIN หลายตาราง (users, residents, zones, comments, medicine)
// ดังนั้น fields จาก LEFT JOIN ต้องเป็น nullable ทั้งหมด

/// สถานะของ ticket
/// ใช้ value ตรงกับค่าที่เก็บใน DB column `status`
enum TicketStatus {
  /// เปิดใหม่ — ยังไม่มีใครหยิบทำ
  open('open', 'เปิด', '📋'),

  /// กำลังดำเนินการ — มีคนรับไปทำแล้ว
  inProgress('in_progress', 'กำลังดำเนินการ', '🔧'),

  /// รอติดตาม — ทำเสร็จแล้วแต่ต้องรอผล (เช่น รอยามาส่ง)
  awaitingFollowUp('awaiting_follow_up', 'รอติดตาม', '⏳'),

  /// เสร็จสิ้น — จบงานแล้ว
  resolved('resolved', 'เสร็จสิ้น', '✅'),

  /// ยกเลิก — ไม่ต้องทำแล้ว
  cancelled('cancelled', 'ยกเลิก', '❌');

  const TicketStatus(this.value, this.displayText, this.emoji);

  /// ค่าที่เก็บใน DB (ต้องตรงกับ column `status` ใน b_ticket)
  final String value;

  /// ข้อความภาษาไทยสำหรับแสดงผลใน UI
  final String displayText;

  /// Emoji สำหรับแสดงสถานะ (ใช้ใน card / list)
  final String emoji;

  /// แปลงจาก string ที่ได้จาก DB เป็น enum
  /// รองรับ backward compat:
  /// - 'completed' → resolved (ค่าเก่าที่เคยใช้)
  /// - 'closed' → resolved (ค่าเก่าที่เคยใช้)
  /// - ค่าที่ไม่รู้จัก → open (safe fallback)
  static TicketStatus fromString(String? value) {
    switch (value) {
      case 'open':
        return TicketStatus.open;
      case 'in_progress':
        return TicketStatus.inProgress;
      case 'awaiting_follow_up':
        return TicketStatus.awaitingFollowUp;
      case 'resolved':
        return TicketStatus.resolved;
      // Backward compat: ค่าเก่าที่อาจยังอยู่ใน DB
      case 'completed':
      case 'closed':
        return TicketStatus.resolved;
      case 'cancelled':
        return TicketStatus.cancelled;
      default:
        return TicketStatus.open;
    }
  }
}

/// หมวดหมู่ของ ticket
/// ใช้แยกประเภท ticket เช่น เรื่องทั่วไป, เรื่องยา, เรื่องงาน
enum TicketCategory {
  /// ทั่วไป — เรื่องที่ไม่เข้าหมวดอื่น
  general('general', 'ทั่วไป', '📝'),

  /// ยา — เกี่ยวกับยาของผู้พัก เช่น ยาหมด, สั่งยาใหม่
  medicine('medicine', 'ยา', '💊'),

  /// งาน — เกี่ยวกับ task/ภารกิจ
  task('task', 'งาน', '📋');

  const TicketCategory(this.value, this.displayText, this.emoji);

  /// ค่าที่เก็บใน DB
  final String value;

  /// ข้อความภาษาไทยสำหรับแสดงผล
  final String displayText;

  /// Emoji สำหรับแสดงหมวดหมู่
  final String emoji;

  /// แปลงจาก string เป็น enum
  /// ถ้าค่าไม่ตรงหรือ null → fallback เป็น general
  static TicketCategory fromString(String? value) {
    switch (value) {
      case 'medicine':
        return TicketCategory.medicine;
      case 'task':
        return TicketCategory.task;
      case 'general':
      default:
        // ค่าที่ไม่รู้จักถือเป็น general เสมอ
        return TicketCategory.general;
    }
  }
}

/// Model สำหรับ Ticket จาก v_tickets_dashboard view
///
/// View นี้ JOIN ข้อมูลจากหลายตาราง:
/// - b_ticket (ตารางหลัก)
/// - users (ข้อมูลผู้สร้าง)
/// - Residents (ข้อมูลผู้พักอาศัย)
/// - zones (ข้อมูลโซน)
/// - b_ticket_comment (คอมเมนต์ล่าสุด)
/// - C_Medicine_List (ข้อมูลยา)
///
/// เนื่องจากใช้ LEFT JOIN ทุก field ที่มาจากตารางอื่น
/// ต้องเป็น nullable (อาจเป็น null ถ้าไม่มีข้อมูล JOIN)
class Ticket {
  // ===== ข้อมูลหลักจาก b_ticket =====

  /// Primary key ของ ticket
  final int id;

  /// เวลาที่สร้าง ticket
  final DateTime createdAt;

  /// หัวข้อ ticket (column: ticket_Title)
  final String? title;

  /// รายละเอียดปัญหา (column: ticket_Description)
  final String? description;

  /// ID ของศูนย์ดูแล
  final int? nursinghomeId;

  /// UUID ของผู้สร้าง ticket
  final String? createdBy;

  /// รายการ UUID ของผู้รับผิดชอบ (assignee)
  /// เก็บเป็น uuid[] ใน DB — ต้อง parse จาก dynamic list อย่างระวัง
  /// เพราะ Supabase อาจส่งมาเป็น dynamic list ที่มี String หรือ null
  final List<String> assignee;

  /// สถานะปัจจุบันของ ticket
  final TicketStatus status;

  /// เป็น ticket ด่วนหรือไม่ (priority flag)
  final bool priority;

  /// อยู่ใน agenda ประชุมหรือไม่ (column: meeting_Agenda)
  final bool meetingAgenda;

  /// วันที่ต้องติดตาม (column: follow_Up_Date)
  /// เป็น DATE type ใน DB (ไม่มีเวลา) → ไม่ต้อง .toLocal()
  final DateTime? followUpDate;

  /// ID ของผู้พักอาศัยที่เกี่ยวข้อง (ถ้ามี)
  final int? residentId;

  /// หมวดหมู่ ticket
  final TicketCategory category;

  /// สถานะ stock สำหรับ ticket ยา (เช่น 'low', 'out_of_stock')
  final String? stockStatus;

  /// ที่มาของ ticket (เช่น 'incident', 'medicine')
  final String? sourceType;

  /// ID ของ source ที่สร้าง ticket (เช่น incident_id, med_history_id)
  final int? sourceId;

  /// ID ของรายการยาที่เกี่ยวข้อง (ถ้าเป็น ticket ยา)
  final int? medListId;

  /// รายการ template_task_id ที่เกี่ยวข้อง (bigint[] ใน DB)
  /// ใช้เชื่อมกับ repeated tasks ที่เกี่ยวข้อง
  final List<int> templateTaskId;

  // ===== Computed fields จาก view (คำนวณใน SQL) =====

  /// ticket เกินกำหนด follow_Up_Date หรือไม่
  /// คำนวณจาก follow_Up_Date < CURRENT_DATE AND status ไม่ใช่ resolved/cancelled
  final bool isOverdue;

  /// จำนวนวันจนถึง follow_Up_Date (ลบ = เกินกำหนด, บวก = เหลืออีกกี่วัน)
  final int? daysUntilFollowUp;

  // ===== Joined fields จาก LEFT JOIN (ทั้งหมด nullable) =====

  /// ชื่อเล่นผู้สร้าง (จาก users table)
  final String? createdByNickname;

  /// URL รูปผู้สร้าง (จาก users table)
  final String? createdByPhotoUrl;

  /// ชื่อผู้พักอาศัย (จาก Residents table)
  final String? residentName;

  /// ชื่อโซน (จาก zones table)
  final String? zoneName;

  /// เนื้อหาคอมเมนต์ล่าสุด (จาก b_ticket_comment)
  final String? lastCommentContent;

  /// เวลาคอมเมนต์ล่าสุด (จาก b_ticket_comment)
  final DateTime? lastCommentAt;

  /// ชื่อเล่นผู้คอมเมนต์ล่าสุด (จาก b_ticket_comment + users)
  final String? lastCommentNickname;

  // ===== Medicine fields (nullable — มีเฉพาะ ticket หมวดยา) =====

  /// ชื่อการค้าของยา (จาก C_Medicine_List)
  final String? medBrandName;

  /// ชื่อสามัญของยา (จาก C_Medicine_List)
  final String? medGenericName;

  /// URL รูปเม็ดยา (จาก C_Medicine_List)
  final String? medPillpicUrl;

  const Ticket({
    required this.id,
    required this.createdAt,
    this.title,
    this.description,
    this.nursinghomeId,
    this.createdBy,
    this.assignee = const [],
    this.status = TicketStatus.open,
    this.priority = false,
    this.meetingAgenda = false,
    this.followUpDate,
    this.residentId,
    this.category = TicketCategory.general,
    this.stockStatus,
    this.sourceType,
    this.sourceId,
    this.medListId,
    this.templateTaskId = const [],
    this.isOverdue = false,
    this.daysUntilFollowUp,
    this.createdByNickname,
    this.createdByPhotoUrl,
    this.residentName,
    this.zoneName,
    this.lastCommentContent,
    this.lastCommentAt,
    this.lastCommentNickname,
    this.medBrandName,
    this.medGenericName,
    this.medPillpicUrl,
  });

  /// Parse จาก JSON (v_tickets_dashboard view)
  ///
  /// หลักการ parsing สำคัญ:
  /// 1. Array fields (assignee, template_task_id) — ต้อง handle dynamic list จาก Supabase
  /// 2. DATE type (follow_Up_Date) — parse ตรงๆ ไม่ต้อง .toLocal() เพราะไม่มี timezone
  /// 3. LEFT JOIN fields — ใช้ `as String?` ไม่ใช่ `as String` (อาจเป็น null)
  /// 4. Enum fields — ใช้ fromString() ที่มี fallback เสมอ
  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      title: json['ticket_Title'] as String?,
      description: json['ticket_Description'] as String?,
      nursinghomeId: json['nursinghome_id'] as int?,
      createdBy: json['created_by'] as String?,

      // assignee เป็น uuid[] ใน DB
      // Supabase ส่งมาเป็น List<dynamic> ที่แต่ละ element อาจเป็น String
      // ใช้ .toString() เพื่อความปลอดภัย กรณี element ไม่ใช่ String
      assignee: (json['assignee'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],

      // status ใช้ fromString ที่รองรับค่าเก่า (completed/closed → resolved)
      status: TicketStatus.fromString(json['status'] as String? ?? 'open'),
      priority: json['priority'] as bool? ?? false,
      meetingAgenda: json['meeting_Agenda'] as bool? ?? false,

      // follow_Up_Date เป็น DATE type (ไม่มีเวลา)
      // Parse ตรงๆ จาก string format 'YYYY-MM-DD'
      // ไม่ต้อง .toLocal() เพราะ DATE ไม่มี timezone component
      followUpDate: json['follow_Up_Date'] != null
          ? DateTime.parse(json['follow_Up_Date'] as String)
          : null,

      residentId: json['resident_id'] as int?,

      // category ใช้ fromString ที่ fallback เป็น general
      category:
          TicketCategory.fromString(json['category'] as String? ?? 'general'),

      stockStatus: json['stock_status'] as String?,
      sourceType: json['source_type'] as String?,
      sourceId: json['source_id'] as int?,
      medListId: json['med_list_id'] as int?,

      // template_task_id เป็น bigint[] ใน DB
      // Supabase ส่งมาเป็น List<dynamic> ที่แต่ละ element เป็น num
      // ใช้ (e as num).toInt() เพื่อ handle ทั้ง int และ double
      templateTaskId: (json['template_task_id'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],

      // Computed fields จาก view (SQL คำนวณให้แล้ว)
      isOverdue: json['is_overdue'] as bool? ?? false,
      daysUntilFollowUp: json['days_until_follow_up'] as int?,

      // Joined fields — ทั้งหมดใช้ `as String?` เพราะมาจาก LEFT JOIN
      // ถ้าไม่มี matching row จะได้ null
      createdByNickname: json['created_by_nickname'] as String?,
      createdByPhotoUrl: json['created_by_photo_url'] as String?,
      residentName: json['resident_name'] as String?,
      zoneName: json['zone_name'] as String?,
      lastCommentContent: json['last_comment_content'] as String?,

      // last_comment_at เป็น timestamptz — parse แล้วต้อง handle null
      lastCommentAt: json['last_comment_at'] != null
          ? DateTime.parse(json['last_comment_at'] as String)
          : null,

      lastCommentNickname: json['last_comment_nickname'] as String?,

      // Medicine fields — มีเฉพาะเมื่อ category = medicine และมี med_list_id
      medBrandName: json['med_brand_name'] as String?,
      medGenericName: json['med_generic_name'] as String?,
      medPillpicUrl: json['med_pillpic_url'] as String?,
    );
  }

  // ===== Computed properties =====

  /// ตรวจสอบว่าเป็น ticket ยาหรือไม่
  bool get isMedicineTicket => category == TicketCategory.medicine;

  /// ตรวจสอบว่าเป็น ticket ที่ยังเปิดอยู่ (ไม่ใช่ resolved/cancelled)
  bool get isActive =>
      status != TicketStatus.resolved && status != TicketStatus.cancelled;

  /// ตรวจสอบว่ามีผู้พักอาศัยเกี่ยวข้องหรือไม่
  bool get hasResident => residentId != null;

  /// ตรวจสอบว่ามีคนรับผิดชอบหรือไม่
  bool get hasAssignee => assignee.isNotEmpty;

  /// ตรวจสอบว่ามีคอมเมนต์หรือไม่
  bool get hasComment => lastCommentContent != null;

  /// ตรวจสอบว่ามี follow up date หรือไม่
  bool get hasFollowUpDate => followUpDate != null;

  /// ตรวจสอบว่า user เป็นผู้สร้าง ticket หรือไม่
  bool isCreatedByUser(String? userId) {
    if (userId == null || createdBy == null) return false;
    return createdBy == userId;
  }

  /// ตรวจสอบว่า user เป็นผู้รับผิดชอบ ticket หรือไม่
  bool isAssignedToUser(String? userId) {
    if (userId == null) return false;
    return assignee.contains(userId);
  }

  /// ข้อความแสดงสถานะพร้อม emoji (เช่น "🔧 กำลังดำเนินการ")
  String get statusDisplayWithEmoji => '${status.emoji} ${status.displayText}';

  /// ข้อความแสดงหมวดหมู่พร้อม emoji (เช่น "💊 ยา")
  String get categoryDisplayWithEmoji =>
      '${category.emoji} ${category.displayText}';

  /// ชื่อยาสำหรับแสดงผล (brand name หรือ generic name)
  /// ใช้ brand name เป็นหลัก ถ้าไม่มีใช้ generic name
  String? get medDisplayName => medBrandName ?? medGenericName;

  /// สร้าง copy พร้อมเปลี่ยนค่าบางส่วน
  Ticket copyWith({
    int? id,
    DateTime? createdAt,
    String? title,
    String? description,
    int? nursinghomeId,
    String? createdBy,
    List<String>? assignee,
    TicketStatus? status,
    bool? priority,
    bool? meetingAgenda,
    DateTime? followUpDate,
    int? residentId,
    TicketCategory? category,
    String? stockStatus,
    String? sourceType,
    int? sourceId,
    int? medListId,
    List<int>? templateTaskId,
    bool? isOverdue,
    int? daysUntilFollowUp,
    String? createdByNickname,
    String? createdByPhotoUrl,
    String? residentName,
    String? zoneName,
    String? lastCommentContent,
    DateTime? lastCommentAt,
    String? lastCommentNickname,
    String? medBrandName,
    String? medGenericName,
    String? medPillpicUrl,
  }) {
    return Ticket(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      description: description ?? this.description,
      nursinghomeId: nursinghomeId ?? this.nursinghomeId,
      createdBy: createdBy ?? this.createdBy,
      assignee: assignee ?? this.assignee,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      meetingAgenda: meetingAgenda ?? this.meetingAgenda,
      followUpDate: followUpDate ?? this.followUpDate,
      residentId: residentId ?? this.residentId,
      category: category ?? this.category,
      stockStatus: stockStatus ?? this.stockStatus,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      medListId: medListId ?? this.medListId,
      templateTaskId: templateTaskId ?? this.templateTaskId,
      isOverdue: isOverdue ?? this.isOverdue,
      daysUntilFollowUp: daysUntilFollowUp ?? this.daysUntilFollowUp,
      createdByNickname: createdByNickname ?? this.createdByNickname,
      createdByPhotoUrl: createdByPhotoUrl ?? this.createdByPhotoUrl,
      residentName: residentName ?? this.residentName,
      zoneName: zoneName ?? this.zoneName,
      lastCommentContent: lastCommentContent ?? this.lastCommentContent,
      lastCommentAt: lastCommentAt ?? this.lastCommentAt,
      lastCommentNickname: lastCommentNickname ?? this.lastCommentNickname,
      medBrandName: medBrandName ?? this.medBrandName,
      medGenericName: medGenericName ?? this.medGenericName,
      medPillpicUrl: medPillpicUrl ?? this.medPillpicUrl,
    );
  }

  @override
  String toString() =>
      'Ticket(id: $id, title: $title, status: ${status.value})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ticket && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
