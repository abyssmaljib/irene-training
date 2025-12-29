import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/med_error_log.dart';
import '../models/meal_photo_group.dart';

/// Service สำหรับจัดการ A_Med_Error_Log (การตรวจสอบรูปยาโดยหัวหน้าเวร)
class MedErrorLogService {
  final _supabase = Supabase.instance.client;

  /// แปลง mealKey เป็น database format
  /// รองรับทั้ง slot key format (morning_before) และ Thai format (หลังอาหารเช้า)
  String _mealKeyToDbFormat(String mealKey) {
    // ถ้าเป็น slot key format (morning_before, noon_after, etc.)
    final (bldb, beforeAfter) = MealSlots.fromSlotKey(mealKey);
    if (bldb.isNotEmpty) {
      // ก่อนนอน ไม่ต้องมี beforeAfter
      if (beforeAfter.isEmpty) return bldb;
      // format: "ก่อนอาหารเช้า", "หลังอาหารกลางวัน"
      return '$beforeAfter$bldb';
    }

    // ถ้าเป็น Thai format อยู่แล้ว (ก่อนอาหารเช้า, หลังอาหารกลางวัน, etc.) ส่งคืนตรงๆ
    return mealKey;
  }

  /// ดึง error logs ทั้งหมดของ resident ในวันที่ระบุ
  Future<List<MedErrorLog>> getErrorLogs({
    required int residentId,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      final response = await _supabase
          .from('A_Med_Error_Log')
          .select('*, user_info:user_id(full_name, nickname)')
          .eq('resident_id', residentId)
          .eq('CalendarDate', dateStr)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => MedErrorLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching med error logs: $e');
      return [];
    }
  }

  /// ดึง error log เฉพาะมื้อและประเภทรูป (2C หรือ 3C)
  Future<MedErrorLog?> getErrorLog({
    required int residentId,
    required DateTime date,
    required String meal,
    required bool is2CPicture,
  }) async {
    try {
      final dateStr = _formatDate(date);
      final pictureField = is2CPicture ? '2CPicture' : '3CPicture';

      final response = await _supabase
          .from('A_Med_Error_Log')
          .select('*, user_info:user_id(full_name, nickname)')
          .eq('resident_id', residentId)
          .eq('CalendarDate', dateStr)
          .eq('meal', meal)
          .eq(pictureField, true)
          .maybeSingle();

      if (response == null) return null;
      return MedErrorLog.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching med error log: $e');
      return null;
    }
  }

  /// บันทึกผลการตรวจสอบรูปยา (Insert หรือ Update)
  /// ถ้ามีอยู่แล้วจะ update, ถ้าไม่มีจะ insert
  Future<bool> saveErrorLog({
    required int residentId,
    required DateTime date,
    required String meal, // mealKey format: morning_before, noon_after, etc.
    required bool is2CPicture,
    required String replyNurseMark,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final dateStr = _formatDate(date);
      final pictureField = is2CPicture ? '2CPicture' : '3CPicture';
      // แปลง mealKey เป็น database format
      final dbMeal = _mealKeyToDbFormat(meal);

      debugPrint('saveErrorLog: mealKey=$meal -> dbMeal=$dbMeal, $pictureField=$replyNurseMark');

      // ตรวจสอบว่ามี record อยู่แล้วหรือไม่
      final existing = await _supabase
          .from('A_Med_Error_Log')
          .select('id')
          .eq('resident_id', residentId)
          .eq('CalendarDate', dateStr)
          .eq('meal', dbMeal)
          .eq(pictureField, true)
          .maybeSingle();

      if (existing != null) {
        // Update existing record
        await _supabase
            .from('A_Med_Error_Log')
            .update({
              'reply_nurseMark': replyNurseMark,
              'user_id': userId,
            })
            .eq('id', existing['id']);
      } else {
        // Insert new record
        final data = {
          'meal': dbMeal, // ใช้ dbMeal ที่แปลงแล้ว (เช่น "ก่อนอาหารเช้า")
          'resident_id': residentId,
          'user_id': userId,
          'CalendarDate': dateStr,
          'admin': true,
          pictureField: true,
          'reply_nurseMark': replyNurseMark,
        };

        await _supabase.from('A_Med_Error_Log').insert(data);
      }

      debugPrint('Saved med error log: $meal, $pictureField, $replyNurseMark');
      return true;
    } catch (e) {
      debugPrint('Error saving med error log: $e');
      return false;
    }
  }

  /// ลบผลการตรวจสอบ (reset สถานะ)
  Future<bool> deleteErrorLog({
    required int residentId,
    required DateTime date,
    required String meal,
    required bool is2CPicture,
  }) async {
    try {
      final dateStr = _formatDate(date);
      final pictureField = is2CPicture ? '2CPicture' : '3CPicture';
      final dbMeal = _mealKeyToDbFormat(meal);

      debugPrint('deleteErrorLog: mealKey=$meal -> dbMeal=$dbMeal, $pictureField');

      await _supabase
          .from('A_Med_Error_Log')
          .delete()
          .eq('resident_id', residentId)
          .eq('CalendarDate', dateStr)
          .eq('meal', dbMeal)
          .eq(pictureField, true);

      debugPrint('Deleted med error log: $dbMeal, $pictureField');
      return true;
    } catch (e) {
      debugPrint('Error deleting med error log: $e');
      return false;
    }
  }

  /// Format date เป็น YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
