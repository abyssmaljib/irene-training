import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/app_version_service.dart';
import '../../../core/services/user_service.dart';
import '../models/bug_report.dart';

/// Service สำหรับจัดการ Bug Reports
/// - Submit bug report พร้อม device info
/// - Upload attachments (รูป/วิดีโอ)
/// - ดึง bug reports ของตัวเอง
class BugReportService {
  // Singleton pattern
  static final instance = BugReportService._();
  BugReportService._();

  final _supabase = Supabase.instance.client;

  /// ชื่อ bucket ใน Supabase Storage สำหรับเก็บไฟล์แนบ
  static const _bucketName = 'bug-reports';

  /// Submit bug report ใหม่
  /// [bugOccurredAt] - เวลาที่เกิดบัค (จาก DateTime Picker)
  /// [activityDescription] - กิจกรรมที่ทำให้เกิดบัค (required)
  /// [additionalNotes] - รายละเอียดเพิ่มเติม (optional)
  /// [attachmentFiles] - ไฟล์แนบ (optional)
  /// Returns: BugReport ที่สร้าง หรือ null ถ้า error
  Future<BugReport?> submitBugReport({
    required DateTime bugOccurredAt,
    required String activityDescription,
    String? additionalNotes,
    List<File>? attachmentFiles,
  }) async {
    try {
      // 1. ดึงข้อมูล user และ device
      final userId = UserService().effectiveUserId;
      if (userId == null) {
        debugPrint('BugReportService: No user logged in');
        return null;
      }

      final nursinghomeId = await UserService().getNursinghomeId();
      final packageInfo = await AppVersionService.instance.getPackageInfo();
      final platform = AppVersionService.instance.getPlatformName();

      // 2. Upload attachments (ถ้ามี)
      final attachmentUrls = <String>[];
      if (attachmentFiles != null && attachmentFiles.isNotEmpty) {
        for (final file in attachmentFiles) {
          final url = await uploadAttachment(file, userId: userId);
          if (url != null) {
            attachmentUrls.add(url);
          }
        }
      }

      // 3. สร้าง BugReport object
      final bugReport = BugReport(
        userId: userId,
        nursinghomeId: nursinghomeId ?? 0,
        platform: platform,
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
        bugOccurredAt: bugOccurredAt,
        activityDescription: activityDescription,
        additionalNotes: additionalNotes,
        attachmentUrls: attachmentUrls,
      );

      // 4. Insert ไปที่ database
      final response = await _supabase
          .from('bug_reports')
          .insert(bugReport.toJson())
          .select()
          .single();

      debugPrint('BugReportService: Bug report submitted successfully');
      return BugReport.fromJson(response);
    } catch (e) {
      debugPrint('BugReportService submitBugReport error: $e');
      return null;
    }
  }

  /// Upload ไฟล์แนบ (รูปหรือวิดีโอ) ไป Supabase Storage
  /// Returns: URL ของไฟล์ หรือ null ถ้า error
  Future<String?> uploadAttachment(File file, {String? userId}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(file.path);
      final safeExt = extension.isNotEmpty ? extension : '.jpg';
      final fileName = '${userId ?? 'unknown'}_$timestamp$safeExt';

      // เลือก folder ตามประเภทไฟล์
      final isVideo = _isVideoFile(extension);
      final folder = isVideo ? 'videos' : 'images';
      final filePath = '$folder/$fileName';

      debugPrint('BugReportService: uploading attachment $filePath');

      // อ่านเป็น bytes สำหรับ upload
      final bytes = await file.readAsBytes();

      // กำหนด content type ตามประเภทไฟล์
      final contentType = isVideo ? 'video/mp4' : 'image/jpeg';

      await _supabase.storage.from(_bucketName).uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(contentType: contentType),
      );

      final url = _supabase.storage.from(_bucketName).getPublicUrl(filePath);

      debugPrint('BugReportService: uploaded attachment successfully, URL: $url');
      return url;
    } catch (e) {
      debugPrint('BugReportService uploadAttachment error: $e');
      return null;
    }
  }

  /// ดึง bug reports ของ user ปัจจุบัน
  /// เรียงตาม created_at DESC (ใหม่สุดก่อน)
  Future<List<BugReport>> getMyBugReports() async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) {
        debugPrint('BugReportService: No user logged in');
        return [];
      }

      final response = await _supabase
          .from('bug_reports')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => BugReport.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('BugReportService getMyBugReports error: $e');
      return [];
    }
  }

  /// ดึง file extension จาก path
  String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filePath.length - 1) {
      return '';
    }
    return filePath.substring(lastDot).toLowerCase();
  }

  /// ตรวจสอบว่าเป็น video file หรือไม่
  bool _isVideoFile(String extension) {
    const videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'];
    return videoExtensions.contains(extension.toLowerCase());
  }
}
