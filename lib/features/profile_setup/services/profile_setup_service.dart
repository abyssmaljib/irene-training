import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service สำหรับจัดการ Profile Setup flow
/// - ตรวจสอบว่า user ต้องกรอก profile หรือยัง
/// - บันทึกข้อมูล profile (หน้า 1 บังคับ, หน้า 2-3 ไม่บังคับ)
/// - อัพโหลดรูปโปรไฟล์
class ProfileSetupService {
  // Singleton pattern เหมือน UserService
  static final ProfileSetupService _instance = ProfileSetupService._internal();
  factory ProfileSetupService() => _instance;
  ProfileSetupService._internal();

  final _supabase = Supabase.instance.client;

  // Storage bucket สำหรับรูปโปรไฟล์
  static const _profilePhotoBucket = 'user-profiles';

  // Storage bucket สำหรับเอกสารพนักงาน
  static const _staffDocumentsBucket = 'staff-documents';

  /// ตรวจสอบว่า user ต้องกรอก profile (หน้า 1) หรือยัง
  /// Returns true ถ้ายังไม่เคยกรอก (profile_setup_completed = false)
  Future<bool> needsProfileSetup() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await _supabase
          .from('user_info')
          .select('profile_setup_completed')
          .eq('id', userId)
          .maybeSingle();

      // ถ้าไม่พบ user_info record หรือ profile_setup_completed = false
      // แปลว่าต้องกรอก profile
      final isCompleted = response?['profile_setup_completed'] as bool? ?? false;
      return !isCompleted;
    } catch (e) {
      debugPrint('ProfileSetupService: Error checking profile setup: $e');
      // ถ้าเกิด error ไม่บังคับให้กรอก (fail-safe)
      return false;
    }
  }

  /// บันทึกข้อมูล profile หน้า 1 (บังคับ)
  /// และ mark profile_setup_completed = true
  Future<void> saveRequiredProfile({
    required String fullName,
    required String nickname,
    String? prefix,
    String? photoUrl,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    try {
      await _supabase.from('user_info').update({
        'full_name': fullName.trim(),
        'nickname': nickname.trim(),
        'prefix': prefix,
        'photo_url': photoUrl,
        'profile_setup_completed': true,
      }).eq('id', userId);

      debugPrint('ProfileSetupService: Saved required profile for $userId');
    } catch (e) {
      debugPrint('ProfileSetupService: Error saving required profile: $e');
      rethrow;
    }
  }

  /// บันทึกข้อมูล profile หน้า 2 (ข้อมูลติดต่อ - ไม่บังคับ)
  Future<void> saveContactInfo({
    String? phoneNumber,
    String? lineId,
    String? bank,
    String? bankAccount,
    String? nationalIdStaff,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    try {
      await _supabase.from('user_info').update({
        'phone_number': phoneNumber?.trim(),
        'line_ID': lineId?.trim(),
        'bank': bank,
        'bank_account': bankAccount?.trim(),
        'national_ID_staff': nationalIdStaff?.trim(),
      }).eq('id', userId);

      debugPrint('ProfileSetupService: Saved contact info for $userId');
    } catch (e) {
      debugPrint('ProfileSetupService: Error saving contact info: $e');
      rethrow;
    }
  }

  /// บันทึกข้อมูล profile หน้า 3 (ข้อมูลส่วนตัว - ไม่บังคับ)
  Future<void> savePersonalInfo({
    String? gender,
    DateTime? dobStaff,
    String? educationDegree,
    String? underlyingDiseaseStaff,
    String? aboutMe,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    try {
      await _supabase.from('user_info').update({
        'gender': gender,
        'DOB_staff': dobStaff?.toIso8601String().split('T')[0], // date only
        'education_degree': educationDegree,
        'underlying_disease_staff': underlyingDiseaseStaff?.trim(),
        'about_me': aboutMe?.trim(),
      }).eq('id', userId);

      debugPrint('ProfileSetupService: Saved personal info for $userId');
    } catch (e) {
      debugPrint('ProfileSetupService: Error saving personal info: $e');
      rethrow;
    }
  }

  /// อัพโหลดรูปโปรไฟล์ไปยัง Supabase Storage
  /// Returns URL ของรูปที่อัพโหลดสำเร็จ
  Future<String?> uploadProfilePhoto(File imageFile) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    try {
      // สร้าง unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // ดึง extension จาก path โดยไม่ใช้ path package
      final filePath = imageFile.path;
      final extension = filePath.contains('.')
          ? '.${filePath.split('.').last.toLowerCase()}'
          : '.jpg';
      final fileName = '$userId/$timestamp$extension';

      // อัพโหลดไปยัง storage
      await _supabase.storage.from(_profilePhotoBucket).upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      // สร้าง public URL
      final publicUrl =
          _supabase.storage.from(_profilePhotoBucket).getPublicUrl(fileName);

      debugPrint('ProfileSetupService: Uploaded profile photo: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('ProfileSetupService: Error uploading profile photo: $e');
      // ไม่ throw error - รูปไม่บังคับ
      return null;
    }
  }

  /// ดึงข้อมูล profile ปัจจุบันของ user
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('user_info')
          .select('''
            full_name, nickname, prefix, photo_url,
            phone_number, line_ID, bank, bank_account, national_ID_staff,
            gender, DOB_staff, education_degree, underlying_disease_staff, about_me,
            profile_setup_completed
          ''')
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('ProfileSetupService: Error getting current profile: $e');
      return null;
    }
  }

  /// ตรวจสอบว่า user กรอกข้อมูล optional (หน้า 2-3) ครบหรือยัง
  /// ใช้สำหรับแสดง nudge ใน Settings
  Future<bool> hasCompleteOptionalProfile() async {
    final profile = await getCurrentProfile();
    if (profile == null) return false;

    // ตรวจสอบข้อมูลหน้า 2 (ติดต่อ) - อย่างน้อยต้องมีเบอร์โทร
    final hasContactInfo = profile['phone_number'] != null &&
        (profile['phone_number'] as String).isNotEmpty;

    // ตรวจสอบข้อมูลหน้า 3 (ส่วนตัว) - อย่างน้อยต้องมีเพศและวันเกิด
    final hasPersonalInfo =
        profile['gender'] != null && profile['DOB_staff'] != null;

    return hasContactInfo && hasPersonalInfo;
  }

  // ========== NEW METHODS FOR GOOGLE FORM MATCHING ==========

  /// บันทึกข้อมูลทั้งหมดในครั้งเดียว (Unified Profile Save)
  /// ใช้สำหรับ UnifiedProfileSetupScreen ที่รวมทุก section
  Future<void> saveFullProfile({
    // Section 1: ข้อมูลพื้นฐาน
    required String fullName,
    required String nickname,
    String? prefix,
    String? photoUrl,
    String? englishName,
    String? gender,
    DateTime? dobStaff,
    double? weight,
    double? height,
    // Section 2: ข้อมูลติดต่อ
    String? nationalIdStaff,
    String? address,
    String? phoneNumber,
    String? lineId,
    // Section 3: วุฒิการศึกษาและทักษะ
    String? educationDegree,
    String? careCertification,
    String? institution,
    List<String>? skills,
    String? workExperience,
    String? specialAbilities,
    // Section 4: การเงิน
    String? bank,
    String? bankAccount,
    String? bankBookPhotoUrl,
    // Section 5: เอกสาร
    String? idCardPhotoUrl,
    String? certificatePhotoUrl,
    String? resumeUrl,
    // Section 6: ข้อมูลเพิ่มเติม
    String? maritalStatus,
    int? childrenCount,
    String? underlyingDiseaseStaff,
    String? aboutMe,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    try {
      final updateData = <String, dynamic>{
        // Section 1
        'full_name': fullName.trim(),
        'nickname': nickname.trim(),
        'prefix': prefix,
        'photo_url': photoUrl,
        'english_name': englishName?.trim(),
        'gender': gender,
        'DOB_staff': dobStaff?.toIso8601String().split('T')[0],
        'weight': weight,
        'height': height,
        // Section 2
        'national_ID_staff': nationalIdStaff?.trim(),
        'address': address?.trim(),
        'phone_number': phoneNumber?.trim(),
        'line_ID': lineId?.trim(),
        // Section 3
        'education_degree': educationDegree,
        'care_certification': careCertification,
        'institution': institution?.trim(),
        'skills': skills,
        'work_experience': workExperience?.trim(),
        'special_abilities': specialAbilities?.trim(),
        // Section 4
        'bank': bank,
        'bank_account': bankAccount?.trim(),
        'bank_book_photo_url': bankBookPhotoUrl,
        // Section 5
        'id_card_photo_url': idCardPhotoUrl,
        'certificate_photo_url': certificatePhotoUrl,
        'resume_url': resumeUrl,
        // Section 6
        'marital_status': maritalStatus,
        'children_count': childrenCount,
        'underlying_disease_staff': underlyingDiseaseStaff?.trim(),
        'about_me': aboutMe?.trim(),
        // Mark as completed
        'profile_setup_completed': true,
      };

      await _supabase.from('user_info').update(updateData).eq('id', userId);

      debugPrint('ProfileSetupService: Saved full profile for $userId');
    } catch (e) {
      debugPrint('ProfileSetupService: Error saving full profile: $e');
      rethrow;
    }
  }

  /// อัพโหลดเอกสารไปยัง staff-documents bucket
  /// documentType: 'id-card', 'certificate', 'resume', 'bank-book'
  Future<String?> uploadDocument(File file, String documentType) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = file.path;
      final extension = filePath.contains('.')
          ? '.${filePath.split('.').last.toLowerCase()}'
          : '.jpg';
      final fileName = '$userId/$documentType/$timestamp$extension';

      await _supabase.storage.from(_staffDocumentsBucket).upload(
            fileName,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      final publicUrl =
          _supabase.storage.from(_staffDocumentsBucket).getPublicUrl(fileName);

      debugPrint('ProfileSetupService: Uploaded document ($documentType): $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('ProfileSetupService: Error uploading document ($documentType): $e');
      return null;
    }
  }

  /// ดึงข้อมูล profile ปัจจุบันของ user (รวม fields ใหม่)
  Future<Map<String, dynamic>?> getFullProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('user_info')
          .select('''
            full_name, nickname, prefix, photo_url, english_name,
            gender, DOB_staff, weight, height,
            national_ID_staff, address, phone_number, line_ID,
            education_degree, care_certification, institution, skills,
            work_experience, special_abilities,
            bank, bank_account, bank_book_photo_url,
            id_card_photo_url, certificate_photo_url, resume_url,
            marital_status, children_count, underlying_disease_staff, about_me,
            profile_setup_completed
          ''')
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('ProfileSetupService: Error getting full profile: $e');
      return null;
    }
  }
}
