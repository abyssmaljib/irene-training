import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../models/report_completion_status.dart';

/// Service สำหรับดึงข้อมูลสถานะการเขียนรายงาน V/S
/// ดึงจากตาราง vitalSign
class ReportCompletionService {
  static final ReportCompletionService _instance =
      ReportCompletionService._internal();
  factory ReportCompletionService() => _instance;
  ReportCompletionService._internal();

  final _userService = UserService();

  /// เวลา cutoff สำหรับเปลี่ยนเวร
  /// - 07:00-19:00 = เวรเช้า
  /// - 19:00-07:00 = เวรดึก
  static const int _morningShiftStart = 7;
  static const int _nightShiftStart = 19;

  /// คำนวณ shift ปัจจุบัน
  String getCurrentShift() {
    final now = DateTime.now();
    if (now.hour >= _morningShiftStart && now.hour < _nightShiftStart) {
      return 'เวรเช้า';
    } else {
      return 'เวรดึก';
    }
  }

  /// คำนวณวันที่สำหรับเช็ครายงานเวรเช้า
  /// - เวรเช้า (07:00-19:00) → วันนี้
  DateTime getMorningReportDate() {
    return DateTime.now();
  }

  /// คำนวณวันที่สำหรับเช็ครายงานเวรดึก
  /// - เวรดึก ส่งรายงานตอนเช้าวันถัดไป
  /// - ถ้าตอนนี้เป็นเวรเช้า → เช็ครายงานเวรดึกของเมื่อวาน (ส่งเมื่อเช้านี้)
  /// - ถ้าตอนนี้เป็นเวรดึก → เช็ครายงานเวรดึกของวันนี้ (จะส่งพรุ่งนี้เช้า)
  DateTime getNightReportDate() {
    final now = DateTime.now();
    if (now.hour >= _morningShiftStart && now.hour < _nightShiftStart) {
      // เวรเช้า - เช็ครายงานเวรดึกของเมื่อวาน
      return now.subtract(const Duration(days: 1));
    } else {
      // เวรดึก - เช็ครายงานเวรดึกของวันนี้
      return now;
    }
  }

  /// ดึงสถานะรายงานของผู้พักทั้งหมด
  Future<Map<int, ReportCompletionStatus>> getReportCompletionStatusMap() async {
    final nursinghomeId = await _userService.getNursinghomeId();
    if (nursinghomeId == null) return {};

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      // Query รายงานเวรเช้าของวันนี้
      final morningReports = await _queryReports(
        nursinghomeId: nursinghomeId,
        shift: 'เวรเช้า',
        date: today,
      );

      // Query รายงานเวรดึก
      // - ถ้าเป็นเวรเช้า → เช็คเวรดึกของเมื่อวาน (ส่งเมื่อเช้านี้)
      // - ถ้าเป็นเวรดึก → เช็คเวรดึกของวันนี้ (ยังไม่ส่ง/จะส่งพรุ่งนี้)
      final isCurrentlyMorningShift =
          now.hour >= _morningShiftStart && now.hour < _nightShiftStart;

      final nightReportDate = isCurrentlyMorningShift ? yesterday : today;
      final nightReportQueryDate = isCurrentlyMorningShift ? today : today.add(const Duration(days: 1));

      // รายงานเวรดึก จะถูก created ตอนเช้าวันถัดไป
      // เช่น เวรดึกของวันที่ 26 → created_at = 27 ธ.ค. เช้า
      final nightReports = await _queryNightReports(
        nursinghomeId: nursinghomeId,
        nightReportDate: nightReportDate,
        createdDate: nightReportQueryDate,
      );

      // รวม results
      final Map<int, ReportCompletionStatus> result = {};

      // ดึง residents ทั้งหมดที่ต้องมีรายงาน
      final residentsResponse = await Supabase.instance.client
          .from('residents')
          .select('id')
          .eq('nursinghome_id', nursinghomeId)
          .eq('s_status', 'Stay');

      for (final r in residentsResponse as List) {
        final residentId = r['id'] as int;
        final morning = morningReports[residentId];
        final night = nightReports[residentId];

        result[residentId] = ReportCompletionStatus(
          residentId: residentId,
          hasMorningReport: morning != null,
          hasNightReport: night != null,
          morningReportAt: morning?['created_at'] != null
              ? DateTime.tryParse(morning!['created_at'] as String)
              : null,
          nightReportAt: night?['created_at'] != null
              ? DateTime.tryParse(night!['created_at'] as String)
              : null,
          morningReportBy: morning?['user_nickname'] as String?,
          nightReportBy: night?['user_nickname'] as String?,
        );
      }

      return result;
    } catch (e) {
      debugPrint('ReportCompletionService.getReportCompletionStatusMap error: $e');
      return {};
    }
  }

  /// Query รายงานเวรเช้า
  Future<Map<int, Map<String, dynamic>>> _queryReports({
    required int nursinghomeId,
    required String shift,
    required DateTime date,
  }) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final response = await Supabase.instance.client
        .from('combined_vitalsign_details_view')
        .select('resident_id, created_at, user_nickname, isFullReport')
        .eq('shift', shift)
        .eq('isFullReport', true)
        .gte('created_at', '$dateStr 00:00:00')
        .lt('created_at', '$dateStr 23:59:59');

    final Map<int, Map<String, dynamic>> result = {};
    for (final row in response as List) {
      final residentId = row['resident_id'] as int;
      // เอาเฉพาะ record แรก (ล่าสุด)
      if (!result.containsKey(residentId)) {
        result[residentId] = row;
      }
    }
    return result;
  }

  /// Query รายงานเวรดึก
  /// เวรดึกของวันที่ X จะถูก created ตอนเช้าวันที่ X+1
  Future<Map<int, Map<String, dynamic>>> _queryNightReports({
    required int nursinghomeId,
    required DateTime nightReportDate,
    required DateTime createdDate,
  }) async {
    final createdDateStr =
        '${createdDate.year}-${createdDate.month.toString().padLeft(2, '0')}-${createdDate.day.toString().padLeft(2, '0')}';

    // เวรดึกส่งตอนเช้า (ก่อน 07:00 - 12:00 โดยประมาณ)
    final response = await Supabase.instance.client
        .from('combined_vitalsign_details_view')
        .select('resident_id, created_at, user_nickname, isFullReport')
        .eq('shift', 'เวรดึก')
        .eq('isFullReport', true)
        .gte('created_at', '$createdDateStr 00:00:00')
        .lt('created_at', '$createdDateStr 12:00:00');

    final Map<int, Map<String, dynamic>> result = {};
    for (final row in response as List) {
      final residentId = row['resident_id'] as int;
      if (!result.containsKey(residentId)) {
        result[residentId] = row;
      }
    }
    return result;
  }
}
