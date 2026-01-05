/// Model สำหรับ Progress ของแต่ละ Time Block
class TimeBlockProgress {
  final String timeBlock; // e.g., "07:00-09:00"
  final String label; // e.g., "เช้า 1"
  final int totalTasks;
  final int completedTasks;
  final int onTimeCount;
  final int slightlyLateCount;
  final int veryLateCount;
  final String? icon; // emoji icon

  const TimeBlockProgress({
    required this.timeBlock,
    required this.label,
    required this.totalTasks,
    required this.completedTasks,
    this.onTimeCount = 0,
    this.slightlyLateCount = 0,
    this.veryLateCount = 0,
    this.icon,
  });

  /// Percent calculations for stacked bar
  double get onTimePercent =>
      completedTasks > 0 ? (onTimeCount / completedTasks) * 100 : 0;
  double get slightlyLatePercent =>
      completedTasks > 0 ? (slightlyLateCount / completedTasks) * 100 : 0;
  double get veryLatePercent =>
      completedTasks > 0 ? (veryLateCount / completedTasks) * 100 : 0;

  double get progress =>
      totalTasks > 0 ? completedTasks / totalTasks : 0.0;

  bool get isComplete => completedTasks >= totalTasks && totalTasks > 0;

  bool get hasStarted => completedTasks > 0;

  String get progressText => '$completedTasks/$totalTasks';

  /// สร้างจาก grouped data
  factory TimeBlockProgress.fromData({
    required String timeBlock,
    required int total,
    required int completed,
  }) {
    // กำหนด label และ icon ตาม time block
    String label;
    String? icon;

    switch (timeBlock) {
      case '07:00-09:00':
        label = 'เช้า 1';
        icon = '☀️';
        break;
      case '09:00-11:00':
        label = 'เช้า 2';
        icon = '☀️';
        break;
      case '11:00-13:00':
        label = 'กลางวัน';
        icon = '🌤️';
        break;
      case '13:00-15:00':
        label = 'บ่าย 1';
        icon = '🌤️';
        break;
      case '15:00-17:00':
        label = 'บ่าย 2';
        icon = '🌥️';
        break;
      case '17:00-19:00':
        label = 'เย็น';
        icon = '🌅';
        break;
      case '19:00-21:00':
        label = 'ค่ำ 1';
        icon = '🌙';
        break;
      case '21:00-23:00':
        label = 'ค่ำ 2';
        icon = '🌙';
        break;
      case '23:00-01:00':
        label = 'ดึก 1';
        icon = '🌑';
        break;
      case '01:00-03:00':
        label = 'ดึก 2';
        icon = '🌑';
        break;
      case '03:00-05:00':
        label = 'ดึก 3';
        icon = '🌑';
        break;
      case '05:00-07:00':
        label = 'เช้ามืด';
        icon = '🌄';
        break;
      default:
        label = timeBlock;
        icon = '📋';
    }

    return TimeBlockProgress(
      timeBlock: timeBlock,
      label: label,
      totalTasks: total,
      completedTasks: completed,
      icon: icon,
    );
  }

  /// สร้างจาก grouped data พร้อม timeliness counts
  factory TimeBlockProgress.fromDataWithTimeliness({
    required String timeBlock,
    required int total,
    required int completed,
    required int onTime,
    required int slightlyLate,
    required int veryLate,
  }) {
    // กำหนด label และ icon ตาม time block
    String label;
    String? icon;

    switch (timeBlock) {
      case '07:00-09:00':
        label = 'เช้า 1';
        icon = '☀️';
        break;
      case '09:00-11:00':
        label = 'เช้า 2';
        icon = '☀️';
        break;
      case '11:00-13:00':
        label = 'กลางวัน';
        icon = '🌤️';
        break;
      case '13:00-15:00':
        label = 'บ่าย 1';
        icon = '🌤️';
        break;
      case '15:00-17:00':
        label = 'บ่าย 2';
        icon = '🌥️';
        break;
      case '17:00-19:00':
        label = 'เย็น';
        icon = '🌅';
        break;
      case '19:00-21:00':
        label = 'ค่ำ 1';
        icon = '🌙';
        break;
      case '21:00-23:00':
        label = 'ค่ำ 2';
        icon = '🌙';
        break;
      case '23:00-01:00':
        label = 'ดึก 1';
        icon = '🌑';
        break;
      case '01:00-03:00':
        label = 'ดึก 2';
        icon = '🌑';
        break;
      case '03:00-05:00':
        label = 'ดึก 3';
        icon = '🌑';
        break;
      case '05:00-07:00':
        label = 'เช้ามืด';
        icon = '🌄';
        break;
      default:
        label = timeBlock;
        icon = '📋';
    }

    return TimeBlockProgress(
      timeBlock: timeBlock,
      label: label,
      totalTasks: total,
      completedTasks: completed,
      onTimeCount: onTime,
      slightlyLateCount: slightlyLate,
      veryLateCount: veryLate,
      icon: icon,
    );
  }
}
