import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';

/// ข้อมูลตั๋วแบบย่อ สำหรับแสดงในหน้า post detail
/// ไม่ต้องมีทุก field — แค่พอแสดงสถานะและข้อมูลสำคัญ
class TicketSummary {
  final int id;
  final String title;
  final String? description;
  final String status; // 'open', 'in_progress', 'completed', 'cancelled'
  final bool priority;
  final bool meetingAgenda;
  final DateTime createdAt;
  final DateTime? followUpDate;
  final String? createdByNickname;

  /// สถานะ stock ของยา (เช่น 'pending', 'received', 'completed')
  /// ใช้เฉพาะ ticket ที่เกี่ยวกับ restock ยา
  final String? stockStatus;

  /// FK ไป medicine_list — ระบุว่า ticket นี้เกี่ยวกับยาตัวไหน
  final int? medListId;

  const TicketSummary({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    required this.meetingAgenda,
    required this.createdAt,
    this.followUpDate,
    this.createdByNickname,
    this.stockStatus,
    this.medListId,
  });

  /// แปลงจาก database row (v_tickets_with_last_comment view)
  factory TicketSummary.fromJson(Map<String, dynamic> json) {
    return TicketSummary(
      id: json['id'] as int,
      title: (json['ticket_Title'] as String?) ?? '',
      description: json['ticket_Description'] as String?,
      status: (json['status'] as String?) ?? 'open',
      priority: (json['priority'] as bool?) ?? false,
      meetingAgenda: (json['meeting_Agenda'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      followUpDate: json['follow_Up_Date'] != null
          ? DateTime.tryParse(json['follow_Up_Date'] as String)
          : null,
      createdByNickname: json['created_by_nickname'] as String?,
      stockStatus: json['stock_status'] as String?,
      medListId: json['med_list_id'] as int?,
    );
  }

  /// Label ภาษาไทยของสถานะ
  String get statusLabel {
    switch (status) {
      case 'open':
        return 'เปิด';
      case 'in_progress':
        return 'กำลังดำเนินการ';
      case 'completed':
      case 'closed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  /// Emoji สำหรับสถานะ
  String get statusEmoji {
    switch (status) {
      case 'open':
        return '🟡';
      case 'in_progress':
        return '🔵';
      case 'completed':
      case 'closed':
        return '🟢';
      case 'cancelled':
        return '⚫';
      default:
        return '⚪';
    }
  }

  /// Label ภาษาไทยของ stock_status (สำหรับ ticket restock ยา)
  /// ถ้าไม่มี stockStatus จะ fallback ไปใช้ statusLabel ปกติ
  String get stockStatusLabel {
    switch (stockStatus) {
      case 'pending':
        return 'รอแจ้งญาติ';
      case 'notified':
        return 'แจ้งญาติแล้ว';
      case 'waiting_relative':
        return 'รอญาตินำยามา';
      case 'waiting_appointment':
        return 'รอไปพบแพทย์';
      case 'added_to_appointment':
        return 'เพิ่มในนัดหมายแล้ว';
      case 'staff_purchase':
        return 'ญาติให้เราซื้อให้';
      case 'purchasing':
        return 'กำลังจัดซื้อ';
      case 'waiting_delivery':
        return 'รอยามาส่ง';
      case 'received':
      case 'completed':
        return 'ได้รับยาแล้ว - เสร็จสิ้น';
      default:
        // ไม่มี stockStatus → ใช้ statusLabel ปกติ
        return statusLabel;
    }
  }

  /// Emoji สำหรับ stock_status (สำหรับ ticket restock ยา)
  /// ถ้าไม่มี stockStatus จะ fallback ไปใช้ statusEmoji ปกติ
  String get stockStatusEmoji {
    switch (stockStatus) {
      case 'pending':
        return '🟡';
      case 'notified':
        return '📞';
      case 'waiting_relative':
        return '🚗';
      case 'waiting_appointment':
        return '🏥';
      case 'added_to_appointment':
        return '📅';
      case 'staff_purchase':
        return '🛒';
      case 'purchasing':
        return '🔄';
      case 'waiting_delivery':
        return '📦';
      case 'received':
      case 'completed':
        return '✅';
      default:
        // ไม่มี stockStatus → ใช้ statusEmoji ปกติ
        return statusEmoji;
    }
  }

  /// ตั๋วปิดแล้วหรือไม่ (completed, cancelled, closed)
  bool get isClosed =>
      status == 'completed' || status == 'cancelled' || status == 'closed';
}

/// Service สำหรับสร้างตั๋ว (Ticket) จาก Flutter app
/// ตั๋วที่สร้างจะไปปรากฏใน irene-training-admin /tickets อัตโนมัติ
/// ผ่าน real-time subscription ของ admin app
class TicketService {
  // Singleton pattern เหมือน BugReportService
  static final instance = TicketService._();
  TicketService._();

  final _supabase = Supabase.instance.client;

  /// สร้างตั๋วจากโพส
  /// [postId] - ID ของโพสต้นทาง (เก็บเป็น source_id)
  /// [title] - หัวข้อตั๋ว (pre-fill จาก post title)
  /// [description] - รายละเอียด (pre-fill จาก post text)
  /// [residentId] - ผู้รับบริการที่เกี่ยวข้อง (จาก post.residentId)
  /// [priority] - ความสำคัญ (true = สำคัญ)
  /// [followUpDate] - วันติดตาม
  /// [meetingAgenda] - เข้าวาระประชุมหรือไม่
  /// Returns: ticket ID ถ้าสำเร็จ, null ถ้า error
  Future<int?> createTicketFromPost({
    required int postId,
    required String title,
    required String description,
    int? residentId,
    bool priority = false,
    DateTime? followUpDate,
    bool meetingAgenda = false,
  }) async {
    try {
      // ดึง userId จาก UserService (รองรับ dev mode impersonation)
      final userId = UserService().effectiveUserId;
      if (userId == null) {
        debugPrint('TicketService: No user logged in');
        return null;
      }

      // ดึง nursinghomeId จาก UserService
      final nursinghomeId = await UserService().getNursinghomeId();
      if (nursinghomeId == null) {
        debugPrint('TicketService: No nursinghome assigned');
        return null;
      }

      // Insert ตั๋วใหม่ลง B_Ticket
      // ใช้ field names ตรงกับ admin CreateTicketModal
      final response = await _supabase
          .from('B_Ticket')
          .insert({
            'ticket_Title': title,
            'ticket_Description': description,
            'nursinghome_id': nursinghomeId,
            'created_by': userId,
            'resident_id': residentId,
            // เก็บที่มาของตั๋ว (polymorphic reference)
            'source_type': 'post',
            'source_id': postId,
            // Default values
            'status': 'open',
            'priority': priority,
            'meeting_Agenda': meetingAgenda,
            // แปลง DateTime เป็น yyyy-MM-dd string (ตรงกับ column type date)
            if (followUpDate != null)
              'follow_Up_Date':
                  followUpDate.toIso8601String().split('T')[0],
          })
          .select('id')
          .single();

      final ticketId = response['id'] as int;
      debugPrint('TicketService: Ticket #$ticketId created from post #$postId');
      return ticketId;
    } catch (e) {
      debugPrint('TicketService createTicketFromPost error: $e');
      return null;
    }
  }

  /// ดึง ticket ที่ยังเปิดอยู่ สำหรับรายการยาที่กำหนด
  /// ใช้ใน restock flow — แสดง ticket ที่เกี่ยวกับยาแต่ละตัว
  /// [medListIds] — list ของ medicine_list IDs ที่ต้องการหา ticket
  /// Returns: Map ของ med_list_id → List of TicketSummary, grouped by ยา
  Future<Map<int, List<TicketSummary>>> getOpenTicketsByMedListIds(
    List<int> medListIds,
  ) async {
    // ไม่มี medListIds → return map เปล่า
    if (medListIds.isEmpty) return {};

    try {
      // Query B_Ticket ตรงๆ — ไม่ใช้ view เพราะต้องการ stock_status + med_list_id
      final response = await _supabase
          .from('B_Ticket')
          .select(
            'id, ticket_Title, ticket_Description, status, priority, '
            'meeting_Agenda, created_at, follow_Up_Date, stock_status, med_list_id',
          )
          // เฉพาะยาที่ระบุ
          .inFilter('med_list_id', medListIds)
          // แสดงทุก ticket ยกเว้น cancelled + stock_status='completed'
          // ไม่ filter ด้วย status เพราะ ticket อาจ resolved แล้วแต่ stock ยังไม่เสร็จ
          // ใช้ or() เพื่อรวม stock_status IS NULL (ticket เก่าที่ไม่มี stock_status)
          .neq('status', 'cancelled')
          .or('stock_status.neq.completed,stock_status.is.null')
          .order('created_at', ascending: false);

      // Group ผลลัพธ์ตาม med_list_id
      final Map<int, List<TicketSummary>> grouped = {};
      for (final row in response as List) {
        final ticket = TicketSummary.fromJson(row as Map<String, dynamic>);
        final mlId = ticket.medListId;
        if (mlId != null) {
          grouped.putIfAbsent(mlId, () => []).add(ticket);
        }
      }
      return grouped;
    } catch (e) {
      debugPrint('TicketService getOpenTicketsByMedListIds error: $e');
      return {};
    }
  }

  /// ปิด ticket หลายใบพร้อมกัน (เมื่อ user สร้าง restock post สำเร็จ)
  /// UPDATE status='resolved', stock_status='completed'
  /// Returns: จำนวน ticket ที่ปิดสำเร็จ
  Future<int> completeTickets(List<int> ticketIds) async {
    if (ticketIds.isEmpty) return 0;

    try {
      // UPDATE B_Ticket SET status='resolved', stock_status='completed'
      // WHERE id IN (ticketIds)
      await _supabase
          .from('B_Ticket')
          .update({
            'status': 'resolved',
            'stock_status': 'completed',
          })
          .inFilter('id', ticketIds);

      debugPrint(
        'TicketService: Completed ${ticketIds.length} tickets: $ticketIds',
      );
      return ticketIds.length;
    } catch (e) {
      debugPrint('TicketService completeTickets error: $e');
      return 0;
    }
  }

  /// อัพเดท stock_status ของ ticket
  /// ใช้ใน TicketDetailBottomSheet เมื่อ user เปลี่ยนสถานะ stock
  /// Returns: true ถ้าสำเร็จ
  Future<bool> updateStockStatus(int ticketId, String newStatus) async {
    try {
      await _supabase
          .from('B_Ticket')
          .update({'stock_status': newStatus})
          .eq('id', ticketId);

      debugPrint(
        'TicketService: Ticket #$ticketId stock_status → $newStatus',
      );
      return true;
    } catch (e) {
      debugPrint('TicketService updateStockStatus error: $e');
      return false;
    }
  }

  /// สร้าง ticket สำหรับยาที่ต้อง restock
  /// ใช้ในหน้าอัพเดตสต็อก เมื่อ user กดปุ่ม "สร้าง Ticket" ด้วยตัวเอง
  /// Pattern เดียวกับ edge function auto-create-medicine-tickets
  /// Returns: TicketSummary ถ้าสำเร็จ, null ถ้า error
  Future<TicketSummary?> createTicketForMedicine({
    required int medicineListId,
    required int residentId,
    required String medicineName,
    String? residentName,
  }) async {
    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) {
        debugPrint('TicketService: No user logged in');
        return null;
      }

      final nursinghomeId = await UserService().getNursinghomeId();
      if (nursinghomeId == null) {
        debugPrint('TicketService: No nursinghome assigned');
        return null;
      }

      // Title format เหมือน edge function: "ยาใกล้หมด - {medName} - {residentName}"
      final title = 'ยาใกล้หมด - $medicineName'
          '${residentName != null ? ' - $residentName' : ''}';

      final response = await _supabase
          .from('B_Ticket')
          .insert({
            'ticket_Title': title,
            'ticket_Description': 'สร้างจากหน้าอัพเดตสต็อก',
            'nursinghome_id': nursinghomeId,
            'created_by': userId,
            'resident_id': residentId,
            'category': 'medicine',
            'source_type': 'medicine',
            'source_id': medicineListId,
            'med_list_id': medicineListId,
            'status': 'open',
            'stock_status': 'pending',
            'priority': false,
          })
          .select(
            'id, ticket_Title, ticket_Description, status, priority, '
            'meeting_Agenda, created_at, follow_Up_Date, stock_status, med_list_id',
          )
          .single();

      final ticket = TicketSummary.fromJson(response);
      debugPrint(
        'TicketService: Medicine ticket #${ticket.id} created for med_list_id=$medicineListId',
      );
      return ticket;
    } catch (e) {
      debugPrint('TicketService createTicketForMedicine error: $e');
      return null;
    }
  }

  /// ดึงตั๋วที่สร้างจากโพสนี้ (ถ้ามี)
  /// ใช้ v_tickets_with_last_comment view เพื่อได้ nickname ผู้สร้างด้วย
  /// Returns: TicketSummary ถ้ามีตั๋ว, null ถ้าไม่มี
  Future<TicketSummary?> getTicketForPost(int postId) async {
    try {
      final response = await _supabase
          .from('v_tickets_with_last_comment')
          .select()
          .eq('source_type', 'post')
          .eq('source_id', postId)
          // เอาตั๋วล่าสุด (กรณีมีหลายตั๋วจากโพสเดียว)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return TicketSummary.fromJson(response);
    } catch (e) {
      debugPrint('TicketService getTicketForPost error: $e');
      return null;
    }
  }
}
