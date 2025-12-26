/// Model สำหรับข้อมูลสถานะการเขียนรายงาน V/S ของผู้พัก
/// ดึงจากตาราง vitalSign
class ReportCompletionStatus {
  final int residentId;
  final bool hasMorningReport; // มีรายงานเวรเช้า
  final bool hasNightReport; // มีรายงานเวรดึก
  final DateTime? morningReportAt; // เวลาที่ส่งรายงานเวรเช้า
  final DateTime? nightReportAt; // เวลาที่ส่งรายงานเวรดึก
  final String? morningReportBy; // ชื่อผู้ส่งรายงานเวรเช้า
  final String? nightReportBy; // ชื่อผู้ส่งรายงานเวรดึก

  const ReportCompletionStatus({
    required this.residentId,
    this.hasMorningReport = false,
    this.hasNightReport = false,
    this.morningReportAt,
    this.nightReportAt,
    this.morningReportBy,
    this.nightReportBy,
  });

  /// ตรวจสอบว่าส่งรายงานครบทั้ง 2 เวรหรือไม่
  bool get isCompleted => hasMorningReport && hasNightReport;

  /// ตรวจสอบว่าส่งรายงานบางส่วน
  bool get isPartial =>
      (hasMorningReport || hasNightReport) && !isCompleted;

  /// ตรวจสอบว่ายังไม่ได้ส่งรายงานเลย
  bool get isNotStarted => !hasMorningReport && !hasNightReport;

  /// จำนวนรายงานที่ส่งแล้ว
  int get completedCount => (hasMorningReport ? 1 : 0) + (hasNightReport ? 1 : 0);
}
