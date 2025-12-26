import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../models/med_completion_status.dart';

/// Service สำหรับดึงข้อมูลสถานะการจัดยา
/// ดึงจาก view: resident_med_completion_status
class MedCompletionService {
  static final MedCompletionService _instance = MedCompletionService._internal();
  factory MedCompletionService() => _instance;
  MedCompletionService._internal();

  final _userService = UserService();

  /// เวลา cutoff สำหรับเปลี่ยนไปดูวันถัดไป (หลังมื้อก่อนนอน)
  /// หลัง 21:00 = เริ่มจัดยาสำหรับวันถัดไป
  static const int _cutoffHour = 21;

  /// คำนวณวันที่สำหรับดึงสถานะจัดยา
  /// - ก่อน 21:00 → ดูวันนี้ (ยาที่จัดเมื่อคืน สำหรับเสิร์ฟวันนี้)
  /// - หลัง 21:00 → ดูวันพรุ่งนี้ (ยาที่กำลังจัดสำหรับเสิร์ฟพรุ่งนี้)
  DateTime getTargetDate() {
    final now = DateTime.now();
    if (now.hour >= _cutoffHour) {
      // หลัง 21:00 - ดูวันพรุ่งนี้
      return DateTime(now.year, now.month, now.day + 1);
    } else {
      // ก่อน 21:00 - ดูวันนี้
      return DateTime(now.year, now.month, now.day);
    }
  }

  /// ดึงสถานะการจัดยาของผู้พักทั้งหมดในวันที่ระบุ
  /// [checkDate] - วันที่ต้องการเช็ค (default: วันนี้)
  Future<List<MedCompletionStatus>> getMedCompletionStatus({
    DateTime? checkDate,
  }) async {
    final nursinghomeId = await _userService.getNursinghomeId();
    if (nursinghomeId == null) return [];

    final date = checkDate ?? DateTime.now();
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      final response = await Supabase.instance.client
          .from('resident_med_completion_status')
          .select()
          .eq('nursinghome_id', nursinghomeId)
          .eq('check_date', dateStr);

      return (response as List)
          .map((json) => MedCompletionStatus.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('MedCompletionService.getMedCompletionStatus error: $e');
      return [];
    }
  }

  /// ดึงสถานะการจัดยาของผู้พักคนเดียว
  Future<MedCompletionStatus?> getMedCompletionStatusByResident({
    required int residentId,
    DateTime? checkDate,
  }) async {
    final date = checkDate ?? DateTime.now();
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      final response = await Supabase.instance.client
          .from('resident_med_completion_status')
          .select()
          .eq('resident_id', residentId)
          .eq('check_date', dateStr)
          .maybeSingle();

      if (response != null) {
        return MedCompletionStatus.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('MedCompletionService.getMedCompletionStatusByResident error: $e');
      return null;
    }
  }

  /// ดึงสถานะการจัดยาเป็น Map โดย key = resident_id
  /// สำหรับใช้ lookup ได้ง่ายในหน้า list
  Future<Map<int, MedCompletionStatus>> getMedCompletionStatusMap({
    DateTime? checkDate,
  }) async {
    final list = await getMedCompletionStatus(checkDate: checkDate);
    return {for (var item in list) item.residentId: item};
  }
}
