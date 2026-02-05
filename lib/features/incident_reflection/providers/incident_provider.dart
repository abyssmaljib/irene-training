// Provider สำหรับจัดการ Incidents ในหน้าถอดบทเรียน
// ใช้ Riverpod สำหรับ state management

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/user_service.dart';
import '../../checklist/providers/task_provider.dart'; // for userChangeCounterProvider
import '../models/incident.dart';
import '../services/incident_service.dart';

/// Provider สำหรับ IncidentService (Singleton)
final incidentServiceProvider = Provider<IncidentService>((ref) {
  return IncidentService.instance;
});

/// Provider สำหรับ UserService (Singleton)
final incidentUserServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

/// Provider สำหรับ current user ID
/// ใช้ effectiveUserId เพื่อรองรับ dev mode impersonation
final incidentCurrentUserIdProvider = Provider<String?>((ref) {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);
  return UserService().effectiveUserId;
});

/// Provider สำหรับ nursinghome ID ของ user ปัจจุบัน
final incidentNursinghomeIdProvider = FutureProvider<int?>((ref) async {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);
  final userService = ref.watch(incidentUserServiceProvider);
  return userService.getNursinghomeId();
});

/// Provider สำหรับดึง incidents ทั้งหมดของ user
///
/// ดึงจาก v_incidents_with_details view โดย filter ที่ staff_id contains userId
final myIncidentsProvider = FutureProvider<List<Incident>>((ref) async {
  final userId = ref.watch(incidentCurrentUserIdProvider);
  final nursinghomeIdAsync = ref.watch(incidentNursinghomeIdProvider);

  // รอ nursinghomeId ก่อน
  final nursinghomeId = nursinghomeIdAsync.value;

  // ถ้าไม่มี userId หรือ nursinghomeId return empty list
  if (userId == null || nursinghomeId == null) {
    return [];
  }

  final service = ref.watch(incidentServiceProvider);
  return service.getMyIncidents(userId, nursinghomeId);
});

/// Provider สำหรับ refresh incidents
/// เรียกเมื่อต้องการ force refresh data
final refreshIncidentsProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final userId = ref.read(incidentCurrentUserIdProvider);
    final nursinghomeIdAsync = ref.read(incidentNursinghomeIdProvider);
    final nursinghomeId = nursinghomeIdAsync.value;

    if (userId == null || nursinghomeId == null) return;

    final service = ref.read(incidentServiceProvider);
    service.invalidateCache();

    // Invalidate the provider to trigger refresh
    ref.invalidate(myIncidentsProvider);
  };
});

/// Tab ที่เลือกใน List Screen
/// ใช้ ReflectionStatus.value เป็นค่า (pending, in_progress, completed)
final selectedTabProvider = StateProvider<String>((ref) {
  return ReflectionStatus.pending.value; // default: รอดำเนินการ
});

/// Provider สำหรับ filter incidents ตาม Tab ที่เลือก
final filteredIncidentsProvider = Provider<List<Incident>>((ref) {
  final incidentsAsync = ref.watch(myIncidentsProvider);
  final selectedTab = ref.watch(selectedTabProvider);

  // ถ้ายังโหลดไม่เสร็จหรือมี error return empty list
  final incidents = incidentsAsync.value ?? [];

  // Filter ตาม reflection_status
  return incidents
      .where((i) => i.reflectionStatus.value == selectedTab)
      .toList();
});

/// Provider สำหรับนับจำนวน incidents ตามสถานะ (ใช้แสดง badge count)
/// "pending" รวม pending + in_progress เพื่อแสดงใน tab รอดำเนินการ
final incidentCountsProvider = Provider<Map<String, int>>((ref) {
  final incidentsAsync = ref.watch(myIncidentsProvider);
  final incidents = incidentsAsync.value ?? [];

  // นับ pending รวม pending + in_progress
  final pendingCount = incidents
      .where((i) =>
          i.reflectionStatus == ReflectionStatus.pending ||
          i.reflectionStatus == ReflectionStatus.inProgress)
      .length;

  return {
    'pending': pendingCount, // รวม pending + in_progress
    'completed': incidents
        .where((i) => i.reflectionStatus == ReflectionStatus.completed)
        .length,
    'total': incidents.length,
  };
});

/// Provider สำหรับ pending count อย่างเดียว (ใช้แสดง badge ใน Settings menu)
/// รวม pending + in_progress แล้ว
final pendingIncidentCountProvider = Provider<int>((ref) {
  final counts = ref.watch(incidentCountsProvider);
  return counts['pending'] ?? 0; // รวม pending + in_progress แล้ว
});

/// Provider สำหรับ incident ที่เลือก (ID)
final selectedIncidentIdProvider = StateProvider<int?>((ref) => null);

/// Provider สำหรับดึง incident ที่เลือก (full object)
final selectedIncidentProvider = Provider<Incident?>((ref) {
  final selectedId = ref.watch(selectedIncidentIdProvider);
  if (selectedId == null) return null;

  final incidentsAsync = ref.watch(myIncidentsProvider);
  final incidents = incidentsAsync.value ?? [];

  try {
    return incidents.firstWhere((i) => i.id == selectedId);
  } catch (e) {
    return null;
  }
});

/// Provider สำหรับ refresh incident เดียว (หลังจาก update chat history)
final refreshSingleIncidentProvider =
    Provider.family<Future<Incident?> Function(), int>((ref, incidentId) {
  return () async {
    final service = ref.read(incidentServiceProvider);
    return service.getIncidentById(incidentId);
  };
});
