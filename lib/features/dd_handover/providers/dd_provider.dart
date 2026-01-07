import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dd_record.dart';
import '../services/dd_service.dart';
import '../../checklist/providers/task_provider.dart';

/// Provider สำหรับ DD Service instance
final ddServiceProvider = Provider<DDService>((ref) {
  return DDService.instance;
});

/// Provider สำหรับ refresh counter (invalidate cache)
final ddRefreshCounterProvider = StateProvider<int>((ref) => 0);

/// Provider สำหรับดึง DD records ทั้งหมดของ user
final ddRecordsProvider = FutureProvider<List<DDRecord>>((ref) async {
  // Watch refresh counter to invalidate cache
  ref.watch(ddRefreshCounterProvider);
  // Watch user change counter to refresh when impersonating
  ref.watch(userChangeCounterProvider);

  final service = ref.read(ddServiceProvider);
  return service.getMyDDRecords(forceRefresh: true);
});

/// Provider สำหรับดึง DD records ที่ยังไม่ได้ทำ
final pendingDDRecordsProvider = FutureProvider<List<DDRecord>>((ref) async {
  final records = await ref.watch(ddRecordsProvider.future);
  return records.where((r) => !r.isCompleted).toList();
});

/// Provider สำหรับดึง DD records ที่ทำแล้ว
final completedDDRecordsProvider = FutureProvider<List<DDRecord>>((ref) async {
  final records = await ref.watch(ddRecordsProvider.future);
  return records.where((r) => r.isCompleted).toList();
});

/// Provider สำหรับจำนวน DD ที่ยังไม่ได้ทำ
final pendingDDCountProvider = FutureProvider<int>((ref) async {
  final records = await ref.watch(pendingDDRecordsProvider.future);
  return records.length;
});

/// Helper function: Refresh DD records
void refreshDDRecords(WidgetRef ref) {
  ref.read(ddServiceProvider).invalidateCache();
  ref.read(ddRefreshCounterProvider.notifier).state++;
}

/// Helper function: Invalidate และ refresh
void invalidateDDRecords(Ref ref) {
  ref.read(ddServiceProvider).invalidateCache();
  ref.invalidate(ddRecordsProvider);
}
