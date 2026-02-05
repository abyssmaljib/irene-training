import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../checklist/providers/task_provider.dart'; // for userChangeCounterProvider
import '../models/app_notification.dart';
import '../services/notification_service.dart';

/// Provider for unread notification count
final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);
  return NotificationService.instance.getUnreadCount();
});

/// Provider for all notifications
final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);
  return NotificationService.instance.fetchNotifications();
});

/// Provider for unread notifications only
final unreadNotificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);
  final notifications = await NotificationService.instance.fetchNotifications();
  return notifications.where((n) => !n.isRead).toList();
});

/// Provider for notifications stream (real-time)
final notificationsStreamProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  // Initialize realtime subscription
  NotificationService.instance.initRealtimeSubscription();
  
  // Fetch initial data
  NotificationService.instance.fetchNotifications();
  
  // Dispose on provider dispose
  ref.onDispose(() {
    NotificationService.instance.disposeRealtimeSubscription();
  });
  
  return NotificationService.instance.notificationsStream;
});

/// State notifier for managing notification actions
/// รับ ref เพื่อให้สามารถ invalidate providers อื่นได้เมื่อ notification state เปลี่ยน
class NotificationStateNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final Ref _ref;

  NotificationStateNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    state = const AsyncValue.loading();
    try {
      final notifications = await NotificationService.instance.fetchNotifications();
      state = AsyncValue.data(notifications);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    try {
      final notifications = await NotificationService.instance.fetchNotifications(forceRefresh: true);
      state = AsyncValue.data(notifications);
      // Invalidate unread count provider เพื่อให้ badge อัพเดต
      // ทำให้หน้า Profile และ Bottom Navigation แสดงจำนวนที่ถูกต้อง
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsRead(int notificationId) async {
    await NotificationService.instance.markAsRead(notificationId);
    await refresh();
  }

  Future<void> markAsUnread(int notificationId) async {
    await NotificationService.instance.markAsUnread(notificationId);
    await refresh();
  }

  Future<void> toggleReadStatus(int notificationId, bool currentIsRead) async {
    await NotificationService.instance.toggleReadStatus(notificationId, currentIsRead);
    await refresh();
  }

  Future<void> markAllAsRead() async {
    await NotificationService.instance.markAllAsRead();
    await refresh();
  }

  Future<void> deleteNotification(int notificationId) async {
    await NotificationService.instance.deleteNotification(notificationId);
    await refresh();
  }
}

/// Provider for notification state with actions
final notificationStateProvider = StateNotifierProvider.autoDispose<NotificationStateNotifier, AsyncValue<List<AppNotification>>>((ref) {
  // ส่ง ref เข้าไปเพื่อให้ NotificationStateNotifier สามารถ invalidate providers อื่นได้
  return NotificationStateNotifier(ref);
});
