import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM Background message: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
}

/// Service for managing Firebase Cloud Messaging (FCM)
class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final _supabase = Supabase.instance.client;

  String? _fcmToken;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Callback for handling notification taps
  Function(RemoteMessage message)? onNotificationTap;

  /// Callback for handling foreground notifications
  Function(RemoteMessage message)? onForegroundMessage;

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Initialize FCM service
  Future<void> initialize() async {
    // Skip on web for now (requires additional setup)
    if (kIsWeb) {
      debugPrint('FCM: Web platform - skipping initialization');
      return;
    }

    try {
      // Request permission
      final settings = await _requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('FCM: Permission denied');
        return;
      }

      // Get FCM token
      await _getAndSaveToken();

      // Listen for token refresh
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM: Token refreshed');
        _fcmToken = newToken;
        _saveTokenToDatabase(newToken);
      });

      // Handle foreground messages
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      debugPrint('FCM: Initialized successfully');
    } catch (e) {
      debugPrint('FCM: Initialization error: $e');
    }
  }

  /// Request notification permission
  Future<NotificationSettings> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('FCM: Permission status: ${settings.authorizationStatus}');
    return settings;
  }

  /// Get FCM token and save to database
  Future<void> _getAndSaveToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('FCM: Token obtained: ${_fcmToken?.substring(0, 20)}...');

      if (_fcmToken != null) {
        await _saveTokenToDatabase(_fcmToken!);
      }
    } catch (e) {
      debugPrint('FCM: Error getting token: $e');
    }
  }

  /// Save FCM token to user_info table
  Future<void> _saveTokenToDatabase(String token) async {
    final userId = UserService().effectiveUserId;
    if (userId == null) {
      debugPrint('FCM: No user ID, skipping token save');
      return;
    }

    try {
      await _supabase
          .from('user_info')
          .update({'fcm_token': token})
          .eq('id', userId);

      debugPrint('FCM: Token saved to database for user: $userId');
    } catch (e) {
      debugPrint('FCM: Error saving token to database: $e');
    }
  }

  /// Handle foreground message
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM: Foreground message received');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Call custom handler if set
    onForegroundMessage?.call(message);
  }

  /// Handle notification tap (app opened from notification)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('FCM: Notification tapped');
    debugPrint('Data: ${message.data}');

    // Call custom handler if set
    onNotificationTap?.call(message);
  }

  /// Clear FCM token from database (on logout)
  Future<void> clearToken() async {
    final userId = UserService().effectiveUserId;
    if (userId == null) return;

    try {
      await _supabase
          .from('user_info')
          .update({'fcm_token': null})
          .eq('id', userId);

      debugPrint('FCM: Token cleared from database');
    } catch (e) {
      debugPrint('FCM: Error clearing token: $e');
    }
  }

  /// Refresh and save token (call after login)
  Future<void> refreshToken() async {
    await _getAndSaveToken();
  }

  /// Dispose subscriptions
  void dispose() {
    _foregroundSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
  }
}
