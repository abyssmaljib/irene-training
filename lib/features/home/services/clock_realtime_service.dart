import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service สำหรับ realtime subscription ของ clock_in_out_ver2
/// ใช้สำหรับรับการอัปเดตแบบ realtime เมื่อเพื่อนขึ้น/ลงเวร
class ClockRealtimeService {
  static final instance = ClockRealtimeService._();
  ClockRealtimeService._();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _clockChannel;

  /// Subscribe to clock_in_out_ver2 table for realtime updates
  /// เมื่อเพื่อนขึ้น/ลงเวร จะ callback เพื่อ refresh occupied residents/break times
  Future<void> subscribe({
    required VoidCallback onClockUpdated,
  }) async {
    // Unsubscribe from existing clock channel first
    await unsubscribe();

    _clockChannel = _supabase
        .channel('public:clock_in_out_ver2')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clock_in_out_ver2',
          callback: (PostgresChangePayload payload) {
            debugPrint('ClockRealtimeService: received update - ${payload.eventType}');
            onClockUpdated();
          },
        )
        .subscribe((status, error) {
          debugPrint('ClockRealtimeService: subscription status = $status');
          if (error != null) {
            debugPrint('ClockRealtimeService: subscription error = $error');
          }
        });

    debugPrint('ClockRealtimeService: subscribed to clock_in_out_ver2');
  }

  /// Unsubscribe from clock channel
  Future<void> unsubscribe() async {
    if (_clockChannel != null) {
      await _clockChannel!.unsubscribe();
      _clockChannel = null;
      debugPrint('ClockRealtimeService: unsubscribed from clock_in_out_ver2');
    }
  }
}
