/// Model สำหรับ Task Log จาก v2_task_logs_with_details view
class TaskLog {
  final int logId;
  final int? taskId;
  final String? title;
  final String? description; // task description จาก task template
  final String? descript; // หมายเหตุที่ user กรอกตอนรายงานปัญหา
  final String? status; // null = pending, 'complete' = done, 'problem' = problem
  final DateTime? expectedDateTime;
  final DateTime? completedAt;
  final String? completedByUid;
  final String? completedByNickname;
  final int? residentId;
  final String? residentName;
  final String? residentPictureUrl;
  final int? zoneId;
  final String? zoneName;
  final String? taskType;
  final String? timeBlock; // "07:00 - 09:00", "09:00 - 11:00", etc.
  final bool requireImage;
  final String? confirmImage;
  final String? formUrl;
  final String? sampleImageUrl;
  final int? postponeFrom;
  final int? postponeTo;
  final DateTime? expectedDatePostponeFrom; // วันเวลาเดิมที่ถูกเลื่อนมา
  final bool mustCompleteByPost; // งานต้องทำหลังจากโพสต์

  // Role assignment fields
  final int? assignedRoleId;
  final String? assignedRoleName;

  // Recurrence note (ข้อความกำกับสำคัญจาก A_Repeated_Task)
  final String? recurNote;

  // Recurrence fields
  final int? recurrenceInterval; // ทุกกี่ (วัน/สัปดาห์/เดือน)
  final String? recurrenceType; // 'วัน', 'สัปดาห์', 'เดือน'
  final List<String> daysOfWeek; // ['จันทร์', 'อังคาร', ...]
  final List<int> recurringDates; // [1, 15, 28] วันที่ในเดือน

  // History seen users (รายชื่อ user ที่เคยเห็น task นี้แล้ว)
  final List<String> historySeenUsers;

  // Resident special status (refer = ส่งต่อ/ย้ายออก)
  final String? residentSpecialStatus;

  const TaskLog({
    required this.logId,
    this.taskId,
    this.title,
    this.description,
    this.descript,
    this.status,
    this.expectedDateTime,
    this.completedAt,
    this.completedByUid,
    this.completedByNickname,
    this.residentId,
    this.residentName,
    this.residentPictureUrl,
    this.zoneId,
    this.zoneName,
    this.taskType,
    this.timeBlock,
    this.requireImage = false,
    this.confirmImage,
    this.formUrl,
    this.sampleImageUrl,
    this.postponeFrom,
    this.postponeTo,
    this.expectedDatePostponeFrom,
    this.mustCompleteByPost = false,
    this.assignedRoleId,
    this.assignedRoleName,
    this.recurNote,
    this.recurrenceInterval,
    this.recurrenceType,
    this.daysOfWeek = const [],
    this.recurringDates = const [],
    this.historySeenUsers = const [],
    this.residentSpecialStatus,
  });

  /// Parse จาก Supabase response
  factory TaskLog.fromJson(Map<String, dynamic> json) {
    return TaskLog(
      logId: json['log_id'] as int,
      taskId: json['task_id'] as int?,
      title: json['task_title'] as String?,
      description: json['task_description'] as String?,
      descript: json['Descript'] as String?, // หมายเหตุจาก user
      status: json['status'] as String?,
      expectedDateTime: _parseDateTime(json['ExpectedDateTime']),
      completedAt: _parseDateTime(json['log_completed_at']),
      completedByUid: json['completed_by'] as String?,
      completedByNickname: json['completed_by_nickname'] as String?,
      residentId: json['resident_id'] as int?,
      residentName: json['resident_name'] as String?,
      residentPictureUrl: json['i_picture_url'] as String?,
      zoneId: json['zone_id'] as int?,
      zoneName: json['zone_name'] as String?,
      taskType: json['taskType'] as String?,
      timeBlock: json['timeBlock'] as String?,
      requireImage: json['reaquire_image'] == true ||
          json['must_complete_by_image'] == true,
      confirmImage: json['confirmImage'] as String?,
      formUrl: json['form_url'] as String?,
      sampleImageUrl: json['sampleImageURL'] as String?,
      postponeFrom: json['postpone_from'] as int?,
      postponeTo: json['postpone_to'] as int?,
      expectedDatePostponeFrom: _parseDateTime(json['expecteddate_postpone_from']),
      mustCompleteByPost: json['mustCompleteByPost'] == true,
      assignedRoleId: json['assigned_role_id'] as int?,
      assignedRoleName: json['assigned_role_name'] as String?,
      recurNote: json['recurNote'] as String?,
      recurrenceInterval: json['recurrence_interval'] as int?,
      recurrenceType: json['recurrence_type'] as String?,
      daysOfWeek: _parseStringList(json['days_of_week']),
      recurringDates: _parseIntList(json['recurring_dates']),
      historySeenUsers: _parseStringList(json['history_seen_users']),
      residentSpecialStatus: json['s_special_status'] as String?,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static List<int> _parseIntList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList();
    }
    return [];
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // Helper getters
  bool get isDone => status == 'complete';
  bool get isProblem => status == 'problem';
  bool get isPending => status == null;
  bool get isPostponed => status == 'postpone';
  bool get isReferred => status == 'refer';

  /// ตรวจสอบว่า resident ถูก refer หรือ home (ส่งต่อ/กลับบ้าน) หรือไม่
  /// ใช้สำหรับซ่อน tasks ของ residents ที่ไม่ได้อยู่แล้ว
  bool get isResidentReferred =>
      residentSpecialStatus == 'Refer' || residentSpecialStatus == 'Home';

  /// ตรวจสอบว่า task ควรถูกซ่อนหรือไม่
  /// - resident ถูก refer/home
  bool get shouldBeHidden => isResidentReferred;

  /// มีรูปตัวอย่างให้ดู
  bool get hasSampleImage => sampleImageUrl != null && sampleImageUrl!.isNotEmpty;

  /// ตรวจสอบว่า task นี้มีอัพเดตที่ user ยังไม่เคยเห็น
  /// - ไม่ใช่งานจัดยา (taskType != 'จัดยา')
  /// - user ยังไม่อยู่ใน historySeenUsers
  bool hasUnseenUpdate(String? userId) {
    if (userId == null) return false;
    if (taskType == 'จัดยา') return false;
    return !historySeenUsers.contains(userId);
  }

  /// ตรวจสอบว่างานอยู่ภายในช่วงเวลาที่กำหนดหรือไม่
  bool isWithinTimeRange(DateTime start, DateTime end) {
    if (expectedDateTime == null) return false;
    return expectedDateTime!.isAfter(start) &&
        expectedDateTime!.isBefore(end.add(const Duration(seconds: 1)));
  }

  /// ตรวจสอบว่างานอยู่ใน zones ที่กำหนดหรือไม่
  bool isInZones(List<int> zones) {
    if (zones.isEmpty) return true;
    if (zoneId == null) return false;
    return zones.contains(zoneId);
  }

  /// ตรวจสอบว่างานอยู่ใน residents ที่กำหนดหรือไม่
  bool isInResidents(List<int> residentIds) {
    if (residentIds.isEmpty) return true;
    if (residentId == null) return false;
    return residentIds.contains(residentId);
  }

  /// ตรวจสอบว่างานถูก assign ให้ role ที่กำหนดหรือไม่
  /// ถ้า assignedRoleId เป็น null = งานสำหรับทุก role
  bool isAssignedToRole(int? roleId) {
    if (assignedRoleId == null) return true; // งานสำหรับทุก role
    if (roleId == null) return true; // ไม่ได้ filter ตาม role
    return assignedRoleId == roleId;
  }

  @override
  String toString() {
    return 'TaskLog(logId: $logId, title: $title, status: $status, timeBlock: $timeBlock)';
  }
}
