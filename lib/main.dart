import 'dart:async';
import 'dart:ui';
import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart'; // สำหรับ initializeDateFormatting
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'firebase_options.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'core/services/app_version_service.dart';
import 'core/services/force_update_service.dart';
import 'core/services/onesignal_service.dart';
import 'core/widgets/force_update_dialog.dart';
import 'features/auth/screens/invitation_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/navigation/screens/main_navigation_screen.dart';
import 'features/profile_setup/screens/unified_profile_setup_screen.dart';
import 'features/profile_setup/services/profile_setup_service.dart';
import 'core/services/user_service.dart';
import 'core/theme/app_colors.dart';

// Global navigator key สำหรับ navigation จาก service (เช่น push notification)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global refresh notifier - ใช้สำหรับบอก HomeScreen ให้ refresh ข้อมูลหลังจาก deep link
// ValueNotifier<int> เพื่อ trigger rebuild เมื่อ value เปลี่ยน
final ValueNotifier<int> globalRefreshNotifier = ValueNotifier<int>(0);

/// เรียก function นี้เพื่อ trigger refresh ทุก screen ที่ listen อยู่
void triggerGlobalRefresh() {
  globalRefreshNotifier.value++;
  debugPrint('Global refresh triggered: ${globalRefreshNotifier.value}');
}

// Global variable to store Clarity project ID after loading
String _clarityProjectId = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  // ต้องเรียกก่อน services อื่นๆ ที่ใช้ Firebase (เช่น Crashlytics)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Setup Crashlytics (ไม่รองรับ Web)
  // จะจับ errors ทั้งหมดและส่งไป Firebase Console
  if (!kIsWeb) {
    // จับ Flutter framework errors (เช่น widget build errors)
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // จับ async errors ที่ไม่ได้ถูก catch (เช่น errors ใน Future, Stream)
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // เปิด Edge-to-Edge mode สำหรับ Android 15+
  // ทำให้แอปแสดงผลเต็มจอ รวมถึง status bar และ navigation bar area
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // ตั้งค่า system overlay style ให้โปร่งใส
  // เพื่อให้แอป render เนื้อหาใต้ status bar และ navigation bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      // Status bar (ด้านบน) - โปร่งใสเพื่อให้เห็นเนื้อหาด้านหลัง
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // icon สีเข้มสำหรับ light theme
      // Navigation bar (ด้านล่าง) - โปร่งใสเพื่อ gesture navigation
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false, // ปิด contrast enforcement
    ),
  );

  // Load .env file with error handling
  try {
    await dotenv.load(fileName: '.env');
    _clarityProjectId = dotenv.env['CLARITY_PROJECT_ID'] ?? '';
    debugPrint('Dotenv loaded successfully');
  } catch (e) {
    debugPrint('Failed to load .env file: $e');
    // Continue without .env - fallback values will be used
  }

  // Initialize OneSignal
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("c657a2e6-7daf-4c82-b468-88bb71f4ce6e");
  OneSignal.Notifications.requestPermission(true);

  // Initialize Supabase with fallback values
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Initialize Thai locale สำหรับ DateFormat
  // ต้องเรียกก่อนใช้ DateFormat('d MMM', 'th') ไม่งั้นจะเกิด LocaleDataException
  await initializeDateFormatting('th');

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap with ClarityWidget for session recording & heatmaps
    Widget app = MaterialApp(
      title: 'Irene Training',
      debugShowCheckedModeBanner: false,
      // ใช้ navigatorKey เพื่อให้ services สามารถ navigate ได้
      navigatorKey: navigatorKey,
      // ========== Thai Localization ==========
      // จำเป็นสำหรับ DatePicker และ UI components อื่นๆ ที่ใช้ locale
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th', 'TH'), // Thai (หลัก)
        Locale('en', 'US'), // English (สำรอง)
      ],
      locale: const Locale('th', 'TH'), // ใช้ภาษาไทยเป็น default
      theme: ThemeData(
        fontFamily: 'MiSansThai',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D9488)),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );

    // Only enable Clarity if project ID is set
    if (_clarityProjectId.isNotEmpty) {
      return ClarityWidget(
        clarityConfig: ClarityConfig(projectId: _clarityProjectId),
        app: app,
      );
    }

    return app;
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with WidgetsBindingObserver {
  Session? _session;
  late final StreamSubscription<AuthState> _authSubscription;

  // Cooldown: เช็ค force update ได้ไม่เกินทุก 5 นาที
  // ป้องกัน query DB ถี่เกินไปเมื่อ user สลับแอปไปมา
  DateTime? _lastForceUpdateCheck;
  static const _forceUpdateCooldown = Duration(minutes: 5);

  // Flag กัน dialog ซ้อน — ถ้า dialog แสดงอยู่แล้วไม่ต้องเช็คอีก
  bool _isForceUpdateDialogShowing = false;

  @override
  void initState() {
    super.initState();

    // ลงทะเบียน lifecycle observer เพื่อเช็ค force update ตอนกลับเข้าแอป
    WidgetsBinding.instance.addObserver(this);

    _session = Supabase.instance.client.auth.currentSession;

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _session = data.session;
        });

        // Set user ID in analytics when logged in
        if (data.session != null) {
          final userId = data.session!.user.id;
          // Set in Clarity
          Clarity.setCustomUserId(userId);
          // Set in Crashlytics (ไม่รองรับ Web)
          // ช่วยให้รู้ว่า crash เกิดจาก user คนไหน
          if (!kIsWeb) {
            FirebaseCrashlytics.instance.setUserIdentifier(userId);
          }

          // Initialize OneSignal and login with user ID
          OneSignalService.instance.initialize();

          // อัพเดตข้อมูล app version ไปที่ user_info
          // เพื่อให้ admin ดูได้ว่า user ใช้ version อะไร
          AppVersionService.instance.updateVersionInfo();

          // เช็ค force update หลัง login
          _checkForceUpdate();
        } else {
          // Logout from OneSignal
          OneSignalService.instance.clearToken();
          // Reset เมื่อ logout เพื่อให้เช็คทันทีตอน login ครั้งหน้า
          _lastForceUpdateCheck = null;
          _isForceUpdateDialogShowing = false;
        }
      }
    });
  }

  /// เช็ค force update เมื่อ user กลับเข้าแอปจาก background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // เช็คเฉพาะตอนกลับเข้าแอป (resumed) และ user ยัง login อยู่
    if (state == AppLifecycleState.resumed && _session != null) {
      debugPrint('🔍 Lifecycle: App resumed → เช็ค force update');
      _checkForceUpdate();
    }
  }

  /// ตรวจสอบว่าต้อง force update หรือไม่
  /// เช็คได้ทุกครั้งที่เรียก แต่มี cooldown 5 นาทีกัน query DB ถี่เกินไป
  Future<void> _checkForceUpdate() async {
    // ถ้า dialog แสดงอยู่แล้ว ไม่ต้องเช็คซ้ำ
    if (_isForceUpdateDialogShowing) {
      debugPrint('🔍 _checkForceUpdate: SKIP - dialog แสดงอยู่แล้ว');
      return;
    }

    // Cooldown: ถ้าเช็คไปไม่ถึง 5 นาที ยังไม่ต้องเช็คใหม่
    final now = DateTime.now();
    if (_lastForceUpdateCheck != null &&
        now.difference(_lastForceUpdateCheck!) < _forceUpdateCooldown) {
      debugPrint('🔍 _checkForceUpdate: SKIP - cooldown ยังไม่หมด '
          '(เหลือ ${_forceUpdateCooldown.inMinutes - now.difference(_lastForceUpdateCheck!).inMinutes} นาที)');
      return;
    }
    _lastForceUpdateCheck = now;

    try {
      final isUpdateRequired =
          await ForceUpdateService.instance.isUpdateRequired();

      debugPrint('🔍 _checkForceUpdate: isUpdateRequired=$isUpdateRequired, mounted=$mounted');

      if (isUpdateRequired && mounted) {
        debugPrint('🔍 _checkForceUpdate: ✅ จะแสดง ForceUpdateDialog');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && navigatorKey.currentContext != null) {
            debugPrint('🔍 _checkForceUpdate: 🎉 แสดง ForceUpdateDialog!');
            _isForceUpdateDialogShowing = true;
            ForceUpdateDialog.show(navigatorKey.currentContext!);
          }
        });
      }
    } catch (e) {
      debugPrint('🔍 _checkForceUpdate: ❌ ERROR: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session != null) {
      // Flow: EmploymentCheckWrapper → ProfileCheckWrapper → MainNavigationScreen
      // 1. ตรวจสอบว่าลาออกหรือยัง และมี nursinghome_id หรือไม่
      // 2. ตรวจสอบว่ากรอก profile แล้วหรือยัง
      // 3. เข้าแอป
      return EmploymentCheckWrapper(
        key: ValueKey(_session!.user.id),
        child: ProfileCheckWrapper(
          key: ValueKey('profile_${_session!.user.id}'),
          child: MainNavigationScreen(key: const ValueKey('main')),
        ),
      );
    } else {
      // แสดง WelcomeScreen ก่อน ให้ผู้ใช้เลือกสมัครสมาชิกหรือเข้าสู่ระบบ
      return const WelcomeScreen(key: ValueKey('welcome'));
    }
  }
}

/// Wrapper ที่ตรวจสอบสถานะการทำงานของ user
/// - ถ้าลาออกแล้ว (resigned) → แสดงหน้า error และ logout
/// - ถ้าไม่มี nursinghome_id → แสดงหน้า error
/// - ถ้าผ่าน → แสดง child (ProfileCheckWrapper)
class EmploymentCheckWrapper extends StatefulWidget {
  final Widget child;

  const EmploymentCheckWrapper({
    super.key,
    required this.child,
  });

  @override
  State<EmploymentCheckWrapper> createState() => _EmploymentCheckWrapperState();
}

enum EmploymentStatus {
  loading,
  valid,
  resigned,
  noNursinghome,
}

class _EmploymentCheckWrapperState extends State<EmploymentCheckWrapper> {
  EmploymentStatus _status = EmploymentStatus.loading;

  /// ป้องกัน auto-navigate ซ้ำ — navigate ไปหน้าค้นหาคำเชิญแค่ครั้งแรก
  /// ถ้ากลับมาแล้วยัง noNursinghome จะแสดงหน้า error พร้อมปุ่มค้นหาแทน
  bool _autoNavigatedToInvitation = false;

  @override
  void initState() {
    super.initState();
    _checkEmploymentStatus();
  }

  Future<void> _checkEmploymentStatus() async {
    try {
      final (isValid, errorType) = await UserService().validateUserAccess();

      if (!mounted) return;

      if (isValid) {
        setState(() => _status = EmploymentStatus.valid);
      } else if (errorType == 'resigned') {
        setState(() => _status = EmploymentStatus.resigned);
      } else if (errorType == 'no_nursinghome') {
        setState(() => _status = EmploymentStatus.noNursinghome);
      }
    } catch (e) {
      debugPrint('EmploymentCheckWrapper: Error: $e');
      // ถ้าเกิด error ให้ผ่านไปก่อน (fail-safe)
      if (mounted) {
        setState(() => _status = EmploymentStatus.valid);
      }
    }
  }

  Future<void> _logout() async {
    UserService().clearCache();
    await Supabase.instance.client.auth.signOut();
  }

  /// Sign out แล้วไปหน้า InvitationScreen ให้ user ค้นหาคำเชิญ
  /// ดึง email ก่อน sign out เพื่อ pre-fill ใน InvitationScreen
  Future<void> _navigateToInvitation() async {
    // เก็บ email ไว้ก่อน sign out (จะหายไปหลัง sign out)
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    // Sign out เพื่อให้ user ใช้ InvitationScreen ปกติ (ใส่ password + login)
    await _logout();

    // หลัง sign out → AuthWrapper จะ rebuild เป็น WelcomeScreen
    // แต่เราสามารถ push InvitationScreen ผ่าน navigator key ได้
    // ใช้ Future.delayed เพื่อรอให้ AuthWrapper rebuild เสร็จก่อน
    if (mounted) {
      // Navigate ไป InvitationScreen พร้อม email ที่ pre-fill ไว้
      Future.delayed(const Duration(milliseconds: 300), () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => InvitationScreen(initialEmail: email),
          ),
        );
      });
    }
  }

  /// ไปหน้า InvitationScreen โดยไม่ต้อง sign out (user มี session อยู่แล้ว)
  /// ใช้สำหรับ user ที่ไม่มี nursinghome_id
  /// หลัง accept invitation สำเร็จ → กลับมา re-check employment status
  Future<void> _navigateToInvitationDirectly() async {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    if (!mounted) return;

    // Push InvitationScreen แบบ alreadyAuthenticated
    // ไม่ต้อง login ซ้ำ — กดเลือก NH แล้ว accept ได้เลย
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvitationScreen(
          initialEmail: email,
          alreadyAuthenticated: true,
        ),
      ),
    );

    // กลับมาจาก InvitationScreen → re-check employment status
    if (mounted) {
      setState(() => _status = EmploymentStatus.loading);
      _checkEmploymentStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case EmploymentStatus.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );

      case EmploymentStatus.valid:
        return widget.child;

      case EmploymentStatus.resigned:
        // หน้า error สำหรับ user ที่ลาออกแล้ว
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.work_off_outlined,
                      size: 64,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'บัญชีถูกระงับ',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'บัญชีของคุณถูกระงับการใช้งานเนื่องจากพ้นสภาพการเป็นพนักงาน\n\nหากได้รับคำเชิญจากสถานดูแล กดปุ่มด้านล่างเพื่อเข้าร่วม',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 48),

                  // ปุ่มค้นหาคำเชิญ — sign out แล้วไปหน้า InvitationScreen
                  // เพื่อให้ user ใส่ password ยืนยันตัวตนใหม่
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _navigateToInvitation(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('ค้นหาคำเชิญ'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('ออกจากระบบ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case EmploymentStatus.noNursinghome:
        // ครั้งแรกที่เจอ noNursinghome → auto-navigate ไปหน้าค้นหาคำเชิญเลย
        // ถ้ากลับมาแล้วยัง noNursinghome → แสดงหน้า error พร้อมปุ่มค้นหา
        if (!_autoNavigatedToInvitation) {
          _autoNavigatedToInvitation = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _navigateToInvitationDirectly();
          });
          // แสดง loading ขณะรอ navigate
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // กลับมาจาก InvitationScreen แล้วยัง noNursinghome
        // แสดงหน้า error พร้อมปุ่มค้นหาคำเชิญ
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.business_outlined,
                      size: 64,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'ยังไม่ได้เข้าร่วมสถานดูแล',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'บัญชีของคุณยังไม่ได้เข้าร่วมสถานดูแลใดๆ\n\nหากได้รับคำเชิญ กดปุ่มด้านล่างเพื่อค้นหาและเข้าร่วม',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 48),

                  // ปุ่มค้นหาคำเชิญ (primary action)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _navigateToInvitationDirectly(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('ค้นหาคำเชิญ'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('ออกจากระบบ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}

/// Wrapper ที่ตรวจสอบว่า user กรอก profile แล้วหรือยัง
/// ถ้ายังไม่กรอก จะแสดง UnifiedProfileSetupScreen (รวมทุกส่วนไว้ในหน้าเดียว)
/// ถ้ากรอกแล้ว จะแสดง child (MainNavigationScreen)
///
/// Flow (Simplified):
/// 1. UnifiedProfileSetupScreen (รวมทุกส่วน - section 1 บังคับ, 2-3 ไม่บังคับ)
/// 2. MainNavigationScreen (เข้าแอป)
class ProfileCheckWrapper extends StatefulWidget {
  final Widget child;

  const ProfileCheckWrapper({
    super.key,
    required this.child,
  });

  @override
  State<ProfileCheckWrapper> createState() => _ProfileCheckWrapperState();
}

/// Step ของการกรอก profile (Simplified)
enum ProfileSetupStep {
  loading,     // กำลังโหลด
  setup,       // UnifiedProfileSetupScreen (รวมทุกส่วน)
  completed,   // เสร็จแล้ว - แสดง MainNavigationScreen
}

class _ProfileCheckWrapperState extends State<ProfileCheckWrapper> {
  ProfileSetupStep _currentStep = ProfileSetupStep.loading;

  @override
  void initState() {
    super.initState();
    _checkProfileStatus();
  }

  /// ตรวจสอบว่า user ต้องกรอก profile หรือไม่
  Future<void> _checkProfileStatus() async {
    try {
      final needsSetup = await ProfileSetupService().needsProfileSetup();
      if (mounted) {
        setState(() {
          // ถ้าต้องกรอก แสดง UnifiedProfileSetupScreen, ถ้าไม่ต้อง เข้าแอปเลย
          _currentStep = needsSetup
              ? ProfileSetupStep.setup
              : ProfileSetupStep.completed;
        });
      }
    } catch (e) {
      debugPrint('ProfileCheckWrapper: Error checking profile: $e');
      // ถ้าเกิด error ไม่บังคับให้กรอก (fail-safe)
      if (mounted) {
        setState(() => _currentStep = ProfileSetupStep.completed);
      }
    }
  }

  /// เรียกเมื่อ user กรอก profile เสร็จ - เข้าแอป
  void _onSetupComplete() {
    setState(() => _currentStep = ProfileSetupStep.completed);
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case ProfileSetupStep.loading:
        // กำลังโหลด - แสดง loading indicator
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );

      case ProfileSetupStep.setup:
        // UnifiedProfileSetupScreen - รวมทุกส่วนไว้ในหน้าเดียว
        // Section 1 บังคับ, Section 2-3 ไม่บังคับ (แสดงเป็น ExpansionTile)
        return UnifiedProfileSetupScreen(
          onComplete: _onSetupComplete,
          showAsOnboarding: true,
        );

      case ProfileSetupStep.completed:
        // เสร็จแล้ว - แสดง MainNavigationScreen
        return widget.child;
    }
  }
}
