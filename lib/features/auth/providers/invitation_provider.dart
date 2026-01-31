import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invitation.dart';
import '../services/invitation_service.dart';

/// Enum สำหรับบอกว่าอยู่ step ไหนของ invitation flow
enum InvitationStep {
  /// Step 1: กรอก email เพื่อค้นหา
  emailInput,

  /// Step 2: แสดงรายการ nursinghomes ที่เชิญ
  showingInvitations,

  /// Step 3a: แสดง form register (สำหรับ user ใหม่)
  registerForm,

  /// Step 3b: แสดง form login (สำหรับ user ที่มีอยู่แล้ว)
  loginForm,
}

/// State class สำหรับ Invitation flow
///
/// เก็บ state ทั้งหมดที่จำเป็นสำหรับ multi-step wizard
@immutable
class InvitationState {
  /// Step ปัจจุบัน
  final InvitationStep step;

  /// Email ที่ user กรอก
  final String email;

  /// รายการ invitations ที่พบ
  final List<Invitation> invitations;

  /// Invitation ที่ user เลือก
  final Invitation? selectedInvitation;

  /// กำลัง loading อยู่หรือไม่
  final bool isLoading;

  /// Error message (ถ้ามี)
  final String? errorMessage;

  /// User มี account อยู่แล้วหรือไม่
  final bool userExists;

  const InvitationState({
    this.step = InvitationStep.emailInput,
    this.email = '',
    this.invitations = const [],
    this.selectedInvitation,
    this.isLoading = false,
    this.errorMessage,
    this.userExists = false,
  });

  /// สร้าง state ใหม่จาก state เดิม โดยเปลี่ยนบาง property
  InvitationState copyWith({
    InvitationStep? step,
    String? email,
    List<Invitation>? invitations,
    Invitation? selectedInvitation,
    bool? isLoading,
    String? errorMessage,
    bool? userExists,
    // ใช้สำหรับ clear selectedInvitation หรือ errorMessage
    bool clearSelectedInvitation = false,
    bool clearErrorMessage = false,
  }) {
    return InvitationState(
      step: step ?? this.step,
      email: email ?? this.email,
      invitations: invitations ?? this.invitations,
      selectedInvitation: clearSelectedInvitation
          ? null
          : (selectedInvitation ?? this.selectedInvitation),
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      userExists: userExists ?? this.userExists,
    );
  }

  @override
  String toString() {
    return 'InvitationState(step: $step, email: $email, '
        'invitations: ${invitations.length}, '
        'selected: ${selectedInvitation?.nursinghomeName}, '
        'loading: $isLoading, error: $errorMessage, userExists: $userExists)';
  }
}

/// StateNotifier สำหรับจัดการ Invitation flow
///
/// ใช้ Riverpod StateNotifier pattern เพื่อจัดการ state
/// และ actions ต่างๆ ใน multi-step wizard
class InvitationNotifier extends StateNotifier<InvitationState> {
  InvitationNotifier() : super(const InvitationState());

  final _service = InvitationService();

  /// ค้นหา invitations ตาม email
  ///
  /// Flow:
  /// 1. Set loading = true
  /// 2. Query invitations จาก Supabase
  /// 3. ถ้าพบ → เปลี่ยนไป step showingInvitations
  /// 4. ถ้าไม่พบ → แสดง error message
  Future<void> searchInvitations(String email) async {
    // Validate email ก่อน
    if (email.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'กรุณากรอกอีเมล');
      return;
    }

    // Set loading state
    state = state.copyWith(
      isLoading: true,
      email: email.trim(),
      clearErrorMessage: true,
    );

    try {
      // Query invitations
      final invitations = await _service.getInvitationsByEmail(email);

      if (invitations.isEmpty) {
        // ไม่พบ invitations
        state = state.copyWith(
          isLoading: false,
          invitations: [],
          step: InvitationStep.showingInvitations, // ไปหน้า empty state
        );
      } else {
        // พบ invitations
        state = state.copyWith(
          isLoading: false,
          invitations: invitations,
          step: InvitationStep.showingInvitations,
        );
      }
    } catch (e) {
      debugPrint('InvitationNotifier: Error searching: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getGeneralErrorMessage(e),
      );
    }
  }

  /// เลือก invitation (nursinghome) ที่ต้องการเข้าร่วม
  ///
  /// หลังเลือก จะ check ว่า user มี account อยู่แล้วหรือไม่
  /// แล้วเปลี่ยนไป step ที่เหมาะสม (register หรือ login)
  Future<void> selectInvitation(Invitation invitation) async {
    state = state.copyWith(
      selectedInvitation: invitation,
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      // Check ว่า user มี account อยู่แล้วหรือไม่
      final exists = await _service.checkUserExists(state.email);

      state = state.copyWith(
        isLoading: false,
        userExists: exists,
        // ถ้ามี account → ไป login, ถ้าไม่มี → ไป register
        step: exists ? InvitationStep.loginForm : InvitationStep.registerForm,
      );
    } catch (e) {
      debugPrint('InvitationNotifier: Error checking user: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getGeneralErrorMessage(e),
      );
    }
  }

  /// Register user ใหม่ และเข้าร่วม nursinghome
  ///
  /// Flow:
  /// 1. Validate passwords
  /// 2. Register user ใน Supabase Auth
  /// 3. สร้าง/อัพเดต user_info พร้อม nursinghome_id
  /// 4. AuthWrapper จะ navigate ไป MainNavigationScreen อัตโนมัติ
  ///
  /// Note: ถ้า step 3 fail จะ sign out เพื่อไม่ให้ AuthWrapper navigate
  /// ไปหน้า main โดยที่ยังไม่มี user_info
  Future<void> register(String password, String confirmPassword) async {
    // Validate passwords
    if (password.isEmpty) {
      state = state.copyWith(errorMessage: 'กรุณากรอกรหัสผ่าน');
      return;
    }

    if (password.length < 6) {
      state = state.copyWith(errorMessage: 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
      return;
    }

    if (password != confirmPassword) {
      state = state.copyWith(errorMessage: 'รหัสผ่านไม่ตรงกัน');
      return;
    }

    final nursinghomeId = state.selectedInvitation?.nursinghomeId;
    if (nursinghomeId == null) {
      state = state.copyWith(errorMessage: 'กรุณาเลือกศูนย์ดูแลก่อน');
      return;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    debugPrint('=== InvitationNotifier.register() START ===');
    debugPrint('Email: ${state.email}');
    debugPrint('NursinghomeId: $nursinghomeId');
    debugPrint('RoleId: ${state.selectedInvitation?.roleId}');
    debugPrint('InvitationId: ${state.selectedInvitation?.invitationId}');

    try {
      // 1. Register user (สร้าง auth user)
      // Note: หลัง signUp สำเร็จ Supabase จะ auto-login
      // และ AuthWrapper จะเริ่ม navigate ไป MainScreen
      debugPrint('Step 1: Calling registerUser...');
      await _service.registerUser(state.email, password);
      debugPrint('Step 1: registerUser SUCCESS');

      // 2. สร้าง/อัพเดต user_info พร้อม nursinghome_id และ role_id
      // ถ้า step นี้ fail จะต้อง sign out เพื่อไม่ให้เข้า main app
      try {
        debugPrint('Step 2: Calling createUserInfoAndJoin...');
        await _service.createUserInfoAndJoin(
          state.email,
          nursinghomeId,
          // ส่ง roleId จาก invitation ถ้ามี
          roleId: state.selectedInvitation?.roleId,
        );
        debugPrint('Step 2: createUserInfoAndJoin SUCCESS');

        // ลบ invitation หลังจาก accept สำเร็จ
        // เพื่อป้องกันไม่ให้ถูกใช้ซ้ำ
        if (state.selectedInvitation != null) {
          debugPrint('Step 3: Calling deleteInvitation...');
          await _service.deleteInvitation(state.selectedInvitation!.invitationId);
          debugPrint('Step 3: deleteInvitation DONE');
        }

        // สำเร็จ - AuthWrapper จะ navigate อัตโนมัติ
        debugPrint('=== InvitationNotifier.register() ALL STEPS COMPLETE ===');
        debugPrint('AuthWrapper should auto-navigate now...');

        // Set loading เป็น false เพื่อให้ UI update
        // แม้ว่า AuthWrapper จะ rebuild แต่ InvitationScreen อาจยังอยู่บน stack
        state = state.copyWith(isLoading: false);
      } catch (e) {
        // createUserInfoAndJoin failed - ต้อง sign out เพื่อ "undo"
        debugPrint('InvitationNotifier: createUserInfoAndJoin failed: $e');
        debugPrint('InvitationNotifier: Signing out to prevent navigation');

        // Sign out เพื่อไม่ให้ AuthWrapper navigate ไป main app
        await Supabase.instance.client.auth.signOut();

        state = state.copyWith(
          isLoading: false,
          errorMessage: _getGeneralErrorMessage(e),
        );
      }
    } on AuthException catch (e) {
      // Auth error (signUp failed) - ไม่ต้อง sign out เพราะไม่ได้ login
      debugPrint('InvitationNotifier: Auth error: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getThaiErrorMessage(e.message),
      );
    } catch (e) {
      // Unexpected error ตอน signUp
      debugPrint('InvitationNotifier: Error registering: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getGeneralErrorMessage(e),
      );
    }
  }

  /// Login user ที่มีอยู่แล้ว และเข้าร่วม nursinghome
  ///
  /// Flow:
  /// 1. Login ใน Supabase Auth
  /// 2. อัพเดต user_info พร้อม nursinghome_id
  /// 3. AuthWrapper จะ navigate ไป MainNavigationScreen อัตโนมัติ
  ///
  /// Note: ถ้า step 2 fail จะ sign out เพื่อไม่ให้ AuthWrapper navigate
  /// ไปหน้า main โดยที่ยัง switch nursinghome ไม่สำเร็จ
  Future<void> loginAndJoin(String password) async {
    if (password.isEmpty) {
      state = state.copyWith(errorMessage: 'กรุณากรอกรหัสผ่าน');
      return;
    }

    final nursinghomeId = state.selectedInvitation?.nursinghomeId;
    if (nursinghomeId == null) {
      state = state.copyWith(errorMessage: 'กรุณาเลือกศูนย์ดูแลก่อน');
      return;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      // 1. Login
      // Note: หลัง login สำเร็จ AuthWrapper จะเริ่ม navigate ไป MainScreen
      await _service.loginUser(state.email, password);

      // 2. อัพเดต user_info พร้อม nursinghome_id
      // ถ้า step นี้ fail จะต้อง sign out
      try {
        await _service.joinNursinghome(nursinghomeId);

        // ลบ invitation หลังจาก accept สำเร็จ
        // เพื่อป้องกันไม่ให้ถูกใช้ซ้ำ
        if (state.selectedInvitation != null) {
          await _service.deleteInvitation(state.selectedInvitation!.invitationId);
        }

        // สำเร็จ - AuthWrapper จะ navigate อัตโนมัติ
        debugPrint('InvitationNotifier: Login and join successful');
      } catch (e) {
        // joinNursinghome failed - ต้อง sign out
        debugPrint('InvitationNotifier: joinNursinghome failed: $e');
        debugPrint('InvitationNotifier: Signing out to prevent navigation');

        await Supabase.instance.client.auth.signOut();

        state = state.copyWith(
          isLoading: false,
          errorMessage: _getGeneralErrorMessage(e),
        );
      }
    } on AuthException catch (e) {
      // Auth error (login failed) - ไม่ต้อง sign out เพราะไม่ได้ login
      debugPrint('InvitationNotifier: Auth error: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getThaiErrorMessage(e.message),
      );
    } catch (e) {
      // Unexpected error ตอน login
      debugPrint('InvitationNotifier: Error logging in: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: _getGeneralErrorMessage(e),
      );
    }
  }

  /// กลับไป step ก่อนหน้า
  void goBack() {
    switch (state.step) {
      case InvitationStep.emailInput:
        // อยู่ step แรกแล้ว ไม่ต้องทำอะไร (Navigator.pop จาก screen)
        break;

      case InvitationStep.showingInvitations:
        // กลับไป emailInput
        state = state.copyWith(
          step: InvitationStep.emailInput,
          clearSelectedInvitation: true,
          clearErrorMessage: true,
        );
        break;

      case InvitationStep.registerForm:
      case InvitationStep.loginForm:
        // กลับไป showingInvitations
        state = state.copyWith(
          step: InvitationStep.showingInvitations,
          clearSelectedInvitation: true,
          clearErrorMessage: true,
        );
        break;
    }
  }

  /// Reset state ทั้งหมด (เริ่มต้นใหม่)
  void reset() {
    state = const InvitationState();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  /// แปลง error message จาก Supabase เป็นภาษาไทย
  ///
  /// Mapping Supabase Auth errors → Thai messages ที่เข้าใจง่าย
  String _getThaiErrorMessage(String message) {
    final lowerMessage = message.toLowerCase();

    // === Login Errors ===
    if (lowerMessage.contains('invalid login credentials') ||
        lowerMessage.contains('invalid credentials')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    }

    // === Email Confirmation ===
    if (lowerMessage.contains('email not confirmed')) {
      return 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ (ตรวจสอบกล่องอีเมลของคุณ)';
    }

    // === Registration Errors ===
    if (lowerMessage.contains('user already registered') ||
        lowerMessage.contains('already been registered')) {
      return 'อีเมลนี้มีบัญชีอยู่แล้ว กรุณาเข้าสู่ระบบแทน';
    }

    // === Password Errors ===
    if (lowerMessage.contains('password should be at least') ||
        lowerMessage.contains('password is too short')) {
      return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    }

    // Weak/Common password (HaveIBeenPwned check)
    // เช่น "123456789aA" ผ่าน requirements แต่เป็น password ที่คนใช้กันเยอะ
    if (lowerMessage.contains('weak and easy to guess') ||
        lowerMessage.contains('password is known') ||
        lowerMessage.contains('commonly used') ||
        lowerMessage.contains('password is too weak')) {
      return 'รหัสผ่านนี้คนอื่นใช้กันเยอะเกินไป ลองใช้รหัสผ่านที่ไม่ซ้ำกับคนอื่น เช่น ผสมตัวอักษรแบบสุ่มหรือใช้ประโยคที่จำง่าย';
    }

    // Leaked/Pwned password (HaveIBeenPwned)
    if (lowerMessage.contains('pwned') ||
        lowerMessage.contains('leaked') ||
        lowerMessage.contains('compromised') ||
        lowerMessage.contains('data breach') ||
        lowerMessage.contains('have i been pwned')) {
      return 'รหัสผ่านนี้เคยถูกเปิดเผยในข้อมูลรั่วไหล กรุณาใช้รหัสผ่านอื่น';
    }

    // Password requirements not met
    if (lowerMessage.contains('password should contain') ||
        lowerMessage.contains('password must contain') ||
        lowerMessage.contains('lowercase') ||
        lowerMessage.contains('uppercase') ||
        lowerMessage.contains('digit')) {
      return 'รหัสผ่านต้องมีตัวพิมพ์เล็ก ตัวพิมพ์ใหญ่ และตัวเลข';
    }

    // === Email Format Errors ===
    if (lowerMessage.contains('invalid email') ||
        lowerMessage.contains('unable to validate email')) {
      return 'รูปแบบอีเมลไม่ถูกต้อง';
    }

    // === Rate Limit Errors ===
    if (lowerMessage.contains('rate limit') ||
        lowerMessage.contains('too many requests') ||
        lowerMessage.contains('email rate limit exceeded')) {
      return 'มีการร้องขอบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่';
    }

    // === Network/Connection Errors ===
    if (lowerMessage.contains('network') ||
        lowerMessage.contains('connection') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('socket')) {
      return 'ไม่สามารถเชื่อมต่อได้ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
    }

    // === Session Errors ===
    if (lowerMessage.contains('session expired') ||
        lowerMessage.contains('refresh token')) {
      return 'เซสชันหมดอายุ กรุณาลองใหม่อีกครั้ง';
    }

    // === User Not Found ===
    if (lowerMessage.contains('user not found')) {
      return 'ไม่พบบัญชีผู้ใช้นี้';
    }

    // === Signup Disabled ===
    if (lowerMessage.contains('signups not allowed') ||
        lowerMessage.contains('signup is disabled')) {
      return 'ระบบปิดการลงทะเบียนชั่วคราว กรุณาติดต่อผู้ดูแลระบบ';
    }

    // === Default: แสดง error จริงเพื่อ debug ===
    // ถ้าไม่รู้จัก error ให้แสดงข้อความจริงเพื่อช่วย debug
    debugPrint('Unknown auth error: $message');
    return 'เกิดข้อผิดพลาด: $message';
  }

  /// แปลง general error (non-AuthException) เป็นภาษาไทย
  ///
  /// ใช้สำหรับ catch block ที่จับ Exception ทั่วไป
  /// เช่น PostgrestException, SocketException, etc.
  String _getGeneralErrorMessage(Object error) {
    final message = error.toString().toLowerCase();

    // === Database Errors (PostgrestException) ===
    if (message.contains('duplicate key') ||
        message.contains('unique constraint')) {
      return 'ข้อมูลนี้มีอยู่ในระบบแล้ว';
    }
    if (message.contains('foreign key') ||
        message.contains('violates foreign key')) {
      return 'ไม่สามารถดำเนินการได้ เนื่องจากข้อมูลเชื่อมโยงกับข้อมูลอื่น';
    }
    if (message.contains('permission denied') ||
        message.contains('rls') ||
        message.contains('row-level security')) {
      return 'ไม่มีสิทธิ์ดำเนินการนี้ กรุณาติดต่อผู้ดูแลระบบ';
    }

    // === Network Errors ===
    if (message.contains('socketexception') ||
        message.contains('connection refused') ||
        message.contains('connection reset')) {
      return 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ต';
    }
    if (message.contains('timeout') || message.contains('timed out')) {
      return 'การเชื่อมต่อใช้เวลานานเกินไป กรุณาลองใหม่';
    }
    if (message.contains('handshake') || message.contains('certificate')) {
      return 'มีปัญหาในการเชื่อมต่อแบบปลอดภัย กรุณาลองใหม่';
    }

    // === Format/Parse Errors ===
    if (message.contains('formatexception') ||
        message.contains('unexpected character')) {
      return 'รูปแบบข้อมูลไม่ถูกต้อง กรุณาตรวจสอบข้อมูลที่กรอก';
    }

    // === Null/Not Found Errors ===
    if (message.contains('null') && message.contains('not a subtype')) {
      return 'ข้อมูลไม่ครบถ้วน กรุณาลองใหม่';
    }

    // === Default: แสดง error จริง (ตัดให้สั้นลง) ===
    debugPrint('Unknown general error: $error');
    // ตัด error message ให้สั้นลงถ้ายาวเกินไป
    final errorStr = error.toString();
    if (errorStr.length > 100) {
      return 'เกิดข้อผิดพลาด: ${errorStr.substring(0, 100)}...';
    }
    return 'เกิดข้อผิดพลาด: $errorStr';
  }
}

/// Provider สำหรับ InvitationNotifier
///
/// ใช้ StateNotifierProvider เพื่อให้ widget สามารถ:
/// 1. อ่าน state ด้วย ref.watch(invitationProvider)
/// 2. เรียก action ด้วย ref.read(invitationProvider.notifier).searchInvitations(...)
final invitationProvider =
    StateNotifierProvider<InvitationNotifier, InvitationState>((ref) {
  return InvitationNotifier();
});
