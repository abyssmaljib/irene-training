import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../main.dart';
import '../../features/notifications/models/app_notification.dart';
import '../../features/notifications/screens/notification_center_screen.dart';
import '../../features/notifications/screens/notification_detail_screen.dart';
import '../../features/notifications/services/notification_service.dart';
import 'user_service.dart';

/// Service for managing OneSignal Push Notifications
/// รองรับ deep link จาก push notification ไปหน้า notification detail
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
      // Handle notification click - navigate ตาม action_url
      OneSignal.Notifications.addClickListener(_handleNotificationClick);

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

  /// Handle เมื่อ user กด push notification
  /// ถ้า action_url เป็น irene://notifications/{id} ให้ navigate ไปหน้า notification detail
  void _handleNotificationClick(OSNotificationClickEvent event) async {
    debugPrint('OneSignal: Notification Clicked: ${event.notification.jsonRepresentation()}');

    // ดึง additional data จาก notification
    final additionalData = event.notification.additionalData;
    final actionUrl = additionalData?['action_url'] as String?;

    if (actionUrl == null || actionUrl.isEmpty) {
      debugPrint('OneSignal: No action_url found');
      return;
    }

    debugPrint('OneSignal: action_url = $actionUrl');

    // Parse action_url: irene://notifications/{id}
    // ตัวอย่าง: irene://notifications/123
    final uri = Uri.tryParse(actionUrl);
    if (uri == null) {
      debugPrint('OneSignal: Failed to parse action_url');
      return;
    }

    // Check scheme และ host
    if (uri.scheme == 'irene' && uri.host == 'notifications') {
      // ดึง notification ID จาก path
      // pathSegments จะเป็น [] ถ้า path เป็น "/" หรือ ['123'] ถ้า path เป็น "/123"
      final pathSegments = uri.pathSegments;

      if (pathSegments.isNotEmpty) {
        // มี notification ID → ไปหน้า detail
        final notificationIdStr = pathSegments.first;
        final notificationId = int.tryParse(notificationIdStr);

        if (notificationId != null && notificationId > 0) {
          // ID ถูกต้อง → ไปหน้า detail
          await _navigateToNotificationDetail(notificationId);
        } else {
          // ID ไม่ถูกต้อง (0 หรือ parse ไม่ได้) → ไปหน้า notification center
          debugPrint('OneSignal: Invalid notification ID: $notificationIdStr, opening notification center');
          await _navigateToNotificationCenter();
        }
      } else {
        // ไม่มี ID → ไปหน้า notification center
        debugPrint('OneSignal: No notification ID, opening notification center');
        await _navigateToNotificationCenter();
      }
    } else {
      debugPrint('OneSignal: Unknown action_url scheme/host: ${uri.scheme}://${uri.host}');
    }
  }

  /// Navigate ไปหน้า notification detail โดยใช้ notification ID
  /// และ trigger global refresh เพื่อให้ HomeScreen โหลดข้อมูลใหม่
  Future<void> _navigateToNotificationDetail(int notificationId) async {
    debugPrint('OneSignal: Navigating to notification detail: $notificationId');

    // ใช้ global navigator key จาก main.dart
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('OneSignal: Navigator not available yet');
      return;
    }

    try {
      // *** สำคัญ: Trigger global refresh ก่อน navigate ***
      // เพื่อให้ HomeScreen และ screen อื่นๆ รู้ว่าต้องโหลดข้อมูลใหม่
      triggerGlobalRefresh();

      // Fetch notification data จาก service
      final notifications = await NotificationService.instance.fetchNotifications(forceRefresh: true);
      final notification = notifications.firstWhere(
        (n) => n.id == notificationId,
        orElse: () => AppNotification(
          id: notificationId,
          title: 'การแจ้งเตือน',
          body: 'กำลังโหลด...',
          userId: '',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );

      // Mark as read
      await NotificationService.instance.markAsRead(notificationId);

      // Navigate ไปหน้า detail
      navigator.push(
        MaterialPageRoute(
          builder: (_) => NotificationDetailScreen(notification: notification),
        ),
      );

      debugPrint('OneSignal: Navigated to notification detail successfully');
    } catch (e) {
      debugPrint('OneSignal: Error navigating to notification detail: $e');
    }
  }

  /// Navigate ไปหน้า notification center (เมื่อไม่มี notification ID หรือ ID ไม่ถูกต้อง)
  Future<void> _navigateToNotificationCenter() async {
    debugPrint('OneSignal: Navigating to notification center');

    // ใช้ global navigator key จาก main.dart
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('OneSignal: Navigator not available yet');
      return;
    }

    try {
      // Navigate ไปหน้า notification center
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const NotificationCenterScreen(),
        ),
      );

      debugPrint('OneSignal: Navigated to notification center successfully');
    } catch (e) {
      debugPrint('OneSignal: Error navigating to notification center: $e');
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
