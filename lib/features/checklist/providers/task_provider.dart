import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../../home/models/zone.dart';
import '../../home/services/zone_service.dart';
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

/// Provider สำหรับ current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

/// Provider สำหรับ nursinghome ID
final nursinghomeIdProvider = FutureProvider<int?>((ref) async {
  final userService = ref.watch(userServiceProvider);
  return userService.getNursinghomeId();
});

/// Provider สำหรับ selected date (default = today)
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
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

/// Helper function to filter tasks by selected zones, residents, and role
/// selectedRoleId: null = ใช้ role ของ user, อื่นๆ = filter ตาม role นั้นเฉพาะ
List<TaskLog> _filterByZonesResidentsAndRole(
  List<TaskLog> tasks,
  Set<int> selectedZones,
  Set<int> selectedResidents,
  SystemRole? userRole,
  int? selectedRoleId,
) {
  var filtered = tasks;

  // Filter out tasks that should be hidden (referred/home residents, empty taskType)
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

  // Filter by role
  // แสดงเฉพาะงานที่:
  // 1. assignedRoleId == selectedRoleId (หรือ userRole.id ถ้า selectedRoleId == null)
  // 2. assignedRoleId == null (งานที่ไม่ระบุ role = ทุกคนทำได้)
  final targetRoleId = selectedRoleId ?? userRole?.id;
  if (targetRoleId != null) {
    filtered = filtered
        .where((t) => t.assignedRoleId == null || t.assignedRoleId == targetRoleId)
        .toList();
  }

  return filtered;
}

/// Provider สำหรับ filtered tasks ตาม view mode
final filteredTasksProvider = Provider<AsyncValue<List<TaskLog>>>((ref) {
  // Watch refresh counter to enable manual refresh
  ref.watch(taskRefreshCounterProvider);

  final tasksAsync = ref.watch(tasksProvider);
  final viewMode = ref.watch(taskViewModeProvider);
  final shiftAsync = ref.watch(userShiftProvider);
  final userId = ref.watch(currentUserIdProvider);
  final service = ref.watch(taskServiceProvider);
  final selectedZones = ref.watch(selectedZonesFilterProvider);
  final selectedResidents = ref.watch(selectedResidentsFilterProvider);
  final selectedRoleId = ref.watch(effectiveRoleFilterProvider);
  final userRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;

  return tasksAsync.when(
    data: (tasks) {
      final shift = shiftAsync.valueOrNull;

      // Apply zone, resident, and role filter
      final filteredTasks = _filterByZonesResidentsAndRole(
        tasks, selectedZones, selectedResidents, userRole, selectedRoleId);

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
final groupedTasksProvider =
    Provider<AsyncValue<Map<String, List<TaskLog>>>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final service = ref.watch(taskServiceProvider);
  final selectedZones = ref.watch(selectedZonesFilterProvider);
  final selectedResidents = ref.watch(selectedResidentsFilterProvider);
  final selectedRoleId = ref.watch(effectiveRoleFilterProvider);
  final userRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;

  return tasksAsync.when(
    data: (tasks) {
      // Apply zone, resident, and role filter
      final filteredTasks = _filterByZonesResidentsAndRole(
        tasks, selectedZones, selectedResidents, userRole, selectedRoleId);
      return AsyncValue.data(service.groupTasksByTimeBlock(filteredTasks));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Provider สำหรับ task counts per view mode
final taskCountsProvider = Provider<Map<TaskViewMode, int>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final shiftAsync = ref.watch(userShiftProvider);
  final userId = ref.watch(currentUserIdProvider);
  final service = ref.watch(taskServiceProvider);
  final selectedZones = ref.watch(selectedZonesFilterProvider);
  final selectedResidents = ref.watch(selectedResidentsFilterProvider);
  final selectedRoleId = ref.watch(effectiveRoleFilterProvider);
  final userRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;

  if (!tasksAsync.hasValue) return {};

  final allTasks = tasksAsync.value!;
  // Apply zone, resident, and role filter
  final tasks = _filterByZonesResidentsAndRole(
    allTasks, selectedZones, selectedResidents, userRole, selectedRoleId);
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
/// ถ้า selectedRoleFilter เป็น null จะใช้ user's role เป็น default
final effectiveRoleFilterProvider = Provider<int?>((ref) {
  final selectedRole = ref.watch(selectedRoleFilterProvider);
  if (selectedRole != null) return selectedRole;

  // ถ้ายังไม่ได้เลือก ใช้ role ของ user เป็น default
  final userRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;
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
}

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
/// Returns Map<zoneId, count>
final pendingTasksPerZoneProvider = Provider<Map<int, int>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final selectedRoleId = ref.watch(effectiveRoleFilterProvider);
  final userRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;

  if (!tasksAsync.hasValue) return {};

  var tasks = tasksAsync.value!;

  // Apply role filter - แสดงเฉพาะงานของ role ที่เลือก + งานที่ไม่ระบุ role
  final targetRoleId = selectedRoleId ?? userRole?.id;
  if (targetRoleId != null) {
    tasks = tasks.where((t) =>
      t.assignedRoleId == null || t.assignedRoleId == targetRoleId
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
  final userRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;

  if (!tasksAsync.hasValue) return 0;

  var tasks = tasksAsync.value!;

  // Apply role filter - แสดงเฉพาะงานของ role ที่เลือก + งานที่ไม่ระบุ role
  final targetRoleId = selectedRoleId ?? userRole?.id;
  if (targetRoleId != null) {
    tasks = tasks.where((t) =>
      t.assignedRoleId == null || t.assignedRoleId == targetRoleId
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
/// Returns Map<roleId, count>
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

