import 'dart:async';
import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'core/services/fcm_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/navigation/screens/main_navigation_screen.dart';
import 'firebase_options.dart';

// Global variable to store Clarity project ID after loading
String _clarityProjectId = '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file with error handling
  try {
    await dotenv.load(fileName: '.env');
    _clarityProjectId = dotenv.env['CLARITY_PROJECT_ID'] ?? '';
    debugPrint('Dotenv loaded successfully');
  } catch (e) {
    debugPrint('Failed to load .env file: $e');
    // Continue without .env - fallback values will be used
  }

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set up FCM background handler (must be before FCM initialization)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Crashlytics (NOT supported on Web)
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Initialize Supabase with fallback values
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

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
          // Set in Crashlytics (NOT supported on Web)
          if (!kIsWeb) {
            FirebaseCrashlytics.instance.setUserIdentifier(userId);
          }
          // Initialize FCM and save token after login
          FCMService.instance.initialize();
        } else {
          // Clear FCM token on logout
          FCMService.instance.clearToken();
        }
      }
    });
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
