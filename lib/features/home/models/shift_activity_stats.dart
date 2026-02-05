import 'package:flutter/foundation.dart' show debugPrint;
import 'break_time_option.dart';
import 'shift_activity_item.dart';

/// รายละเอียดช่วงว่าง (dead air gap)
class DeadAirGap {
  final DateTime gapStart;
  final DateTime gapEnd;
  final int gapMinutes;
  final int breakMinutes;
  final int deadAirMinutes;

  const DeadAirGap({
    required this.gapStart,
    required this.gapEnd,
    required this.gapMinutes,
    required this.breakMinutes,
    required this.deadAirMinutes,
  });
}

/// Model สำหรับ stats summary ของกิจกรรมในเวร
class ShiftActivityStats {
  final int totalCompleted;
  final int teamTotalCompleted; // เพิ่ม field สำหรับงานที่ทีมทำเสร็จ
  final int onTimeCount;
  final int slightlyLateCount;
  final int veryLateCount;
  final int kindnessCount; // งาน "น้ำใจ" ช่วยคนอื่น
  final int totalTasks; // รวมทั้ง completed และ pending
  final int deadAirMinutes; // เวลาอู้งานรวม (นาที) = totalGapMinutes - allowance - breakOverlapMinutes
  final int totalWorkMinutes; // เวลาทำงานทั้งหมดตั้งแต่ clock-in (นาที)
  final List<DeadAirGap> deadAirGaps; // รายละเอียดช่วงว่างแต่ละช่วง
  final int totalBreakMinutes; // เวลาพักรวมที่ทับกับ gaps (สำหรับ UI)
  final int totalGapMinutes; // รวมช่วงห่างทั้งหมด (ก่อนหัก allowance และ break)

  const ShiftActivityStats({
    required this.totalCompleted,
    required this.teamTotalCompleted,
    required this.onTimeCount,
    required this.slightlyLateCount,
    required this.veryLateCount,
    required this.kindnessCount,
    required this.totalTasks,
    required this.deadAirMinutes,
    required this.totalWorkMinutes,
    this.deadAirGaps = const [],
    this.totalBreakMinutes = 0,
    this.totalGapMinutes = 0,
  });

  /// สร้าง empty stats
  factory ShiftActivityStats.empty() {
    return const ShiftActivityStats(
      totalCompleted: 0,
      teamTotalCompleted: 0,
      onTimeCount: 0,
      slightlyLateCount: 0,
      veryLateCount: 0,
      kindnessCount: 0,
      totalTasks: 0,
      deadAirMinutes: 0,
      totalWorkMinutes: 0,
      totalGapMinutes: 0,
    );
  }

  /// สร้างจาก backend dead air value
  /// ใช้เมื่อ deadAirMinutes มาจาก database (คำนวณโดย trigger)
  /// สูตร: Dead Air = Total Gaps - Task Time - 75 นาที (allowance) - Break Overlap
  /// Task Time: Score 1-3 = 5 นาที, Score 4-6 = 10 นาที, Score 7-10 = 15 นาที
  factory ShiftActivityStats.fromBackend({
    required List<ShiftActivityItem> activities,
    required int totalTasks,
    required int teamTotalCompleted,
    required DateTime clockInTime,
    required int deadAirMinutes, // จาก backend (ClockInOut.deadAirMinutes)
    List<int> myResidentIds = const [],
  }) {
    int onTime = 0;
    int slightlyLate = 0;
    int veryLate = 0;
    int kindness = 0;

    for (final activity in activities) {
      // Check if kindness task (helped someone else's resident)
      if (activity.isKindnessTask(myResidentIds)) {
        kindness++;
        continue;
      }

      switch (activity.timelinessStatus) {
        case 'onTime':
          onTime++;
          break;
        case 'slightlyLate':
          slightlyLate++;
          break;
        case 'veryLate':
          veryLate++;
          break;
      }
    }

    // คำนวณเวลาทำงานทั้งหมด
    final now = DateTime.now();
    final totalWorkMinutes = now.difference(clockInTime).inMinutes;

    return ShiftActivityStats(
      totalCompleted: activities.length,
      teamTotalCompleted: teamTotalCompleted,
      onTimeCount: onTime,
      slightlyLateCount: slightlyLate,
      veryLateCount: veryLate,
      kindnessCount: kindness,
      totalTasks: totalTasks,
      deadAirMinutes: deadAirMinutes, // ใช้ค่าจาก backend โดยตรง
      totalWorkMinutes: totalWorkMinutes,
      deadAirGaps: const [], // ไม่มี breakdown จาก backend
      totalBreakMinutes: 0, // ไม่มีจาก backend
      totalGapMinutes: 0, // ไม่มีจาก backend
    );
  }

  /// สร้างจาก list ของ activities
  factory ShiftActivityStats.fromActivities({
    required List<ShiftActivityItem> activities,
    required int totalTasks,
    required int teamTotalCompleted, // รับค่า teamTotalCompleted
    required DateTime clockInTime,
    required List<BreakTimeOption> selectedBreakTimes,
    List<int> myResidentIds = const [],
  }) {
    int onTime = 0;
    int slightlyLate = 0;
    int veryLate = 0;
    int kindness = 0;

    for (final activity in activities) {
      // Check if kindness task (helped someone else's resident)
      if (activity.isKindnessTask(myResidentIds)) {
        kindness++;
        continue; // ไม่นับ timeliness สำหรับงานน้ำใจ
      }

      switch (activity.timelinessStatus) {
        case 'onTime':
          onTime++;
          break;
        case 'slightlyLate':
          slightlyLate++;
          break;
        case 'veryLate':
          veryLate++;
          break;
      }
    }

    // คำนวณเวลาทำงานทั้งหมด
    final now = DateTime.now();
    final totalWorkMinutes = now.difference(clockInTime).inMinutes;

    // คำนวณ dead air พร้อมรายละเอียด
    final deadAirResult = _calculateDeadAirWithDetails(
      activities: activities,
      clockInTime: clockInTime,
      selectedBreakTimes: selectedBreakTimes,
    );

    return ShiftActivityStats(
      totalCompleted: activities.length,
      teamTotalCompleted: teamTotalCompleted,
      onTimeCount: onTime,
      slightlyLateCount: slightlyLate,
      veryLateCount: veryLate,
      kindnessCount: kindness,
      totalTasks: totalTasks,
      deadAirMinutes: deadAirResult.totalDeadAir,
      totalWorkMinutes: totalWorkMinutes,
      deadAirGaps: deadAirResult.gaps,
      totalBreakMinutes: deadAirResult.totalBreakMinutes,
      totalGapMinutes: deadAirResult.totalGapMinutes,
    );
  }

  /// Percent ของ tasks ที่ตรงเวลา
  double get onTimePercent =>
      totalCompleted > 0 ? (onTimeCount / totalCompleted) * 100 : 0;

  /// Percent ของ tasks ที่สายเล็กน้อย
  double get slightlyLatePercent =>
      totalCompleted > 0 ? (slightlyLateCount / totalCompleted) * 100 : 0;

  /// Percent ของ tasks ที่สายมาก
  double get veryLatePercent =>
      totalCompleted > 0 ? (veryLateCount / totalCompleted) * 100 : 0;

  /// Percent ของเวลาอู้ต่อเวลาทำงานทั้งหมด
  double get deadAirPercent =>
      totalWorkMinutes > 0 ? (deadAirMinutes / totalWorkMinutes) * 100 : 0;

  /// มี activity หรือไม่
  bool get hasActivities => totalCompleted > 0;

  /// Allowance สำหรับ dead air - 75 นาที (1 ชม. 15 นาที) ให้ฟรี
  static const int deadAirAllowanceMinutes = 75;

  /// คำนวณ Dead Air จาก list ของ completed tasks พร้อมรายละเอียด
  /// สูตรใหม่:
  /// 1. รวมทุก gap (ไม่มี threshold ต่อ gap)
  /// 2. Break Overlap = ส่วนที่ gaps ทับกับเวลาพักที่ user เลือก
  /// 3. Dead Air = Total Gaps - 75 (allowance) - Break Overlap
  ///
  /// หมายเหตุ: Break จะหักได้เฉพาะส่วนที่ gap ทับกับเวลาพัก
  /// เพื่อให้ user ไปพักตรงเวลาที่เลือก
  static ({int totalDeadAir, List<DeadAirGap> gaps, int totalBreakMinutes, int totalGapMinutes})
      _calculateDeadAirWithDetails({
    required List<ShiftActivityItem> activities,
    required DateTime clockInTime,
    required List<BreakTimeOption> selectedBreakTimes,
  }) {
    if (activities.isEmpty) {
      return (totalDeadAir: 0, gaps: [], totalBreakMinutes: 0, totalGapMinutes: 0);
    }

    // เรียงตาม completedAt
    final sorted = List<ShiftActivityItem>.from(activities)
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    int totalGapMinutes = 0;
    int totalBreakOverlap = 0;
    final List<DeadAirGap> gaps = [];
    DateTime lastActivityTime = clockInTime;

    // รวบรวมทุก gap
    for (final activity in sorted) {
      final gapMinutes =
          activity.completedAt.difference(lastActivityTime).inMinutes;

      if (gapMinutes > 0) {
        // คำนวณ break overlap สำหรับ gap นี้
        final breakMinutesInGap = _calculateBreakMinutesInRange(
          lastActivityTime,
          activity.completedAt,
          selectedBreakTimes,
        );

        totalGapMinutes += gapMinutes;
        totalBreakOverlap += breakMinutesInGap;

        // บันทึก gap detail
        gaps.add(DeadAirGap(
          gapStart: lastActivityTime,
          gapEnd: activity.completedAt,
          gapMinutes: gapMinutes,
          breakMinutes: breakMinutesInGap,
          deadAirMinutes: 0, // จะคำนวณทีหลังจาก total
        ));
      }

      lastActivityTime = activity.completedAt;
    }

    // Gap สุดท้าย: จาก activity ล่าสุดถึงปัจจุบัน
    final now = DateTime.now();
    final lastGapMinutes = now.difference(lastActivityTime).inMinutes;
    if (lastGapMinutes > 0) {
      final breakMinutesInGap = _calculateBreakMinutesInRange(
        lastActivityTime,
        now,
        selectedBreakTimes,
      );

      totalGapMinutes += lastGapMinutes;
      totalBreakOverlap += breakMinutesInGap;

      gaps.add(DeadAirGap(
        gapStart: lastActivityTime,
        gapEnd: now,
        gapMinutes: lastGapMinutes,
        breakMinutes: breakMinutesInGap,
        deadAirMinutes: 0,
      ));
    }

    // คำนวณ Dead Air ตามสูตรใหม่:
    // Dead Air = Total Gaps - 75 (allowance) - Break Overlap
    final totalDeadAir =
        totalGapMinutes - deadAirAllowanceMinutes - totalBreakOverlap;

    debugPrint('=== Dead Air Calculation (New Formula) ===');
    debugPrint('Total Gaps: $totalGapMinutes นาที');
    debugPrint('Allowance: $deadAirAllowanceMinutes นาที');
    debugPrint('Break Overlap: $totalBreakOverlap นาที');
    debugPrint(
        'Dead Air: $totalGapMinutes - $deadAirAllowanceMinutes - $totalBreakOverlap = ${totalDeadAir > 0 ? totalDeadAir : 0} นาที');

    return (
      totalDeadAir: totalDeadAir > 0 ? totalDeadAir : 0,
      gaps: gaps,
      totalBreakMinutes: totalBreakOverlap,
      totalGapMinutes: totalGapMinutes,
    );
  }

  /// คำนวณจำนวนนาทีพักที่อยู่ในช่วงเวลา
  static int _calculateBreakMinutesInRange(
    DateTime start,
    DateTime end,
    List<BreakTimeOption> breakTimes,
  ) {
    int totalBreakMinutes = 0;

    // แปลงเป็น local time เพราะ break time string เป็นเวลาไทย
    final localStart = start.toLocal();
    final localEnd = end.toLocal();

    debugPrint('=== _calculateBreakMinutesInRange ===');
    debugPrint('Gap: $localStart -> $localEnd');
    debugPrint('Break times count: ${breakTimes.length}');

    for (final breakTime in breakTimes) {
      debugPrint('Processing break: "${breakTime.breakTime}"');

      // Parse break time: "12:00 - 12:20" -> start and end time (local)
      final times = _parseBreakTimeRange(breakTime.breakTime, localStart);
      if (times == null) {
        debugPrint('  -> Parse failed!');
        continue;
      }

      final (breakStart, breakEnd) = times;
      debugPrint('  -> Parsed: $breakStart - $breakEnd');

      // ตรวจสอบว่าช่วงพักทับกับช่วงเวลาที่กำหนดหรือไม่
      if (breakEnd.isBefore(localStart) || breakStart.isAfter(localEnd)) {
        debugPrint('  -> No overlap');
        continue;
      }

      // คำนวณช่วงที่ทับกัน
      final overlapStart = breakStart.isBefore(localStart) ? localStart : breakStart;
      final overlapEnd = breakEnd.isAfter(localEnd) ? localEnd : breakEnd;

      if (overlapEnd.isAfter(overlapStart)) {
        final overlapMinutes = overlapEnd.difference(overlapStart).inMinutes;
        debugPrint('  -> Overlap: $overlapMinutes minutes ($overlapStart - $overlapEnd)');
        totalBreakMinutes += overlapMinutes;
      }
    }

    debugPrint('Total break minutes in range: $totalBreakMinutes');
    return totalBreakMinutes;
  }

  /// Parse break time string "HH:mm - HH:mm" or "HH.mm น. - HH.mm น." to DateTime tuple
  static (DateTime, DateTime)? _parseBreakTimeRange(
      String breakTimeStr, DateTime referenceDate) {
    try {
      // Format: "12:00 - 12:20" or "12.00 น. - 13.00 น."
      // ลบ "น." และ space ออก แล้วแปลง . เป็น : เพื่อ parse ง่ายขึ้น
      final cleanStr = breakTimeStr
          .replaceAll('น.', '')
          .replaceAll(' ', '')
          .replaceAll('.', ':') // แปลง 12.00 เป็น 12:00
          .trim();
      final parts = cleanStr.split('-');
      if (parts.length != 2) return null;

      final startParts = parts[0].split(':');
      final endParts = parts[1].split(':');

      if (startParts.length < 2 || endParts.length < 2) return null;

      final startHour = int.tryParse(startParts[0]) ?? 0;
      final startMinute = int.tryParse(startParts[1]) ?? 0;
      final endHour = int.tryParse(endParts[0]) ?? 0;
      final endMinute = int.tryParse(endParts[1]) ?? 0;

      final breakStart = DateTime(
        referenceDate.year,
        referenceDate.month,
        referenceDate.day,
        startHour,
        startMinute,
      );

      final breakEnd = DateTime(
        referenceDate.year,
        referenceDate.month,
        referenceDate.day,
        endHour,
        endMinute,
      );

      return (breakStart, breakEnd);
    } catch (e) {
      return null;
    }
  }
}
