import 'dart:async';
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

  // Realtime subscription
  RealtimeChannel? _channel;
  final _statusController = StreamController<Map<int, ReportCompletionStatus>>.broadcast();

  /// Stream ของ report completion status
  /// ใช้สำหรับ listen การเปลี่ยนแปลงแบบ realtime
  Stream<Map<int, ReportCompletionStatus>> get statusStream => _statusController.stream;

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
  /// Logic:
  /// - เวรเช้า: รายงานที่เขียนวันนี้ช่วง 07:00-19:00
  /// - เวรดึก: รายงานที่เขียนเมื่อวาน 19:00 ถึงวันนี้ 07:00
  Future<Map<int, ReportCompletionStatus>> getReportCompletionStatusMap() async {
    final nursinghomeId = await _userService.getNursinghomeId();
    if (nursinghomeId == null) return {};

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      // Query รายงานเวรเช้า: วันนี้ 07:00 - 19:00
      final morningReports = await _queryMorningReports(
        nursinghomeId: nursinghomeId,
        date: today,
      );

      // Query รายงานเวรดึก: เมื่อวาน 19:00 - วันนี้ 07:00
      final nightReports = await _queryNightReports2(
        nursinghomeId: nursinghomeId,
        yesterday: yesterday,
        today: today,
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

  /// Query รายงานเวรเช้า: วันนี้ตั้งแต่ 00:00 (ไม่จำกัดเวลาสิ้นสุด เผื่อส่งช้า)
  Future<Map<int, Map<String, dynamic>>> _queryMorningReports({
    required int nursinghomeId,
    required DateTime date,
  }) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final response = await Supabase.instance.client
        .from('combined_vitalsign_details_view')
        .select('resident_id, created_at, user_nickname, isFullReport')
        .eq('shift', 'เวรเช้า')
        .eq('isFullReport', true)
        .gte('created_at', '$dateStr 00:00:00');

    final Map<int, Map<String, dynamic>> result = {};
    for (final row in response as List) {
      final residentId = row['resident_id'] as int;
      if (!result.containsKey(residentId)) {
        result[residentId] = row;
      }
    }
    return result;
  }

  /// Query รายงานเวรดึก: เมื่อวาน 19:00 - วันนี้ 12:00 (เผื่อส่งช้า แต่ไม่ซ้อนกับเวรเช้า)
  Future<Map<int, Map<String, dynamic>>> _queryNightReports2({
    required int nursinghomeId,
    required DateTime yesterday,
    required DateTime today,
  }) async {
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final response = await Supabase.instance.client
        .from('combined_vitalsign_details_view')
        .select('resident_id, created_at, user_nickname, isFullReport')
        .eq('shift', 'เวรดึก')
        .eq('isFullReport', true)
        .gte('created_at', '$yesterdayStr 19:00:00')
        .lt('created_at', '$todayStr 12:00:00');

    final Map<int, Map<String, dynamic>> result = {};
    for (final row in response as List) {
      final residentId = row['resident_id'] as int;
      if (!result.containsKey(residentId)) {
        result[residentId] = row;
      }
    }
    return result;
  }

  /// เริ่ม realtime subscription สำหรับ vitalSign table
  /// จะ refresh status เมื่อมี INSERT ใหม่
  Future<void> subscribeToRealtimeUpdates() async {
    // Unsubscribe ก่อนถ้ามี channel เดิม
    await unsubscribe();

    _channel = Supabase.instance.client
        .channel('vital_sign_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'vitalSign',
          callback: (payload) async {
            debugPrint('ReportCompletionService: New vital sign inserted');
            // Refresh และ emit ข้อมูลใหม่
            final statusMap = await getReportCompletionStatusMap();
            if (!_statusController.isClosed) {
              _statusController.add(statusMap);
            }
          },
        )
        .subscribe();

    debugPrint('ReportCompletionService: Subscribed to realtime updates');
  }

  /// ยกเลิก subscription
  Future<void> unsubscribe() async {
    if (_channel != null) {
      await Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
      debugPrint('ReportCompletionService: Unsubscribed from realtime updates');
    }
  }

  /// Dispose service (เรียกเมื่อไม่ใช้งานแล้ว)
  void dispose() {
    unsubscribe();
    _statusController.close();
  }
}
