import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../learning/services/badge_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/input_fields.dart';
import '../services/profile_setup_service.dart';
import '../widgets/certification_dropdown.dart';
import '../widgets/document_upload_picker.dart';
import '../widgets/marital_status_dropdown.dart';
import '../widgets/prefix_dropdown.dart';
import '../widgets/profile_photo_picker.dart';
import '../widgets/badge_celebration_dialog.dart';
import '../widgets/skills_multi_select.dart';

/// หน้า Profile Setup รวมทั้ง 6 ส่วนไว้ในหน้าเดียว
/// ใช้ ExpansionTile pattern เหมือน Create Vital Sign
///
/// โครงสร้าง:
/// - Header: รูปโปรไฟล์ + ข้อความต้อนรับ (onboarding mode)
/// - Section 1: ข้อมูลพื้นฐาน (ชื่อจริง+ชื่อเล่น บังคับ, อื่นๆ optional)
/// - Section 2: ข้อมูลติดต่อ (optional)
/// - Section 3: วุฒิการศึกษาและทักษะ (optional)
/// - Section 4: การเงิน (optional)
/// - Section 5: เอกสาร (optional)
/// - Section 6: ข้อมูลเพิ่มเติม (optional)
/// - ปุ่ม: บันทึก (enabled เมื่อกรอกชื่อจริง+ชื่อเล่น)
///
/// หมายเหตุ: User สามารถกรอกแค่ชื่อจริง+ชื่อเล่นแล้วเข้าใช้งานก่อนได้
/// ส่วนที่เหลือจะแสดงเป็น progress ให้กรอกเพิ่มในภายหลัง
class UnifiedProfileSetupScreen extends ConsumerStatefulWidget {
  /// Callback เมื่อกรอกเสร็จ (ใช้ใน onboarding mode)
  final VoidCallback? onComplete;

  /// แสดงแบบ onboarding (บังคับกรอก) หรือจาก Settings
  final bool showAsOnboarding;

  const UnifiedProfileSetupScreen({
    super.key,
    this.onComplete,
    this.showAsOnboarding = false,
  });

  @override
  ConsumerState<UnifiedProfileSetupScreen> createState() =>
      _UnifiedProfileSetupScreenState();
}

class _UnifiedProfileSetupScreenState
    extends ConsumerState<UnifiedProfileSetupScreen> {
  final _service = ProfileSetupService();

  // Loading states
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  // ========== Section 1: ข้อมูลพื้นฐาน (บังคับ) ==========
  File? _selectedPhoto;
  String? _photoUrl;
  String? _selectedPrefix;
  final _fullNameController = TextEditingController();
  final _englishNameController = TextEditingController();
  final _nicknameController = TextEditingController();

  // FocusNode สำหรับตรวจจับเมื่อออกจาก field ชื่อเล่น
  final _nicknameFocusNode = FocusNode();
  String? _selectedGender;
  DateTime? _selectedDob;
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  // ========== Section 2: ข้อมูลติดต่อ (บังคับ) ==========
  final _nationalIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _lineIdController = TextEditingController();

  // ========== Section 3: วุฒิการศึกษาและทักษะ (บังคับ) ==========
  String? _selectedEducation;
  String? _selectedCertification;
  final _institutionController = TextEditingController();
  Set<String> _selectedSkills = {};
  final _workExperienceController = TextEditingController();
  final _specialAbilitiesController = TextEditingController();

  // ========== Section 4: การเงิน (บังคับ) ==========
  String? _selectedBank;
  final _bankAccountController = TextEditingController();
  File? _selectedBankBookPhoto;
  String? _bankBookPhotoUrl;

  // ========== Section 5: เอกสาร (บังคับ) ==========
  File? _selectedIdCardPhoto;
  String? _idCardPhotoUrl;
  File? _selectedCertificatePhoto;
  String? _certificatePhotoUrl;
  File? _selectedResume;
  String? _resumeUrl;

  // ========== Section 6: ข้อมูลเพิ่มเติม (ไม่บังคับ) ==========
  String? _selectedMaritalStatus;
  final _childrenCountController = TextEditingController();
  final _diseaseController = TextEditingController();
  final _aboutMeController = TextEditingController();

  // ExpansionTile states
  bool _section1Expanded = true;
  bool _section2Expanded = false;
  bool _section3Expanded = false;
  bool _section4Expanded = false;
  bool _section5Expanded = false;
  bool _section6Expanded = false;

  // Secret logout tap counter (for dev)
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  // Track popup state - แสดง popup เมื่อ user กรอกชื่อจริง+ชื่อเล่นครบครั้งแรก
  bool _hasShownMinimumFieldsPopup = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();

    // ฟัง focus change ของ field ชื่อเล่น
    // เมื่อออกจาก field (unfocus) และกรอกครบ ให้แสดง popup
    _nicknameFocusNode.addListener(_onNicknameFocusChange);
  }

  /// เมื่อ focus ของ nickname field เปลี่ยน
  void _onNicknameFocusChange() {
    // ถ้าออกจาก field (unfocus) ให้เช็คว่าครบหรือยัง
    if (!_nicknameFocusNode.hasFocus) {
      _checkMinimumFieldsAndShowPopup();
    }
  }

  @override
  void dispose() {
    _nicknameFocusNode.removeListener(_onNicknameFocusChange);
    _nicknameFocusNode.dispose();
    _fullNameController.dispose();
    _englishNameController.dispose();
    _nicknameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _nationalIdController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _lineIdController.dispose();
    _institutionController.dispose();
    _workExperienceController.dispose();
    _specialAbilitiesController.dispose();
    _bankAccountController.dispose();
    _childrenCountController.dispose();
    _diseaseController.dispose();
    _aboutMeController.dispose();
    super.dispose();
  }

  /// โหลดข้อมูล profile ปัจจุบันมาแสดงในฟอร์ม
  Future<void> _loadCurrentProfile() async {
    setState(() => _isLoading = true);

    try {
      final profile = await _service.getFullProfile();
      if (profile != null && mounted) {
        setState(() {
          // Section 1
          _photoUrl = profile['photo_url'];
          _selectedPrefix = profile['prefix'];
          _fullNameController.text = profile['full_name'] ?? '';
          _englishNameController.text = profile['english_name'] ?? '';
          _nicknameController.text = profile['nickname'] ?? '';
          _selectedGender = profile['gender'];
          if (profile['DOB_staff'] != null) {
            _selectedDob = DateTime.tryParse(profile['DOB_staff']);
          }
          if (profile['weight'] != null) {
            _weightController.text = profile['weight'].toString();
          }
          if (profile['height'] != null) {
            _heightController.text = profile['height'].toString();
          }

          // Section 2
          _nationalIdController.text = profile['national_ID_staff'] ?? '';
          _addressController.text = profile['address'] ?? '';
          _phoneController.text = profile['phone_number'] ?? '';
          _lineIdController.text = profile['line_ID'] ?? '';

          // Section 3
          _selectedEducation = profile['education_degree'];
          // Normalize certification เพราะ DB อาจเก็บเป็น label แทน value code
          _selectedCertification = normalizeCertificationValue(
            profile['care_certification'],
          );
          _institutionController.text = profile['institution'] ?? '';
          _selectedSkills = skillsFromJson(profile['skills']);
          _workExperienceController.text = profile['work_experience'] ?? '';
          _specialAbilitiesController.text = profile['special_abilities'] ?? '';

          // Section 4
          _selectedBank = profile['bank'];
          _bankAccountController.text = profile['bank_account'] ?? '';
          _bankBookPhotoUrl = profile['bank_book_photo_url'];

          // Section 5
          _idCardPhotoUrl = profile['id_card_photo_url'];
          _certificatePhotoUrl = profile['certificate_photo_url'];
          _resumeUrl = profile['resume_url'];

          // Section 6
          _selectedMaritalStatus = profile['marital_status'];
          if (profile['children_count'] != null) {
            _childrenCountController.text = profile['children_count'].toString();
          }
          _diseaseController.text = profile['underlying_disease_staff'] ?? '';
          _aboutMeController.text = profile['about_me'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('UnifiedProfileSetupScreen: Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ========== Validation ==========

  /// ข้อมูลขั้นต่ำที่ต้องกรอก: ชื่อจริง + ชื่อเล่น
  /// User สามารถเข้าใช้งานได้ทันทีหลังกรอกแค่นี้
  bool get _isMinimumValid =>
      _fullNameController.text.trim().isNotEmpty &&
      _nicknameController.text.trim().isNotEmpty;

  /// ตรวจสอบว่า section 1 ครบหรือยัง (สำหรับแสดง progress)
  bool get _isSection1Valid =>
      _fullNameController.text.trim().isNotEmpty &&
      _englishNameController.text.trim().isNotEmpty &&
      _nicknameController.text.trim().isNotEmpty &&
      _selectedGender != null &&
      _selectedDob != null &&
      _weightController.text.trim().isNotEmpty &&
      _heightController.text.trim().isNotEmpty;

  /// ตรวจสอบว่า section 2 ครบหรือยัง (สำหรับแสดง progress)
  bool get _isSection2Valid =>
      _nationalIdController.text.trim().isNotEmpty &&
      _addressController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty;

  /// ตรวจสอบว่า section 3 ครบหรือยัง (สำหรับแสดง progress)
  bool get _isSection3Valid =>
      _selectedEducation != null &&
      _selectedCertification != null &&
      _selectedSkills.isNotEmpty;

  /// ตรวจสอบว่า section 4 ครบหรือยัง (สำหรับแสดง progress)
  bool get _isSection4Valid =>
      _selectedBank != null &&
      _bankAccountController.text.trim().isNotEmpty &&
      (_selectedBankBookPhoto != null || _bankBookPhotoUrl != null);

  /// ตรวจสอบว่า section 5 ครบหรือยัง (สำหรับแสดง progress)
  bool get _isSection5Valid =>
      (_selectedIdCardPhoto != null || _idCardPhotoUrl != null) &&
      (_selectedCertificatePhoto != null || _certificatePhotoUrl != null);

  /// ตรวจสอบว่ากรอกครบทุก section หรือยัง (สำหรับแสดง progress)
  bool get _isAllSectionsComplete =>
      _isSection1Valid &&
      _isSection2Valid &&
      _isSection3Valid &&
      _isSection4Valid &&
      _isSection5Valid;

  /// ตรวจสอบว่ามีข้อมูล section 6 หรือไม่
  bool get _hasSection6Data =>
      _selectedMaritalStatus != null ||
      _childrenCountController.text.isNotEmpty ||
      _diseaseController.text.isNotEmpty ||
      _aboutMeController.text.isNotEmpty;

  // ========== Popup Logic ==========

  /// ตรวจสอบว่ากรอก ชื่อจริง+ชื่อเล่น ครบแล้วหรือยัง
  /// ถ้าครบแล้วและยังไม่เคยแสดง popup ให้แสดง popup ถามว่าจะเข้าใช้งานเลยหรือกรอกต่อ
  void _checkMinimumFieldsAndShowPopup() {
    setState(() {});

    // ถ้ายังไม่ครบ หรือแสดง popup แล้ว ก็ไม่ต้องทำอะไร
    if (!_isMinimumValid || _hasShownMinimumFieldsPopup) return;

    // แสดงเฉพาะใน onboarding mode
    if (!widget.showAsOnboarding) return;

    // Mark ว่าแสดงแล้ว
    _hasShownMinimumFieldsPopup = true;

    // แสดง popup หลังจาก build เสร็จ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showMinimumFieldsPopup();
    });
  }

  /// แสดง popup แจ้งว่าสามารถเข้าใช้งานก่อนได้
  void _showMinimumFieldsPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // รูปแมวน่ารัก
              Image.asset(
                'assets/images/checking_cat.webp',
                width: 120,
                height: 120,
              ),
              SizedBox(height: AppSpacing.md),

              // หัวข้อ
              Text(
                'รีบมั้ย?',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.sm),

              // คำอธิบาย
              Text(
                'คุณสามารถเข้าใช้งานแอปได้เลยตอนนี้\n'
                'ส่วนข้อมูลที่เหลือ สามารถกลับมากรอกเพิ่มได้ภายหลังที่หน้า "ตั้งค่า"',
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.lg),

              // ปุ่มต่างๆ - ใช้ reusable widgets จาก design system
              Row(
                children: [
                  // ปุ่มกรอกต่อ - ใช้ SecondaryButton
                  Expanded(
                    child: SecondaryButton(
                      text: 'กรอกต่อ',
                      width: double.infinity,
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  // ปุ่มเข้าใช้งานเลย - ใช้ PrimaryButton
                  Expanded(
                    child: PrimaryButton(
                      text: 'เข้าใช้งานเลย!',
                      width: double.infinity,
                      onPressed: () {
                        Navigator.pop(dialogContext); // ปิด dialog
                        _handleSave(); // บันทึกและเข้าใช้งาน
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAsOnboarding
          ? null
          : AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              leading: IconButton(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  color: AppColors.primaryText,
                  size: AppIconSize.xl,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'แก้ไขโปรไฟล์',
                style: AppTypography.title.copyWith(color: AppColors.primaryText),
              ),
              centerTitle: true,
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppSpacing.paddingMd,
                    child: Column(
                      children: [
                        // Header (onboarding mode only)
                        if (widget.showAsOnboarding) _buildHeader(),

                        // Spacing ระหว่าง header กับ card แรก (onboarding mode)
                        if (widget.showAsOnboarding)
                          SizedBox(height: AppSpacing.md),

                        // Section 1: ข้อมูลพื้นฐาน
                        _buildSection1(),
                        SizedBox(height: AppSpacing.md),

                        // Section 2: ข้อมูลติดต่อ
                        _buildSection2(),
                        SizedBox(height: AppSpacing.md),

                        // Section 3: วุฒิการศึกษาและทักษะ
                        _buildSection3(),
                        SizedBox(height: AppSpacing.md),

                        // Section 4: การเงิน
                        _buildSection4(),
                        SizedBox(height: AppSpacing.md),

                        // Section 5: เอกสาร
                        _buildSection5(),
                        SizedBox(height: AppSpacing.md),

                        // Section 6: ข้อมูลเพิ่มเติม
                        _buildSection6(),
                        SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),

                // Bottom bar
                _buildBottomBar(),
              ],
            ),
    );
  }

  /// Header สำหรับ onboarding mode
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.md,
        bottom: AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            // Secret tap สำหรับ dev logout - เปิดเฉพาะ debug mode
            onTap: kDebugMode ? _handleSecretTap : null,
            child: Text(
              'ยินดีต้อนรับ',
              style: AppTypography.heading2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'มาสร้างโปรไฟล์กันเถอะ',
            style: AppTypography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ProfilePhotoPicker(
              currentPhotoUrl: _photoUrl,
              selectedPhoto: _selectedPhoto,
              isUploading: _isUploadingPhoto,
              onPhotoSelected: (file) {
                setState(() => _selectedPhoto = file);
              },
              size: 120,
            ),
          ),
        ],
      ),
    );
  }

  /// Section 1: ข้อมูลพื้นฐาน (บังคับ)
  Widget _buildSection1() {
    return _buildCollapsibleSection(
      title: '📝 ข้อมูลพื้นฐาน',
      subtitle: 'จำเป็นต้องกรอก',
      isRequired: true,
      hasData: _isSection1Valid,
      isExpanded: _section1Expanded,
      onExpansionChanged: (expanded) {
        setState(() => _section1Expanded = expanded);
      },
      children: [
        // รูปโปรไฟล์ (ถ้าไม่ใช่ onboarding)
        if (!widget.showAsOnboarding) ...[
          Center(
            child: ProfilePhotoPicker(
              currentPhotoUrl: _photoUrl,
              selectedPhoto: _selectedPhoto,
              isUploading: _isUploadingPhoto,
              onPhotoSelected: (file) {
                setState(() => _selectedPhoto = file);
              },
              size: 100,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
        ],

        // คำนำหน้าชื่อ
        PrefixDropdown(
          label: 'คำนำหน้าชื่อ',
          value: _selectedPrefix,
          onChanged: (value) => setState(() => _selectedPrefix = value),
        ),
        SizedBox(height: AppSpacing.md),

        // ชื่อ-สกุล (บังคับ)
        AppTextField(
          label: 'ชื่อ-สกุล *',
          hintText: 'เช่น สมชาย ใจดี',
          controller: _fullNameController,
          textCapitalization: TextCapitalization.words,
          prefixIcon: HugeIcons.strokeRoundedUser,
          fillColor: AppColors.primaryBackground,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: AppSpacing.md),

        // ชื่อเล่น (บังคับ) - ย้ายมาอยู่หลังชื่อ-สกุลเลย
        // ใช้ FocusNode เพื่อตรวจจับเมื่อ user ออกจาก field แล้วค่อยเช็ค
        AppTextField(
          label: 'ชื่อเล่น *',
          hintText: 'เช่น ชาย, เจ้ย',
          controller: _nicknameController,
          focusNode: _nicknameFocusNode,
          textCapitalization: TextCapitalization.words,
          prefixIcon: HugeIcons.strokeRoundedSmile,
          fillColor: AppColors.primaryBackground,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: AppSpacing.md),

        // ชื่อภาษาอังกฤษ (บังคับ)
        AppTextField(
          label: 'English Name - Surname *',
          hintText: 'e.g. Somchai Jaidee',
          controller: _englishNameController,
          textCapitalization: TextCapitalization.words,
          prefixIcon: HugeIcons.strokeRoundedLanguageCircle,
          fillColor: AppColors.primaryBackground,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: AppSpacing.md),

        // เพศ (บังคับ)
        _buildGenderSelection(),
        SizedBox(height: AppSpacing.md),

        // วันเกิด (บังคับ)
        _buildDateOfBirthPicker(isRequired: true),
        SizedBox(height: AppSpacing.md),

        // น้ำหนัก + ส่วนสูง (บังคับ)
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'น้ำหนัก (กก.) *',
                hintText: 'เช่น 55',
                controller: _weightController,
                keyboardType: TextInputType.number,
                prefixIcon: HugeIcons.strokeRoundedWeightScale01,
                fillColor: AppColors.primaryBackground,
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                label: 'ส่วนสูง (ซม.) *',
                hintText: 'เช่น 165',
                controller: _heightController,
                keyboardType: TextInputType.number,
                prefixIcon: HugeIcons.strokeRoundedRuler,
                fillColor: AppColors.primaryBackground,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),

        // Helper text
        SizedBox(height: AppSpacing.md),
        _buildRequiredFieldsHint(),
      ],
    );
  }

  /// Section 2: ข้อมูลติดต่อ (บังคับ)
  Widget _buildSection2() {
    return _buildCollapsibleSection(
      title: '📞 ข้อมูลติดต่อ',
      subtitle: 'จำเป็นต้องกรอก',
      isRequired: true,
      hasData: _isSection2Valid,
      isExpanded: _section2Expanded,
      onExpansionChanged: (expanded) {
        setState(() => _section2Expanded = expanded);
      },
      children: [
        // เลขบัตรประชาชน (บังคับ)
        AppTextField(
          label: 'เลขบัตรประชาชน *',
          hintText: 'ไม่ต้องใส่ - หรือเว้นวรรค',
          controller: _nationalIdController,
          keyboardType: TextInputType.number,
          prefixIcon: HugeIcons.strokeRoundedId,
          fillColor: AppColors.primaryBackground,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: AppSpacing.md),

        // ที่อยู่ (บังคับ)
        AppTextField(
          label: 'ที่อยู่ *',
          hintText: 'ใช้ที่อยู่ที่สามารถติดต่อผ่านทางไปรษณีย์ได้',
          controller: _addressController,
          maxLines: 3,
          prefixIcon: HugeIcons.strokeRoundedLocation01,
          fillColor: AppColors.primaryBackground,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: AppSpacing.md),

        // เบอร์โทรศัพท์ (บังคับ)
        AppTextField(
          label: 'เบอร์โทรศัพท์ *',
          hintText: 'ไม่ต้องใส่ - หรือเว้นวรรค',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: HugeIcons.strokeRoundedCall,
          fillColor: AppColors.primaryBackground,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: AppSpacing.md),

        // Line ID (ไม่บังคับ)
        AppTextField(
          label: 'Line ID',
          hintText: 'กรอก Line ID ของคุณ',
          controller: _lineIdController,
          prefixIcon: HugeIcons.strokeRoundedBubbleChat,
          fillColor: AppColors.primaryBackground,
        ),
      ],
    );
  }

  /// Section 3: วุฒิการศึกษาและทักษะ (บังคับ)
  Widget _buildSection3() {
    return _buildCollapsibleSection(
      title: '🎓 วุฒิการศึกษาและทักษะ',
      subtitle: 'จำเป็นต้องกรอก',
      isRequired: true,
      hasData: _isSection3Valid,
      isExpanded: _section3Expanded,
      onExpansionChanged: (expanded) {
        setState(() => _section3Expanded = expanded);
      },
      children: [
        // วุฒิการศึกษา (บังคับ)
        _buildEducationDropdown(isRequired: true),
        SizedBox(height: AppSpacing.md),

        // วุฒิบัตรด้านการบริบาล (บังคับ)
        CertificationDropdown(
          label: 'วุฒิบัตร/ประกาศนียบัตร ด้านการบริบาล',
          value: _selectedCertification,
          isRequired: true,
          onChanged: (value) => setState(() => _selectedCertification = value),
        ),
        SizedBox(height: AppSpacing.md),

        // จากสถาบัน (ไม่บังคับ)
        AppTextField(
          label: 'จากสถาบัน',
          hintText: 'ชื่อสถาบันที่ได้รับวุฒิบัตร',
          controller: _institutionController,
          prefixIcon: HugeIcons.strokeRoundedBuilding04,
          fillColor: AppColors.primaryBackground,
        ),
        SizedBox(height: AppSpacing.md),

        // ทักษะที่ทำได้ (บังคับ - multi select)
        SkillsMultiSelect(
          label: 'ทักษะที่สามารถทำได้อย่างคล่องแคล่ว',
          selectedSkills: _selectedSkills,
          isRequired: true,
          onChanged: (skills) => setState(() => _selectedSkills = skills),
        ),
        SizedBox(height: AppSpacing.md),

        // ประสบการณ์ทำงาน (ไม่บังคับ)
        AppTextField(
          label: 'ประสบการณ์ทำงาน',
          hintText: 'หากไม่มีให้เว้นว่างไว้',
          controller: _workExperienceController,
          maxLines: 3,
          prefixIcon: HugeIcons.strokeRoundedBriefcase01,
          fillColor: AppColors.primaryBackground,
        ),
        SizedBox(height: AppSpacing.md),

        // ความสามารถพิเศษ (ไม่บังคับ)
        AppTextField(
          label: 'ความสามารถพิเศษอื่นๆ',
          hintText: 'เช่น ทำอาหาร, ขับรถ',
          controller: _specialAbilitiesController,
          maxLines: 2,
          prefixIcon: HugeIcons.strokeRoundedStar,
          fillColor: AppColors.primaryBackground,
        ),
      ],
    );
  }

  /// Section 4: การเงิน (บังคับ)
  Widget _buildSection4() {
    return _buildCollapsibleSection(
      title: '🏦 การเงิน',
      subtitle: 'จำเป็นต้องกรอก',
      isRequired: true,
      hasData: _isSection4Valid,
      isExpanded: _section4Expanded,
      onExpansionChanged: (expanded) {
        setState(() => _section4Expanded = expanded);
      },
      children: [
        // ธนาคาร (บังคับ)
        _buildBankDropdown(isRequired: true),
        SizedBox(height: AppSpacing.md),

        // เลขบัญชี (บังคับ)
        AppTextField(
          label: 'เลขบัญชี *',
          hintText: 'กรอกเลขบัญชี',
          controller: _bankAccountController,
          keyboardType: TextInputType.number,
          prefixIcon: HugeIcons.strokeRoundedCreditCard,
          fillColor: AppColors.primaryBackground,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: AppSpacing.md),

        // หน้าบุ๊คแบงค์ (บังคับ)
        DocumentUploadPicker(
          documentType: DocumentType.bankBook,
          currentDocumentUrl: _bankBookPhotoUrl,
          selectedFile: _selectedBankBookPhoto,
          isRequired: true,
          onFileSelected: (file) {
            setState(() => _selectedBankBookPhoto = file);
          },
        ),
      ],
    );
  }

  /// Section 5: เอกสาร (บังคับ)
  Widget _buildSection5() {
    return _buildCollapsibleSection(
      title: '📄 เอกสาร',
      subtitle: 'จำเป็นต้องกรอก',
      isRequired: true,
      hasData: _isSection5Valid,
      isExpanded: _section5Expanded,
      onExpansionChanged: (expanded) {
        setState(() => _section5Expanded = expanded);
      },
      children: [
        // สำเนาบัตรประชาชน (บังคับ)
        DocumentUploadPicker(
          documentType: DocumentType.idCard,
          currentDocumentUrl: _idCardPhotoUrl,
          selectedFile: _selectedIdCardPhoto,
          isRequired: true,
          onFileSelected: (file) {
            setState(() => _selectedIdCardPhoto = file);
          },
        ),
        SizedBox(height: AppSpacing.md),

        // วุฒิบัตร/ประกาศนียบัตร (บังคับ)
        DocumentUploadPicker(
          documentType: DocumentType.certificate,
          currentDocumentUrl: _certificatePhotoUrl,
          selectedFile: _selectedCertificatePhoto,
          isRequired: true,
          onFileSelected: (file) {
            setState(() => _selectedCertificatePhoto = file);
          },
        ),
        SizedBox(height: AppSpacing.md),

        // Resume (ไม่บังคับ)
        DocumentUploadPicker(
          documentType: DocumentType.resume,
          currentDocumentUrl: _resumeUrl,
          selectedFile: _selectedResume,
          isRequired: false,
          onFileSelected: (file) {
            setState(() => _selectedResume = file);
          },
        ),
      ],
    );
  }

  /// Section 6: ข้อมูลเพิ่มเติม (ไม่บังคับ)
  Widget _buildSection6() {
    return _buildCollapsibleSection(
      title: '👤 ข้อมูลเพิ่มเติม',
      subtitle: 'กรอกภายหลังได้',
      isRequired: false,
      hasData: _hasSection6Data,
      isExpanded: _section6Expanded,
      onExpansionChanged: (expanded) {
        setState(() => _section6Expanded = expanded);
      },
      children: [
        // สถานภาพ
        MaritalStatusDropdown(
          label: 'สถานภาพ',
          value: _selectedMaritalStatus,
          onChanged: (value) => setState(() => _selectedMaritalStatus = value),
        ),
        SizedBox(height: AppSpacing.md),

        // จำนวนบุตร
        AppTextField(
          label: 'จำนวนบุตร',
          hintText: 'เช่น 2',
          controller: _childrenCountController,
          keyboardType: TextInputType.number,
          prefixIcon: HugeIcons.strokeRoundedBabyBed01,
          fillColor: AppColors.primaryBackground,
        ),
        SizedBox(height: AppSpacing.md),

        // โรคประจำตัว
        AppTextField(
          label: 'โรคประจำตัว',
          hintText: 'หากไม่มีให้เว้นว่างไว้',
          controller: _diseaseController,
          maxLines: 2,
          prefixIcon: HugeIcons.strokeRoundedFirstAidKit,
          fillColor: AppColors.primaryBackground,
        ),
        SizedBox(height: AppSpacing.md),

        // เกี่ยวกับฉัน
        AppTextField(
          label: 'แนะนำตัว',
          hintText: 'บอกเล่าเกี่ยวกับตัวคุณ...',
          controller: _aboutMeController,
          maxLines: 3,
          prefixIcon: HugeIcons.strokeRoundedUserEdit01,
          fillColor: AppColors.primaryBackground,
        ),
      ],
    );
  }

  /// Collapsible Section pattern
  Widget _buildCollapsibleSection({
    required String title,
    required String subtitle,
    required bool isRequired,
    required bool hasData,
    required bool isExpanded,
    required ValueChanged<bool> onExpansionChanged,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [AppShadows.subtle],
      ),
      // Clip เพื่อให้เงาโค้งตามมุมการ์ด
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // Shape ให้ ExpansionTile โค้งมุมตามการ์ด
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(title, style: AppTypography.heading3),
              ),
              if (hasData)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.tagPassedBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                        color: AppColors.tagPassedText,
                        size: AppIconSize.sm,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'ครบแล้ว',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.tagPassedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isRequired)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.tagPendingBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'จำเป็น',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.tagPendingText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          initiallyExpanded: isExpanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          children: [
            Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Helper Widgets ==========

  Widget _buildRequiredFieldsHint() {
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedInformationCircle,
          color: AppColors.primary,
          size: 14,
        ),
        SizedBox(width: 6),
        Text(
          'ฟิลด์ที่มี * จำเป็นต้องกรอก',
          style: TextStyle(fontSize: 12, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildGenderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('เพศ', style: AppTypography.label),
            Text(' *', style: AppTypography.label.copyWith(color: AppColors.error)),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _buildGenderOption(gender: 'หญิง', icon: HugeIcons.strokeRoundedWoman),
            SizedBox(width: AppSpacing.md),
            _buildGenderOption(gender: 'ชาย', icon: HugeIcons.strokeRoundedMan),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption({required String gender, required dynamic icon}) {
    final isSelected = _selectedGender == gender;
    // ใช้สีชมพูสำหรับหญิง และสีฟ้าสำหรับชาย
    final genderColor = gender == 'หญิง' ? AppColors.tertiary : AppColors.secondary;
    // สีพื้นหลังแบบอ่อนๆ (10% opacity)
    final bgColor = gender == 'หญิง'
        ? AppColors.tertiary.withValues(alpha: 0.1)
        : AppColors.secondary.withValues(alpha: 0.1);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = gender),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? bgColor : AppColors.background,
            borderRadius: AppRadius.smallRadius,
            border: Border.all(
              color: isSelected ? genderColor : AppColors.alternate,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              HugeIcon(
                icon: icon,
                color: isSelected ? genderColor : AppColors.secondaryText,
                size: AppIconSize.xxl,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                gender,
                style: AppTypography.body.copyWith(
                  color: isSelected ? genderColor : AppColors.primaryText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateOfBirthPicker({bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('วันเกิด', style: AppTypography.label),
            if (isRequired)
              Text(' *', style: AppTypography.label.copyWith(color: AppColors.error)),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'กรุณาใส่เป็น ค.ศ.',
          style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
        ),
        SizedBox(height: AppSpacing.xs),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDob ?? DateTime(1990),
              firstDate: DateTime(1940),
              lastDate: DateTime.now(),
              locale: const Locale('th'),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: AppColors.primary,
                      onPrimary: AppColors.surface,
                      surface: AppColors.surface,
                      onSurface: AppColors.primaryText,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() => _selectedDob = date);
            }
          },
          child: Container(
            padding: AppSpacing.inputPadding,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.smallRadius,
              border: Border.all(color: AppColors.alternate),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  color: AppColors.textSecondary,
                  size: AppIconSize.input,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _selectedDob != null
                        ? '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}'
                        : 'เลือกวันเกิด',
                    style: AppTypography.body.copyWith(
                      color: _selectedDob != null
                          ? AppColors.primaryText
                          : AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowDown01,
                  color: AppColors.textSecondary,
                  size: AppIconSize.input,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEducationDropdown({bool isRequired = false}) {
    const educations = [
      'ป.6',
      'ม.3',
      'ม.6',
      'ปวช',
      'ปวส',
      'ปริญญาตรี',
      'ปริญญาโท',
      'ปริญญาเอก',
      'อื่นๆ',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('ระดับการศึกษา', style: AppTypography.label),
            if (isRequired)
              Text(' *', style: AppTypography.label.copyWith(color: AppColors.error)),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.smallRadius,
            border: Border.all(color: AppColors.alternate),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedEducation,
              hint: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedMortarboard01,
                    color: AppColors.textSecondary,
                    size: AppIconSize.input,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'เลือกระดับการศึกษา',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              selectedItemBuilder: (context) {
                return educations.map((edu) {
                  return Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedMortarboard01,
                        color: AppColors.textSecondary,
                        size: AppIconSize.input,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(edu, style: AppTypography.body),
                    ],
                  );
                }).toList();
              },
              isExpanded: true,
              padding: AppSpacing.inputPadding,
              borderRadius: AppRadius.smallRadius,
              dropdownColor: AppColors.surface,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                color: AppColors.textSecondary,
                size: AppIconSize.input,
              ),
              items: educations.map((edu) {
                return DropdownMenuItem(value: edu, child: Text(edu, style: AppTypography.body));
              }).toList(),
              onChanged: (value) => setState(() => _selectedEducation = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBankDropdown({bool isRequired = false}) {
    const banks = ['กรุงเทพ', 'กรุงไทย', 'กรุงศรีอยุธยา', 'กสิกรไทย', 'ทหารไทย', 'ไทยพาณิชย์', 'ออมสิน'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('ธนาคาร', style: AppTypography.label),
            if (isRequired)
              Text(' *', style: AppTypography.label.copyWith(color: AppColors.error)),
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.smallRadius,
            border: Border.all(color: AppColors.alternate),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBank,
              hint: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedBank,
                    color: AppColors.textSecondary,
                    size: AppIconSize.input,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'เลือกธนาคาร',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              selectedItemBuilder: (context) {
                return banks.map((bank) {
                  return Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedBank,
                        color: AppColors.textSecondary,
                        size: AppIconSize.input,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(bank, style: AppTypography.body),
                    ],
                  );
                }).toList();
              },
              isExpanded: true,
              padding: AppSpacing.inputPadding,
              borderRadius: AppRadius.smallRadius,
              dropdownColor: AppColors.surface,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                color: AppColors.textSecondary,
                size: AppIconSize.input,
              ),
              items: banks.map((bank) {
                return DropdownMenuItem(value: bank, child: Text(bank, style: AppTypography.body));
              }).toList(),
              onChanged: (value) => setState(() => _selectedBank = value),
            ),
          ),
        ),
      ],
    );
  }

  /// Bottom bar: ปุ่มบันทึก
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: const [AppShadows.elevated],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // แสดง progress (ถ้ายังกรอกไม่ครบ 5 sections)
            if (!_isAllSectionsComplete) ...[
              _buildProgressIndicator(),
              SizedBox(height: AppSpacing.sm),
            ],

            // ปุ่มบันทึก - enabled เมื่อกรอกชื่อจริง+ชื่อเล่น (ขั้นต่ำ)
            // ถ้ากรอกครบทุก section แสดง "บันทึกข้อมูล" แทน "เริ่มใช้งาน!!"
            PrimaryButton(
              text: widget.showAsOnboarding
                  ? (_isAllSectionsComplete ? 'บันทึกข้อมูล' : 'เริ่มใช้งาน!!')
                  : 'บันทึก',
              icon: HugeIcons.strokeRoundedFloppyDisk,
              isLoading: _isSaving,
              isDisabled: !_isMinimumValid,
              width: double.infinity,
              onPressed: _isMinimumValid ? _handleSave : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final completedSections = [
      _isSection1Valid,
      _isSection2Valid,
      _isSection3Valid,
      _isSection4Valid,
      _isSection5Valid,
    ].where((v) => v).length;

    return Row(
      children: [
        Text(
          'กรอกครบแล้ว $completedSections/5 ส่วน',
          style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: LinearProgressIndicator(
            value: completedSections / 5,
            backgroundColor: AppColors.alternate,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  /// บันทึกข้อมูลทั้งหมด
  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      String? photoUrl = _photoUrl;
      String? bankBookUrl = _bankBookPhotoUrl;
      String? idCardUrl = _idCardPhotoUrl;
      String? certificateUrl = _certificatePhotoUrl;
      String? resumeUrlValue = _resumeUrl;

      // อัพโหลดรูป/เอกสารที่เลือกใหม่
      if (_selectedPhoto != null) {
        setState(() => _isUploadingPhoto = true);
        photoUrl = await _service.uploadProfilePhoto(_selectedPhoto!);
      }

      if (_selectedBankBookPhoto != null) {
        bankBookUrl = await _service.uploadDocument(_selectedBankBookPhoto!, 'bank-book');
      }

      if (_selectedIdCardPhoto != null) {
        idCardUrl = await _service.uploadDocument(_selectedIdCardPhoto!, 'id-card');
      }

      if (_selectedCertificatePhoto != null) {
        certificateUrl = await _service.uploadDocument(_selectedCertificatePhoto!, 'certificate');
      }

      if (_selectedResume != null) {
        resumeUrlValue = await _service.uploadDocument(_selectedResume!, 'resume');
      }

      // บันทึกข้อมูลทั้งหมด
      await _service.saveFullProfile(
        // Section 1
        fullName: _fullNameController.text,
        nickname: _nicknameController.text,
        prefix: _selectedPrefix,
        photoUrl: photoUrl,
        englishName: _englishNameController.text,
        gender: _selectedGender,
        dobStaff: _selectedDob,
        weight: double.tryParse(_weightController.text),
        height: double.tryParse(_heightController.text),
        // Section 2
        nationalIdStaff: _nationalIdController.text.replaceAll('-', ''),
        address: _addressController.text,
        phoneNumber: _phoneController.text.replaceAll('-', ''),
        lineId: _lineIdController.text,
        // Section 3
        educationDegree: _selectedEducation,
        careCertification: _selectedCertification,
        institution: _institutionController.text,
        skills: skillsToJson(_selectedSkills),
        workExperience: _workExperienceController.text,
        specialAbilities: _specialAbilitiesController.text,
        // Section 4
        bank: _selectedBank,
        bankAccount: _bankAccountController.text,
        bankBookPhotoUrl: bankBookUrl,
        // Section 5
        idCardPhotoUrl: idCardUrl,
        certificatePhotoUrl: certificateUrl,
        resumeUrl: resumeUrlValue,
        // Section 6
        maritalStatus: _selectedMaritalStatus,
        childrenCount: int.tryParse(_childrenCountController.text),
        underlyingDiseaseStaff: _diseaseController.text,
        aboutMe: _aboutMeController.text,
      );

      // มอบ badge "The Perfect Starter" ถ้ากรอกครบทุก section ตอน onboarding
      // แสดง celebration dialog พร้อม confetti เมื่อได้รับ badge
      if (widget.showAsOnboarding && _isAllSectionsComplete) {
        final badge = await BadgeService().awardPerfectStarterBadge();
        if (badge != null && mounted) {
          debugPrint('🏆 Awarded badge: ${badge.name}');
          // แสดง celebration dialog พร้อม confetti
          await BadgeCelebrationDialog.show(context, badge);
        }
      }

      if (mounted) {
        AppSnackbar.success(context, 'บันทึกข้อมูลเรียบร้อย');

        if (widget.showAsOnboarding) {
          widget.onComplete?.call();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('UnifiedProfileSetupScreen: Error saving: $e');
      if (mounted) {
        AppSnackbar.error(context, 'บันทึกไม่สำเร็จ: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingPhoto = false;
        });
      }
    }
  }

  // ========== Dev Tools ==========

  void _handleSecretTap() {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds > 2000) {
      _secretTapCount = 0;
    }
    _lastTapTime = now;
    _secretTapCount++;

    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _showDevLogoutDialog();
    }
  }

  void _showDevLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🐱 Dev Mode'),
        content: const Text('ต้องการออกจากระบบไหมเมี๊ยว?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }
}
