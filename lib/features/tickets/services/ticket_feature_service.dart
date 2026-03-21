// Service หลักสำหรับ Tickets feature (Sprint 1 — Read only)
//
// ใช้ Singleton pattern เพื่อให้มี instance เดียวทั้ง app
// พร้อมระบบ cache 2 ชั้น:
//   - Ticket cache (2 นาที) — ข้อมูลเปลี่ยนบ่อย
//   - Staff cache (10 นาที) — ข้อมูลเปลี่ยนน้อย
//
// Error resilience: ถ้า fetch ล้มเหลว จะ return stale cache แทน crash
// เพื่อให้ UX ไม่สะดุด — user ยังเห็นข้อมูลเก่าได้

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ticket.dart';
import '../models/ticket_comment.dart';
import '../models/staff_member.dart';

/// Service สำหรับจัดการ Tickets ใน feature module ใหม่
/// ใช้ Singleton pattern เพื่อให้มี instance เดียวทั้ง app
///
/// Sprint 1: Read methods only (getTickets, getTicketById, getTicketTimeline, getActiveStaff)
/// Sprint 2: Write methods (create, update, delete) จะเพิ่มทีหลัง
class TicketFeatureService {
  // ── Singleton ────────────────────────────────────────────────
  static final TicketFeatureService instance = TicketFeatureService._();
  TicketFeatureService._();

  final _supabase = Supabase.instance.client;

  // ── Ticket cache (2 นาที) ────────────────────────────────────
  // เก็บ list ของ tickets ตาม nursinghome_id
  // TTL สั้น เพราะ ticket อาจเปลี่ยนสถานะบ่อย (เช่น comment ใหม่, status เปลี่ยน)
  int? _cachedNursinghomeId;
  List<Ticket>? _cachedTickets;
  DateTime? _cacheTime;
  static const _cacheMaxAge = Duration(minutes: 2);

  // ── Staff cache (10 นาที) ────────────────────────────────────
  // เก็บ list ของ staff members ตาม nursinghome_id
  // TTL ยาวกว่า เพราะ staff list ไม่ค่อยเปลี่ยน (มีคนเข้า-ออกไม่บ่อย)
  int? _cachedStaffNhId;
  List<StaffMember>? _cachedStaff;
  DateTime? _staffCacheTime;
  static const _staffCacheMaxAge = Duration(minutes: 10);

  // ════════════════════════════════════════════════════════════
  // Cache helpers
  // ════════════════════════════════════════════════════════════

  /// ตรวจสอบว่า ticket cache ยังใช้ได้อยู่
  /// cache valid เมื่อ: nursinghome ตรง + มีข้อมูล + ยังไม่หมดอายุ
  bool _isTicketCacheValid(int nursinghomeId) {
    if (_cachedNursinghomeId != nursinghomeId) return false;
    if (_cachedTickets == null) return false;
    if (_cacheTime == null) return false;
    return DateTime.now().difference(_cacheTime!) < _cacheMaxAge;
  }

  /// ตรวจสอบว่า staff cache ยังใช้ได้อยู่
  bool _isStaffCacheValid(int nursinghomeId) {
    if (_cachedStaffNhId != nursinghomeId) return false;
    if (_cachedStaff == null) return false;
    if (_staffCacheTime == null) return false;
    return DateTime.now().difference(_staffCacheTime!) < _staffCacheMaxAge;
  }

  /// ล้าง cache ทั้งหมด (ticket + staff)
  /// เรียกเมื่อ: สร้าง/แก้ไข/ลบ ticket, หรือ user switch nursinghome
  void invalidateCache() {
    _cachedTickets = null;
    _cacheTime = null;
    _cachedStaff = null;
    _staffCacheTime = null;
    debugPrint('TicketFeatureService: cache invalidated');
  }

  // ════════════════════════════════════════════════════════════
  // Read Methods (Sprint 1)
  // ════════════════════════════════════════════════════════════

  /// ดึง tickets ทั้งหมดของ nursinghome
  ///
  /// สำคัญ: ต้อง filter ด้วย nursinghome_id เสมอ
  /// เพราะ v_tickets_dashboard เป็น view ที่ bypass RLS (S1 bug)
  /// ถ้าไม่ filter จะเห็น tickets ของ nursinghome อื่นด้วย
  ///
  /// Cache strategy:
  /// - ใช้ cache ถ้ายังไม่หมดอายุ (2 นาที) และ nursinghome_id ตรง
  /// - ถ้า fetch ล้มเหลว จะ return stale cache แทน (ข้อมูลเก่าดีกว่าไม่มีข้อมูล)
  /// - ถ้าไม่มี cache เลย จะ rethrow error ให้ caller จัดการ
  Future<List<Ticket>> getTickets(int nursinghomeId) async {
    // ใช้ cache ถ้ายังใช้ได้ — ลด network calls
    if (_isTicketCacheValid(nursinghomeId)) {
      debugPrint(
        'TicketFeatureService.getTickets: using cache '
        '(${_cachedTickets!.length} tickets)',
      );
      return _cachedTickets!;
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Query จาก v_tickets_dashboard view
      // CRITICAL: filter nursinghome_id เสมอ เพราะ view bypass RLS
      // limit 200 เพื่อป้องกัน response ใหญ่เกินไป
      final response = await _supabase
          .from('v_tickets_dashboard')
          .select()
          .eq('nursinghome_id', nursinghomeId)
          .order('created_at', ascending: false)
          .limit(200);

      stopwatch.stop();

      // แปลง JSON → Ticket objects
      final tickets = (response as List)
          .map((json) => Ticket.fromJson(json as Map<String, dynamic>))
          .toList();

      // อัพเดต cache
      _cachedNursinghomeId = nursinghomeId;
      _cachedTickets = tickets;
      _cacheTime = DateTime.now();

      debugPrint(
        'TicketFeatureService.getTickets: fetched ${tickets.length} tickets '
        'in ${stopwatch.elapsedMilliseconds}ms',
      );
      return tickets;
    } catch (e) {
      debugPrint('TicketFeatureService.getTickets error: $e');

      // Error resilience: return stale cache ถ้ามี
      // ข้อมูลเก่า (อาจ outdated) ดีกว่าหน้าจอ error เปล่า
      if (_cachedTickets != null &&
          _cachedNursinghomeId == nursinghomeId) {
        debugPrint(
          'TicketFeatureService.getTickets: returning stale cache on error',
        );
        return _cachedTickets!;
      }

      // ไม่มี cache เลย — rethrow ให้ caller (provider) จัดการแสดง error
      rethrow;
    }
  }

  /// ดึง ticket เดียวโดย ID
  ///
  /// ใช้สำหรับหน้า detail หรือ refresh ticket เดี่ยว
  /// Return null ถ้าไม่เจอ (เช่น ticket ถูกลบไปแล้ว — S6 bug)
  /// แทนที่จะ throw error เพื่อให้ UI จัดการ "ticket not found" ได้สะอาด
  Future<Ticket?> getTicketById(int ticketId) async {
    try {
      // Query เดี่ยว — ไม่ใช้ cache เพราะต้องการข้อมูลล่าสุดเสมอ
      final response = await _supabase
          .from('v_tickets_dashboard')
          .select()
          .eq('id', ticketId)
          .maybeSingle();

      // maybeSingle() return null ถ้าไม่เจอ row
      // กรณี ticket ถูกลบไปแล้ว จะ return null แทน throw
      if (response == null) return null;

      return Ticket.fromJson(response);
    } catch (e) {
      debugPrint('TicketFeatureService.getTicketById error: $e');
      return null;
    }
  }

  /// ดึง timeline (comments) ของ ticket เรียงตามเวลา
  ///
  /// Query join กับ user_info เพื่อได้ nickname + photo_url ของคนที่เขียน comment
  /// เรียงจากเก่าไปใหม่ (ascending) เพื่อแสดงเป็น timeline แบบ chat
  Future<List<TicketComment>> getTicketTimeline(int ticketId) async {
    try {
      final stopwatch = Stopwatch()..start();

      // Select พร้อม join user_info ผ่าน FK created_by
      // เพื่อได้ nickname และ photo_url ของผู้เขียน comment
      final response = await _supabase
          .from('B_Ticket_Comments')
          .select('*, user_info!created_by(nickname, photo_url)')
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);

      stopwatch.stop();

      // แปลง JSON → TicketComment objects
      final comments = (response as List)
          .map(
            (json) => TicketComment.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      debugPrint(
        'TicketFeatureService.getTicketTimeline: fetched ${comments.length} '
        'comments in ${stopwatch.elapsedMilliseconds}ms',
      );
      return comments;
    } catch (e) {
      debugPrint('TicketFeatureService.getTicketTimeline error: $e');
      return [];
    }
  }

  /// ดึงรายชื่อ staff ที่ยังทำงานอยู่ (ไม่ใช่ resigned)
  ///
  /// ใช้สำหรับ assign ticket ให้ staff
  /// Cache 10 นาที เพราะ staff list ไม่ค่อยเปลี่ยน
  Future<List<StaffMember>> getActiveStaff(int nursinghomeId) async {
    // ใช้ staff cache ถ้ายังใช้ได้
    if (_isStaffCacheValid(nursinghomeId)) {
      debugPrint(
        'TicketFeatureService.getActiveStaff: using cache '
        '(${_cachedStaff!.length} staff)',
      );
      return _cachedStaff!;
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Query user_info — เฉพาะคนที่ยังไม่ลาออก
      // select เฉพาะ fields ที่ต้องใช้ เพื่อลด payload
      // หมายเหตุ: .neq() ใน Supabase/PostgREST จะ exclude NULL ด้วย
      // (NULL != 'resigned' = NULL → ไม่ผ่าน filter)
      // ต้องใช้ .or() เพื่อรวม NULL employment_type ด้วย
      final response = await _supabase
          .from('user_info')
          .select('id, nickname, i_Name_Surname, photo_url')
          .eq('nursinghome_id', nursinghomeId)
          .or('employment_type.neq.resigned,employment_type.is.null')
          .order('nickname');

      stopwatch.stop();

      // แปลง JSON → StaffMember objects
      final staff = (response as List)
          .map(
            (json) => StaffMember.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      // อัพเดต staff cache
      _cachedStaffNhId = nursinghomeId;
      _cachedStaff = staff;
      _staffCacheTime = DateTime.now();

      debugPrint(
        'TicketFeatureService.getActiveStaff: fetched ${staff.length} staff '
        'in ${stopwatch.elapsedMilliseconds}ms',
      );
      return staff;
    } catch (e) {
      debugPrint('TicketFeatureService.getActiveStaff error: $e');

      // Error resilience: return stale staff cache ถ้ามี
      if (_cachedStaff != null && _cachedStaffNhId == nursinghomeId) {
        debugPrint(
          'TicketFeatureService.getActiveStaff: returning stale cache on error',
        );
        return _cachedStaff!;
      }

      return [];
    }
  }

  // ===== Sprint 2: Write Methods =====

  /// เปลี่ยนสถานะตั๋ว + บันทึก status_change event ใน timeline
  /// IMPORTANT: ต้อง invalidateCache() หลังเรียก
  Future<void> changeStatus(int ticketId, String newStatus, {String? oldStatus}) async {
    // CRITICAL: ใช้ auth.uid() ไม่ใช่ effectiveUserId (C1 bug prevention)
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

    // 1. UPDATE ticket status
    await _supabase
        .from('B_Ticket')
        .update({'status': newStatus})
        .eq('id', ticketId);

    // 2. INSERT status_change comment (C20: ไม่ atomic — แจ้ง warning ถ้า fail)
    try {
      await _supabase.from('B_Ticket_Comments').insert({
        'ticket_id': ticketId,
        'content': 'เปลี่ยนสถานะ',
        'created_by': userId,
        'event_type': 'status_change',
        'old_status': oldStatus,
        'new_status': newStatus,
      });
    } catch (e) {
      debugPrint('TicketFeatureService: INSERT status_change comment failed: $e');
      // ไม่ throw — สถานะเปลี่ยนแล้วแต่ timeline อาจไม่มี record
    }

    invalidateCache();
  }

  /// เพิ่ม comment ใน timeline
  /// CRITICAL: created_by ต้องเป็น auth.uid() เท่านั้น (RLS enforces)
  Future<void> addComment(int ticketId, String content, {List<String>? mentionedUsers}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

    // Validate content ไม่ว่าง (C9 bug prevention)
    if (content.trim().isEmpty) throw Exception('กรุณากรอกข้อความ');

    await _supabase.from('B_Ticket_Comments').insert({
      'ticket_id': ticketId,
      'content': content.trim(),
      'created_by': userId,
      'event_type': 'comment',
      'mentioned_users': mentionedUsers ?? [],
    });

    invalidateCache();
  }

  /// อัปเดตวันติดตาม
  Future<void> updateFollowUpDate(int ticketId, DateTime? date) async {
    await _supabase
        .from('B_Ticket')
        .update({'follow_Up_Date': date?.toIso8601String().split('T').first})
        .eq('id', ticketId);
    invalidateCache();
  }

  /// Toggle priority (สำคัญ/ไม่สำคัญ)
  Future<void> togglePriority(int ticketId, bool value) async {
    await _supabase
        .from('B_Ticket')
        .update({'priority': value})
        .eq('id', ticketId);
    invalidateCache();
  }

  /// Toggle meeting agenda
  Future<void> toggleMeetingAgenda(int ticketId, bool value) async {
    await _supabase
        .from('B_Ticket')
        .update({'meeting_Agenda': value})
        .eq('id', ticketId);
    invalidateCache();
  }

  /// อัปเดต stock status (สำหรับ medicine tickets)
  Future<void> updateStockStatus(int ticketId, String newStatus) async {
    await _supabase
        .from('B_Ticket')
        .update({'stock_status': newStatus})
        .eq('id', ticketId);
    invalidateCache();
  }

  // ===== Sprint 3: Create + Mention Methods =====

  /// สร้างตั๋วใหม่ — return ticket id
  /// CRITICAL: ต้อง set created_by explicitly (C18: ไม่มี DEFAULT ใน DB)
  Future<int> createTicket({
    required String title,
    String? description,
    required String category,
    required int nursinghomeId,
    int? residentId,
    bool priority = false,
    DateTime? followUpDate,
    bool meetingAgenda = false,
    List<String>? mentionedUsers,
  }) async {
    // ดึง userId จาก auth — ต้องไม่ใช่ effectiveUserId (impersonation)
    // เพราะ RLS จะตรวจสอบว่า created_by ตรงกับ auth.uid()
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

    // Insert ตั๋วใหม่ พร้อม select('id') เพื่อ return ticket id กลับมา
    // C18: ต้อง set created_by ชัดเจน เพราะ DB ไม่มี DEFAULT สำหรับ column นี้
    final response = await _supabase.from('B_Ticket').insert({
      'ticket_Title': title.trim(),
      'ticket_Description': description?.trim(),
      'category': category,
      'nursinghome_id': nursinghomeId,
      'resident_id': residentId,
      'priority': priority,
      'follow_Up_Date': followUpDate?.toIso8601String().split('T').first,
      'meeting_Agenda': meetingAgenda,
      'created_by': userId,
      'status': 'open',
      'mentioned_users': mentionedUsers ?? [],
    }).select('id').single();

    // ล้าง cache เพื่อให้ list screen เห็นตั๋วใหม่ทันที
    invalidateCache();
    return response['id'] as int;
  }

  /// ส่ง notification ให้คนที่ถูก @mention
  /// S4: reference_id ต้องเป็น String (RPC รับ text)
  /// S5: ใส่ delay ระหว่าง calls ป้องกัน rate limit
  /// C15: dedupe userIds ด้วย Set
  Future<void> sendMentionNotifications({
    required List<String> userIds,
    required int ticketId,
    required String content,
    required String senderNickname,
  }) async {
    // C15: dedupe ด้วย Set เพื่อไม่ให้ส่ง notification ซ้ำหลายรอบ
    final uniqueIds = userIds.toSet();
    // ไม่ส่ง notification ให้ตัวเอง (ไม่งั้น user จะได้ noti ทุกครั้งที่ mention ตัวเอง)
    final currentUserId = _supabase.auth.currentUser?.id;
    uniqueIds.remove(currentUserId);

    for (final userId in uniqueIds) {
      try {
        // เรียก RPC create_notification เพื่อสร้าง notification record ใน DB
        // S4: reference_id ต้อง convert เป็น String เพราะ RPC parameter รับ text
        await _supabase.rpc('create_notification', params: {
          'p_user_id': userId,
          'p_title': '$senderNickname แท็กคุณในตั๋ว #$ticketId',
          'p_body': content.length > 100
              ? '${content.substring(0, 100)}...'
              : content,
          'p_type': 'ticket_mention',
          'p_reference_id': ticketId.toString(), // S4: convert to String
          'p_reference_table': 'B_Ticket',
        });
        // S5: delay ระหว่าง calls เพื่อป้องกัน rate limit จาก Supabase
        if (uniqueIds.length > 1) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (e) {
        debugPrint('sendMentionNotification failed for $userId: $e');
        // ไม่ throw — ส่ง noti ไม่สำเร็จไม่ควร block flow หลัก
        // เพราะตั๋วถูกสร้างเรียบร้อยแล้ว การส่ง noti เป็นแค่ bonus
      }
    }
  }
}
