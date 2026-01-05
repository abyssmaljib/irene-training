/// Lightweight model for shift activity timeline
class ShiftActivityItem {
  final int logId;
  final String title;
  final String? residentName;
  final int? residentId;
  final DateTime completedAt;
  final DateTime? expectedDateTime;

  const ShiftActivityItem({
    required this.logId,
    required this.title,
    this.residentName,
    this.residentId,
    required this.completedAt,
    this.expectedDateTime,
  });

  factory ShiftActivityItem.fromJson(Map<String, dynamic> json) {
    return ShiftActivityItem(
      logId: json['log_id'] as int,
      title: json['task_title'] as String? ?? '',
      residentName: json['resident_name'] as String?,
      residentId: json['resident_id'] as int?,
      completedAt: DateTime.parse(json['log_completed_at'] as String),
      expectedDateTime: json['ExpectedDateTime'] != null
          ? DateTime.tryParse(json['ExpectedDateTime'] as String)
          : null,
    );
  }

  /// เช็คว่าเป็นงาน "น้ำใจ" (ช่วยคนไข้ที่ไม่ใช่ของตัวเอง)
  bool isKindnessTask(List<int> myResidentIds) {
    if (residentId == null) return false;
    return !myResidentIds.contains(residentId);
  }

  /// Calculate timeliness status
  /// Returns: 'onTime', 'slightlyLate', 'veryLate'
  String get timelinessStatus {
    if (expectedDateTime == null) return 'onTime';

    final diff = completedAt.difference(expectedDateTime!).inMinutes.abs();

    if (diff <= 30) return 'onTime'; // Green: within +/- 30 min
    if (diff <= 60) return 'slightlyLate'; // Yellow: within +/- 60 min
    return 'veryLate'; // Red: > 60 min
  }

  /// Format completed time as HH:mm (Thai local time)
  String get formattedTime {
    final localTime = completedAt.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Display text: "คุณResidentName - Title" or just "Title"
  String get displayText {
    if (residentName != null && residentName!.isNotEmpty) {
      return 'คุณ$residentName - $title';
    }
    return title;
  }
}
