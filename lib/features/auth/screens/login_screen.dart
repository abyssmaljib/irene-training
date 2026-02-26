import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/input_fields.dart';
import 'invitation_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _pinCodeController = TextEditingController();

  // Focus Nodes
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();

  // States
  bool _isPasswordMode = true;  // true = password, false = OTP
  bool _isLoading = false;
  bool _otpSent = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _pinCodeController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  // Login with email & password
  Future<void> _loginWithPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'กรุณากรอกอีเมลและรหัสผ่าน');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // ไม่ต้อง Navigator.pushReplacement เพราะ AuthWrapper ใน main.dart
      // จะ listen auth state change และ rebuild ไป MainNavigationScreen อัตโนมัติ
      // การทำ navigation ซ้ำจะทำให้เกิด race condition และ UI แสดงผลผิดพลาด
    } on AuthException catch (e) {
      debugPrint('AuthException: ${e.message}');
      setState(() => _errorMessage = _getThaiErrorMessage(e.message));
    } catch (e, stackTrace) {
      debugPrint('Login error: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() => _errorMessage = 'เกิดข้อผิดพลาด: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Send OTP
  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) {
      setState(() => _errorMessage = 'กรุณากรอกอีเมล');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: _emailController.text.trim(),
      );

      setState(() => _otpSent = true);

      if (mounted) {
        AppSnackbar.success(context, 'ส่งรหัส OTP ไปที่ ${_emailController.text} แล้ว');
      }
    } catch (e) {
      setState(() => _errorMessage = 'ไม่สามารถส่ง OTP ได้ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Verify OTP
  Future<void> _verifyOtp() async {
    if (_pinCodeController.text.isEmpty) {
      setState(() => _errorMessage = 'กรุณากรอกรหัส OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _pinCodeController.text.trim(),
        type: OtpType.email,
      );

      // ไม่ต้อง Navigator.pushReplacement เพราะ AuthWrapper ใน main.dart
      // จะ listen auth state change และ rebuild ไป MainNavigationScreen อัตโนมัติ
      // การทำ navigation ซ้ำจะทำให้เกิด race condition และ UI แสดงผลผิดพลาด
    } on AuthException catch (e) {
      setState(() => _errorMessage = _getThaiErrorMessage(e.message));
    } catch (e) {
      setState(() => _errorMessage = 'รหัส OTP ไม่ถูกต้อง');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getThaiErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    } else if (message.contains('Email not confirmed')) {
      return 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ';
    } else if (message.contains('Invalid OTP')) {
      return 'รหัส OTP ไม่ถูกต้อง';
    }
    return 'เกิดข้อผิดพลาด กรุณาลองใหม่';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ปิด resizeToAvoidBottomInset เพื่อป้องกัน Scaffold resize body ทุกเฟรม
      // ระหว่าง keyboard animation → ทำให้เนื้อหาไม่กระตุก
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        // เพิ่ม padding ล่างตาม viewInsets เพื่อให้ scroll ผ่านคีย์บอร์ดได้
        // ใช้ viewInsetsOf แทน .of().viewInsets เพื่อ subscribe เฉพาะ viewInsets ไม่ใช่ทุก MediaQuery change
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            // Header with gradient
            _buildHeader(),

            // Login form card
            Transform.translate(
              offset: const Offset(0, -40),
              child: _buildLoginCard(),
            ),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.mediumRadius,
                boxShadow: AppShadows.cardShadow,
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedHospital01,
                  size: AppIconSize.xxl,
                  color: AppColors.primary,
                ),
              ),
            ),
            AppSpacing.verticalGapSm,
            Text(
              'IRENE PLUS',
              style: AppTypography.heading2.copyWith(
                color: AppColors.surface,
                letterSpacing: 2,
              ),
            ),
            Text(
              'ระบบบริหารจัดการสุขภาพ',
              style: AppTypography.caption.copyWith(
                color: AppColors.surface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            'เข้าสู่ระบบด้วย',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          AppSpacing.verticalGapMd,

          // Toggle: Password / OTP
          _buildToggle(),
          AppSpacing.verticalGapLg,

            // Email field
            _buildEmailField(),
          AppSpacing.verticalGapMd,

          // Password or OTP fields
          if (_isPasswordMode) ...[
            _buildPasswordField(),
          ] else ...[
            _buildOtpSection(),
          ],

          // Error message
          if (_errorMessage != null) ...[
            AppSpacing.verticalGapSm,
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: AppIconSize.sm, color: AppColors.error),
                AppSpacing.horizontalGapXs,
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],

          AppSpacing.verticalGapLg,

          // Login button
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.smallRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isPasswordMode = true;
                _errorMessage = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: _isPasswordMode ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.xs + 2), // 6px for inner toggle
                ),
                child: Text(
                  'รหัสผ่าน',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _isPasswordMode ? AppColors.surface : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isPasswordMode = false;
                _errorMessage = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: !_isPasswordMode ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.xs + 2), // 6px for inner toggle
                ),
                child: Text(
                  'รหัสครั้งเดียว (OTP)',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: !_isPasswordMode ? AppColors.surface : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return AppTextField(
      controller: _emailController,
      label: 'อีเมล',
      hintText: 'example@ireneplus.com',
      prefixIcon: HugeIcons.strokeRoundedUser,
      keyboardType: TextInputType.emailAddress,
      focusNode: _emailFocusNode,
      textInputAction: _isPasswordMode ? TextInputAction.next : TextInputAction.done,
      onSubmitted: (_) {
        if (_isPasswordMode) {
          _passwordFocusNode.requestFocus();
        } else if (!_otpSent) {
          _sendOtp();
        }
      },
    );
  }

  Widget _buildPasswordField() {
    return PasswordField(
      controller: _passwordController,
      label: 'รหัสผ่าน',
      hintText: '••••••••',
      focusNode: _passwordFocusNode,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _loginWithPassword(),
    );
  }

  Widget _buildOtpSection() {
    return Column(
      children: [
        // Send OTP button
        if (!_otpSent)
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _sendOtp,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.smallRadius,
                ),
              ),
              child: Text(
                _isLoading ? 'กำลังส่ง...' : 'ขอรหัส OTP ทางอีเมล',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          )
        else ...[
          Container(
            padding: AppSpacing.paddingSm,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.smallRadius,
            ),
            child: Text(
              'ส่งรหัส OTP ไปที่อีเมลแล้ว กรุณาตรวจสอบ',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          AppSpacing.verticalGapLg,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: PinCodeTextField(
              appContext: context,
              length: 6,
              controller: _pinCodeController,
              keyboardType: TextInputType.number,
              textStyle: AppTypography.heading3.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              enableActiveFill: false,
              autoFocus: true,
              enablePinAutofill: true,
              showCursor: true,
              cursorColor: AppColors.primary,
              obscureText: false,
              hintCharacter: '-',
              hintStyle: AppTypography.heading3.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              ),
              pinTheme: PinTheme(
                fieldHeight: 50,
                fieldWidth: 44,
                borderWidth: 2,
                borderRadius: AppRadius.mediumRadius,
                shape: PinCodeFieldShape.box,
                activeColor: AppColors.textPrimary,
                inactiveColor: AppColors.inputBorder,
                selectedColor: AppColors.primary,
                activeFillColor: Colors.transparent,
                inactiveFillColor: Colors.transparent,
                selectedFillColor: Colors.transparent,
              ),
              onChanged: (value) {},
              onCompleted: (value) {
                _verifyOtp();
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : (_isPasswordMode ? _loginWithPassword : (_otpSent ? _verifyOtp : null)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smallRadius,
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.surface),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isPasswordMode ? 'เข้าสู่ระบบ' : 'ยืนยัน OTP',
                    style: AppTypography.button.copyWith(
                      color: AppColors.surface,
                    ),
                  ),
                  AppSpacing.horizontalGapSm,
                  HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: AppIconSize.lg),
                ],
              ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        children: [
          // Forgot password link
          SizedBox(
            height: AppSpacing.buttonHeight,
            child: TextButton(
              onPressed: () {
                // Navigate ไปหน้า forgot password พร้อมส่ง email ไปด้วย (ถ้ามี)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ForgotPasswordScreen(
                      initialEmail: _emailController.text.trim(),
                    ),
                  ),
                );
              },
              child: Text(
                'ลืมรหัสผ่าน?',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),

          AppSpacing.verticalGapLg,

          // Divider with text - "หรือลงทะเบียนด้วยคำเชิญ"
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(child: Divider(color: AppColors.inputBorder)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    'หรือลงทะเบียนด้วยคำเชิญ',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.inputBorder)),
              ],
            ),
          ),

          AppSpacing.verticalGapMd,

          // Search invitation button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate ไปหน้า InvitationScreen พร้อมส่ง email ไปด้วย
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvitationScreen(
                        initialEmail: _emailController.text.trim(),
                      ),
                    ),
                  );
                },
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  color: AppColors.textPrimary,
                  size: 16,
                ),
                label: Text(
                  'ค้นหาคำเชิญ',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.inputBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.smallRadius,
                  ),
                  backgroundColor: AppColors.background,
                ),
              ),
            ),
          ),

          AppSpacing.verticalGapLg,

          // Copyright
          Text(
            '© 2025 Irene Plus',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

