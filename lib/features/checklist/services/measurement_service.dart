import 'package:supabase_flutter/supabase_flutter.dart';

/// Service สำหรับบันทึกค่า measurement ลง resident_measurements table
/// ใช้เมื่อ staff ทำ task เสร็จ (เช่น "ชั่งน้ำหนัก") แล้วกรอกค่าที่วัดได้
class MeasurementService {
  final SupabaseClient _supabase;

  MeasurementService(this._supabase);

  /// Singleton instance ใช้ Supabase.instance.client
  static MeasurementService get instance =>
      MeasurementService(Supabase.instance.client);

  /// Insert ค่า measurement เข้า resident_measurements
  ///
  /// Parameters:
  /// - [residentId] — ID ของผู้พักอาศัย
  /// - [nursinghomeId] — ID ของสถานดูแล
  /// - [recordedBy] — UUID ของ staff ที่กรอกค่า
  /// - [measurementType] — ประเภท เช่น 'weight', 'height'
  /// - [numericValue] — ค่าที่วัดได้ เช่น 65.5
  /// - [unit] — หน่วย เช่น 'kg', 'cm'
  /// - [taskLogId] — ID ของ task log ที่ผูกกับ measurement นี้
  /// - [photoUrl] — URL ของรูปตาชั่ง/อุปกรณ์วัด (ถ้ามี)
  ///
  /// Returns: true ถ้า insert สำเร็จ, false ถ้าล้มเหลว
  Future<bool> insertMeasurement({
    required int residentId,
    required int nursinghomeId,
    required String recordedBy,
    required String measurementType,
    required double numericValue,
    required String unit,
    required int taskLogId,
    String? photoUrl,
  }) async {
    try {
      await _supabase.from('resident_measurements').insert({
        'resident_id': residentId,
        'nursinghome_id': nursinghomeId,
        'recorded_by': recordedBy,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
        'measurement_type': measurementType,
        'numeric_value': numericValue,
        'unit': unit,
        'source': 'task', // มาจาก checklist task
        'task_log_id': taskLogId,
        if (photoUrl != null) 'photo_url': photoUrl,
      });
      return true;
    } catch (e) {
      // ไม่ print error — ให้ caller จัดการ error เอง
      return false;
    }
  }
}
