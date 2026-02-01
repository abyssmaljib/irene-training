import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service สำหรับ sync ข้อมูล Profile ไปยัง Google Sheet
/// ใช้ Google Apps Script Web App เป็น API endpoint
///
/// การตั้งค่า:
/// 1. Deploy Google Apps Script ตามไฟล์ docs/google_apps_script_profile_sync.js
/// 2. ใส่ URL ที่ได้จาก deployment ใน [webAppUrl]
///
/// การใช้งาน:
/// ```dart
/// final service = GoogleSheetSyncService();
/// await service.syncProfile(profileData);
/// ```
class GoogleSheetSyncService {
  // Singleton pattern
  static final GoogleSheetSyncService _instance =
      GoogleSheetSyncService._internal();
  factory GoogleSheetSyncService() => _instance;
  GoogleSheetSyncService._internal();

  /// URL ของ Google Apps Script Web App
  /// ⚠️ ต้องแก้ไขให้ตรงกับ URL ที่ได้จาก deployment
  ///
  /// วิธี deploy:
  /// 1. เปิด Google Apps Script Editor
  /// 2. Deploy > New deployment > Web app
  /// 3. Execute as: Me, Who has access: Anyone
  /// 4. Copy URL มาใส่ที่นี่
  static const String webAppUrl =
      'https://script.google.com/macros/s/AKfycbzx7X05dD7f2ttJ6QIk7PTNLjYAZCXeoLc01faHZMv7z5-u3oZtnA88Cdw4j32-UXfAmQ/exec';

  /// Timeout สำหรับ HTTP request (30 วินาที)
  static const Duration _timeout = Duration(seconds: 30);

  /// ตรวจสอบว่าได้ตั้งค่า URL แล้วหรือยัง
  bool get isConfigured =>
      webAppUrl.isNotEmpty &&
      !webAppUrl.contains('YOUR_GOOGLE_APPS_SCRIPT') &&
      webAppUrl.startsWith('https://script.google.com');

  /// Sync ข้อมูล profile ไปยัง Google Sheet
  ///
  /// [profileData] - Map ที่มี keys ตรงกับ column ใน Google Sheet
  /// Returns [GoogleSheetSyncResult] ที่บอก success/error
  ///
  /// Keys ที่รองรับ:
  /// - nickname, prefix, full_name, english_name
  /// - dob (format: YYYY-MM-DD), national_id
  /// - gender, weight, height
  /// - address, marital_status, children_count, disease
  /// - phone, education, certification, institution
  /// - skills (List of String หรือ String), work_experience, special_abilities
  /// - certificate_url, resume_url, id_card_url, photo_url
  /// - email, bank, bank_account, bank_book_url
  Future<GoogleSheetSyncResult> syncProfile(
      Map<String, dynamic> profileData) async {
    // ⚠️ Skip sync บน Web เพราะ Google Apps Script มี CORS limitation
    // ใช้งานได้เฉพาะบน Mobile (Android/iOS) เท่านั้น
    if (kIsWeb) {
      debugPrint(
          'GoogleSheetSyncService: ไม่รองรับบน Web (CORS) - ข้ามการ sync');
      return GoogleSheetSyncResult(
        success: false,
        error: 'Google Sheet sync ไม่รองรับบน Web browser',
        skipped: true,
      );
    }

    // ตรวจสอบว่าตั้งค่า URL แล้วหรือยัง
    if (!isConfigured) {
      debugPrint(
          'GoogleSheetSyncService: Web App URL ยังไม่ได้ตั้งค่า - ข้ามการ sync');
      return GoogleSheetSyncResult(
        success: false,
        error: 'Google Sheet sync ยังไม่ได้ตั้งค่า',
        skipped: true,
      );
    }

    // ตรวจสอบ required field (เลขบัตรประชาชน)
    if (profileData['national_id'] == null ||
        (profileData['national_id'] as String).isEmpty) {
      debugPrint(
          'GoogleSheetSyncService: ไม่มีเลขบัตรประชาชน - ข้ามการ sync');
      return GoogleSheetSyncResult(
        success: false,
        error: 'ต้องมีเลขบัตรประชาชนเพื่อ sync กับ Google Sheet',
        skipped: true,
      );
    }

    try {
      debugPrint('GoogleSheetSyncService: กำลัง sync ข้อมูลไป Google Sheet...');

      // ส่ง POST request ไปยัง Google Apps Script
      final response = await http
          .post(
            Uri.parse(webAppUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(profileData),
          )
          .timeout(_timeout);

      // Parse response
      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

      if (responseBody['success'] == true) {
        debugPrint(
            'GoogleSheetSyncService: Sync สำเร็จ - ${responseBody['message']}');
        return GoogleSheetSyncResult(
          success: true,
          action: responseBody['action'] as String?,
          row: responseBody['row'] as int?,
          message: responseBody['message'] as String?,
        );
      } else {
        debugPrint(
            'GoogleSheetSyncService: Sync ไม่สำเร็จ - ${responseBody['error']}');
        return GoogleSheetSyncResult(
          success: false,
          error: responseBody['error'] as String?,
        );
      }
    } catch (e) {
      debugPrint('GoogleSheetSyncService: Error syncing to Google Sheet: $e');
      return GoogleSheetSyncResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// แปลงข้อมูลจาก Supabase profile format เป็น Google Sheet format
  ///
  /// รับ Map ที่มี keys จาก Supabase user_info table
  /// และแปลงเป็น format ที่ Google Apps Script รับได้
  Map<String, dynamic> convertProfileToSheetFormat({
    // Section 1: ข้อมูลพื้นฐาน
    String? fullName,
    String? nickname,
    String? prefix,
    String? photoUrl,
    String? englishName,
    String? gender,
    DateTime? dob,
    double? weight,
    double? height,
    // Section 2: ข้อมูลติดต่อ
    String? nationalId,
    String? address,
    String? phone,
    String? lineId,
    // Section 3: วุฒิการศึกษาและทักษะ
    String? education,
    String? certification,
    String? institution,
    List<String>? skills,
    String? workExperience,
    String? specialAbilities,
    // Section 4: การเงิน
    String? bank,
    String? bankAccount,
    String? bankBookUrl,
    // Section 5: เอกสาร
    String? idCardUrl,
    String? certificateUrl,
    String? resumeUrl,
    // Section 6: ข้อมูลเพิ่มเติม
    String? maritalStatus,
    int? childrenCount,
    String? disease,
    String? aboutMe,
    // อื่นๆ
    String? email,
  }) {
    // สร้าง Map โดยใส่เฉพาะ field ที่มีค่าจริงๆ
    // field ที่เป็น null หรือ empty จะไม่ถูกส่งไป → ไม่ทับข้อมูลเดิมใน Google Sheet
    final data = <String, dynamic>{};

    // Helper function ตรวจสอบว่ามีค่าจริงไหม
    void addIfNotEmpty(String key, dynamic value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is List && value.isEmpty) return;
      data[key] = value;
    }

    // ข้อมูลพื้นฐาน
    addIfNotEmpty('nickname', nickname);
    addIfNotEmpty('prefix', prefix);
    addIfNotEmpty('full_name', fullName);
    addIfNotEmpty('english_name', englishName);
    addIfNotEmpty('dob', dob?.toIso8601String().split('T')[0]);
    addIfNotEmpty('national_id', nationalId); // ⚠️ required สำหรับ sync
    addIfNotEmpty('gender', gender);
    addIfNotEmpty('weight', weight);
    addIfNotEmpty('height', height);

    // ข้อมูลติดต่อ
    addIfNotEmpty('address', address);
    addIfNotEmpty('phone', phone);

    // วุฒิการศึกษา
    addIfNotEmpty('education', education);
    addIfNotEmpty('certification', certification);
    addIfNotEmpty('institution', institution);
    addIfNotEmpty('skills', skills);
    addIfNotEmpty('work_experience', workExperience);
    addIfNotEmpty('special_abilities', specialAbilities);

    // ข้อมูลส่วนตัว
    addIfNotEmpty('marital_status', maritalStatus);
    // children_count = 0 ถือว่ามีค่า (ไม่ใช่ null)
    if (childrenCount != null) data['children_count'] = childrenCount;
    addIfNotEmpty('disease', disease);

    // เอกสาร
    addIfNotEmpty('certificate_url', certificateUrl);
    addIfNotEmpty('resume_url', resumeUrl);
    addIfNotEmpty('id_card_url', idCardUrl);
    addIfNotEmpty('photo_url', photoUrl);

    // การเงิน
    addIfNotEmpty('bank', bank);
    addIfNotEmpty('bank_account', bankAccount);
    addIfNotEmpty('bank_book_url', bankBookUrl);

    // อื่นๆ
    addIfNotEmpty('email', email);

    return data;
  }

  /// ทดสอบการเชื่อมต่อกับ Google Apps Script
  /// Returns true ถ้าเชื่อมต่อได้
  /// ⚠️ ไม่ทำงานบน Web (CORS limitation)
  Future<bool> testConnection() async {
    // Skip บน Web
    if (kIsWeb) return false;
    if (!isConfigured) return false;

    try {
      final response = await http.get(Uri.parse(webAppUrl)).timeout(_timeout);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['success'] == true;
    } catch (e) {
      debugPrint('GoogleSheetSyncService: Connection test failed: $e');
      return false;
    }
  }
}

/// ผลลัพธ์จากการ sync ข้อมูลไป Google Sheet
class GoogleSheetSyncResult {
  /// sync สำเร็จหรือไม่
  final bool success;

  /// action ที่ทำ: 'created' (เพิ่มใหม่) หรือ 'updated' (อัพเดท)
  final String? action;

  /// Row number ที่ถูกสร้าง/อัพเดท
  final int? row;

  /// ข้อความจาก server
  final String? message;

  /// Error message (ถ้ามี)
  final String? error;

  /// ถูกข้ามการ sync หรือไม่ (เช่น URL ยังไม่ได้ตั้งค่า)
  final bool skipped;

  GoogleSheetSyncResult({
    required this.success,
    this.action,
    this.row,
    this.message,
    this.error,
    this.skipped = false,
  });

  @override
  String toString() {
    if (skipped) return 'GoogleSheetSyncResult: skipped - $error';
    if (success) return 'GoogleSheetSyncResult: $action row $row - $message';
    return 'GoogleSheetSyncResult: failed - $error';
  }
}
