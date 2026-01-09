import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/monthly_summary.dart';
import '../models/clock_summary.dart';
import '../services/shift_summary_service.dart';
import '../../checklist/providers/task_provider.dart';

/// Provider สำหรับ ShiftSummaryService
final shiftSummaryServiceProvider = Provider<ShiftSummaryService>((ref) {
  return ShiftSummaryService.instance;
});

/// Counter เพื่อ trigger refresh
final shiftSummaryRefreshCounterProvider = StateProvider<int>((ref) => 0);

/// Provider สำหรับ monthly summaries
final monthlySummariesProvider = FutureProvider<List<MonthlySummary>>((ref) async {
  // Watch refresh counter to trigger rebuild
  ref.watch(shiftSummaryRefreshCounterProvider);
  // Watch user change counter to refresh when impersonating
  ref.watch(userChangeCounterProvider);

  final service = ref.watch(shiftSummaryServiceProvider);
  return service.getMonthlySummaries();
});

/// Parameter class for shift details query
class MonthYear {
  final int month;
  final int year;

  const MonthYear({required this.month, required this.year});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonthYear && other.month == month && other.year == year;
  }

  @override
  int get hashCode => month.hashCode ^ year.hashCode;
}

/// Provider สำหรับ shift details ของเดือน/ปีที่ระบุ
final shiftDetailsProvider = FutureProvider.family<List<ClockSummary>, MonthYear>(
  (ref, monthYear) async {
    // Watch refresh counter to trigger rebuild
    ref.watch(shiftSummaryRefreshCounterProvider);
    // Watch user change counter to refresh when impersonating
    ref.watch(userChangeCounterProvider);

    final service = ref.watch(shiftSummaryServiceProvider);
    return service.getShiftDetails(
      month: monthYear.month,
      year: monthYear.year,
    );
  },
);

/// Selected month/year สำหรับ popup
final selectedMonthYearProvider = StateProvider<MonthYear?>((ref) => null);

/// Provider สำหรับนับจำนวนวันขาดงานที่ยังไม่ได้แนบหลักฐาน (เดือนปัจจุบัน)
/// ใช้แสดง badge notification ที่ปุ่ม "เวรของฉัน"
final pendingAbsenceCountProvider = FutureProvider.autoDispose<int>((ref) async {
  // Watch refresh counter to trigger rebuild
  ref.watch(shiftSummaryRefreshCounterProvider);
  // Watch user change counter to refresh when impersonating
  ref.watch(userChangeCounterProvider);

  final now = DateTime.now();
  final service = ref.watch(shiftSummaryServiceProvider);

  final details = await service.getShiftDetails(
    month: now.month,
    year: now.year,
  );

  // Count records where user is absent but hasn't claimed sick leave yet
  return details.where((d) => d.canClaimSickLeave).length;
});
