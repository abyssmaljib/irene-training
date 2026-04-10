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
  /// รองรับทั้ง task (taskLogId) และ post (postId)
  /// - ถ้ามี taskLogId → source = 'task'
  /// - ถ้ามี postId → source = 'post'
  /// - ต้องส่งอย่างใดอย่างหนึ่ง
  ///
  /// Returns: true ถ้า insert สำเร็จ, false ถ้าล้มเหลว
  Future<bool> insertMeasurement({
    required int residentId,
    required int nursinghomeId,
    required String recordedBy,
    required String measurementType,
    required double numericValue,
    required String unit,
    int? taskLogId,
    int? postId,
    String? photoUrl,
  }) async {
    // กำหนด source ตาม context ที่ส่งมา
    final String source;
    if (taskLogId != null) {
      source = 'task';
    } else if (postId != null) {
      source = 'post';
    } else {
      source = 'manual';
    }

    try {
      await _supabase.from('resident_measurements').insert({
        'resident_id': residentId,
        'nursinghome_id': nursinghomeId,
        'recorded_by': recordedBy,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
        'measurement_type': measurementType,
        'numeric_value': numericValue,
        'unit': unit,
        'source': source,
        if (taskLogId != null) 'task_log_id': taskLogId,
        if (postId != null) 'post_id': postId,
        if (photoUrl != null) 'photo_url': photoUrl,
      });
      return true;
    } catch (e) {
      // ไม่ print error — ให้ caller จัดการ error เอง
      return false;
    }
  }

  /// ดึง measurements ที่ผูกกับ post (สำหรับ edit post)
  /// Returns: list ของ map { measurement_type, numeric_value, unit, photo_url }
  Future<List<Map<String, dynamic>>> getMeasurementsForPost(int postId) async {
    try {
      final result = await _supabase
          .from('resident_measurements')
          .select('measurement_type, numeric_value, unit, photo_url')
          .eq('post_id', postId)
          .eq('is_deleted', false);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      return [];
    }
  }

  /// Soft-delete measurements ทั้งหมดที่ผูกกับ post (ใช้ก่อน re-insert เมื่อ edit)
  /// ใช้ soft delete (is_deleted = true) เพื่อเก็บ audit trail
  Future<void> deleteMeasurementsForPost(int postId) async {
    try {
      await _supabase
          .from('resident_measurements')
          .update({'is_deleted': true, 'post_id': null})
          .eq('post_id', postId);
    } catch (e) {
      // silent fail — ถ้าลบไม่ได้ re-insert จะ error เอง
    }
  }
}
