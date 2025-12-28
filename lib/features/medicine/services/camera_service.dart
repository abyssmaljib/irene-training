import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service สำหรับจัดการการถ่ายรูปยาและ upload ไป Supabase Storage
class CameraService {
  static final instance = CameraService._();
  CameraService._();

  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;

  /// ชื่อ bucket ใน Supabase Storage
  static const _bucketName = 'med-photos';

  /// ถ่ายรูปจากกล้อง
  /// Returns File path หรือ null ถ้ายกเลิก
  Future<File?> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // ลดขนาดเพื่อ upload เร็วขึ้น
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo == null) return null;
      return File(photo.path);
    } catch (e) {
      debugPrint('CameraService takePhoto error: $e');
      return null;
    }
  }

  /// Upload รูปไป Supabase Storage
  /// [file] - File ที่จะ upload
  /// [residentId] - ID ของ resident
  /// [mealKey] - ชื่อมื้อ เช่น 'ก่อนอาหารเช้า'
  /// [photoType] - '2C' หรือ '3C'
  /// [date] - วันที่ของรูป
  /// Returns URL ของรูปที่ upload แล้ว หรือ null ถ้า error
  Future<String?> uploadPhoto({
    required File file,
    required int residentId,
    required String mealKey,
    required String photoType, // '2C' or '3C'
    required DateTime date,
  }) async {
    try {
      // สร้างชื่อไฟล์ unique
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final safeMealKey = _sanitizeFileName(mealKey);
      final fileName = '${residentId}_${dateStr}_${safeMealKey}_${photoType}_$timestamp.jpg';
      final filePath = 'residents/$residentId/$fileName';

      debugPrint('CameraService: uploading $filePath');

      // Upload ไป Supabase Storage
      await _supabase.storage
          .from(_bucketName)
          .upload(filePath, file);

      // ดึง public URL
      final url = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(filePath);

      debugPrint('CameraService: uploaded successfully, URL: $url');
      return url;
    } catch (e) {
      debugPrint('CameraService uploadPhoto error: $e');
      return null;
    }
  }

  /// อัพเดต med_log ด้วย URL รูปที่ upload
  /// [residentId] - ID ของ resident
  /// [mealKey] - ชื่อมื้อ
  /// [date] - วันที่
  /// [photoUrl] - URL ของรูป
  /// [photoType] - '2C' หรือ '3C'
  Future<bool> updateMedLog({
    required int residentId,
    required String mealKey,
    required DateTime date,
    required String photoUrl,
    required String photoType,
  }) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // ค้นหา med_log ที่มีอยู่แล้ว
      final existingLogs = await _supabase
          .from('A_Med_logs')
          .select('id')
          .eq('resident_id', residentId)
          .eq('meal', mealKey)
          .eq('Created_Date', dateStr);

      final userId = _supabase.auth.currentUser?.id;

      if ((existingLogs as List).isNotEmpty) {
        // Update log ที่มีอยู่
        final logId = existingLogs[0]['id'];
        final updateData = <String, dynamic>{};

        if (photoType == '2C') {
          updateData['SecondCPictureUrl'] = photoUrl;
          updateData['2C_completed_by'] = userId;
        } else {
          updateData['ThirdCPictureUrl'] = photoUrl;
          updateData['3C_Compleated_by'] = userId;
          updateData['3C_time_stamps'] = DateTime.now().toIso8601String();
        }

        await _supabase
            .from('A_Med_logs')
            .update(updateData)
            .eq('id', logId);

        debugPrint('CameraService: updated med_log $logId with $photoType photo');
      } else {
        // สร้าง log ใหม่
        final insertData = <String, dynamic>{
          'resident_id': residentId,
          'meal': mealKey,
          'Created_Date': dateStr,
        };

        if (photoType == '2C') {
          insertData['SecondCPictureUrl'] = photoUrl;
          insertData['2C_completed_by'] = userId;
        } else {
          insertData['ThirdCPictureUrl'] = photoUrl;
          insertData['3C_Compleated_by'] = userId;
          insertData['3C_time_stamps'] = DateTime.now().toIso8601String();
        }

        await _supabase
            .from('A_Med_logs')
            .insert(insertData);

        debugPrint('CameraService: created new med_log with $photoType photo');
      }

      return true;
    } catch (e) {
      debugPrint('CameraService updateMedLog error: $e');
      return false;
    }
  }

  /// ถ่ายรูปและ upload พร้อมอัพเดต med_log
  /// Returns URL ของรูปที่ upload หรือ null ถ้า error/ยกเลิก
  Future<String?> captureAndUpload({
    required int residentId,
    required String mealKey,
    required String photoType,
    required DateTime date,
  }) async {
    // ถ่ายรูป
    final file = await takePhoto();
    if (file == null) return null;

    // Upload รูป
    final url = await uploadPhoto(
      file: file,
      residentId: residentId,
      mealKey: mealKey,
      photoType: photoType,
      date: date,
    );
    if (url == null) return null;

    // อัพเดต med_log
    final success = await updateMedLog(
      residentId: residentId,
      mealKey: mealKey,
      date: date,
      photoUrl: url,
      photoType: photoType,
    );

    if (!success) {
      debugPrint('CameraService: failed to update med_log');
      // ยัง return URL เพราะรูปถูก upload แล้ว
    }

    return url;
  }

  /// ลบรูปยาจาก med_log
  /// [residentId] - ID ของ resident
  /// [mealKey] - ชื่อมื้อ
  /// [date] - วันที่
  /// [photoType] - '2C' หรือ '3C'
  Future<bool> deletePhoto({
    required int residentId,
    required String mealKey,
    required DateTime date,
    required String photoType,
  }) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // ค้นหา med_log
      final existingLogs = await _supabase
          .from('A_Med_logs')
          .select('id, SecondCPictureUrl, ThirdCPictureUrl')
          .eq('resident_id', residentId)
          .eq('meal', mealKey)
          .eq('Created_Date', dateStr);

      if ((existingLogs as List).isEmpty) {
        debugPrint('CameraService: no med_log found to delete photo');
        return false;
      }

      final logId = existingLogs[0]['id'];
      final updateData = <String, dynamic>{};

      if (photoType == '2C') {
        // ลบรูป 2C
        updateData['SecondCPictureUrl'] = null;
        updateData['2C_completed_by'] = null;
      } else {
        // ลบรูป 3C
        updateData['ThirdCPictureUrl'] = null;
        updateData['3C_Compleated_by'] = null;
        updateData['3C_time_stamps'] = null;
      }

      await _supabase
          .from('A_Med_logs')
          .update(updateData)
          .eq('id', logId);

      debugPrint('CameraService: deleted $photoType photo from med_log $logId');
      return true;
    } catch (e) {
      debugPrint('CameraService deletePhoto error: $e');
      return false;
    }
  }

  /// แปลงชื่อไฟล์ให้ safe (ลบ characters พิเศษ)
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(' ', '_')
        .replaceAll('ก่อน', 'before')
        .replaceAll('หลัง', 'after')
        .replaceAll('อาหาร', 'meal')
        .replaceAll('เช้า', 'morning')
        .replaceAll('กลางวัน', 'noon')
        .replaceAll('เย็น', 'evening')
        .replaceAll('นอน', 'bed');
  }
}
