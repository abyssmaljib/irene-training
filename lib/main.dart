import 'dart:async';
import 'dart:ui';
import 'package:clarity_flutter/clarity_flutter.dart';
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
import 'features/auth/screens/login_screen.dart';
import 'features/navigation/screens/main_navigation_screen.dart';

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

class _AuthWrapperState extends State<AuthWrapper> {
  Session? _session;
  late final StreamSubscription<AuthState> _authSubscription;

  // Flag เพื่อป้องกันการเช็ค force update ซ้ำ
  bool _hasCheckedForceUpdate = false;

  @override
  void initState() {
    super.initState();

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
          // ใช้ addPostFrameCallback เพื่อให้ context พร้อมใช้งาน
          _checkForceUpdate();
        } else {
          // Logout from OneSignal
          OneSignalService.instance.clearToken();
          // Reset flag เมื่อ logout เพื่อให้เช็คใหม่ตอน login ครั้งหน้า
          _hasCheckedForceUpdate = false;
        }
      }
    });
  }

  /// ตรวจสอบว่าต้อง force update หรือไม่
  /// ถ้าต้อง update จะแสดง dialog ที่ปิดไม่ได้
  Future<void> _checkForceUpdate() async {
    // ป้องกันการเช็คซ้ำ
    if (_hasCheckedForceUpdate) return;
    _hasCheckedForceUpdate = true;

    try {
      final isUpdateRequired =
          await ForceUpdateService.instance.isUpdateRequired();

      if (isUpdateRequired && mounted) {
        // รอให้ frame build เสร็จก่อนแสดง dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && navigatorKey.currentContext != null) {
            ForceUpdateDialog.show(navigatorKey.currentContext!);
          }
        });
      }
    } catch (e) {
      debugPrint('AuthWrapper: Error checking force update: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session != null) {
      return MainNavigationScreen(key: ValueKey(_session!.user.id));
    } else {
      return const LoginScreen(key: ValueKey('login'));
    }
  }
}
