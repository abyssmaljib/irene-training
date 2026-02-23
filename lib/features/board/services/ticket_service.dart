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
