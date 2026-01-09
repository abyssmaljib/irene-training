import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../models/app_notification.dart';

/// Service for managing notifications
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _supabase = Supabase.instance.client;
  
  // Stream controller for real-time updates
  StreamController<List<AppNotification>>? _notificationsController;
  RealtimeChannel? _realtimeChannel;
  
  // Cache
  List<AppNotification>? _cachedNotifications;
  DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 2);

  /// Get notifications stream for real-time updates
  Stream<List<AppNotification>> get notificationsStream {
    _notificationsController ??= StreamController<List<AppNotification>>.broadcast();
    return _notificationsController!.stream;
  }

  /// Initialize real-time subscription
  Future<void> initRealtimeSubscription() async {
    final userId = UserService().effectiveUserId;
    if (userId == null) return;

    // Cancel existing subscription
    await _realtimeChannel?.unsubscribe();

    _realtimeChannel = _supabase
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('Notification realtime event: ${payload.eventType}');
            // Refresh notifications on any change
            fetchNotifications(forceRefresh: true);
          },
        )
        .subscribe();

    debugPrint('Notification realtime subscription initialized for user: $userId');
  }

  /// Dispose real-time subscription
  Future<void> disposeRealtimeSubscription() async {
    await _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    await _notificationsController?.close();
    _notificationsController = null;
  }

  /// Fetch all notifications for current user
  Future<List<AppNotification>> fetchNotifications({
    bool forceRefresh = false,
    int limit = 50,
  }) async {
    final userId = UserService().effectiveUserId;
    if (userId == null) return [];

    // Check cache
    if (!forceRefresh &&
        _cachedNotifications != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _cachedNotifications!;
    }

    try {
      final response = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final notifications = (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();

      _cachedNotifications = notifications;
      _lastFetchTime = DateTime.now();

      // Emit to stream
      _notificationsController?.add(notifications);

      return notifications;
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return _cachedNotifications ?? [];
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    final userId = UserService().effectiveUserId;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark a notification as read
  Future<bool> markAsRead(int notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      // Update cache
      if (_cachedNotifications != null) {
        final index = _cachedNotifications!.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _cachedNotifications![index] = _cachedNotifications![index].copyWith(isRead: true);
          _notificationsController?.add(_cachedNotifications!);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark a notification as unread
  Future<bool> markAsUnread(int notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': false})
          .eq('id', notificationId);

      // Update cache
      if (_cachedNotifications != null) {
        final index = _cachedNotifications!.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _cachedNotifications![index] = _cachedNotifications![index].copyWith(isRead: false);
          _notificationsController?.add(_cachedNotifications!);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error marking notification as unread: $e');
      return false;
    }
  }

  /// Toggle read status of a notification
  Future<bool> toggleReadStatus(int notificationId, bool currentIsRead) async {
    if (currentIsRead) {
      return markAsUnread(notificationId);
    } else {
      return markAsRead(notificationId);
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    final userId = UserService().effectiveUserId;
    if (userId == null) return false;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      // Update cache
      if (_cachedNotifications != null) {
        _cachedNotifications = _cachedNotifications!
            .map((n) => n.copyWith(isRead: true))
            .toList();
        _notificationsController?.add(_cachedNotifications!);
      }

      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(int notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      // Update cache
      if (_cachedNotifications != null) {
        _cachedNotifications!.removeWhere((n) => n.id == notificationId);
        _notificationsController?.add(_cachedNotifications!);
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }

  /// Invalidate cache
  void invalidateCache() {
    _cachedNotifications = null;
    _lastFetchTime = null;
  }
}
