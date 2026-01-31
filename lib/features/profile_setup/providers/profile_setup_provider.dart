import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/profile_setup_service.dart';

/// State สำหรับ Profile Setup Form (หน้า 1)
/// เก็บข้อมูลที่ user กรอก และสถานะของ form
@immutable
class ProfileSetupState {
  // ข้อมูล form
  final String? prefix;
  final String fullName;
  final String nickname;
  final String? photoUrl;
  final File? selectedPhoto; // รูปที่เลือกแต่ยังไม่ upload

  // สถานะ
  final bool isLoading;
  final bool isUploadingPhoto;
  final String? errorMessage;
  final bool isSubmitSuccess;

  const ProfileSetupState({
    this.prefix,
    this.fullName = '',
    this.nickname = '',
    this.photoUrl,
    this.selectedPhoto,
    this.isLoading = false,
    this.isUploadingPhoto = false,
    this.errorMessage,
    this.isSubmitSuccess = false,
  });

  /// ตรวจสอบว่า form valid หรือไม่ (กรอกข้อมูลครบ)
  bool get isValid =>
      fullName.trim().isNotEmpty && nickname.trim().isNotEmpty;

  /// ตรวจสอบว่ามีรูปหรือไม่ (เลือกใหม่หรือมี URL เดิม)
  bool get hasPhoto => selectedPhoto != null || photoUrl != null;

  ProfileSetupState copyWith({
    String? prefix,
    String? fullName,
    String? nickname,
    String? photoUrl,
    File? selectedPhoto,
    bool? isLoading,
    bool? isUploadingPhoto,
    String? errorMessage,
    bool? isSubmitSuccess,
    bool clearSelectedPhoto = false,
    bool clearError = false,
  }) {
    return ProfileSetupState(
      prefix: prefix ?? this.prefix,
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      photoUrl: photoUrl ?? this.photoUrl,
      selectedPhoto: clearSelectedPhoto ? null : (selectedPhoto ?? this.selectedPhoto),
      isLoading: isLoading ?? this.isLoading,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSubmitSuccess: isSubmitSuccess ?? this.isSubmitSuccess,
    );
  }
}

/// Provider สำหรับ ProfileSetupService
final profileSetupServiceProvider = Provider<ProfileSetupService>((ref) {
  return ProfileSetupService();
});

// ============================================
// Profile Completion Status (Updated for 6 sections)
// ============================================

/// Model สำหรับเก็บสถานะการกรอกข้อมูล profile แต่ละ section
/// ใช้แสดง badge และ card ชวน user กรอกข้อมูลให้ครบ
///
/// Section 1-5 เป็น required, Section 6 เป็น optional (ไม่นับใน completion)
@immutable
class ProfileCompletionStatus {
  /// Section 1: ข้อมูลพื้นฐาน (ชื่อ, ชื่อเล่น, เพศ, วันเกิด, น้ำหนัก, ส่วนสูง)
  final bool hasBasicInfo;

  /// Section 2: ข้อมูลติดต่อ (บัตรประชาชน, ที่อยู่, เบอร์โทร)
  final bool hasContactInfo;

  /// Section 3: วุฒิการศึกษาและทักษะ (ระดับการศึกษา, วุฒิบัตร, ทักษะ)
  final bool hasEducationInfo;

  /// Section 4: การเงิน (ธนาคาร, เลขบัญชี, รูปหน้าบุ๊คแบงค์)
  final bool hasFinanceInfo;

  /// Section 5: เอกสาร (สำเนาบัตรประชาชน, วุฒิบัตร)
  final bool hasDocuments;

  // Note: Section 6 (ข้อมูลเพิ่มเติม) เป็น optional ไม่นับใน completion

  /// จำนวน section ที่กรอกครบแล้ว (0-5)
  int get completedSections {
    int count = 0;
    if (hasBasicInfo) count++;
    if (hasContactInfo) count++;
    if (hasEducationInfo) count++;
    if (hasFinanceInfo) count++;
    if (hasDocuments) count++;
    return count;
  }

  /// จำนวน section ที่ต้องกรอก (5 sections)
  static const int totalRequiredSections = 5;

  /// กรอกครบทั้ง 5 section หรือยัง
  bool get isComplete =>
      hasBasicInfo &&
      hasContactInfo &&
      hasEducationInfo &&
      hasFinanceInfo &&
      hasDocuments;

  /// จำนวน section ที่ยังไม่ได้กรอก (สำหรับแสดง badge)
  int get incompleteCount => totalRequiredSections - completedSections;

  /// เปอร์เซ็นต์ความสมบูรณ์ (0-100)
  int get completionPercent =>
      (completedSections / totalRequiredSections * 100).round();

  const ProfileCompletionStatus({
    this.hasBasicInfo = false,
    this.hasContactInfo = false,
    this.hasEducationInfo = false,
    this.hasFinanceInfo = false,
    this.hasDocuments = false,
  });
}

/// Provider ตรวจสอบสถานะการกรอก profile แบบละเอียด
/// ใช้แสดง badge ใน Settings และ card ใน Home
///
/// Performance: ใช้ keepAlive เพื่อ cache ผลลัพธ์ไว้
/// ไม่ต้อง query Supabase ซ้ำทุกครั้งที่ widget rebuild
/// เมื่อต้องการ refresh ให้ใช้ ref.invalidate(profileCompletionStatusProvider)
final profileCompletionStatusProvider =
    FutureProvider<ProfileCompletionStatus>((ref) async {
  // keepAlive: เก็บ cache ไว้ไม่ให้ dispose เมื่อไม่มี listener
  // ช่วยลด API calls เพราะ provider นี้ถูก watch หลายที่
  // (MainNavigationScreen, SettingsScreen, ProfileCompletionCard)
  ref.keepAlive();

  final service = ref.watch(profileSetupServiceProvider);
  // ใช้ getFullProfile() เพื่อดึง fields ใหม่ทั้งหมด
  final profile = await service.getFullProfile();

  if (profile == null) {
    return const ProfileCompletionStatus();
  }

  // Helper function ตรวจสอบว่า field มีค่าหรือไม่
  bool hasValue(String key) {
    final value = profile[key];
    if (value == null) return false;
    if (value is String) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    return true; // สำหรับ number, date, etc.
  }

  // Section 1: ข้อมูลพื้นฐาน
  // Required: full_name, english_name, nickname, gender, DOB_staff, weight, height
  final hasBasicInfo = hasValue('full_name') &&
      hasValue('english_name') &&
      hasValue('nickname') &&
      hasValue('gender') &&
      hasValue('DOB_staff') &&
      hasValue('weight') &&
      hasValue('height');

  // Section 2: ข้อมูลติดต่อ
  // Required: national_ID_staff, address, phone_number
  final hasContactInfo = hasValue('national_ID_staff') &&
      hasValue('address') &&
      hasValue('phone_number');

  // Section 3: วุฒิการศึกษาและทักษะ
  // Required: education_degree, care_certification, skills (at least 1)
  final hasEducationInfo = hasValue('education_degree') &&
      hasValue('care_certification') &&
      hasValue('skills');

  // Section 4: การเงิน
  // Required: bank, bank_account, bank_book_photo_url
  final hasFinanceInfo = hasValue('bank') &&
      hasValue('bank_account') &&
      hasValue('bank_book_photo_url');

  // Section 5: เอกสาร
  // Required: id_card_photo_url, certificate_photo_url
  final hasDocuments =
      hasValue('id_card_photo_url') && hasValue('certificate_photo_url');

  return ProfileCompletionStatus(
    hasBasicInfo: hasBasicInfo,
    hasContactInfo: hasContactInfo,
    hasEducationInfo: hasEducationInfo,
    hasFinanceInfo: hasFinanceInfo,
    hasDocuments: hasDocuments,
  );
});

/// Provider ตรวจสอบว่า user ต้องกรอก profile หรือไม่
/// ใช้ใน ProfileCheckWrapper เพื่อ redirect ไปหน้า setup
final needsProfileSetupProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(profileSetupServiceProvider);
  return service.needsProfileSetup();
});

/// Provider สำหรับ Profile Setup Form (หน้า 1)
final profileSetupFormProvider =
    StateNotifierProvider<ProfileSetupFormNotifier, ProfileSetupState>((ref) {
  return ProfileSetupFormNotifier(ref.watch(profileSetupServiceProvider));
});

/// Notifier สำหรับจัดการ Profile Setup Form state
class ProfileSetupFormNotifier extends StateNotifier<ProfileSetupState> {
  ProfileSetupFormNotifier(this._service) : super(const ProfileSetupState());

  final ProfileSetupService _service;

  /// อัพเดท prefix (คำนำหน้าชื่อ)
  void setPrefix(String? value) {
    state = state.copyWith(prefix: value, clearError: true);
  }

  /// อัพเดท full name (ชื่อ-สกุล)
  void setFullName(String value) {
    state = state.copyWith(fullName: value, clearError: true);
  }

  /// อัพเดท nickname (ชื่อเล่น)
  void setNickname(String value) {
    state = state.copyWith(nickname: value, clearError: true);
  }

  /// เลือกรูปโปรไฟล์ (ยังไม่ upload)
  void setSelectedPhoto(File? photo) {
    state = state.copyWith(
      selectedPhoto: photo,
      clearSelectedPhoto: photo == null,
      clearError: true,
    );
  }

  /// ลบรูปที่เลือก
  void clearPhoto() {
    state = state.copyWith(
      clearSelectedPhoto: true,
      photoUrl: null,
    );
  }

  /// Submit form (upload รูป + บันทึก profile)
  Future<bool> submit() async {
    // ตรวจสอบ validation
    if (!state.isValid) {
      state = state.copyWith(
        errorMessage: 'กรุณากรอกชื่อ-สกุล และชื่อเล่น',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      String? photoUrl = state.photoUrl;

      // อัพโหลดรูปถ้ามีเลือกไว้
      if (state.selectedPhoto != null) {
        state = state.copyWith(isUploadingPhoto: true);
        photoUrl = await _service.uploadProfilePhoto(state.selectedPhoto!);
        state = state.copyWith(isUploadingPhoto: false);
      }

      // บันทึก profile (mark profile_setup_completed = true)
      await _service.saveRequiredProfile(
        fullName: state.fullName,
        nickname: state.nickname,
        prefix: state.prefix,
        photoUrl: photoUrl,
      );

      state = state.copyWith(
        isLoading: false,
        isSubmitSuccess: true,
        photoUrl: photoUrl,
      );

      debugPrint('ProfileSetupFormNotifier: Profile saved successfully');
      return true;
    } catch (e) {
      debugPrint('ProfileSetupFormNotifier: Error saving profile: $e');
      state = state.copyWith(
        isLoading: false,
        isUploadingPhoto: false,
        errorMessage: 'บันทึกข้อมูลไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
      );
      return false;
    }
  }

  /// Reset form state
  void reset() {
    state = const ProfileSetupState();
  }
}
