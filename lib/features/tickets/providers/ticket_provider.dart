// Provider สำหรับจัดการ Tickets ในหน้า ticket list
// ใช้ Riverpod สำหรับ state management
// Pattern เดียวกับ incident_provider.dart — ใช้ userChangeCounterProvider
// เพื่อรองรับ dev mode impersonation

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/user_service.dart';
import '../../checklist/providers/task_provider.dart'; // for userChangeCounterProvider
import '../models/ticket.dart';
import '../models/ticket_comment.dart';
import '../models/staff_member.dart';
import '../services/ticket_feature_service.dart';

// =============================================================================
// Service Provider
// =============================================================================

/// Provider สำหรับ TicketFeatureService (Singleton)
/// ใช้เข้าถึง service instance จาก provider tree
final ticketFeatureServiceProvider = Provider<TicketFeatureService>((ref) {
  return TicketFeatureService.instance;
});

// =============================================================================
// Data Providers
// =============================================================================

/// Provider สำหรับดึง tickets ทั้งหมดของ nursinghome
///
/// ทำงาน:
/// 1. Watch userChangeCounterProvider เพื่อ refresh เมื่อ impersonate user อื่น
/// 2. ดึง nursinghomeId จาก UserService (ใช้ effectiveUserId สำหรับ impersonation)
/// 3. เรียก TicketFeatureService.getTickets() เพื่อดึงข้อมูลจาก Supabase
///
/// Return empty list ถ้าไม่มี nursinghomeId (เช่น user ยังไม่ได้ login)
final allTicketsProvider = FutureProvider<List<Ticket>>((ref) async {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);

  // ดึง nursinghomeId ของ user ปัจจุบัน (รองรับ impersonation)
  final userService = UserService();
  final nursinghomeId = await userService.getNursinghomeId();

  // ถ้าไม่มี nursinghomeId → return empty list (ยังไม่ได้ login หรือไม่มีสังกัด)
  if (nursinghomeId == null) {
    return [];
  }

  // ดึง tickets ทั้งหมดของ nursinghome จาก service
  return TicketFeatureService.instance.getTickets(nursinghomeId);
});

// =============================================================================
// Filter Providers
// =============================================================================

/// Provider สำหรับ tab filter ที่เลือกอยู่
/// - null = แสดงทั้งหมด ("ทั้งหมด" tab)
/// - TicketStatus.open = แสดงเฉพาะ ticket ที่เปิดอยู่
/// - TicketStatus.inProgress = แสดงเฉพาะ ticket ที่กำลังดำเนินการ
/// - ฯลฯ
final ticketFilterTabProvider = StateProvider<TicketStatus?>((ref) {
  return null; // default: แสดงทั้งหมด
});

/// Provider สำหรับ tickets ที่ผ่านการ filter ตาม tab ที่เลือก
///
/// ทำงาน:
/// 1. Watch allTicketsProvider (ได้ AsyncValue of List Ticket)
/// 2. Watch ticketFilterTabProvider (ได้ TicketStatus? ที่เลือก)
/// 3. ถ้า filter เป็น null → return ทั้งหมด
/// 4. ถ้ามี filter → return เฉพาะ ticket ที่ status ตรงกัน
///
/// Return AsyncValue เพื่อให้ UI จัดการ loading/error state ได้
final filteredTicketsProvider = Provider<AsyncValue<List<Ticket>>>((ref) {
  // ดึง tickets ทั้งหมด (เป็น AsyncValue — อาจอยู่ใน loading/error/data)
  final allTicketsAsync = ref.watch(allTicketsProvider);

  // ดึง filter tab ที่เลือก
  final filterStatus = ref.watch(ticketFilterTabProvider);

  // ใช้ .whenData() เพื่อ transform data โดยคง loading/error state ไว้
  // ถ้า allTicketsAsync กำลัง loading → return AsyncLoading
  // ถ้า allTicketsAsync error → return AsyncError
  // ถ้า allTicketsAsync มี data → filter แล้ว return AsyncData
  return allTicketsAsync.whenData((tickets) {
    // ถ้าไม่ได้เลือก filter → return ทั้งหมด
    if (filterStatus == null) {
      return tickets;
    }

    // Filter เฉพาะ ticket ที่ status ตรงกับ tab ที่เลือก
    return tickets.where((ticket) => ticket.status == filterStatus).toList();
  });
});

// =============================================================================
// Count Providers
// =============================================================================

/// Provider สำหรับนับจำนวน tickets ตามสถานะ (ใช้แสดง badge count บน tab)
///
/// Return map เช่น:
/// {
///   'all': 10,
///   'open': 3,
///   'in_progress': 2,
///   'awaiting_follow_up': 1,
///   'resolved': 3,
///   'cancelled': 1,
/// }
///
/// ถ้ายังโหลดไม่เสร็จหรือมี error → return map ที่ค่าเป็น 0 ทั้งหมด
final ticketCountsProvider = Provider<Map<String, int>>((ref) {
  final allTicketsAsync = ref.watch(allTicketsProvider);

  // ใช้ .when() เพื่อจัดการทุกสถานะของ AsyncValue
  return allTicketsAsync.when(
    data: (tickets) {
      // นับจำนวน ticket ตามแต่ละสถานะ
      return {
        'all': tickets.length,
        'open': tickets
            .where((t) => t.status == TicketStatus.open)
            .length,
        'in_progress': tickets
            .where((t) => t.status == TicketStatus.inProgress)
            .length,
        'awaiting_follow_up': tickets
            .where((t) => t.status == TicketStatus.awaitingFollowUp)
            .length,
        'resolved': tickets
            .where((t) => t.status == TicketStatus.resolved)
            .length,
        'cancelled': tickets
            .where((t) => t.status == TicketStatus.cancelled)
            .length,
      };
    },
    // กำลังโหลด → return ค่า 0 ทั้งหมด (UI จะแสดง loading indicator แทน)
    loading: () => {
      'all': 0,
      'open': 0,
      'in_progress': 0,
      'awaiting_follow_up': 0,
      'resolved': 0,
      'cancelled': 0,
    },
    // มี error → return ค่า 0 ทั้งหมด (UI จะแสดง error state แทน)
    error: (_, _) => {
      'all': 0,
      'open': 0,
      'in_progress': 0,
      'awaiting_follow_up': 0,
      'resolved': 0,
      'cancelled': 0,
    },
  );
});

// =============================================================================
// Action Providers
// =============================================================================

/// Provider สำหรับ refresh tickets (force reload จาก server)
///
/// ใช้เมื่อ:
/// - User pull-to-refresh
/// - หลังจากสร้าง/แก้ไข/ลบ ticket
/// - หลังจากเปลี่ยนสถานะ ticket
///
/// ทำงาน:
/// 1. ล้าง cache ใน TicketFeatureService (บังคับ fetch ใหม่จาก Supabase)
/// 2. Invalidate allTicketsProvider (trigger re-fetch)
/// 3. Provider อื่นที่ watch allTicketsProvider จะ update ตามอัตโนมัติ
///    (filteredTicketsProvider, ticketCountsProvider)
final refreshTicketsProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // ล้าง cache ใน service เพื่อบังคับ fetch ข้อมูลใหม่จาก Supabase
    TicketFeatureService.instance.invalidateCache();

    // Invalidate provider เพื่อ trigger re-fetch
    // Provider ทุกตัวที่ watch allTicketsProvider จะ rebuild ตามอัตโนมัติ
    ref.invalidate(allTicketsProvider);
  };
});

// =============================================================================
// Sprint 2: Detail Providers
// =============================================================================

/// Provider สำหรับดึงข้อมูลตั๋วรายตัว — ใช้ใน ticket_detail_screen
/// ใช้ .family เพื่อรับ ticketId เป็น parameter
final ticketDetailProvider = FutureProvider.family<Ticket?, int>((ref, ticketId) async {
  // Watch user change สำหรับ dev mode impersonation
  ref.watch(userChangeCounterProvider);
  return TicketFeatureService.instance.getTicketById(ticketId);
});

/// Provider สำหรับ timeline ของตั๋ว — comments, status changes, doctor orders
final ticketTimelineProvider = FutureProvider.family<List<TicketComment>, int>((ref, ticketId) async {
  ref.watch(userChangeCounterProvider);
  return TicketFeatureService.instance.getTicketTimeline(ticketId);
});

/// Provider สำหรับ staff list (ใช้ใน @mention)
final ticketStaffListProvider = FutureProvider<List<StaffMember>>((ref) async {
  ref.watch(userChangeCounterProvider);
  final nursinghomeId = await UserService().getNursinghomeId();
  if (nursinghomeId == null) return [];
  return TicketFeatureService.instance.getActiveStaff(nursinghomeId);
});

/// Refresh detail + timeline provider
final refreshTicketDetailProvider = Provider.family<Future<void> Function(), int>((ref, ticketId) {
  return () async {
    TicketFeatureService.instance.invalidateCache();
    ref.invalidate(ticketDetailProvider(ticketId));
    ref.invalidate(ticketTimelineProvider(ticketId));
    // Also invalidate the list
    ref.invalidate(allTicketsProvider);
  };
});
