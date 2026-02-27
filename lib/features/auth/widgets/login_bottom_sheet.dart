import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/input_fields.dart';
import '../../../core/widgets/buttons.dart';
import '../screens/forgot_password_screen.dart';

/// Bottom Sheet สำหรับ Login
/// รองรับ 2 modes: Password และ OTP
/// เรียกใช้ผ่าน LoginBottomSheet.show(context)
class LoginBottomSheet extends StatefulWidget {
  const LoginBottomSheet({super.key});

  /// แสดง Bottom Sheet สำหรับ Login
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ให้ bottom sheet ขยายตาม content
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent, // ไม่ให้พื้นหลังมืดลง
      builder: (context) => const LoginBottomSheet(),
    );
  }

  @override
  State<LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<LoginBottomSheet> {
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinCodeController = TextEditingController();

  // Focus Nodes
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  // States
  bool _isPasswordMode = true; // true = password, false = OTP
  bool _isLoading = false;
  bool _otpSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pinCodeController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // Login ด้วย email & password
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

      // ปิด bottom sheet หลัง login สำเร็จ
      // AuthWrapper ใน main.dart จะ handle navigation ไป MainNavigationScreen
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      setState(() => _errorMessage = _getThaiErrorMessage(e.message));
    } catch (e) {
      setState(() => _errorMessage = 'เกิดข้อผิดพลาด กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ส่ง OTP ไปที่ email
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
        AppToast.success(context, 'ส่งรหัส OTP ไปที่ ${_emailController.text} แล้ว');
      }
    } catch (e) {
      setState(() => _errorMessage = 'ไม่สามารถส่ง OTP ได้ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ยืนยัน OTP
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

      // ปิด bottom sheet หลัง login สำเร็จ
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      setState(() => _errorMessage = _getThaiErrorMessage(e.message));
    } catch (e) {
      setState(() => _errorMessage = 'รหัส OTP ไม่ถูกต้อง');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // แปลง error message เป็นภาษาไทย
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
    // คำนวณ padding สำหรับ keyboard
    // เมื่อ keyboard ขึ้น ให้ bottom sheet ขยับขึ้นตาม
    // ใช้ viewInsetsOf แทน .of().viewInsets เพื่อลดการ rebuild ตอน keyboard animation
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      // ใช้ AnimatedPadding เพื่อให้ขยับขึ้นเมื่อ keyboard แสดง
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.lg),
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar - บอกว่าลากปิดได้
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.inputBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                SizedBox(height: AppSpacing.md),

                // Toggle: Password / OTP
                _buildToggle(),

                SizedBox(height: AppSpacing.lg),

                // Email field
                _buildEmailField(),

                SizedBox(height: AppSpacing.md),

                // Password or OTP fields
                if (_isPasswordMode) ...[
                  _buildPasswordField(),
                ] else ...[
                  _buildOtpSection(),
                ],

                // Error message
                if (_errorMessage != null) ...[
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedAlert02,
                        size: AppIconSize.sm,
                        color: AppColors.error,
                      ),
                      SizedBox(width: AppSpacing.xs),
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

                SizedBox(height: AppSpacing.lg),

                // Login button
                _buildLoginButton(),

                SizedBox(height: AppSpacing.md),

                // Forgot password link
                Center(
                  child: TextButton(
                    onPressed: () {
                      // ปิด bottom sheet ก่อน แล้วไปหน้า forgot password
                      Navigator.pop(context);
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

                // เว้นที่ด้านล่างเพื่อความสวยงาม
                SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Toggle สลับระหว่าง Password กับ OTP
  // ใช้ Stack + AnimatedAlign เพื่อให้ indicator เลื่อนไปมาอย่าง smooth
  Widget _buildToggle() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.smallRadius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // คำนวณความกว้างของแต่ละ tab (ครึ่งหนึ่งของ container)
          final tabWidth = (constraints.maxWidth) / 2;

          return Stack(
            children: [
              // Sliding indicator - เลื่อนไปมาตาม tab ที่เลือก
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: _isPasswordMode
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: tabWidth,
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.xs + 2),
                  ),
                  // ใส่ Text ที่มองไม่เห็นเพื่อให้ความสูงถูกต้อง
                  child: Text(
                    '',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // Tab buttons - อยู่ด้านบน indicator
              Row(
                children: [
                  // ปุ่ม "รหัสผ่าน"
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isPasswordMode = true;
                        _errorMessage = null;
                      }),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _isPasswordMode
                                ? AppColors.surface
                                : AppColors.textSecondary,
                          ),
                          child: const Text(
                            'รหัสผ่าน',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ปุ่ม "รหัสครั้งเดียว (OTP)"
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isPasswordMode = false;
                        _errorMessage = null;
                      }),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: !_isPasswordMode
                                ? AppColors.surface
                                : AppColors.textSecondary,
                          ),
                          child: const Text(
                            'รหัสครั้งเดียว (OTP)',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // Email field
  Widget _buildEmailField() {
    return AppTextField(
      controller: _emailController,
      label: 'อีเมล',
      hintText: 'example@ireneplus.com',
      prefixIcon: HugeIcons.strokeRoundedUser,
      keyboardType: TextInputType.emailAddress,
      focusNode: _emailFocusNode,
      textInputAction:
          _isPasswordMode ? TextInputAction.next : TextInputAction.done,
      onSubmitted: (_) {
        if (_isPasswordMode) {
          _passwordFocusNode.requestFocus();
        } else if (!_otpSent) {
          _sendOtp();
        }
      },
    );
  }

  // Password field
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

  // OTP section - ปุ่มส่ง OTP และช่องกรอก
  Widget _buildOtpSection() {
    return Column(
      children: [
        // ปุ่มส่ง OTP (แสดงถ้ายังไม่ได้ส่ง)
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
          // แสดงข้อความว่าส่ง OTP แล้ว
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
          SizedBox(height: AppSpacing.lg),
          // ช่องกรอก OTP 6 หลัก
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

  // Login button
  Widget _buildLoginButton() {
    return PrimaryButton(
      text: _isPasswordMode ? 'เข้าสู่ระบบ' : 'ยืนยัน OTP',
      width: double.infinity,
      isLoading: _isLoading,
      isDisabled: _isPasswordMode ? false : !_otpSent,
      icon: HugeIcons.strokeRoundedArrowRight01,
      onPressed: _isPasswordMode
          ? _loginWithPassword
          : (_otpSent ? _verifyOtp : null),
    );
  }
}
