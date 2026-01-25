import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service สำหรับ realtime subscription ของ tasks
/// ใช้สำหรับรับการอัปเดตแบบ realtime เมื่อ NA คนอื่นทำงาน
class TaskRealtimeService {
  static final instance = TaskRealtimeService._();
  TaskRealtimeService._();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _taskLogsChannel;

  /// เก็บ callback สำหรับ re-subscribe
  VoidCallback? _onTaskUpdated;

  /// Flag ป้องกัน multiple subscriptions
  bool _isSubscribing = false;

  /// Timer สำหรับ retry เมื่อ connection ขาด
  Timer? _retryTimer;

  /// จำนวนครั้งที่ retry
  int _retryCount = 0;

  /// Max retry attempts
  static const _maxRetries = 5;

  /// Subscribe to A_Task_logs_ver2 table for realtime updates
  /// รองรับ auto-reconnect เมื่อ connection ขาด
  Future<void> subscribe({
    required VoidCallback onTaskUpdated,
  }) async {
    // เก็บ callback ไว้สำหรับ re-subscribe
    _onTaskUpdated = onTaskUpdated;
    _retryCount = 0;

    await _doSubscribe();
  }

  /// Internal subscribe method - ใช้สำหรับ initial และ retry
  Future<void> _doSubscribe() async {
    // ป้องกัน multiple subscriptions
    if (_isSubscribing) {
      debugPrint('TaskRealtimeService: already subscribing, skipping...');
      return;
    }

    _isSubscribing = true;

    // Unsubscribe channel เดิมก่อน (เฉพาะ task channel ไม่ใช่ทุก channel)
    await unsubscribe();

    // Cancel retry timer ถ้ามี
    _retryTimer?.cancel();
    _retryTimer = null;

    try {
      // สร้าง unique channel name เพื่อหลีกเลี่ยง conflict
      final channelName = 'task-logs-${DateTime.now().millisecondsSinceEpoch}';

      _taskLogsChannel = _supabase
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'A_Task_logs_ver2',
            callback: (PostgresChangePayload payload) {
              debugPrint('TaskRealtimeService: received ${payload.eventType} for task ${payload.newRecord['id'] ?? payload.oldRecord['id']}');
              _onTaskUpdated?.call();
            },
          )
          .subscribe((status, error) {
            debugPrint('TaskRealtimeService: status = $status');

            if (error != null) {
              debugPrint('TaskRealtimeService: error = $error');
            }

            // Handle different statuses
            switch (status) {
              case RealtimeSubscribeStatus.subscribed:
                // สำเร็จ - reset retry count
                _retryCount = 0;
                debugPrint('TaskRealtimeService: subscribed successfully!');
                break;

              case RealtimeSubscribeStatus.closed:
              case RealtimeSubscribeStatus.channelError:
                // Connection ขาด - ลอง reconnect
                debugPrint('TaskRealtimeService: connection lost, will retry...');
                _scheduleRetry();
                break;

              case RealtimeSubscribeStatus.timedOut:
                // Timeout - ลอง reconnect
                debugPrint('TaskRealtimeService: timeout, will retry...');
                _scheduleRetry();
                break;
            }
          });

      debugPrint('TaskRealtimeService: subscribing to A_Task_logs_ver2...');
    } catch (e) {
      debugPrint('TaskRealtimeService: subscribe error - $e');
      _scheduleRetry();
    } finally {
      _isSubscribing = false;
    }
  }

  /// ตั้งเวลา retry ด้วย exponential backoff
  void _scheduleRetry() {
    if (_onTaskUpdated == null) {
      debugPrint('TaskRealtimeService: no callback, skipping retry');
      return;
    }

    if (_retryCount >= _maxRetries) {
      debugPrint('TaskRealtimeService: max retries reached, giving up');
      return;
    }

    _retryCount++;
    // Exponential backoff: 2s, 4s, 8s, 16s, 32s
    final delay = Duration(seconds: 2 * (1 << (_retryCount - 1)));
    debugPrint('TaskRealtimeService: retry #$_retryCount in ${delay.inSeconds}s');

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      debugPrint('TaskRealtimeService: retrying subscription...');
      _doSubscribe();
    });
  }

  /// Unsubscribe from ALL realtime channels (including other tables)
  /// เรียกตอน dispose screen
  Future<void> unsubscribeAll() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _onTaskUpdated = null;
    _retryCount = 0;

    try {
      // Remove all existing channels from Supabase client
      await _supabase.removeAllChannels();
      _taskLogsChannel = null;
      debugPrint('TaskRealtimeService: removed all channels');
    } catch (e) {
      debugPrint('TaskRealtimeService: error removing channels - $e');
    }
  }

  /// Unsubscribe from task logs channel only (ไม่กระทบ channel อื่น)
  Future<void> unsubscribe() async {
    if (_taskLogsChannel != null) {
      try {
        await _supabase.removeChannel(_taskLogsChannel!);
        debugPrint('TaskRealtimeService: removed task logs channel');
      } catch (e) {
        debugPrint('TaskRealtimeService: error removing channel - $e');
      }
      _taskLogsChannel = null;
    }
  }
}
