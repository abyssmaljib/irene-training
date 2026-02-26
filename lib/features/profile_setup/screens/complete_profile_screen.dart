import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/input_fields.dart';
import '../services/profile_setup_service.dart';

/// หน้าสำหรับกรอกข้อมูลโปรไฟล์เพิ่มเติม (ไม่บังคับ)
/// เข้าถึงได้จากหน้า Settings หรือแสดงหลังจากหน้า 1 (onboarding)
///
/// ใช้ PageView แยกเป็น 2 หน้า:
/// - หน้า 2: ข้อมูลติดต่อ (เบอร์โทร, Line, ธนาคาร)
/// - หน้า 3: ข้อมูลส่วนตัว (เพศ, วันเกิด, การศึกษา)
///
/// Parameters:
/// - [onComplete]: Callback เมื่อเสร็จหรือข้าม (ใช้ใน onboarding mode)
/// - [showAsOnboarding]: true = แสดงแบบ onboarding (มีปุ่มข้าม), false = จาก Settings
class CompleteProfileScreen extends ConsumerStatefulWidget {
  /// Callback เมื่อกรอกเสร็จหรือกดข้าม (ใช้ใน onboarding mode)
  final VoidCallback? onComplete;

  /// แสดงแบบ onboarding (มีปุ่มข้าม) หรือจาก Settings (ไม่มีปุ่มข้าม)
  final bool showAsOnboarding;

  const CompleteProfileScreen({
    super.key,
    this.onComplete,
    this.showAsOnboarding = false,
  });

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _pageController = PageController();
  final _service = ProfileSetupService();

  // Current page index (0 = contact info, 1 = personal info)
  int _currentPage = 0;

  // Loading state
  bool _isLoading = false;
  bool _isSaving = false;

  // Page 2: Contact info
  final _phoneController = TextEditingController();
  final _lineIdController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _nationalIdController = TextEditingController();
  String? _selectedBank;

  // Page 3: Personal info
  String? _selectedGender;
  DateTime? _selectedDob;
  String? _selectedEducation;
  final _diseaseController = TextEditingController();
  final _aboutMeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _lineIdController.dispose();
    _bankAccountController.dispose();
    _nationalIdController.dispose();
    _diseaseController.dispose();
    _aboutMeController.dispose();
    super.dispose();
  }

  /// โหลดข้อมูล profile ปัจจุบันเพื่อแสดงในฟอร์ม
  Future<void> _loadCurrentProfile() async {
    setState(() => _isLoading = true);

    try {
      final profile = await _service.getCurrentProfile();
      if (profile != null && mounted) {
        setState(() {
          // Page 2
          _phoneController.text = profile['phone_number'] ?? '';
          _lineIdController.text = profile['line_ID'] ?? '';
          _selectedBank = profile['bank'];
          _bankAccountController.text = profile['bank_account'] ?? '';
          _nationalIdController.text = profile['national_ID_staff'] ?? '';

          // Page 3
          _selectedGender = profile['gender'];
          if (profile['DOB_staff'] != null) {
            _selectedDob = DateTime.tryParse(profile['DOB_staff']);
          }
          _selectedEducation = profile['education_degree'];
          _diseaseController.text = profile['underlying_disease_staff'] ?? '';
          _aboutMeController.text = profile['about_me'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('CompleteProfileScreen: Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// บันทึกข้อมูลหน้าปัจจุบัน
  Future<void> _saveCurrentPage() async {
    setState(() => _isSaving = true);

    try {
      if (_currentPage == 0) {
        // Save contact info (Page 2)
        await _service.saveContactInfo(
          phoneNumber: _phoneController.text.replaceAll('-', ''),
          lineId: _lineIdController.text,
          bank: _selectedBank,
          bankAccount: _bankAccountController.text,
          nationalIdStaff: _nationalIdController.text.replaceAll('-', ''),
        );
      } else {
        // Save personal info (Page 3)
        await _service.savePersonalInfo(
          gender: _selectedGender,
          dobStaff: _selectedDob,
          educationDegree: _selectedEducation,
          underlyingDiseaseStaff: _diseaseController.text,
          aboutMe: _aboutMeController.text,
        );
      }

      if (mounted) {
        AppSnackbar.success(context, 'บันทึกข้อมูลเรียบร้อย');
      }
    } catch (e) {
      debugPrint('CompleteProfileScreen: Error saving: $e');
      if (mounted) {
        AppSnackbar.error(context, 'บันทึกไม่สำเร็จ: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _goToNextPage() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        // Onboarding mode: ไม่มีปุ่มกลับ (ใช้ปุ่มข้ามด้านล่างแทน)
        // Settings mode: มีปุ่มกลับ
        leading: widget.showAsOnboarding
            ? const SizedBox.shrink()
            : IconButton(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  color: AppColors.primaryText,
                  size: AppIconSize.xl,
                ),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          widget.showAsOnboarding ? 'ข้อมูลเพิ่มเติม' : 'แก้ไขโปรไฟล์',
          style: AppTypography.title.copyWith(color: AppColors.primaryText),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Page indicator
                _buildPageIndicator(),

                // Page content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      _buildContactInfoPage(),
                      _buildPersonalInfoPage(),
                    ],
                  ),
                ),

                // Bottom buttons
                _buildBottomButtons(),
              ],
            ),
    );
  }

  /// Step indicator แสดง step 2 และ 3 พร้อมเส้นเชื่อมต่อ
  /// Active step จะมี background สี primary และ text สีขาว
  /// Inactive step จะมี background สีเทาและ text สีเทา
  Widget _buildPageIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Step 2 - ข้อมูลติดต่อ
          _buildStepIndicator(
            stepNumber: 2,
            label: 'ข้อมูลติดต่อ',
            isActive: _currentPage == 0,
            isCompleted: _currentPage > 0,
          ),

          // เส้นเชื่อมระหว่าง step
          Expanded(
            child: Container(
              height: 2,
              margin: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              // เส้นจะเป็นสี primary ถ้า step แรกเสร็จแล้ว
              color: _currentPage > 0
                  ? AppColors.primary
                  : AppColors.alternate,
            ),
          ),

          // Step 3 - ข้อมูลส่วนตัว
          _buildStepIndicator(
            stepNumber: 3,
            label: 'ข้อมูลส่วนตัว',
            isActive: _currentPage == 1,
            isCompleted: false, // หน้าสุดท้าย ไม่มี completed state
          ),
        ],
      ),
    );
  }

  /// สร้าง step indicator แต่ละ step
  /// - isActive: กำลังอยู่หน้านี้ (วงกลมสี primary)
  /// - isCompleted: ผ่านหน้านี้ไปแล้ว (วงกลมสี primary แต่ไม่ active)
  Widget _buildStepIndicator({
    required int stepNumber,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    // Active หรือ completed จะใช้สี primary
    final isPrimaryColor = isActive || isCompleted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // วงกลมแสดงเลข step
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPrimaryColor ? AppColors.primary : AppColors.alternate,
          ),
          child: Center(
            child: Text(
              '$stepNumber',
              style: AppTypography.button.copyWith(
                color: isPrimaryColor
                    ? AppColors.surface
                    : AppColors.secondaryText,
                fontSize: 15,
              ),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        // Label ใต้วงกลม
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isActive ? AppColors.primary : AppColors.secondaryText,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  /// หน้า 2: ข้อมูลการติดต่อ
  /// ประกอบด้วย: เบอร์โทร, Line ID, ธนาคาร, เลขบัญชี, เลขบัตรประชาชน
  Widget _buildContactInfoPage() {
    return SingleChildScrollView(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header - แบบ simple ไม่มี icon box
          Text(
            'ข้อมูลการติดต่อ',
            style: AppTypography.heading3.copyWith(
              color: AppColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.verticalGapXs,
          Text(
            'เพื่อให้ทีมงานติดต่อคุณได้สะดวก',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          AppSpacing.verticalGapLg,

          // เบอร์โทรศัพท์
          AppTextField(
            label: 'เบอร์โทรศัพท์',
            hintText: '0XX-XXX-XXXX',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: HugeIcons.strokeRoundedCall,
            fillColor: AppColors.surface, // สีขาวบนพื้นเทา
          ),
          AppSpacing.verticalGapMd,

          // Line ID
          AppTextField(
            label: 'Line ID',
            hintText: 'กรอก Line ID ของคุณ',
            controller: _lineIdController,
            prefixIcon: HugeIcons.strokeRoundedBubbleChat,
            fillColor: AppColors.surface,
          ),
          AppSpacing.verticalGapMd,

          // ธนาคาร - dropdown พร้อม icon
          _buildBankDropdown(),
          AppSpacing.verticalGapMd,

          // เลขบัญชีธนาคาร
          AppTextField(
            label: 'เลขบัญชีธนาคาร',
            hintText: 'กรอกเลขบัญชี',
            controller: _bankAccountController,
            keyboardType: TextInputType.number,
            prefixIcon: HugeIcons.strokeRoundedCreditCard,
            fillColor: AppColors.surface,
          ),
          AppSpacing.verticalGapMd,

          // เลขบัตรประชาชน
          AppTextField(
            label: 'เลขบัตรประชาชน',
            hintText: 'X-XXXX-XXXXX-XX-X',
            controller: _nationalIdController,
            keyboardType: TextInputType.number,
            prefixIcon: HugeIcons.strokeRoundedId,
            fillColor: AppColors.surface,
          ),

          // เพิ่ม spacing ด้านล่างเพื่อไม่ให้ field สุดท้ายชิด bottom bar
          AppSpacing.verticalGapXl,
        ],
      ),
    );
  }

  /// Dropdown สำหรับเลือกธนาคาร
  /// Style เหมือน AppTextField - มี icon ซ้าย, dropdown arrow ขวา
  Widget _buildBankDropdown() {
    const banks = [
      'กสิกรไทย',
      'กรุงไทย',
      'ไทยพาณิชย์',
      'กรุงเทพ',
      'กรุงศรีอยุธยา',
      'ทหารไทยธนชาต',
      'ออมสิน',
      'ธ.ก.ส.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label เหมือน AppTextField
        Text('ธนาคาร', style: AppTypography.label),
        AppSpacing.verticalGapXs,

        // Dropdown container - style เหมือน input field (สีขาวบนพื้นเทา)
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.smallRadius,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBank,
              hint: Row(
                children: [
                  // Icon ด้านซ้าย (เหมือน prefixIcon ของ AppTextField)
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedBank,
                    color: AppColors.textSecondary,
                    size: AppIconSize.input,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  // Hint text
                  Text(
                    'เลือกธนาคาร',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              // เมื่อเลือกแล้ว แสดง icon + ชื่อธนาคาร
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
              // Dropdown arrow icon
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                color: AppColors.textSecondary,
                size: AppIconSize.input,
              ),
              items: banks.map((bank) {
                return DropdownMenuItem(
                  value: bank,
                  child: Text(bank, style: AppTypography.body),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedBank = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// หน้า 3: ข้อมูลส่วนตัว
  /// ประกอบด้วย: เพศ, วันเกิด, วุฒิการศึกษา, โรคประจำตัว, เกี่ยวกับฉัน
  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header - แบบ simple
          Text(
            'ข้อมูลส่วนตัว',
            style: AppTypography.heading3.copyWith(
              color: AppColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.verticalGapXs,
          Text(
            'บอกเราเกี่ยวกับตัวคุณอีกนิดหน่อย',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          AppSpacing.verticalGapLg,

          // เพศ - แสดงเป็น selection cards
          _buildGenderSelection(),
          AppSpacing.verticalGapMd,

          // วันเกิด - date picker
          _buildDateOfBirthPicker(),
          AppSpacing.verticalGapMd,

          // วุฒิการศึกษา - dropdown
          _buildEducationDropdown(),
          AppSpacing.verticalGapMd,

          // โรคประจำตัว
          AppTextField(
            label: 'โรคประจำตัว (ถ้ามี)',
            hintText: 'เช่น ภูมิแพ้, เบาหวาน',
            controller: _diseaseController,
            prefixIcon: HugeIcons.strokeRoundedFirstAidKit,
            maxLines: 2,
            fillColor: AppColors.surface, // สีขาวบนพื้นเทา
          ),
          AppSpacing.verticalGapMd,

          // เกี่ยวกับฉัน
          AppTextField(
            label: 'เกี่ยวกับฉัน',
            hintText: 'บอกเล่าเกี่ยวกับตัวคุณ...',
            controller: _aboutMeController,
            prefixIcon: HugeIcons.strokeRoundedUserEdit01,
            maxLines: 3,
            fillColor: AppColors.surface,
          ),

          // เพิ่ม spacing ด้านล่างเพื่อไม่ให้ field สุดท้ายชิด bottom bar
          AppSpacing.verticalGapXl,
        ],
      ),
    );
  }

  /// Selection สำหรับเลือกเพศ
  /// แสดงเป็น 2 cards: ชาย และ หญิง
  Widget _buildGenderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('เพศ', style: AppTypography.label),
        AppSpacing.verticalGapSm,
        Row(
          children: [
            // ตัวเลือก ชาย
            _buildGenderOption(
              gender: 'ชาย',
              icon: HugeIcons.strokeRoundedMan,
            ),
            SizedBox(width: AppSpacing.md),
            // ตัวเลือก หญิง
            _buildGenderOption(
              gender: 'หญิง',
              icon: HugeIcons.strokeRoundedWoman,
            ),
          ],
        ),
      ],
    );
  }

  /// สร้าง card สำหรับเลือกเพศแต่ละตัวเลือก
  /// เมื่อ selected จะมี border สี primary และ background สี accent
  Widget _buildGenderOption({
    required String gender,
    required dynamic icon,
  }) {
    final isSelected = _selectedGender == gender;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = gender),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            // Background สี accent เมื่อเลือก, ไม่งั้นสีขาว (บนพื้นเทา)
            color: isSelected ? AppColors.accent1 : AppColors.surface,
            borderRadius: AppRadius.smallRadius,
            // Border สี primary เมื่อเลือก
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // Icon
              HugeIcon(
                icon: icon,
                color: isSelected ? AppColors.primary : AppColors.secondaryText,
                size: AppIconSize.xxl,
              ),
              SizedBox(height: AppSpacing.sm),
              // Label
              Text(
                gender,
                style: AppTypography.body.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.primaryText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Date picker สำหรับเลือกวันเกิด
  /// Style เหมือน input field - มี icon ซ้าย
  Widget _buildDateOfBirthPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('วันเกิด', style: AppTypography.label),
        AppSpacing.verticalGapXs,
        GestureDetector(
          onTap: () async {
            // เปิด date picker dialog
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDob ?? DateTime(1990),
              firstDate: DateTime(1940),
              lastDate: DateTime.now(),
              locale: const Locale('th'),
              builder: (context, child) {
                // ปรับ theme ของ date picker ให้เข้ากับ design system
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
              color: AppColors.surface, // สีขาวบนพื้นเทา
              borderRadius: AppRadius.smallRadius,
            ),
            child: Row(
              children: [
                // Icon ด้านซ้าย
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  color: AppColors.textSecondary,
                  size: AppIconSize.input,
                ),
                SizedBox(width: AppSpacing.sm),
                // แสดงวันที่ที่เลือก หรือ placeholder
                Expanded(
                  child: Text(
                    _selectedDob != null
                        ? '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}' // แสดงเป็น ค.ศ.
                        : 'เลือกวันเกิด',
                    style: AppTypography.body.copyWith(
                      color: _selectedDob != null
                          ? AppColors.primaryText
                          : AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                // Icon calendar ด้านขวา
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

  /// Dropdown สำหรับเลือกวุฒิการศึกษา
  /// Style เหมือน bank dropdown - มี icon ซ้าย, dropdown arrow ขวา
  Widget _buildEducationDropdown() {
    const educations = [
      'ประถมศึกษา',
      'มัธยมศึกษาตอนต้น',
      'มัธยมศึกษาตอนปลาย',
      'ปวช.',
      'ปวส.',
      'ปริญญาตรี',
      'ปริญญาโท',
      'ปริญญาเอก',
      'อื่นๆ',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('วุฒิการศึกษา', style: AppTypography.label),
        AppSpacing.verticalGapXs,
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface, // สีขาวบนพื้นเทา
            borderRadius: AppRadius.smallRadius,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedEducation,
              hint: Row(
                children: [
                  // Icon ด้านซ้าย
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedMortarboard01,
                    color: AppColors.textSecondary,
                    size: AppIconSize.input,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  // Hint text
                  Text(
                    'เลือกวุฒิการศึกษา',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              // เมื่อเลือกแล้ว แสดง icon + วุฒิการศึกษา
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
              // Dropdown arrow icon
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                color: AppColors.textSecondary,
                size: AppIconSize.input,
              ),
              items: educations.map((edu) {
                return DropdownMenuItem(
                  value: edu,
                  child: Text(edu, style: AppTypography.body),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedEducation = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// จัดการเมื่อกดปุ่มข้าม - ข้ามหน้าปัจจุบันไปหน้าถัดไป หรือเข้าแอป
  void _handleSkip() {
    if (_currentPage < 1) {
      // ยังอยู่หน้า 2 - ข้ามไปหน้า 3
      _goToNextPage();
    } else {
      // อยู่หน้า 3 แล้ว - ข้ามเข้าแอปเลย
      _finishAndExit();
    }
  }

  /// จัดการเมื่อกดปุ่มข้ามทั้งหมด - ข้ามไปเข้าแอปเลย
  void _handleSkipAll() {
    _finishAndExit();
  }

  /// เสร็จสิ้นและออกจากหน้านี้
  void _finishAndExit() {
    if (widget.showAsOnboarding && widget.onComplete != null) {
      // Onboarding mode - เรียก callback
      widget.onComplete!();
    } else {
      // Settings mode - กลับไปหน้าก่อน
      Navigator.pop(context);
    }
  }

  /// Bottom buttons bar
  /// Onboarding mode: [ข้ามทั้งหมด] [ข้าม] [บันทึกและไปต่อ]
  /// Settings mode: [กลับ/ย้อนกลับ] [บันทึก]
  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: const [AppShadows.elevated],
      ),
      child: SafeArea(
        child: widget.showAsOnboarding
            ? _buildOnboardingButtons()
            : _buildSettingsButtons(),
      ),
    );
  }

  /// ปุ่มสำหรับ onboarding mode
  /// Layout: [ข้ามทั้งหมด (text)] [ข้าม (outline)] [บันทึกและไปต่อ (primary)]
  Widget _buildOnboardingButtons() {
    return Row(
      children: [
        // ปุ่มซ้ายสุด: ข้ามทั้งหมด (text button) หรือ ย้อนกลับ
        if (_currentPage == 0)
          // หน้า 2 - แสดง "ข้ามทั้งหมด"
          TextButton(
            onPressed: _handleSkipAll,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
            ),
            child: Text(
              'ข้ามทั้งหมด',
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          )
        else
          // หน้า 3 - แสดง "ย้อนกลับ"
          TextButton(
            onPressed: _goToPreviousPage,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
            ),
            child: Text(
              'ย้อนกลับ',
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ),

        SizedBox(width: AppSpacing.sm),

        // ปุ่มกลาง: ข้าม (outline button)
        Expanded(
          child: OutlinedButton(
            onPressed: _handleSkip,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              side: BorderSide(color: AppColors.alternate),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.smallRadius,
              ),
            ),
            child: Text(
              'ข้าม',
              style: AppTypography.button.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ),

        SizedBox(width: AppSpacing.sm),

        // ปุ่มขวาสุด: บันทึกและไปต่อ (primary button)
        Expanded(
          flex: 2,
          child: PrimaryButton(
            text: _currentPage < 1 ? 'บันทึกและไปต่อ' : 'เสร็จสิ้น',
            isLoading: _isSaving,
            onPressed: () async {
              await _saveCurrentPage();
              if (_currentPage < 1) {
                _goToNextPage();
              } else {
                // หน้าสุดท้าย - เข้าแอป
                _finishAndExit();
              }
            },
          ),
        ),
      ],
    );
  }

  /// ปุ่มสำหรับ settings mode (เข้าจาก Settings)
  /// Layout: [กลับ/ย้อนกลับ] [บันทึก]
  Widget _buildSettingsButtons() {
    return Row(
      children: [
        // ปุ่มซ้าย: กลับ หรือ ย้อนกลับ
        Expanded(
          child: OutlinedButton(
            onPressed:
                _currentPage > 0 ? _goToPreviousPage : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.smallRadius,
              ),
            ),
            child: Text(
              _currentPage > 0 ? 'ย้อนกลับ' : 'กลับ',
              style: AppTypography.button.copyWith(color: AppColors.primary),
            ),
          ),
        ),

        SizedBox(width: AppSpacing.md),

        // ปุ่มขวา: บันทึก
        Expanded(
          flex: 2,
          child: PrimaryButton(
            text: _currentPage < 1 ? 'บันทึกและไปต่อ' : 'บันทึก',
            isLoading: _isSaving,
            onPressed: () async {
              await _saveCurrentPage();
              if (_currentPage < 1) {
                _goToNextPage();
              } else {
                // หน้าสุดท้าย - กลับไป Settings
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
        ),
      ],
    );
  }
}
