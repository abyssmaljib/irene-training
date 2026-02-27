import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_log.dart';
import '../services/task_service_v2.dart';
import 'task_provider.dart'; // สำหรับ shared providers (viewMode, selectedDate, etc.)

// ============================================================
// Provider V2 - ใช้ v3_task_logs_simplified view
// Logic เหมือน V1 เป๊ะ (task_provider.dart) ต่างแค่:
// - ใช้ TaskServiceV2 (query จาก v3_task_logs_simplified)
// - ชื่อ providers มี V2 ต่อท้าย
// ============================================================

/// Provider V2 สำหรับ TaskServiceV2
final taskServiceV2Provider = Provider<TaskServiceV2>((ref) {
  return TaskServiceV2.instance;
});

/// Provider V2 สำหรับ Tasks (query จาก v3_task_logs_simplified)
final tasksV2Provider = FutureProvider<List<TaskLog>>((ref) async {
  final date = ref.watch(selectedDateProvider);
  final nursinghomeId = await ref.watch(nursinghomeIdProvider.future);

  if (nursinghomeId == null) return [];

  final service = ref.watch(taskServiceV2Provider);
  return service.getTasksByDate(date, nursinghomeId);
});

/// Provider V2 สำหรับ refresh tasks (เพิ่ม counter เพื่อ trigger rebuild)
final taskRefreshCounterV2Provider = StateProvider<int>((ref) => 0);

/// Helper function to filter tasks by selected zones, residents, role, and task types
/// (เหมือน V1 เป๊ะ - copy logic จาก task_provider.dart)
/// selectedRoleId: null = แสดงทุก role, อื่นๆ = filter ตาม role นั้นเฉพาะ
List<TaskLog> _filterByZonesResidentsRoleAndType(
  List<TaskLog> tasks,
  Set<int> selectedZones,
  Set<int> selectedResidents,
  int? selectedRoleId,
  Set<String> selectedTaskTypes,
) {
  var filtered = tasks;

  // Filter out tasks that should be hidden (referred/home residents)
  // ✅ เหมือน V1 - สำคัญมาก! ถ้าไม่มีจะแสดง task ที่ไม่ควรแสดง
  filtered = filtered.where((t) => !t.shouldBeHidden).toList();

  // Filter by zones first
  if (selectedZones.isNotEmpty) {
    filtered = filtered
        .where((t) => t.zoneId != null && selectedZones.contains(t.zoneId))
        .toList();
  }

  // Then filter by residents (if any selected)
  if (selectedResidents.isNotEmpty) {
    filtered = filtered
        .where(
            (t) => t.residentId != null && selectedResidents.contains(t.residentId))
        .toList();
  }

  // Filter by role (only if selectedRoleId is specified)
  // selectedRoleId == null means show all roles (no filter)
  // ✅ เหมือน V1 - ไม่มี special case สำหรับ roleId=0
  if (selectedRoleId != null) {
    filtered = filtered
        .where((t) =>
            t.assignedRoleId == null || t.assignedRoleId == selectedRoleId)
        .toList();
  }

  // Filter by task types
  if (selectedTaskTypes.isNotEmpty) {
    filtered = filtered
        .where(
            (t) => t.taskType != null && selectedTaskTypes.contains(t.taskType))
        .toList();
  }

  return filtered;
}

/// Helper function สำหรับ merge optimistic updates กับ server data
/// ใช้ optimistic เฉพาะเมื่อ status ยังไม่ตรงกับ server
/// ถ้า status ตรงกันแล้ว = server sync เสร็จ → ใช้ server data
/// Returns: (mergedTasks, syncedLogIds) - logIds ที่ sync เสร็จแล้วสามารถ cleanup ได้
/// ✅ เหมือน V1 เป๊ะ - return type เป็น Set of int
(List<TaskLog>, Set<int>) _mergeOptimisticUpdatesWithCleanup(
  List<TaskLog> serverTasks,
  Map<int, TaskLog> optimisticUpdates,
) {
  if (optimisticUpdates.isEmpty) return (serverTasks, {});

  final syncedLogIds = <int>{};

  final merged = serverTasks.map((serverTask) {
    final optimistic = optimisticUpdates[serverTask.logId];
    if (optimistic == null) return serverTask;

    // Compare status: ถ้าตรงกัน = server sync เสร็จแล้ว → ใช้ server data
    // ถ้าไม่ตรง = server ยังไม่ sync → ใช้ optimistic ต่อไป
    if (serverTask.status == optimistic.status) {
      syncedLogIds.add(serverTask.logId); // mark สำหรับ cleanup
      return serverTask;
    }

    return optimistic;
  }).toList();

  return (merged, syncedLogIds);
}

/// Simple merge function (ไม่มี cleanup tracking)
List<TaskLog> _mergeOptimisticUpdates(
  List<TaskLog> serverTasks,
  Map<int, TaskLog> optimisticUpdates,
) {
  final (merged, _) =
      _mergeOptimisticUpdatesWithCleanup(serverTasks, optimisticUpdates);
  return merged;
}

/// Provider V2 สำหรับ filtered tasks ตาม view mode
/// ✅ เหมือน V1 เป๊ะ (filteredTasksProvider ใน task_provider.dart)
final filteredTasksV2Provider =
    Provider<AsyncValue<List<TaskLog>>>((ref) {
  // Watch refresh counter to enable manual refresh
  ref.watch(taskRefreshCounterV2Provider);

  final tasksAsync = ref.watch(tasksV2Provider);
  final optimisticUpdates = ref.watch(optimisticTaskUpdatesProvider);
  final viewMode = ref.watch(taskViewModeProvider);
  final shiftAsync = ref.watch(userShiftProvider);
  final userId = ref.watch(currentUserIdProvider);
  final service = ref.watch(taskServiceV2Provider);
  final selectedZones = ref.watch(selectedZonesFilterProvider);
  final selectedResidents = ref.watch(selectedResidentsFilterProvider);
  final selectedRoleId = ref.watch(effectiveRoleFilterProvider);
  final selectedTaskTypes = ref.watch(selectedTaskTypesFilterProvider);

  return tasksAsync.when(
    data: (tasks) {
      // รวม optimistic updates เข้ากับ tasks (ใช้ smart merge)
      final mergedTasks = _mergeOptimisticUpdates(tasks, optimisticUpdates);

      final shift = shiftAsync.valueOrNull;

      // Apply zone, resident, role, and task type filter
      final filteredTasks = _filterByZonesResidentsRoleAndType(
          mergedTasks,
          selectedZones,
          selectedResidents,
          selectedRoleId,
          selectedTaskTypes);

      switch (viewMode) {
        case TaskViewMode.upcoming:
          return AsyncValue.data(
              service.getUpcomingTasks(filteredTasks, shift));
        case TaskViewMode.all:
          return AsyncValue.data(filteredTasks);
        case TaskViewMode.problem:
          return AsyncValue.data(service.getProblemTasks(filteredTasks));
        case TaskViewMode.myDone:
          if (userId == null) return const AsyncValue.data([]);
          return AsyncValue.data(
              service.getMyCompletedTasks(filteredTasks, userId));
      }
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Provider V2 สำหรับ grouped tasks by timeBlock (สำหรับ view mode = all)
/// ✅ เหมือน V1 เป๊ะ (groupedTasksProvider ใน task_provider.dart)
/// V1 ใช้ raw tasks แล้ว filter ภายใน → V2 ทำเหมือนกัน
final groupedTasksV2Provider =
    Provider<AsyncValue<Map<String, List<TaskLog>>>>((ref) {
  final tasksAsync = ref.watch(tasksV2Provider);
  final optimisticUpdates = ref.watch(optimisticTaskUpdatesProvider);
  final service = ref.watch(taskServiceV2Provider);
  final selectedZones = ref.watch(selectedZonesFilterProvider);
  final selectedResidents = ref.watch(selectedResidentsFilterProvider);
  final selectedRoleId = ref.watch(effectiveRoleFilterProvider);
  final selectedTaskTypes = ref.watch(selectedTaskTypesFilterProvider);

  return tasksAsync.when(
    data: (tasks) {
      // รวม optimistic updates เข้ากับ tasks (ใช้ smart merge)
      final mergedTasks = _mergeOptimisticUpdates(tasks, optimisticUpdates);

      // Apply zone, resident, role, and task type filter
      final filteredTasks = _filterByZonesResidentsRoleAndType(
          mergedTasks,
          selectedZones,
          selectedResidents,
          selectedRoleId,
          selectedTaskTypes);
      return AsyncValue.data(service.groupTasksByTimeBlock(filteredTasks));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Provider V2 สำหรับ batch grouped tasks (เหมือน batchGroupedTasksProvider แต่ใช้ V2 data)
/// transform groupedTasksV2Provider เป็น mixed list ของ BatchTaskGroup + single TaskLog
final batchGroupedTasksV2Provider =
    Provider<AsyncValue<Map<String, List<BatchMixedItem>>>>((ref) {
  final groupedAsync = ref.watch(groupedTasksV2Provider);

  return groupedAsync.when(
    data: (grouped) {
      final Map<String, List<BatchMixedItem>> result = {};

      for (final entry in grouped.entries) {
        final timeBlock = entry.key;
        final tasks = entry.value;

        // group tasks ที่มี title+zone+timeBlock เดียวกัน
        final batchGroups = groupBatchTasks(tasks);

        // หา tasks ที่ไม่เข้า group (คนไข้เดียวใน key นั้น)
        final groupedTaskIds = <int>{};
        for (final group in batchGroups.values) {
          for (final t in group.tasks) {
            groupedTaskIds.add(t.logId);
          }
        }

        final List<BatchMixedItem> items = [];

        // เพิ่ม batch groups ก่อน (เรียง title)
        final sortedGroups = batchGroups.values.toList()
          ..sort((a, b) => a.title.compareTo(b.title));
        for (final group in sortedGroups) {
          items.add(BatchMixedItem.batch(group));
        }

        // เพิ่ม singles ตามหลัง (เรียงตาม order เดิม)
        for (final task in tasks) {
          if (!groupedTaskIds.contains(task.logId)) {
            items.add(BatchMixedItem.single(task));
          }
        }

        result[timeBlock] = items;
      }

      return AsyncValue.data(result);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Provider V2 สำหรับ task counts per view mode
/// ✅ เหมือน V1 เป๊ะ (taskCountsProvider ใน task_provider.dart)
final taskCountsV2Provider = Provider<Map<TaskViewMode, int>>((ref) {
  final tasksAsync = ref.watch(tasksV2Provider);
  final optimisticUpdates = ref.watch(optimisticTaskUpdatesProvider);
  final shiftAsync = ref.watch(userShiftProvider);
  final userId = ref.watch(currentUserIdProvider);
  final service = ref.watch(taskServiceV2Provider);
  final selectedZones = ref.watch(selectedZonesFilterProvider);
  final selectedResidents = ref.watch(selectedResidentsFilterProvider);
  final selectedRoleId = ref.watch(effectiveRoleFilterProvider);
  final selectedTaskTypes = ref.watch(selectedTaskTypesFilterProvider);

  if (!tasksAsync.hasValue) return {};

  final allTasks = tasksAsync.value!;

  // รวม optimistic updates เข้ากับ tasks (ใช้ smart merge)
  final mergedTasks = _mergeOptimisticUpdates(allTasks, optimisticUpdates);

  // Apply zone, resident, role, and task type filter
  final tasks = _filterByZonesResidentsRoleAndType(
      mergedTasks,
      selectedZones,
      selectedResidents,
      selectedRoleId,
      selectedTaskTypes);
  final shift = shiftAsync.valueOrNull;

  return {
    TaskViewMode.upcoming: service.getUpcomingTasks(tasks, shift).length,
    TaskViewMode.all: tasks.length,
    TaskViewMode.problem: service.getProblemTasks(tasks).length,
    TaskViewMode.myDone:
        userId != null ? service.getMyCompletedTasks(tasks, userId).length : 0,
  };
});

// ============================================================
// Pending Tasks Count Providers (งานค้างใน 2 ชม. ข้างหน้า)
// ✅ เหมือน V1 เป๊ะ
// ============================================================

/// Helper function to count pending tasks in next 2 hours
/// ✅ เหมือน V1 เป๊ะ (_getPendingTasksInNext2Hours ใน task_provider.dart)
List<TaskLog> _getPendingTasksInNext2Hours(List<TaskLog> tasks) {
  final now = DateTime.now();
  final twoHoursLater = now.add(const Duration(hours: 2));

  return tasks.where((task) {
    // Skip hidden tasks (referred/home residents, empty taskType)
    if (task.shouldBeHidden) return false;

    // Only pending tasks (not done, not problem)
    if (task.isDone || task.isProblem) return false;

    // Within next 2 hours
    if (task.expectedDateTime == null) return false;
    return task.expectedDateTime!
                .isAfter(now.subtract(const Duration(minutes: 1))) &&
        task.expectedDateTime!.isBefore(twoHoursLater);
  }).toList();
}

/// Provider V2 สำหรับจำนวนงานค้างของ role ตัวเอง (ใน 2 ชม. ข้างหน้า)
/// ใช้แสดง badge ที่ icon filter - ไม่ขึ้นกับ role ที่เลือกในตัวกรอง
/// ✅ เหมือน V1 เป๊ะ (myRolePendingTasksCountProvider ใน task_provider.dart)
final myRolePendingTasksCountV2Provider = Provider<int>((ref) {
  final tasksAsync = ref.watch(tasksV2Provider);
  final userRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;

  if (!tasksAsync.hasValue) return 0;

  var tasks = tasksAsync.value!;

  // Filter เฉพาะงานของ role ตัวเอง + งานที่ไม่ระบุ role
  if (userRole != null) {
    tasks = tasks
        .where(
            (t) => t.assignedRoleId == null || t.assignedRoleId == userRole.id)
        .toList();
  }

  return _getPendingTasksInNext2Hours(tasks).length;
});

/// ✨ Refresh tasks V2 - ใช้กับ ChecklistScreenV2
/// ✅ เหมือน refreshTasksWithContainer ใน V1
void refreshTasksWithContainerV2(ProviderContainer container) {
  TaskServiceV2.instance.invalidateCache();
  container.read(taskRefreshCounterV2Provider.notifier).state++;
  container.invalidate(tasksV2Provider);
  container.invalidate(userShiftProvider);
}