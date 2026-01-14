import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../../home/models/zone.dart';
import '../../home/models/clock_in_out.dart';
import '../../home/services/zone_service.dart';
import '../../home/services/clock_service.dart';
import '../models/resident_simple.dart';
import '../models/system_role.dart';
import '../models/task_log.dart';
import '../models/user_shift.dart';
import '../services/task_realtime_service.dart';
import '../services/task_service.dart';

/// Provider สำหรับ TaskRealtimeService
final taskRealtimeServiceProvider = Provider<TaskRealtimeService>((ref) {
  return TaskRealtimeService.instance;
});

/// View mode สำหรับหน้า Checklist
enum TaskViewMode {
  upcoming, // งานถัดไป (2 ชม. ข้างหน้า + filtered by my zones/residents)
  all, // ทั้งหมด (grouped by timeBlock)
  problem, // ติดปัญหา
  myDone, // ที่เราติ๊ก
}

extension TaskViewModeExtension on TaskViewMode {
  String get label {
    switch (this) {
      case TaskViewMode.upcoming:
        return 'งานถัดไป';
      case TaskViewMode.all:
        return 'ทั้งหมด';
      case TaskViewMode.problem:
        return 'ติดปัญหา';
      case TaskViewMode.myDone:
        return 'ที่เราติ๊ก';
    }
  }

  String get description {
    switch (this) {
      case TaskViewMode.upcoming:
        return 'งานภายใน 2 ชม. ที่อยู่ในความดูแลของคุณ';
      case TaskViewMode.all:
        return 'งานทั้งหมดของวัน แบ่งตามช่วงเวลา';
      case TaskViewMode.problem:
        return 'งานที่รายงานว่ามีปัญหา';
      case TaskViewMode.myDone:
        return 'งานที่คุณทำเสร็จแล้ว';
    }
  }
}

/// Provider สำหรับ TaskService
final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService.instance;
});

/// Provider สำหรับ UserService
final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

/// Provider that tracks user changes (for dev mode impersonation)
/// Increment this to force rebuild of user-dependent providers
final userChangeCounterProvider = StateProvider<int>((ref) => 0);

/// Provider สำหรับ current user ID (uses effectiveUserId for dev mode)
final currentUserIdProvider = Provider<String?>((ref) {
  // Watch the counter to rebuild when user changes
  ref.watch(userChangeCounterProvider);
  return UserService().effectiveUserId;
});

/// Provider สำหรับ current user nickname
/// ใช้สำหรับ Optimistic Update เพื่อแสดงชื่อผู้ทำงานทันที
final currentUserNicknameProvider = FutureProvider<String?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  try {
    final response = await Supabase.instance.client
        .from('user_info')
        .select('nickname')
        .eq('id', userId)
        .maybeSingle();
    return response?['nickname'] as String?;
  } catch (e) {
    return null;
  }
});

/// Provider สำหรับ nursinghome ID
final nursinghomeIdProvider = FutureProvider<int?>((ref) async {
  final userService = ref.watch(userServiceProvider);
  return userService.getNursinghomeId();
});

/// คำนวณ "วันทำงาน" ตามรอบของแอพ (07:00-06:59 วันถัดไป)
/// ถ้าเวลา 00:00-06:59 ให้ใช้วันเมื่อวาน
DateTime getWorkingDate([DateTime? dateTime]) {
  final now = dateTime ?? DateTime.now();
  // ถ้าเวลาก่อน 07:00 น. ให้ใช้วันเมื่อวาน
  if (now.hour < 7) {
    return DateTime(now.year, now.month, now.day - 1);
  }
  return DateTime(now.year, now.month, now.day);
}

/// Provider สำหรับ selected date (default = working date)
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return getWorkingDate();
});

/// Provider สำหรับ view mode
final taskViewModeProvider = StateProvider<TaskViewMode>((ref) {
  return TaskViewMode.upcoming; // default: งานถัดไป
});

/// Provider สำหรับ user shift (zones/residents filter จากการขึ้นเวร)
final userShiftProvider = FutureProvider<UserShift?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final nursinghomeId = await ref.watch(nursinghomeIdProvider.future);

  if (userId == null || nursinghomeId == null) return null;

  final service = ref.watch(taskServiceProvider);
  return service.getCurrentUserShift(userId, nursinghomeId);
});

/// Provider สำหรับ tasks ทั้งหมดของวันที่เลือก
final tasksProvider = FutureProvider<List<TaskLog>>((ref) async {
  final date = ref.watch(selectedDateProvider);
  final nursinghomeId = await ref.watch(nursinghomeIdProvider.future);

  if (nursinghomeId == null) return [];

  final service = ref.watch(taskServiceProvider);
  return service.getTasksByDate(date, nursinghomeId);
});

/// Provider สำหรับ refresh tasks (เพิ่ม counter เพื่อ trigger rebuild)
final taskRefreshCounterProvider = StateProvider<int>((ref) => 0);

/// Helper function to filter tasks by selected zones, residents, role, and task types
/// selectedRoleId: null = แสดงทุก role, อื่นๆ = filter ตาม role นั้นเฉพาะ
List<TaskLog> _filterByZonesResidentsRoleAndType(
  List<TaskLog> tasks,
  Set<int> selectedZones,
  Set<int> selectedResidents,
  SystemRole? userRole,
  int? selectedRoleId,
  Set<String> selectedTaskTypes,
) {
  var filtered = tasks;

  // Filter out tasks that should be hidden (referred/home residents)
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
        .where((t) => t.residentId != null && selectedResidents.contains(t.residentId))
        .toList();
  }

  // Filter by role (only if selectedRoleId is specified)
  // selectedRoleId == null means show all roles (no filter)
  if (selectedRoleId != null) {
    filtered = filtered
        .where((t) => t.assignedRoleId == null || t.assignedRoleId == selectedRoleId)
        .toList();
  }

  // Filter by task types
  if (selectedTaskTypes.isNotEmpty) {
    filtered = filtered
        .where((t) => t.taskType != null && selectedTaskTypes.contains(t.taskType))
        .toList();
  }

  return filtered;
}

/// Provider สำหรับ filtered tasks ตาม view mode
/// ใช้ optimistic updates เพื่อให้ UI ตอบสนองทันที
final filteredTasksProvider = Provider<AsyncValue<List<TaskLog>>>((ref) {
  // Watch refresh counter to enable manual refresh
  ref.watch(taskRefreshCounterProvider);

  final tasksAsync = ref.watch(tasksProvider);
  final optimisticUpdates = ref.watch(optimisticTaskUpdatesProvider);
  final viewMode = ref.watch(taskViewModeProvider);
  final shiftAsync = ref.watch(userShiftProvider);
  final userId = ref.watch(currentUserIdProvider);
  final service = ref.watch(taskServiceProvider);
  final selectedZones = ref.watch(selectedZonesFilterProvider);
  final selectedResidents = ref.watch(selectedResidentsFilterProvider);
  final selectedRoleId = ref.watch(effectiveRoleFilterProvider);
  final userRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;
  final selectedTaskTypes = ref.watch(selectedTaskTypesFilterProvider);

  return tasksAsync.when(
    data: (tasks) {
      // รวม optimistic updates เข้ากับ tasks
      final mergedTasks = optimisticUpdates.isEmpty
          ? tasks
          : tasks.map((task) => optimisticUpdates[task.logId] ?? task).toList();

      final shift = shiftAsync.valueOrNull;

      // Apply zone, resident, role, and task type filter
      final filteredTasks = _filterByZonesResidentsRoleAndType(
        mergedTasks, selectedZones, selectedResidents, userRole, selectedRoleId, selectedTaskTypes);

      switch (viewMode) {
        case TaskViewMode.upcoming:
          return AsyncValue.data(service.getUpcomingTasks(filteredTasks, shift));
        case TaskViewMode.all:
          return AsyncValue.data(filteredTasks);
        case TaskViewMode.problem:
          return AsyncValue.data(service.getProblemTasks(filteredTasks));
        case TaskViewMode.myDone:
          if (userId == null) return const AsyncValue.data([]);
          return AsyncValue.data(service.getMyCompletedTasks(filteredTasks, userId));
      }
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Provider สำหรับ grouped tasks by timeBlock (สำหรับ view mode = all)
/// ใช้ optimistic updates เพื่อให้ UI ตอบสนองทันที
final groupedTasksProvider =
    Provider<AsyncValue<Map<String, List<TaskLog>>>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final optimisticUpdates = ref.watch(optimisticTaskUpdatesProvider);
  final service = ref.watch(taskServiceProvider);
  final selectedZones = ref.watch(selectedZonesFilterProvider);
  final selectedResidents = ref.watch(selectedResidentsFilterProvider);
  final selectedRoleId = ref.watch(effectiveRoleFilterProvider);
  final userRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;
  final selectedTaskTypes = ref.watch(selectedTaskTypesFilterProvider);

  return tasksAsync.when(
    data: (tasks) {
      // รวม optimistic updates เข้ากับ tasks
      final mergedTasks = optimisticUpdates.isEmpty
          ? tasks
          : tasks.map((task) => optimisticUpdates[task.logId] ?? task).toList();

      // Apply zone, resident, role, and task type filter
      final filteredTasks = _filterByZonesResidentsRoleAndType(
        mergedTasks, selectedZones, selectedResidents, userRole, selectedRoleId, selectedTaskTypes);
      return AsyncValue.data(service.groupTasksByTimeBlock(filteredTasks));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Provider สำหรับ task counts per view mode
/// ใช้ optimistic updates เพื่อให้ count อัพเดตทันที
final taskCountsProvider = Provider<Map<TaskViewMode, int>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final optimisticUpdates = ref.watch(optimisticTaskUpdatesProvider);
  final shiftAsync = ref.watch(userShiftProvider);
  final userId = ref.watch(currentUserIdProvider);
  final service = ref.watch(taskServiceProvider);
  final selectedZones = ref.watch(selectedZonesFilterProvider);
  final selectedResidents = ref.watch(selectedResidentsFilterProvider);
  final selectedRoleId = ref.watch(effectiveRoleFilterProvider);
  final userRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;
  final selectedTaskTypes = ref.watch(selectedTaskTypesFilterProvider);

  if (!tasksAsync.hasValue) return {};

  final allTasks = tasksAsync.value!;

  // รวม optimistic updates เข้ากับ tasks
  final mergedTasks = optimisticUpdates.isEmpty
      ? allTasks
      : allTasks.map((task) => optimisticUpdates[task.logId] ?? task).toList();

  // Apply zone, resident, role, and task type filter
  final tasks = _filterByZonesResidentsRoleAndType(
    mergedTasks, selectedZones, selectedResidents, userRole, selectedRoleId, selectedTaskTypes);
  final shift = shiftAsync.valueOrNull;

  return {
    TaskViewMode.upcoming: service.getUpcomingTasks(tasks, shift).length,
    TaskViewMode.all: tasks.length,
    TaskViewMode.problem: service.getProblemTasks(tasks).length,
    TaskViewMode.myDone:
        userId != null ? service.getMyCompletedTasks(tasks, userId).length : 0,
  };
});

/// Provider สำหรับ selected zones filter (สำหรับ UI filter chips)
/// ถ้า empty = แสดงทุก zone, ถ้ามีค่า = filter เฉพาะ zones ที่เลือก
final selectedZonesFilterProvider = StateProvider<Set<int>>((ref) {
  return {}; // default: แสดงทุก zone
});

// ============================================================
// Role Filter Providers
// ============================================================

/// Provider สำหรับ current user's system role
final currentUserSystemRoleProvider = FutureProvider<SystemRole?>((ref) async {
  final userService = ref.watch(userServiceProvider);
  return userService.getSystemRole();
});

/// Provider สำหรับ all available system roles (สำหรับ filter dropdown)
final allSystemRolesProvider = FutureProvider<List<SystemRole>>((ref) async {
  final userService = ref.watch(userServiceProvider);
  return userService.getAllSystemRoles();
});

/// Provider สำหรับ selected role filter
/// null = ยังไม่ได้ตั้งค่า (จะใช้ role ของ user เป็น default)
/// -1 = ดูทุก role
/// อื่นๆ = filter ตาม role_id นั้น
final selectedRoleFilterProvider = StateProvider<int?>((ref) {
  return null; // default: จะใช้ role ของ user
});

/// Provider สำหรับ effective role filter (รวม default logic)
/// null = ใช้ role ของ user เป็น default (NA เห็นงาน NA, หัวหน้าเวรเห็นงานหัวหน้าเวร)
/// -1 = ดูทุก role (ไม่ filter) - ต้องเลือกเองใน filter
/// อื่นๆ = filter ตาม role_id ที่เลือก
final effectiveRoleFilterProvider = Provider<int?>((ref) {
  final selectedRole = ref.watch(selectedRoleFilterProvider);
  final userRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;

  // ถ้า -1 = เลือก "ดูทุก role" = ไม่ filter
  if (selectedRole == -1) return null;

  // ถ้าเลือก role อื่น = ใช้ role ที่เลือก
  if (selectedRole != null) return selectedRole;

  // ถ้า null = ยังไม่ได้เลือก = ใช้ role ของ user เป็น default
  return userRole?.id;
});

/// Provider สำหรับ ZoneService
final zoneServiceProvider = Provider<ZoneService>((ref) {
  return ZoneService();
});

/// Provider สำหรับ zones ทั้งหมดของ nursinghome
final nursinghomeZonesProvider = FutureProvider<List<Zone>>((ref) async {
  final zoneService = ref.watch(zoneServiceProvider);
  return zoneService.getZones();
});

/// Provider สำหรับ selected residents filter (สำหรับ UI filter chips)
/// ถ้า empty = แสดงทุก resident, ถ้ามีค่า = filter เฉพาะ residents ที่เลือก
final selectedResidentsFilterProvider = StateProvider<Set<int>>((ref) {
  return {}; // default: แสดงทุก resident
});

// ============================================================
// "คนไข้ของฉัน" Filter - ใช้ข้อมูลจาก Clock In
// ============================================================

/// Provider สำหรับ ClockService
final clockServiceProvider = Provider<ClockService>((ref) {
  return ClockService.instance;
});

/// Provider สำหรับ current shift ของ user
final currentShiftProvider = FutureProvider<ClockInOut?>((ref) async {
  // Watch for user changes (dev mode impersonation)
  ref.watch(userChangeCounterProvider);
  final clockService = ref.watch(clockServiceProvider);
  return clockService.getCurrentShift(forceRefresh: true);
});

/// State สำหรับว่ากำลัง filter ด้วย "คนไข้ของฉัน" อยู่หรือไม่
final myPatientsFilterActiveProvider = StateProvider<bool>((ref) {
  return false;
});

/// State สำหรับตรวจสอบว่า init filter "คนไข้ของฉัน" แล้วหรือยัง
/// เพื่อป้องกันไม่ให้ init ซ้ำ - tracks which user ID was initialized
final _myPatientsFilterInitializedForUserProvider = StateProvider<String?>((ref) {
  return null;
});

/// Provider ที่จะ auto-initialize "คนไข้ของฉัน" filter เมื่อ user clock in
/// เรียกใช้ใน ChecklistScreen เพื่อ init filter ตอนเปิดหน้า
/// หมายเหตุ: ตอน init ใช้ shift.zones เพราะยังไม่โหลด residents
/// แต่เมื่อ user กดปุ่ม "คนไข้ของฉัน" จะหา zones จาก residents ที่ถูกต้อง
final initMyPatientsFilterProvider = Provider<void>((ref) {
  final currentShiftAsync = ref.watch(currentShiftProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  final initializedForUser = ref.watch(_myPatientsFilterInitializedForUserProvider);

  // ถ้า init แล้วสำหรับ user นี้ ไม่ต้องทำอีก
  if (initializedForUser == currentUserId) return;

  currentShiftAsync.whenData((shift) {
    if (shift != null && shift.isClockedIn) {
      // Set filter เมื่อ user clock in อยู่
      // ใช้ addPostFrameCallback เพื่อหลีกเลี่ยง assertion error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_myPatientsFilterInitializedForUserProvider.notifier).state = currentUserId;
        ref.read(myPatientsFilterActiveProvider.notifier).state = true;

        // ตอน init ใช้ shift.zones ก่อน (default)
        // เมื่อ user กดปุ่ม "คนไข้ของฉัน" toggle จะหา zones จาก residents ที่ถูกต้อง
        ref.read(selectedZonesFilterProvider.notifier).state =
            shift.zones.toSet();
        ref.read(selectedResidentsFilterProvider.notifier).state =
            shift.selectedResidentIdList.toSet();
      });
    } else {
      // User is not clocked in - reset filter
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_myPatientsFilterInitializedForUserProvider.notifier).state = currentUserId;
        ref.read(myPatientsFilterActiveProvider.notifier).state = false;
        ref.read(selectedZonesFilterProvider.notifier).state = {};
        ref.read(selectedResidentsFilterProvider.notifier).state = {};
      });
    }
  });
});

/// Helper function สำหรับหา zones จาก resident IDs
/// ใช้ใน ChecklistScreen._toggleMyPatientsFilter
Set<int> getZonesFromResidentIds(List<ResidentSimple> allResidents, Set<int> residentIds) {
  return allResidents
      .where((r) => residentIds.contains(r.id))
      .map((r) => r.zoneId)
      .toSet();
}

// ============================================================
// Task Type Filter Providers
// ============================================================

/// Provider สำหรับ unique task types จาก tasks ทั้งหมด
final availableTaskTypesProvider = Provider<List<String>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);

  if (!tasksAsync.hasValue) return [];

  final tasks = tasksAsync.value!;
  final types = tasks
      .map((t) => t.taskType)
      .where((t) => t != null && t.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList();
  types.sort();
  return types;
});

/// Provider สำหรับ selected task types filter
/// ถ้า empty = แสดงทุก type, ถ้ามีค่า = filter เฉพาะ types ที่เลือก
final selectedTaskTypesFilterProvider = StateProvider<Set<String>>((ref) {
  return {}; // default: แสดงทุก type
});

/// Provider สำหรับ search query ของ task type
final taskTypeSearchQueryProvider = StateProvider<String>((ref) {
  return '';
});

/// Provider สำหรับ filtered task types ตาม search query
final filteredTaskTypesProvider = Provider<List<String>>((ref) {
  final allTypes = ref.watch(availableTaskTypesProvider);
  final query = ref.watch(taskTypeSearchQueryProvider).toLowerCase().trim();

  if (query.isEmpty) return allTypes;

  return allTypes.where((t) => t.toLowerCase().contains(query)).toList();
});

/// Provider สำหรับ residents ทั้งหมดของ nursinghome (sorted by name)
final nursinghomeResidentsProvider = FutureProvider<List<ResidentSimple>>((ref) async {
  final nursinghomeId = await ref.watch(nursinghomeIdProvider.future);
  if (nursinghomeId == null) return [];

  try {
    final response = await Supabase.instance.client
        .from('residents')
        .select('id, i_Name_Surname, nursinghome_zone(id)')
        .eq('nursinghome_id', nursinghomeId)
        .eq('s_status', 'Stay')
        .order('i_Name_Surname');

    return (response as List)
        .map((json) => ResidentSimple.fromJson(json))
        .toList();
  } catch (e) {
    return [];
  }
});

/// Provider สำหรับ residents ที่ถูก filter ตาม selected zones
final filteredResidentsProvider = Provider<AsyncValue<List<ResidentSimple>>>((ref) {
  final residentsAsync = ref.watch(nursinghomeResidentsProvider);
  final selectedZones = ref.watch(selectedZonesFilterProvider);

  return residentsAsync.when(
    data: (residents) {
      if (selectedZones.isEmpty) {
        // ถ้าไม่ได้เลือก zone = ไม่แสดง residents
        return const AsyncValue.data([]);
      }
      // filter residents ตาม selected zones
      final filtered = residents
          .where((r) => selectedZones.contains(r.zoneId))
          .toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Helper function to refresh tasks
void refreshTasks(WidgetRef ref) {
  TaskService.instance.invalidateCache();
  ref.read(taskRefreshCounterProvider.notifier).state++;
  ref.invalidate(tasksProvider);
  ref.invalidate(userShiftProvider);
  // Clear task type filter and search query
  ref.read(selectedTaskTypesFilterProvider.notifier).state = {};
  ref.read(taskTypeSearchQueryProvider.notifier).state = '';
}

/// Helper function to refresh tasks using ProviderContainer (for realtime callbacks)
void refreshTasksWithContainer(ProviderContainer container) {
  TaskService.instance.invalidateCache();
  container.read(taskRefreshCounterProvider.notifier).state++;
  container.invalidate(tasksProvider);
  container.invalidate(userShiftProvider);
}

// ============================================================
// Optimistic Update - อัพเดต UI ทันทีก่อนรอ server ตอบกลับ
// ============================================================

/// Provider สำหรับเก็บ optimistic updates ที่ยังไม่ได้ sync กับ server
/// Key = logId, Value = optimistically updated TaskLog
final optimisticTaskUpdatesProvider = StateProvider<Map<int, TaskLog>>((ref) {
  return {};
});

/// อัพเดต task แบบ optimistic (อัพเดต UI ทันทีก่อนรอ server)
/// คืนค่า function สำหรับ rollback ถ้า server error
///
/// Usage:
/// ```dart
/// final rollback = optimisticUpdateTask(ref, updatedTask);
/// try {
///   await server.updateTask(...);
///   commitOptimisticUpdate(ref, logId); // ยืนยัน - ลบ optimistic state
/// } catch (e) {
///   rollback(); // ย้อนกลับ
/// }
/// ```
void Function() optimisticUpdateTask(WidgetRef ref, TaskLog updatedTask) {
  final updates = ref.read(optimisticTaskUpdatesProvider);
  final previousTask = updates[updatedTask.logId];

  // เก็บ optimistic update
  ref.read(optimisticTaskUpdatesProvider.notifier).state = {
    ...updates,
    updatedTask.logId: updatedTask,
  };

  // Trigger UI rebuild
  ref.read(taskRefreshCounterProvider.notifier).state++;

  // คืน rollback function
  return () {
    final current = ref.read(optimisticTaskUpdatesProvider);
    if (previousTask != null) {
      // คืนค่าเดิม
      ref.read(optimisticTaskUpdatesProvider.notifier).state = {
        ...current,
        updatedTask.logId: previousTask,
      };
    } else {
      // ลบออก
      final newMap = Map<int, TaskLog>.from(current);
      newMap.remove(updatedTask.logId);
      ref.read(optimisticTaskUpdatesProvider.notifier).state = newMap;
    }
    ref.read(taskRefreshCounterProvider.notifier).state++;
  };
}

/// ยืนยัน optimistic update เมื่อ server สำเร็จ
/// ลบ optimistic state และ invalidate cache เพื่อ fetch ข้อมูลใหม่
void commitOptimisticUpdate(WidgetRef ref, int logId) {
  final updates = ref.read(optimisticTaskUpdatesProvider);
  final newMap = Map<int, TaskLog>.from(updates);
  newMap.remove(logId);
  ref.read(optimisticTaskUpdatesProvider.notifier).state = newMap;

  // Invalidate cache เพื่อให้ realtime sync มาแล้วข้อมูลถูกต้อง
  TaskService.instance.invalidateCache();
}

/// Provider ที่รวม tasks จาก server กับ optimistic updates
/// ใช้แทน tasksProvider ใน UI
final tasksWithOptimisticProvider = Provider<AsyncValue<List<TaskLog>>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final optimisticUpdates = ref.watch(optimisticTaskUpdatesProvider);

  // Watch refresh counter เพื่อ trigger rebuild
  ref.watch(taskRefreshCounterProvider);

  return tasksAsync.when(
    data: (tasks) {
      if (optimisticUpdates.isEmpty) {
        return AsyncValue.data(tasks);
      }

      // แทนที่ tasks ด้วย optimistic updates
      final updatedTasks = tasks.map((task) {
        return optimisticUpdates[task.logId] ?? task;
      }).toList();

      return AsyncValue.data(updatedTasks);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

// ============================================================
// Pending Tasks Count Providers (งานค้างใน 2 ชม. ข้างหน้า)
// ============================================================

/// Helper function to count pending tasks in next 2 hours
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
    return task.expectedDateTime!.isAfter(now.subtract(const Duration(minutes: 1))) &&
           task.expectedDateTime!.isBefore(twoHoursLater);
  }).toList();
}

/// Provider สำหรับจำนวนงานค้างต่อ Zone (ใน 2 ชม. ข้างหน้า)
/// Returns Map of zoneId to count
final pendingTasksPerZoneProvider = Provider<Map<int, int>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final selectedRoleId = ref.watch(effectiveRoleFilterProvider);

  if (!tasksAsync.hasValue) return {};

  var tasks = tasksAsync.value!;

  // Apply role filter (only if selectedRoleId is specified)
  if (selectedRoleId != null) {
    tasks = tasks.where((t) =>
      t.assignedRoleId == null || t.assignedRoleId == selectedRoleId
    ).toList();
  }

  // Get pending tasks in next 2 hours
  final pendingTasks = _getPendingTasksInNext2Hours(tasks);

  // Group by zone
  final Map<int, int> result = {};
  for (final task in pendingTasks) {
    if (task.zoneId != null) {
      result[task.zoneId!] = (result[task.zoneId!] ?? 0) + 1;
    }
  }

  return result;
});

/// Provider สำหรับจำนวนงานค้างทั้งหมด (ใน 2 ชม. ข้างหน้า) - ตาม role ที่เลือกในตัวกรอง
final totalPendingTasksCountProvider = Provider<int>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final selectedRoleId = ref.watch(effectiveRoleFilterProvider);

  if (!tasksAsync.hasValue) return 0;

  var tasks = tasksAsync.value!;

  // Apply role filter (only if selectedRoleId is specified)
  if (selectedRoleId != null) {
    tasks = tasks.where((t) =>
      t.assignedRoleId == null || t.assignedRoleId == selectedRoleId
    ).toList();
  }

  return _getPendingTasksInNext2Hours(tasks).length;
});

/// Provider สำหรับจำนวนงานค้างของ role ตัวเอง (ใน 2 ชม. ข้างหน้า)
/// ใช้แสดง badge ที่ icon filter - ไม่ขึ้นกับ role ที่เลือกในตัวกรอง
final myRolePendingTasksCountProvider = Provider<int>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final userRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;

  if (!tasksAsync.hasValue) return 0;

  var tasks = tasksAsync.value!;

  // Filter เฉพาะงานของ role ตัวเอง + งานที่ไม่ระบุ role
  if (userRole != null) {
    tasks = tasks.where((t) =>
      t.assignedRoleId == null || t.assignedRoleId == userRole.id
    ).toList();
  }

  return _getPendingTasksInNext2Hours(tasks).length;
});

/// Provider สำหรับจำนวนงานค้างต่อ Role (ใน 2 ชม. ข้างหน้า)
/// Returns Map of roleId to count
/// roleId = null (key -999) หมายถึงงานที่ไม่ระบุ role (ทุกคนทำได้)
final pendingTasksPerRoleProvider = Provider<Map<int, int>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final selectedZones = ref.watch(selectedZonesFilterProvider);

  if (!tasksAsync.hasValue) return {};

  var tasks = tasksAsync.value!;

  // Apply zone filter
  if (selectedZones.isNotEmpty) {
    tasks = tasks.where((t) => t.zoneId != null && selectedZones.contains(t.zoneId)).toList();
  }

  // Get pending tasks in next 2 hours
  final pendingTasks = _getPendingTasksInNext2Hours(tasks);

  // Group by role
  final Map<int, int> result = {};
  for (final task in pendingTasks) {
    final roleId = task.assignedRoleId ?? -999; // -999 = งานสำหรับทุก role
    result[roleId] = (result[roleId] ?? 0) + 1;
  }

  return result;
});

