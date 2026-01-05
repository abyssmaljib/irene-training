/// Model สำหรับ Task ในแต่ละ Time Block
class TimeBlockTask {
  final int logId;
  final String taskTitle;
  final String? residentName;
  final String status; // 'complete', 'pending', 'refer', 'postpone'
  final DateTime? completedAt;
  final DateTime? expectedDateTime;

  const TimeBlockTask({
    required this.logId,
    required this.taskTitle,
    this.residentName,
    required this.status,
    this.completedAt,
    this.expectedDateTime,
  });

  factory TimeBlockTask.fromJson(Map<String, dynamic> json) {
    return TimeBlockTask(
      logId: json['log_id'] as int,
      taskTitle: json['task_title'] as String? ?? '',
      residentName: json['resident_name'] as String?,
      status: json['status'] as String? ?? 'pending',
      completedAt: json['log_completed_at'] != null
          ? DateTime.tryParse(json['log_completed_at'] as String)
          : null,
      expectedDateTime: json['ExpectedDateTime'] != null
          ? DateTime.tryParse(json['ExpectedDateTime'] as String)
          : null,
    );
  }

  bool get isCompleted =>
      status == 'complete' || status == 'refer' || status == 'postpone';

  /// Display name with resident
  String get displayText {
    if (residentName != null && residentName!.isNotEmpty) {
      return 'คุณ$residentName - $taskTitle';
    }
    return taskTitle;
  }

  /// Formatted completed time (Thai local time)
  String? get formattedCompletedTime {
    if (completedAt == null) return null;
    final localTime = completedAt!.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Calculate timeliness status
  String get timelinessStatus {
    if (!isCompleted || completedAt == null || expectedDateTime == null) {
      return 'pending';
    }

    final diff = completedAt!.difference(expectedDateTime!).inMinutes.abs();

    if (diff <= 30) return 'onTime';
    if (diff <= 60) return 'slightlyLate';
    return 'veryLate';
  }
}
