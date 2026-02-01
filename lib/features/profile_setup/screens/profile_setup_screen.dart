import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/input_fields.dart';
import '../providers/profile_setup_provider.dart';
import '../widgets/prefix_dropdown.dart';
import '../widgets/profile_photo_picker.dart';

/// หน้าสำหรับกรอกข้อมูลโปรไฟล์ครั้งแรก (บังคับ)
/// แสดงหลังจากสมัครบัญชีสำเร็จ - ต้องกรอกก่อนเข้าแอป
///
/// Design:
/// - Gradient header ด้านบน (teal -> light blue)
/// - Profile photo picker อยู่บน header
/// - Card สีขาวสำหรับ form
/// - ใช้สี primary (teal) เป็นหลัก
///
/// ข้อมูลที่ต้องกรอก:
/// - รูปโปรไฟล์ (ไม่บังคับ)
/// - คำนำหน้าชื่อ (ไม่บังคับ)
/// - ชื่อ-สกุล (บังคับ)
/// - ชื่อเล่น (บังคับ)
///
/// หลังกรอกหน้านี้เสร็จ จะเข้าแอปได้เลย
/// ส่วนหน้า 2-3 (ข้อมูลติดต่อ, ข้อมูลส่วนตัว) กรอกทีหลังได้จาก Settings
class ProfileSetupScreen extends ConsumerStatefulWidget {
  /// Callback เมื่อกรอกข้อมูลเสร็จ
  final VoidCallback onComplete;

  const ProfileSetupScreen({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  // Controllers สำหรับ text fields
  final _fullNameController = TextEditingController();
  final _nicknameController = TextEditingController();

  // Focus nodes
  final _fullNameFocus = FocusNode();
  final _nicknameFocus = FocusNode();

  // Secret logout tap counter (for dev)
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  @override
  void dispose() {
    _fullNameController.dispose();
    _nicknameController.dispose();
    _fullNameFocus.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileSetupFormProvider);
    final notifier = ref.read(profileSetupFormProvider.notifier);

    // Listen for submit success
    ref.listen<ProfileSetupState>(profileSetupFormProvider, (prev, next) {
      if (next.isSubmitSuccess && !(prev?.isSubmitSuccess ?? false)) {
        widget.onComplete();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Gradient header พร้อม profile photo
            _buildGradientHeader(context, state, notifier),

            // Form card
            Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                children: [
                  // Title section
                  _buildTitle(),
                  AppSpacing.verticalGapLg,

                  // Form card สีขาว
                  Container(
                    padding: AppSpacing.paddingLg,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Form fields
                        _buildForm(state, notifier),
                        AppSpacing.verticalGapLg,

                        // Error message
                        if (state.errorMessage != null) ...[
                          _buildErrorMessage(state.errorMessage!),
                          AppSpacing.verticalGapMd,
                        ],

                        // Submit button
                        PrimaryButton(
                          text: 'เริ่มงานได้เลย!!',
                          icon: HugeIcons.strokeRoundedArrowRight01,
                          isLoading: state.isLoading,
                          isDisabled: !state.isValid,
                          width: double.infinity,
                          onPressed:
                              state.isValid ? () => notifier.submit() : null,
                        ),
                      ],
                    ),
                  ),

                  // Footer spacing
                  AppSpacing.verticalGapLg,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Header พื้นหลัง gradient พร้อม profile photo picker
  Widget _buildGradientHeader(
    BuildContext context,
    ProfileSetupState state,
    ProfileSetupFormNotifier notifier,
  ) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        // ใช้ gradient จาก teal ไป light blue
        gradient: AppColors.primaryGradient,
        // โค้งมนด้านล่าง
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Spacing ด้านบน
            AppSpacing.verticalGapLg,

            // Welcome text บน gradient (กด 5 ครั้งเพื่อ logout - สำหรับ dev)
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
            const SizedBox(height: 4),
            Text(
              'มาสร้างโปรไฟล์กันเถอะ',
              style: AppTypography.body.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            AppSpacing.verticalGapLg,

            // Profile photo picker - อยู่ตรงกลาง ล้ำขอบ gradient ลงมา
            Transform.translate(
              offset: const Offset(0, 30),
              child: Container(
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
                  currentPhotoUrl: state.photoUrl,
                  selectedPhoto: state.selectedPhoto,
                  isUploading: state.isUploadingPhoto,
                  onPhotoSelected: notifier.setSelectedPhoto,
                  size: 130,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Title section - มี spacing ด้านบนเพื่อรองรับ profile photo ที่ล้ำลงมา
  Widget _buildTitle() {
    return Column(
      children: [
        // Spacing สำหรับ profile photo ที่ล้ำลงมา 30px
        const SizedBox(height: 50),

        // Subtitle text
        Text(
          'กรอกข้อมูลเบื้องต้นเพื่อเริ่มต้นใช้งาน',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(ProfileSetupState state, ProfileSetupFormNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent1,
                borderRadius: BorderRadius.circular(10),
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedUserEdit01,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'ข้อมูลของฉัน',
              style: AppTypography.subtitle.copyWith(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        AppSpacing.verticalGapMd,

        // Prefix dropdown
        PrefixDropdown(
          label: 'คำนำหน้าชื่อ',
          value: state.prefix,
          onChanged: notifier.setPrefix,
        ),
        AppSpacing.verticalGapMd,

        // Full name (required)
        AppTextField(
          label: 'ชื่อ-สกุล *',
          hintText: 'เช่น สมชาย ใจดี',
          controller: _fullNameController,
          focusNode: _fullNameFocus,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          prefixIcon: HugeIcons.strokeRoundedUser,
          onChanged: notifier.setFullName,
          onSubmitted: (_) => _nicknameFocus.requestFocus(),
        ),
        AppSpacing.verticalGapMd,

        // Nickname (required)
        AppTextField(
          label: 'ชื่อเล่น *',
          hintText: 'เช่น ชาย, เจ้ย',
          controller: _nicknameController,
          focusNode: _nicknameFocus,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          prefixIcon: HugeIcons.strokeRoundedSmile,
          onChanged: notifier.setNickname,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
        ),

        // Helper text with icon
        AppSpacing.verticalGapMd,
        Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedInformationCircle,
              color: AppColors.primary,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              'ฟิลด์ที่มี * จำเป็นต้องกรอก',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Secret tap handler สำหรับ dev - กด 5 ครั้งติดๆ กันเพื่อ logout
  void _handleSecretTap() {
    final now = DateTime.now();

    // Reset counter ถ้าผ่านไป 2 วินาที
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds > 2000) {
      _secretTapCount = 0;
    }

    _lastTapTime = now;
    _secretTapCount++;

    // ถ้ากด 5 ครั้งแล้ว แสดง dialog
    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _showDevLogoutDialog();
    }
  }

  /// Dialog สำหรับ dev logout
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
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlertCircle,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.error,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
