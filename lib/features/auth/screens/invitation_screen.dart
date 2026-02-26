import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/input_fields.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/network_image.dart';
import '../models/invitation.dart';
import '../providers/invitation_provider.dart';
import 'forgot_password_screen.dart';

/// หน้า Invitation - Multi-step wizard
///
/// Flow:
/// 1. กรอก email เพื่อค้นหา invitations
/// 2. แสดงรายการ nursinghomes ที่เชิญ (หรือ empty state)
/// 3a. Register form (สำหรับ user ใหม่)
/// 3b. Login form (สำหรับ user ที่มีอยู่แล้ว)
class InvitationScreen extends ConsumerStatefulWidget {
  /// Email ที่ส่งมาจากหน้า login (ถ้ามี)
  final String? initialEmail;

  /// true = user login อยู่แล้ว (ไม่ต้องใส่ password ซ้ำ)
  /// ใช้สำหรับ user ที่ไม่มี nursinghome_id แต่มี session อยู่
  /// เมื่อเลือก invitation จะ accept โดยตรงผ่าน RPC
  final bool alreadyAuthenticated;

  const InvitationScreen({
    super.key,
    this.initialEmail,
    this.alreadyAuthenticated = false,
  });

  @override
  ConsumerState<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends ConsumerState<InvitationScreen> {
  // Controllers
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Focus Nodes
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  // Auth state subscription - ใช้ pop หน้านี้เมื่อ login สำเร็จ
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // ใช้ email จากหน้า login ถ้ามี
    _emailController = TextEditingController(text: widget.initialEmail ?? '');

    if (widget.alreadyAuthenticated) {
      // User login อยู่แล้ว → ไม่ต้อง listen auth state changes
      // เพราะจะ accept invitation โดยตรงผ่าน RPC แล้ว pop เอง

      // Auto-search ถ้ามี email
      if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchInvitations();
        });
      }
    } else {
      // Flow ปกติ: Listen for auth state changes
      // เมื่อ register/login สำเร็จ Supabase จะ emit signedIn event
      // ให้ pop หน้านี้ออกเพื่อให้ AuthWrapper แสดงหน้าถัดไป
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        debugPrint('InvitationScreen: Auth state changed: ${data.event}');
        if (data.event == AuthChangeEvent.signedIn && mounted) {
          debugPrint('InvitationScreen: Signed in! Popping screen...');
          // Pop หน้านี้ออก ให้ AuthWrapper แสดง ProfileSetupScreen หรือ MainScreen
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
  }

  @override
  void dispose() {
    // Cancel auth subscription
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // อ่าน state จาก provider
    final state = ref.watch(invitationProvider);

    return Scaffold(
      // resizeToAvoidBottomInset: true (default) - Scaffold จะย่อ body
      // เมื่อ keyboard ขึ้น ทำให้ Expanded + SingleChildScrollView scroll ได้
      body: SafeArea(
        child: Column(
          children: [
            // AppBar แบบ custom
            _buildAppBar(state),

            // Content ที่เปลี่ยนตาม step
            // Expanded + SingleChildScrollView จะย่อขยายตาม keyboard อัตโนมัติ
            // (เพราะ resizeToAvoidBottomInset: true เป็น default)
            Expanded(
              child: SingleChildScrollView(
                // ปิด keyboard เมื่อ scroll (UX ที่ดี)
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  // เพิ่ม extra bottom padding เพื่อให้ scroll
                  // ขึ้นมาเห็น input fields ด้านล่างได้สะดวก
                  bottom: AppSpacing.lg + 100,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildContent(state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// สร้าง custom AppBar ที่เปลี่ยนตาม step
  Widget _buildAppBar(InvitationState state) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () {
              // ถ้าอยู่ step แรก → Navigator.pop
              // ถ้าอยู่ step อื่น → goBack() ใน provider
              if (state.step == InvitationStep.emailInput) {
                Navigator.of(context).pop();
              } else {
                ref.read(invitationProvider.notifier).goBack();
                // Clear password fields เมื่อกลับ
                _passwordController.clear();
                _confirmPasswordController.clear();
              }
            },
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: AppColors.textPrimary,
              size: AppIconSize.lg,
            ),
          ),

          AppSpacing.horizontalGapSm,

          // Title ที่เปลี่ยนตาม step
          Expanded(
            child: Text(
              _getAppBarTitle(state.step),
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ดึง title ตาม step
  String _getAppBarTitle(InvitationStep step) {
    switch (step) {
      case InvitationStep.emailInput:
        return 'ค้นหาคำเชิญ';
      case InvitationStep.showingInvitations:
        return 'รายการคำเชิญ';
      case InvitationStep.registerForm:
        return 'สร้างบัญชีใหม่';
      case InvitationStep.loginForm:
        return 'เข้าสู่ระบบ';
    }
  }

  /// สร้าง content ตาม step
  Widget _buildContent(InvitationState state) {
    switch (state.step) {
      case InvitationStep.emailInput:
        return _buildEmailInputSection(state);
      case InvitationStep.showingInvitations:
        return _buildInvitationsSection(state);
      case InvitationStep.registerForm:
        return _buildRegisterSection(state);
      case InvitationStep.loginForm:
        return _buildLoginSection(state);
    }
  }

  // ============================================
  // Step 1: Email Input Section
  // ============================================

  Widget _buildEmailInputSection(InvitationState state) {
    // ตรวจสอบว่า keyboard ขึ้นหรือไม่
    // ใช้ viewInsetsOf แทน .of().viewInsets เพื่อลดการ rebuild ตอน keyboard animation
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 50;

    return Column(
      key: const ValueKey('email_input'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // รูป mascot + Title
        // ย่อ/ซ่อนรูปเมื่อ keyboard ขึ้น เพื่อให้มีพื้นที่สำหรับ input
        Center(
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                // ย่อรูปจาก 280 เหลือ 120 เมื่อ keyboard ขึ้น
                height: keyboardVisible ? 120 : 280,
                child: Image.asset(
                  'assets/images/login/photo_cat2.webp',
                  fit: BoxFit.contain,
                ),
              ),
              // ซ่อน text เมื่อ keyboard ขึ้น เพื่อประหยัดพื้นที่
              if (!keyboardVisible) ...[
                AppSpacing.verticalGapLg,
                Text(
                  'กรุณากรอกอีเมลที่ได้รับคำเชิญ',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),

        AppSpacing.verticalGapXl,

        // Email input field
        AppTextField(
          controller: _emailController,
          label: 'อีเมล',
          hintText: 'example@ireneplus.com',
          prefixIcon: HugeIcons.strokeRoundedUser,
          keyboardType: TextInputType.emailAddress,
          focusNode: _emailFocusNode,
          textInputAction: TextInputAction.done,
          autofocus: true,
          errorText: state.errorMessage,
          onSubmitted: (_) => _searchInvitations(),
        ),

        AppSpacing.verticalGapLg,

        // Search button
        PrimaryButton(
          text: 'ค้นหาคำเชิญ',
          icon: HugeIcons.strokeRoundedSearch01,
          isLoading: state.isLoading,
          width: double.infinity,
          onPressed: state.isLoading ? null : _searchInvitations,
        ),

        AppSpacing.verticalGapXl,

        // Help text
        Center(
          child: Text(
            'หากไม่พบคำเชิญ กรุณาติดต่อผู้ดูแลระบบของศูนย์ดูแล',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// Accept invitation โดยตรง (ไม่ต้อง login ซ้ำ)
  /// ใช้เมื่อ user มี session อยู่แล้ว (alreadyAuthenticated = true)
  Future<void> _acceptDirectly(Invitation invitation) async {
    final success = await ref
        .read(invitationProvider.notifier)
        .acceptInvitationDirectly(invitation);

    if (!mounted) return;

    if (success) {
      // สำเร็จ → pop กลับไปให้ EmploymentCheckWrapper re-check
      Navigator.of(context).pop();
    } else {
      // แสดง error ใน snackbar
      final errorMessage = ref.read(invitationProvider).errorMessage;
      if (errorMessage != null) {
        AppSnackbar.error(context, errorMessage);
      }
    }
  }

  void _searchInvitations() {
    // Clear error ก่อน search
    ref.read(invitationProvider.notifier).clearError();
    ref.read(invitationProvider.notifier).searchInvitations(
          _emailController.text.trim(),
        );
  }

  // ============================================
  // Step 2: Invitations List Section
  // ============================================

  Widget _buildInvitationsSection(InvitationState state) {
    // ถ้าไม่พบ invitations → แสดง empty state
    if (state.invitations.isEmpty) {
      return Column(
        key: const ValueKey('empty_state'),
        children: [
          AppSpacing.verticalGapXl,
          EmptyStateWidget(
            message: 'ไม่พบคำเชิญสำหรับอีเมลนี้',
            subMessage: 'กรุณาตรวจสอบอีเมลให้ถูกต้อง\nหรือติดต่อผู้ดูแลระบบ',
            action: SecondaryButton(
              text: 'ลองใหม่อีกครั้ง',
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: () {
                ref.read(invitationProvider.notifier).goBack();
              },
            ),
          ),
        ],
      );
    }

    // แสดงรายการ invitations
    return Column(
      key: const ValueKey('invitations_list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Text(
          'พบคำเชิญ ${state.invitations.length} รายการ',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          'สำหรับ ${state.email}',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),

        AppSpacing.verticalGapLg,

        // Invitations list
        ...state.invitations.map((invitation) => _buildInvitationCard(
              invitation,
              state.isLoading,
            )),
      ],
    );
  }

  Widget _buildInvitationCard(Invitation invitation, bool isLoading) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      // ใช้ Material + InkWell เพื่อให้มี ripple effect เมื่อกด
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        child: InkWell(
          // ให้ทั้ง card กดได้
          onTap: isLoading
              ? null
              : () {
                  if (widget.alreadyAuthenticated) {
                    // User login อยู่แล้ว → accept invitation โดยตรง
                    _acceptDirectly(invitation);
                  } else {
                    // Flow ปกติ → ไปหน้า login/register
                    ref
                        .read(invitationProvider.notifier)
                        .selectInvitation(invitation);
                  }
                },
          borderRadius: AppRadius.mediumRadius,
          child: Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              borderRadius: AppRadius.mediumRadius,
              border: Border.all(color: AppColors.inputBorder),
              boxShadow: AppShadows.cardShadow,
            ),
            child: Row(
              children: [
                // Nursinghome logo/image
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smallRadius,
                  ),
                  child: invitation.nursinghomePicUrl != null
                      ? ClipRRect(
                          borderRadius: AppRadius.smallRadius,
                          child: IreneNetworkImage(
                            imageUrl: invitation.nursinghomePicUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            memCacheWidth: 112,
                            compact: true,
                          ),
                        )
                      : Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedHospital01,
                            color: AppColors.primary,
                            size: AppIconSize.xl,
                          ),
                        ),
                ),

                AppSpacing.horizontalGapMd,

                // Nursinghome info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.nursinghomeName,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppSpacing.verticalGapXs,
                      Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedMail01,
                            color: AppColors.textSecondary,
                            size: AppIconSize.sm,
                          ),
                          AppSpacing.horizontalGapXs,
                          Expanded(
                            child: Text(
                              invitation.userEmail,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                AppSpacing.horizontalGapMd,

                // Select button (เป็น visual indicator ว่ากดได้)
                Container(
                  height: 36,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.smallRadius,
                  ),
                  child: Center(
                    child: isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(AppColors.surface),
                            ),
                          )
                        : Text(
                            // เปลี่ยนข้อความตาม auth state
                            widget.alreadyAuthenticated ? 'เข้าร่วม' : 'เลือก',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.surface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // Step 3a: Register Section
  // ============================================

  Widget _buildRegisterSection(InvitationState state) {
    return Column(
      key: const ValueKey('register_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header - nursinghome info
        _buildSelectedNursinghomeCard(state),

        AppSpacing.verticalGapLg,

        // Info message
        Container(
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
                  'ยังไม่มีบัญชี กรุณาสร้างบัญชีใหม่',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
        ),

        AppSpacing.verticalGapLg,

        // Email (readonly)
        AppTextField(
          label: 'อีเมล',
          controller: TextEditingController(text: state.email),
          prefixIcon: HugeIcons.strokeRoundedMail01,
          enabled: false,
        ),

        AppSpacing.verticalGapMd,

        // Password
        PasswordField(
          label: 'รหัสผ่าน',
          hintText: 'สร้างรหัสผ่านใหม่',
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
        ),

        // Password requirements indicator (real-time validation)
        _buildPasswordRequirements(),

        AppSpacing.verticalGapMd,

        // Confirm Password with match indicator
        _buildConfirmPasswordField(),

        // Error message
        if (state.errorMessage != null) ...[
          AppSpacing.verticalGapMd,
          _buildErrorMessage(state.errorMessage!),
        ],

        AppSpacing.verticalGapLg,

        // Register button
        PrimaryButton(
          text: 'สร้างบัญชีและเข้าร่วม',
          icon: HugeIcons.strokeRoundedUserAdd01,
          isLoading: state.isLoading,
          width: double.infinity,
          onPressed: state.isLoading ? null : _register,
        ),
      ],
    );
  }

  void _register() {
    ref.read(invitationProvider.notifier).register(
          _passwordController.text,
          _confirmPasswordController.text,
        );
  }

  /// สร้าง Password Requirements Indicator
  ///
  /// แสดง checklist ของ password requirements แบบ real-time
  /// ใช้ ValueListenableBuilder เพื่อ rebuild เฉพาะส่วนนี้
  Widget _buildPasswordRequirements() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _passwordController,
      builder: (context, value, child) {
        final password = value.text;

        // กำหนด requirements ที่ต้องตรวจสอบ
        final requirements = [
          _PasswordRequirement(
            label: 'อย่างน้อย 6 ตัวอักษร',
            isMet: password.length >= 6,
          ),
          _PasswordRequirement(
            label: 'มีตัวอักษรพิมพ์เล็ก (a-z)',
            isMet: password.contains(RegExp(r'[a-z]')),
          ),
          _PasswordRequirement(
            label: 'มีตัวอักษรพิมพ์ใหญ่ (A-Z)',
            isMet: password.contains(RegExp(r'[A-Z]')),
          ),
          _PasswordRequirement(
            label: 'มีตัวเลข (0-9)',
            isMet: password.contains(RegExp(r'[0-9]')),
          ),
        ];

        // นับจำนวนที่ผ่าน
        final passedCount = requirements.where((r) => r.isMet).length;
        final allPassed = passedCount == requirements.length;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.only(top: AppSpacing.sm),
          padding: AppSpacing.paddingSm,
          decoration: BoxDecoration(
            color: allPassed
                ? AppColors.success.withValues(alpha: 0.05)
                : AppColors.surface,
            borderRadius: AppRadius.smallRadius,
            border: Border.all(
              color: allPassed
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.inputBorder.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  HugeIcon(
                    icon: allPassed
                        ? HugeIcons.strokeRoundedCheckmarkBadge01
                        : HugeIcons.strokeRoundedShield01,
                    color: allPassed ? AppColors.success : AppColors.textSecondary,
                    size: 16,
                  ),
                  AppSpacing.horizontalGapXs,
                  Text(
                    allPassed ? 'รหัสผ่านแข็งแรง' : 'รหัสผ่านต้องประกอบด้วย',
                    style: AppTypography.caption.copyWith(
                      color:
                          allPassed ? AppColors.success : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Progress indicator
                  Text(
                    '$passedCount/${requirements.length}',
                    style: AppTypography.caption.copyWith(
                      color:
                          allPassed ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              AppSpacing.verticalGapXs,

              // Requirements list
              ...requirements.map((req) => _buildRequirementRow(req)),

              // Common password warning
              if (password.isNotEmpty) ...[
                AppSpacing.verticalGapXs,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedAlert02,
                        color: AppColors.warning,
                        size: 12,
                      ),
                    ),
                    AppSpacing.horizontalGapXs,
                    Expanded(
                      child: Text(
                        'หลีกเลี่ยงรหัสผ่านที่คนอื่นใช้กันเยอะ เช่น 123456, password, qwerty หรือ ตัวเลขเรียงกัน',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.warning,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// สร้าง row แสดง requirement แต่ละข้อ
  Widget _buildRequirementRow(_PasswordRequirement requirement) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Icon แสดงสถานะ
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: HugeIcon(
              key: ValueKey(requirement.isMet),
              icon: requirement.isMet
                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                  : HugeIcons.strokeRoundedCircle,
              color: requirement.isMet
                  ? AppColors.success
                  : AppColors.textSecondary.withValues(alpha: 0.5),
              size: 14,
            ),
          ),
          AppSpacing.horizontalGapXs,
          // Label
          Text(
            requirement.label,
            style: AppTypography.caption.copyWith(
              color: requirement.isMet
                  ? AppColors.success
                  : AppColors.textSecondary.withValues(alpha: 0.7),
              decoration:
                  requirement.isMet ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  /// สร้าง Confirm Password Field พร้อม match indicator
  Widget _buildConfirmPasswordField() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _confirmPasswordController,
      builder: (context, confirmValue, child) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _passwordController,
          builder: (context, passwordValue, child) {
            final password = passwordValue.text;
            final confirmPassword = confirmValue.text;

            // ตรวจสอบว่า password ตรงกันหรือไม่
            final isMatching =
                confirmPassword.isNotEmpty && password == confirmPassword;
            final isNotMatching =
                confirmPassword.isNotEmpty && password != confirmPassword;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PasswordField(
                  label: 'ยืนยันรหัสผ่าน',
                  hintText: 'กรอกรหัสผ่านอีกครั้ง',
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocusNode,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                  // แสดง error ถ้าไม่ตรงกัน
                  errorText: isNotMatching ? 'รหัสผ่านไม่ตรงกัน' : null,
                ),

                // Match indicator
                if (isMatching)
                  Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xs),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                          color: AppColors.success,
                          size: 14,
                        ),
                        AppSpacing.horizontalGapXs,
                        Text(
                          'รหัสผ่านตรงกัน',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================
  // Step 3b: Login Section
  // ============================================

  Widget _buildLoginSection(InvitationState state) {
    return Column(
      key: const ValueKey('login_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header - nursinghome info
        _buildSelectedNursinghomeCard(state),

        AppSpacing.verticalGapLg,

        // Info message
        Container(
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: AppRadius.smallRadius,
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                color: AppColors.success,
                size: AppIconSize.lg,
              ),
              AppSpacing.horizontalGapSm,
              Expanded(
                child: Text(
                  'พบบัญชีที่ใช้อีเมลนี้อยู่แล้ว กรุณาเข้าสู่ระบบ',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),

        AppSpacing.verticalGapLg,

        // Email (readonly)
        AppTextField(
          label: 'อีเมล',
          controller: TextEditingController(text: state.email),
          prefixIcon: HugeIcons.strokeRoundedMail01,
          enabled: false,
        ),

        AppSpacing.verticalGapMd,

        // Password
        PasswordField(
          label: 'รหัสผ่าน',
          hintText: 'กรอกรหัสผ่านของคุณ',
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loginAndJoin(),
        ),

        // Error message
        if (state.errorMessage != null) ...[
          AppSpacing.verticalGapMd,
          _buildErrorMessage(state.errorMessage!),
        ],

        AppSpacing.verticalGapLg,

        // Login button
        PrimaryButton(
          text: 'เข้าสู่ระบบและเข้าร่วม',
          icon: HugeIcons.strokeRoundedLogin01,
          isLoading: state.isLoading,
          width: double.infinity,
          onPressed: state.isLoading ? null : _loginAndJoin,
        ),

        AppSpacing.verticalGapMd,

        // Forgot password link
        Center(
          child: TextButton(
            onPressed: () {
              // Navigate ไปหน้า forgot password พร้อมส่ง email ไปด้วย
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ForgotPasswordScreen(
                    initialEmail: state.email,
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
      ],
    );
  }

  void _loginAndJoin() {
    ref.read(invitationProvider.notifier).loginAndJoin(
          _passwordController.text,
        );
  }

  // ============================================
  // Shared Widgets
  // ============================================

  /// แสดง nursinghome ที่เลือก (ใช้ใน register และ login sections)
  Widget _buildSelectedNursinghomeCard(InvitationState state) {
    final invitation = state.selectedInvitation;
    if (invitation == null) return const SizedBox.shrink();

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Nursinghome logo
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.smallRadius,
            ),
            child: invitation.nursinghomePicUrl != null
                ? ClipRRect(
                    borderRadius: AppRadius.smallRadius,
                    child: IreneNetworkImage(
                      imageUrl: invitation.nursinghomePicUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      memCacheWidth: 96,
                      compact: true,
                    ),
                  )
                : Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedHospital01,
                      color: AppColors.primary,
                      size: AppIconSize.lg,
                    ),
                  ),
          ),

          AppSpacing.horizontalGapMd,

          // Nursinghome info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เข้าร่วม',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  invitation.nursinghomeName,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// แสดง error message
  Widget _buildErrorMessage(String message) {
    return Container(
      padding: AppSpacing.paddingSm,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: AppRadius.smallRadius,
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            color: AppColors.error,
            size: AppIconSize.md,
          ),
          AppSpacing.horizontalGapSm,
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Data class สำหรับ Password Requirement
///
/// เก็บข้อมูล label และสถานะว่าผ่านเงื่อนไขหรือไม่
class _PasswordRequirement {
  final String label;
  final bool isMet;

  const _PasswordRequirement({
    required this.label,
    required this.isMet,
  });
}
