import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../navigation/screens/main_navigation_screen.dart';

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
  bool _obscurePassword = true;
  bool _otpSent = false;
  String? _errorMessage;

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

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = _getThaiErrorMessage(e.message));
    } catch (e) {
      setState(() => _errorMessage = 'เกิดข้อผิดพลาด กรุณาลองใหม่');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งรหัส OTP ไปที่ ${_emailController.text} แล้ว')),
        );
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

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
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
      body: SingleChildScrollView(
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
              child: Icon(
                Iconsax.hospital,
                size: 36,
                color: AppColors.primary,
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
              'Healthcare Management System',
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
            _buildTextField(
            controller: _emailController,
            label: 'อีเมล',
            hintText: 'example@ireneplus.com',
            prefixIcon: Iconsax.user,
            keyboardType: TextInputType.emailAddress,
            focusNode: _emailFocusNode,
            nextFocusNode: _isPasswordMode ? _passwordFocusNode : null,
            onSubmitted: _isPasswordMode ? null : (_otpSent ? null : _sendOtp),
          ),
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
                Icon(Iconsax.warning_2, size: 16, color: AppColors.error),
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
                  'OTP',
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

  Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required String hintText,
  required IconData prefixIcon,
  TextInputType? keyboardType,
  bool obscureText = false,
  Widget? suffixIcon,
  FocusNode? focusNode,
  FocusNode? nextFocusNode,
  VoidCallback? onSubmitted,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
      SizedBox(height: AppSpacing.xs + 2), // 6px
      SizedBox(
        height: AppSpacing.buttonHeight,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
          onSubmitted: (_) {
            if (nextFocusNode != null) {
              nextFocusNode.requestFocus();
            } else if (onSubmitted != null) {
              onSubmitted();
            }
          },
          style: AppTypography.body.copyWith(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.body.copyWith(
              fontSize: 15,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(
              prefixIcon,
              color: AppColors.textSecondary,
              size: 22,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 0),
            border: OutlineInputBorder(
              borderRadius: AppRadius.smallRadius,
              borderSide: BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.smallRadius,
              borderSide: BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.smallRadius,
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ),
    ],
  );
}

    Widget _buildPasswordField() {
    return _buildTextField(
        controller: _passwordController,
        label: 'รหัสผ่าน',
        hintText: '••••••••',
        prefixIcon: Iconsax.lock,
        obscureText: _obscurePassword,
        focusNode: _passwordFocusNode,
        onSubmitted: _loginWithPassword,
        suffixIcon: IconButton(
        icon: Icon(
            _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
            color: AppColors.textSecondary,
        ),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
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
                  Icon(Iconsax.arrow_right, size: 20),
                ],
              ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final forgotEmailController = TextEditingController(text: _emailController.text);
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.mediumRadius,
            ),
            title: Text(
              'ลืมรหัสผ่าน',
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'กรอกอีเมลของคุณ เราจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ให้',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                AppSpacing.verticalGapMd,
                SizedBox(
                  height: AppSpacing.buttonHeight,
                  child: TextField(
                    controller: forgotEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTypography.body.copyWith(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'example@ireneplus.com',
                      hintStyle: AppTypography.body.copyWith(
                        fontSize: 15,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        Iconsax.sms,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.smallRadius,
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.smallRadius,
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.smallRadius,
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                ),
                if (errorMessage != null) ...[
                  AppSpacing.verticalGapSm,
                  Text(
                    errorMessage!,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              SizedBox(
                height: AppSpacing.buttonHeight,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.smallRadius,
                    ),
                  ),
                  child: Text(
                    'ยกเลิก',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final email = forgotEmailController.text.trim();

                          if (email.isEmpty) {
                            setDialogState(() => errorMessage = 'กรุณากรอกอีเมล');
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          try {
                            debugPrint('Sending reset email to: $email');
                            await Supabase.instance.client.auth.resetPasswordForEmail(
                              email,
                            );
                            debugPrint('Reset email sent successfully');

                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('ส่งลิงก์รีเซ็ตรหัสผ่านไปที่ $email แล้ว'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint('Reset password error: $e');
                            setDialogState(() {
                              errorMessage = 'ไม่สามารถส่งอีเมลได้ กรุณาลองใหม่';
                              isLoading = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.smallRadius,
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.surface),
                          ),
                        )
                      : Text(
                          'ส่งลิงก์รีเซ็ต',
                          style: AppTypography.body.copyWith(
                            color: AppColors.surface,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
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
              onPressed: _showForgotPasswordDialog,
              child: Text(
                'ลืมรหัสผ่าน?',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          AppSpacing.verticalGapMd,
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
