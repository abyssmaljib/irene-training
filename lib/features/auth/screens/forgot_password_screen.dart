import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/input_fields.dart';
import '../../../core/widgets/buttons.dart';

/// หน้า Forgot Password
///
/// ให้ user กรอก email แล้วส่ง reset password link ไปทาง email
class ForgotPasswordScreen extends StatefulWidget {
  /// Email ที่ส่งมาจากหน้า login (ถ้ามี)
  final String? initialEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Controller
  late final TextEditingController _emailController;

  // Focus Node
  final _emailFocusNode = FocusNode();

  // States
  bool _isLoading = false;
  bool _emailSent = false; // เมื่อส่ง email สำเร็จจะเปลี่ยนเป็น success state
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // ใช้ email จากหน้า login ถ้ามี
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  /// ส่ง reset password email
  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    // Validate email
    if (email.isEmpty) {
      setState(() => _errorMessage = 'กรุณากรอกอีเมล');
      return;
    }

    // Simple email validation
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'รูปแบบอีเมลไม่ถูกต้อง');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // เรียก Supabase reset password
      await Supabase.instance.client.auth.resetPasswordForEmail(email);

      // สำเร็จ - แสดง success state
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
    } catch (e) {
      debugPrint('ForgotPassword error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'ไม่สามารถส่งอีเมลได้ กรุณาลองใหม่';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      // ปิด resizeToAvoidBottomInset เพื่อป้องกัน Scaffold resize body ทุกเฟรม
      // ระหว่าง keyboard animation → ทำให้เนื้อหาไม่กระตุก
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            _buildAppBar(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                // เพิ่ม padding ล่างตาม viewInsets เพื่อให้ scroll ผ่านคีย์บอร์ดได้
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: _emailSent ? _buildSuccessState() : _buildForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: AppColors.textPrimary,
              size: AppIconSize.lg,
            ),
          ),

          AppSpacing.horizontalGapSm,

          // Title
          Expanded(
            child: Text(
              'จำรหัสผ่านไม่ได้?',
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Form สำหรับกรอก email
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon + Description
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.largeRadius,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedLockPassword,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ),

              AppSpacing.verticalGapLg,

              // Description text
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  'เราจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปยังอีเมลของคุณ',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        AppSpacing.verticalGapXl,

        // Email input
        AppTextField(
          controller: _emailController,
          label: 'อีเมล',
          hintText: 'example@ireneplus.com',
          prefixIcon: HugeIcons.strokeRoundedMail01,
          keyboardType: TextInputType.emailAddress,
          focusNode: _emailFocusNode,
          textInputAction: TextInputAction.done,
          autofocus: widget.initialEmail == null, // auto focus ถ้าไม่มี email ส่งมา
          errorText: _errorMessage,
          onSubmitted: (_) => _sendResetEmail(),
        ),

        AppSpacing.verticalGapLg,

        // Send button
        PrimaryButton(
          text: 'ส่งลิงก์รีเซ็ตรหัสผ่าน',
          icon: HugeIcons.strokeRoundedMailSend01,
          isLoading: _isLoading,
          width: double.infinity,
          onPressed: _isLoading ? null : _sendResetEmail,
        ),

        AppSpacing.verticalGapLg,

        // Back to login link
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'กลับไปหน้าเข้าสู่ระบบ',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Success state หลังส่ง email สำเร็จ
  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSpacing.verticalGapXl,

        // Success icon
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                color: AppColors.success,
                size: 50,
              ),
            ),
          ),
        ),

        AppSpacing.verticalGapLg,

        // Success title
        Text(
          'ส่งอีเมลแล้ว!',
          style: AppTypography.heading3.copyWith(
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),

        AppSpacing.verticalGapMd,

        // Success message
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'เราได้ส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปที่',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        AppSpacing.verticalGapSm,

        // Email display
        Text(
          _emailController.text,
          style: AppTypography.body.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),

        AppSpacing.verticalGapMd,

        // Hint text
        Container(
          margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: AppRadius.smallRadius,
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedInformationCircle,
                color: AppColors.info,
                size: AppIconSize.lg,
              ),
              AppSpacing.horizontalGapSm,
              Expanded(
                child: Text(
                  'กรุณาตรวจสอบกล่องขาเข้าหรือ spam folder',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
        ),

        AppSpacing.verticalGapXl,

        // Back to login button
        PrimaryButton(
          text: 'กลับไปหน้าเข้าสู่ระบบ',
          icon: HugeIcons.strokeRoundedLogin01,
          width: double.infinity,
          onPressed: () => Navigator.of(context).pop(),
        ),

        AppSpacing.verticalGapMd,

        // Resend link
        Center(
          child: TextButton(
            onPressed: () {
              // Reset state และให้ส่งใหม่ได้
              setState(() {
                _emailSent = false;
                _errorMessage = null;
              });
            },
            child: Text(
              'ไม่ได้รับอีเมล? ส่งอีกครั้ง',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
