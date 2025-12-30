import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service สำหรับ realtime subscription ของ tasks
/// ใช้สำหรับรับการอัปเดตแบบ realtime เมื่อ NA คนอื่นทำงาน
class TaskRealtimeService {
  static final instance = TaskRealtimeService._();
  TaskRealtimeService._();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _taskLogsChannel;

  /// Subscribe to A_Task_logs_ver2 table for realtime updates
  Future<void> subscribe({
    required VoidCallback onTaskUpdated,
  }) async {
    // Unsubscribe from ALL existing channels first (including other tables)
    await unsubscribeAll();

    _taskLogsChannel = _supabase
        .channel('public:A_Task_logs_ver2')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'A_Task_logs_ver2',
          callback: (PostgresChangePayload payload) {
            debugPrint('TaskRealtimeService: received update - ${payload.eventType}');
            onTaskUpdated();
          },
        )
        .subscribe((status, error) {
          debugPrint('TaskRealtimeService: subscription status = $status');
          if (error != null) {
            debugPrint('TaskRealtimeService: subscription error = $error');
          }
        });

    debugPrint('TaskRealtimeService: subscribed to A_Task_logs_ver2');
  }

  /// Unsubscribe from ALL realtime channels (including other tables)
  /// เรียกก่อน subscribe เพื่อให้แน่ใจว่าไม่มี subscription ค้างอยู่
  Future<void> unsubscribeAll() async {
    try {
      // Remove all existing channels from Supabase client
      await _supabase.removeAllChannels();
      _taskLogsChannel = null;
      debugPrint('TaskRealtimeService: removed all channels');
    } catch (e) {
      debugPrint('TaskRealtimeService: error removing channels - $e');
    }
  }

  /// Unsubscribe from task logs channel only
  Future<void> unsubscribe() async {
    if (_taskLogsChannel != null) {
      await _taskLogsChannel!.unsubscribe();
      _taskLogsChannel = null;
      debugPrint('TaskRealtimeService: unsubscribed from A_Task_logs_ver2');
    }
  }
}
