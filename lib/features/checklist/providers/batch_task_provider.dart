import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../points/services/points_service.dart';
import '../models/measurement_config.dart';
import '../models/task_log.dart';
import '../services/measurement_service.dart';
import '../widgets/measurement_input_dialog.dart';
import 'task_provider.dart';
import '../../../core/services/retry_queue_service.dart';

// ============================================================
// Co-Workers Provider — ดึงรายชื่อเพื่อนร่วมเวร
// ============================================================

/// Provider ดึงรายชื่อเพื่อนร่วมเวร (คนที่ clock-in เวรเดียวกัน ยังไม่ clock-out)
/// ใช้สำหรับ co-worker picker ใน BatchTaskScreen
final coWorkersProvider = FutureProvider.autoDispose<List<CoWorker>>((ref) async {
  final clockService = ref.watch(clockServiceProvider);
  final rawList = await clockService.getCoWorkersInCurrentShift();

  // แปลง raw Map เป็น CoWorker model
  return rawList.map((row) {
    // user_info มาจาก Supabase FK join — อาจเป็น Map หรือ null
    final userInfo = row['user_info'] as Map<String, dynamic>?;
    return CoWorker(
      userId: row['user_id'] as String? ?? '',
      nickname: userInfo?['nickname'] as String? ?? 'ไม่ทราบชื่อ',
      photoUrl: userInfo?['photo_url'] as String?,
    );
  }).where((cw) => cw.userId.isNotEmpty).toList();
});

// ============================================================
// Batch Task Provider — State Management สำหรับ BatchTaskScreen
// ============================================================

/// สถานะของ task แต่ละคนไข้ใน batch
enum BatchResidentStatus {
  pending, // ยังไม่ทำ
  completing, // กำลัง upload/complete
  completed, // เสร็จแล้ว
  failed, // เกิดข้อผิดพลาด
}

/// State สำหรับ task ของคนไข้แต่ละคนใน batch
class BatchResidentState {
  /// TaskLog ของคนไข้คนนี้
  final TaskLog task;

  /// สถานะปัจจุบัน
  final BatchResidentStatus status;

  /// URL รูปที่ upload แล้ว (ใช้แสดง thumbnail)
  final String? uploadedImageUrl;

  /// ชื่อคนที่ complete งานนี้
  final String? completedByNickname;

  /// error message ถ้า failed
  final String? errorMessage;

  const BatchResidentState({
    required this.task,
    this.status = BatchResidentStatus.pending,
    this.uploadedImageUrl,
    this.completedByNickname,
    this.errorMessage,
  });

  /// สร้าง state ใหม่จาก task ที่มี status แล้ว
  /// ถ้า task.status != null (complete/problem/refer/postpone) → ถือว่า "จัดการแล้ว"
  /// แสดงเป็น completed ใน batch เพื่อให้ progress นับรวม
  factory BatchResidentState.fromTask(TaskLog task) {
    if (task.status != null) {
      return BatchResidentState(
        task: task,
        status: BatchResidentStatus.completed,
        uploadedImageUrl: task.confirmImage,
        completedByNickname: task.completedByNickname,
      );
    }
    return BatchResidentState(task: task);
  }

  BatchResidentState copyWith({
    TaskLog? task,
    BatchResidentStatus? status,
    String? uploadedImageUrl,
    String? completedByNickname,
    String? errorMessage,
  }) {
    return BatchResidentState(
      task: task ?? this.task,
      status: status ?? this.status,
      uploadedImageUrl: uploadedImageUrl ?? this.uploadedImageUrl,
      completedByNickname: completedByNickname ?? this.completedByNickname,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// ข้อมูลเพื่อนร่วมเวร (co-worker)
class CoWorker {
  final String userId;
  final String nickname;
  final String? photoUrl;

  const CoWorker({
    required this.userId,
    required this.nickname,
    this.photoUrl,
  });
}

/// State รวมของ batch ทั้งหมด
class BatchState {
  /// รายชื่อคนไข้ทั้งหมดใน batch (พร้อมสถานะ)
  final List<BatchResidentState> residents;

  /// เพื่อนร่วมเวรที่เลือก (สำหรับหาร point)
  final List<CoWorker> selectedCoWorkers;

  /// ชื่อ task (เช่น "พลิกตัว")
  final String taskTitle;

  /// ชื่อโซน
  final String zoneName;

  /// รูปตัวอย่างจาก template (ถ้ามี)
  final String? sampleImageUrl;

  const BatchState({
    required this.residents,
    this.selectedCoWorkers = const [],
    required this.taskTitle,
    required this.zoneName,
    this.sampleImageUrl,
  });

  /// จำนวนคนไข้ที่ complete แล้ว
  int get completedCount =>
      residents.where((r) => r.status == BatchResidentStatus.completed).length;

  /// จำนวนคนไข้ทั้งหมด
  int get totalCount => residents.length;

  /// เปอร์เซ็นต์ความคืบหน้า
  double get progress =>
      totalCount > 0 ? completedCount / totalCount : 0.0;

  BatchState copyWith({
    List<BatchResidentState>? residents,
    List<CoWorker>? selectedCoWorkers,
    String? taskTitle,
    String? zoneName,
    String? sampleImageUrl,
  }) {
    return BatchState(
      residents: residents ?? this.residents,
      selectedCoWorkers: selectedCoWorkers ?? this.selectedCoWorkers,
      taskTitle: taskTitle ?? this.taskTitle,
      zoneName: zoneName ?? this.zoneName,
      sampleImageUrl: sampleImageUrl ?? this.sampleImageUrl,
    );
  }
}

/// StateNotifier สำหรับจัดการ batch task
/// แต่ละ instance จัดการ 1 batch (1 group ของ tasks ที่มี title+zone+timeBlock เดียวกัน)
class BatchTaskNotifier extends StateNotifier<BatchState> {
  final Ref _ref;

  BatchTaskNotifier(this._ref, BatchState initialState) : super(initialState);

  /// เพิ่มเพื่อนร่วมเวร
  void addCoWorker(CoWorker coWorker) {
    // ป้องกันเพิ่มซ้ำ
    if (state.selectedCoWorkers.any((c) => c.userId == coWorker.userId)) return;
    state = state.copyWith(
      selectedCoWorkers: [...state.selectedCoWorkers, coWorker],
    );
  }

  /// ลบเพื่อนร่วมเวร
  void removeCoWorker(String userId) {
    state = state.copyWith(
      selectedCoWorkers:
          state.selectedCoWorkers.where((c) => c.userId != userId).toList(),
    );
  }

  /// Upload รูป + mark complete สำหรับคนไข้ 1 คน
  /// เรียกหลังจาก user ถ่ายรูป + preview + rate difficulty เสร็จแล้ว
  ///
  /// ใช้ logId (unique task log ID) แทน array index เพื่อป้องกัน
  /// race condition: ระหว่างที่ user ถ่ายรูป (async หลายวินาที)
  /// ลำดับ residents อาจเปลี่ยนเมื่อ provider rebuild จาก realtime update
  /// ถ้าใช้ index → อาจ complete task ผิดคน!
  ///
  /// Flow:
  /// 1. ค้นหา resident ด้วย logId (ไม่ใช่ index)
  /// 2. อัพเดต status → completing
  /// 3. Upload รูปไป Supabase Storage
  /// 4. เรียก markTaskComplete()
  /// 5. อัพเดต status → completed (พร้อม thumbnail + ชื่อคน)
  /// 6. สร้าง optimistic update ใน provider
  Future<bool> completeResident({
    required int taskLogId,
    required File imageFile,
    required int? difficultyScore,
    MeasurementResult? measurementResult,
    MeasurementConfig? measurementConfig,
  }) async {
    // ค้นหา resident ด้วย logId แทน array index
    // ป้องกัน bug: ลำดับ residents เปลี่ยนระหว่าง async flow (ถ่ายรูป/preview/rating)
    final resident = state.residents.where(
      (r) => r.task.logId == taskLogId,
    ).firstOrNull;
    if (resident == null) {
      debugPrint('⚠️ completeResident: logId=$taskLogId not found in state');
      return false;
    }
    final task = resident.task;
    final userId = _ref.read(currentUserIdProvider);
    final userNickname = _ref.read(currentUserNicknameProvider).valueOrNull;

    if (userId == null) return false;

    // 1. อัพเดต status → completing
    _updateResidentByLogId(task.logId, resident.copyWith(
      status: BatchResidentStatus.completing,
    ));

    try {
      // 2. Upload รูปไป Supabase Storage
      final storagePath =
          'task_confirms/${task.logId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await imageFile.readAsBytes();

      await Supabase.instance.client.storage
          .from('med-photos')
          .uploadBinary(storagePath, bytes);

      final imageUrl = Supabase.instance.client.storage
          .from('med-photos')
          .getPublicUrl(storagePath);

      // 3. Mark task complete (ผ่าน TaskService เดิม)
      // ถ้ามี co-workers → skip points recording เพื่อให้ batch จัดการหาร point เอง
      final hasCoWorkers = state.selectedCoWorkers.isNotEmpty;
      final service = _ref.read(taskServiceProvider);
      final success = await service.markTaskComplete(
        task.logId,
        userId,
        imageUrl: imageUrl,
        difficultyScore: difficultyScore,
        difficultyRatedBy: userId,
        skipPointsRecording: hasCoWorkers,
      );

      if (!success) throw Exception('markTaskComplete failed');

      // 4. สร้าง optimistic update ให้ checklist screen เห็นทันที
      // ใช้ _ref.read() โดยตรงเพราะ optimisticUpdateTask รับ WidgetRef
      final optimisticTask = task.copyWith(
        status: 'complete',
        completedByUid: userId,
        completedByNickname: userNickname,
        completedAt: DateTime.now(),
        confirmImage: imageUrl,
        difficultyScore: difficultyScore ?? 5,
        difficultyRatedBy: userId,
        difficultyRaterNickname: userNickname,
      );
      final updates = _ref.read(optimisticTaskUpdatesProvider);
      _ref.read(optimisticTaskUpdatesProvider.notifier).state = {
        ...updates,
        optimisticTask.logId: optimisticTask,
      };
      _ref.read(taskRefreshCounterProvider.notifier).state++;

      // 5. อัพเดต status → completed (ใช้ logId ค้นหาใหม่ ปลอดภัยจาก race condition)
      _updateResidentByLogId(task.logId, resident.copyWith(
        status: BatchResidentStatus.completed,
        uploadedImageUrl: imageUrl,
        completedByNickname: userNickname ?? 'ฉัน',
      ));

      // 6. บันทึก point แบบหาร (ถ้ามี co-workers)
      // ถ้าไม่มี co-workers → points ถูก record ใน markTaskComplete() แล้ว
      if (hasCoWorkers) {
        try {
          final coWorkerIds =
              state.selectedCoWorkers.map((c) => c.userId).toList();
          await PointsService().recordBatchTaskCompleted(
            completingUserId: userId,
            taskLogId: task.logId,
            taskName: task.title ?? 'งาน',
            residentName: task.residentName ?? 'คนไข้',
            coWorkerIds: coWorkerIds,
            difficultyScore: difficultyScore,
          );
        } catch (e) {
          // ไม่ให้ error จาก points กระทบ task completion
          // เก็บใน retry queue แล้ว sync ทีหลัง (ไม่หายเงียบ)
          debugPrint('Batch points error, queuing for retry: $e');
          final coWorkerIds =
              state.selectedCoWorkers.map((c) => c.userId).toList();
          await RetryQueueService.instance.enqueueBatchPoints(
            completingUserId: userId,
            taskLogId: task.logId,
            taskName: task.title ?? 'งาน',
            residentName: task.residentName ?? 'คนไข้',
            coWorkerIds: coWorkerIds,
            difficultyScore: difficultyScore,
          );
        }
      }

      // 7. บันทึกค่า measurement (ถ้าเป็น measurement task)
      if (measurementResult != null &&
          measurementConfig != null &&
          task.residentId != null) {
        final nursinghomeId =
            await _ref.read(nursinghomeIdProvider.future) ?? 0;
        final measSuccess =
            await MeasurementService.instance.insertMeasurement(
          residentId: task.residentId!,
          nursinghomeId: nursinghomeId,
          recordedBy: userId,
          measurementType: measurementConfig.measurementType,
          numericValue: measurementResult.value,
          unit: measurementConfig.unit,
          taskLogId: task.logId,
          photoUrl: measurementResult.photoUrl,
        );
        if (!measSuccess) {
          // Measurement fail → revert task กลับ pending บน server
          await service.unmarkTask(task.logId);
          // ลบ optimistic update ที่สร้างไว้ตอน step 4 ด้วย
          // ไม่งั้นหน้า checklist จะยังแสดง task เป็น "complete" ทั้งที่ server เป็น pending
          final currentUpdates = _ref.read(optimisticTaskUpdatesProvider);
          if (currentUpdates.containsKey(task.logId)) {
            final cleaned = Map<int, TaskLog>.of(currentUpdates)
              ..remove(task.logId);
            _ref.read(optimisticTaskUpdatesProvider.notifier).state = cleaned;
            _ref.read(taskRefreshCounterProvider.notifier).state++;
          }
          throw Exception('insertMeasurement failed');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Batch complete error: $e');
      // Rollback status (ใช้ logId ค้นหาใหม่ ปลอดภัยจาก race condition)
      _updateResidentByLogId(task.logId, resident.copyWith(
        status: BatchResidentStatus.failed,
        errorMessage: 'เกิดข้อผิดพลาด กรุณาลองใหม่',
      ));
      return false;
    }
  }

  /// อัพเดต state ของ resident ด้วย logId (ปลอดภัยจาก race condition)
  /// ค้นหา index ใหม่ทุกครั้งเพื่อป้องกันกรณีที่ลำดับ residents เปลี่ยน
  void _updateResidentByLogId(int logId, BatchResidentState newState) {
    final index = state.residents.indexWhere((r) => r.task.logId == logId);
    if (index == -1) return; // resident ถูกลบออกไปแล้ว
    final updated = [...state.residents];
    updated[index] = newState;
    state = state.copyWith(residents: updated);
  }

  /// Reset status ของ resident ที่ failed กลับเป็น pending (ลองใหม่ได้)
  /// ใช้ logId แทน index เพื่อป้องกัน race condition เดียวกับ completeResident
  void retryResident(int taskLogId) {
    final index = state.residents.indexWhere(
      (r) => r.task.logId == taskLogId,
    );
    if (index == -1) return;
    _updateResidentByLogId(taskLogId, state.residents[index].copyWith(
      status: BatchResidentStatus.pending,
      errorMessage: null,
    ));
  }
}

/// Provider สำหรับ BatchTaskNotifier
/// ใช้ family parameter = groupKey เพื่อให้แต่ละ batch มี state แยกกัน
/// autoDispose เมื่อออกจากหน้า BatchTaskScreen
///
/// ใช้ ref.read (ไม่ใช่ ref.watch) เพื่อป้องกัน provider rebuild ระหว่าง async flow:
/// ถ้าใช้ watch → realtime update จะ trigger rebuild → สร้าง notifier ใหม่
/// → old notifier ที่กำลังทำ completeResident() ถูก dispose → state หาย
/// pull-to-refresh ยังทำงานได้ปกติ เพราะใช้ ref.invalidate() ตรงๆ
final batchTaskProvider = StateNotifierProvider.autoDispose
    .family<BatchTaskNotifier, BatchState, String>((ref, groupKey) {
  // ดึง batch group จาก batchGroupedTasksProvider
  // ใช้ ref.read แทน ref.watch เพื่อไม่ให้ provider rebuild อัตโนมัติจาก realtime
  final batchGroupedAsync = ref.read(batchGroupedTasksProvider);
  final batchData = batchGroupedAsync.valueOrNull;

  List<TaskLog> tasks = [];
  String title = '';
  String zoneName = '';
  String? sampleImageUrl;

  if (batchData != null) {
    // ค้นหาใน ทุก timeBlock
    for (final items in batchData.values) {
      for (final item in items) {
        if (item.isBatch && item.batchGroup!.groupKey == groupKey) {
          tasks = item.batchGroup!.tasks;
          title = item.batchGroup!.title;
          zoneName = item.batchGroup!.zoneName;
          sampleImageUrl = item.batchGroup!.sampleImageUrl;
          break;
        }
      }
      if (tasks.isNotEmpty) break;
    }
  }

  return BatchTaskNotifier(
    ref,
    BatchState(
      taskTitle: title,
      zoneName: zoneName,
      sampleImageUrl: sampleImageUrl,
      // สร้าง resident state จาก tasks (แสดง status ที่ถูกต้องสำหรับ task ที่ complete ไปแล้ว)
      residents: tasks.map((t) => BatchResidentState.fromTask(t)).toList(),
    ),
  );
});
