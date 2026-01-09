import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'user_service.dart';

/// Service for managing OneSignal Push Notifications
class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  /// Initialize OneSignal service (Login/Setup)
  Future<void> initialize() async {
    if (kIsWeb) return; // Skip on web

    try {
      final userId = UserService().effectiveUserId;
      if (userId != null) {
        // Login to OneSignal with Supabase User ID
        await OneSignal.login(userId);
        debugPrint('OneSignal: Logged in as $userId');

        // Add email/phone if available (optional)
        // await OneSignal.User.addEmail(email);
      }

      // Add event listeners
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('OneSignal: Notification Clicked: ${event.notification.jsonRepresentation()}');
      });

      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint('OneSignal: Foreground Notification received: ${event.notification.jsonRepresentation()}');
        /// Prevent Default generation of notification causing duplicate notifications?
        /// OneSignal by default shows notification.
        /// event.preventDefault();
        /// event.notification.display();
      });

      debugPrint('OneSignal: Initialized successfully');
    } catch (e) {
      debugPrint('OneSignal: Initialization error: $e');
    }
  }

  /// Logout from OneSignal
  Future<void> clearToken() async {
    try {
      await OneSignal.logout();
      debugPrint('OneSignal: Logged out');
    } catch (e) {
      debugPrint('OneSignal: Logout error: $e');
    }
  }

  /// Refresh (re-login)
  Future<void> refreshToken() async {
    await initialize();
  }
}
