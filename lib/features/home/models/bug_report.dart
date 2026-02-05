import 'package:flutter/material.dart';

/// Model สำหรับข้อมูล Bug Report จาก bug_reports table
/// เก็บข้อมูลการรายงานปัญหา/Bug จาก users
class BugReport {
  final String? id;
  final String userId;
  final int nursinghomeId;

  // Device Info (auto-captured)
  final String platform; // 'android', 'ios', 'web', 'windows'
  final String appVersion; // e.g., "1.2.3"
  final String? buildNumber; // e.g., "45"

  // Bug Report Info (user input)
  final DateTime bugOccurredAt; // เวลาที่เกิดบัค
  final String activityDescription; // กิจกรรมที่ทำให้เกิดบัค
  final String? additionalNotes; // รายละเอียดเพิ่มเติม (optional)

  // Attachments (optional)
  final List<String> attachmentUrls;

  // Status (สำหรับ admin)
  final String status; // 'open', 'in_progress', 'resolved', 'wont_fix'
  final String? adminNotes;

  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BugReport({
    this.id,
    required this.userId,
    required this.nursinghomeId,
    required this.platform,
    required this.appVersion,
    this.buildNumber,
    required this.bugOccurredAt,
    required this.activityDescription,
    this.additionalNotes,
    this.attachmentUrls = const [],
    this.status = 'open',
    this.adminNotes,
    this.createdAt,
    this.updatedAt,
  });

  /// Parse จาก Supabase response
  factory BugReport.fromJson(Map<String, dynamic> json) {
    return BugReport(
      id: json['id'] as String?,
      userId: json['user_id'] as String? ?? '',
      nursinghomeId: json['nursinghome_id'] as int? ?? 0,
      platform: json['platform'] as String? ?? '',
      appVersion: json['app_version'] as String? ?? '',
      buildNumber: json['build_number'] as String?,
      bugOccurredAt: _parseDateTime(json['bug_occurred_at']) ?? DateTime.now(),
      activityDescription: json['activity_description'] as String? ?? '',
      additionalNotes: json['additional_notes'] as String?,
      attachmentUrls: _parseStringList(json['attachment_urls']),
      status: json['status'] as String? ?? 'open',
      adminNotes: json['admin_notes'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  /// Convert เป็น JSON สำหรับ insert
  /// ไม่รวม id, createdAt, updatedAt (Supabase จัดการเอง)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'nursinghome_id': nursinghomeId,
      'platform': platform,
      'app_version': appVersion,
      if (buildNumber != null) 'build_number': buildNumber,
      'bug_occurred_at': bugOccurredAt.toIso8601String(),
      'activity_description': activityDescription,
      if (additionalNotes != null && additionalNotes!.isNotEmpty)
        'additional_notes': additionalNotes,
      'attachment_urls': attachmentUrls,
      'status': status,
    };
  }

  /// ตรวจสอบว่ามีไฟล์แนบหรือไม่
  bool get hasAttachments => attachmentUrls.isNotEmpty;

  /// จำนวนไฟล์แนบ
  int get attachmentCount => attachmentUrls.length;

  /// ตรวจสอบว่า resolved แล้วหรือไม่
  bool get isResolved => status == 'resolved' || status == 'wont_fix';

  /// แสดงสถานะเป็นภาษาไทย
  String get statusText {
    switch (status) {
      case 'open':
        return 'รอตรวจสอบ';
      case 'in_progress':
        return 'กำลังดำเนินการ';
      case 'resolved':
        return 'แก้ไขแล้ว';
      case 'wont_fix':
        return 'ไม่แก้ไข';
      default:
        return status;
    }
  }

  /// สีของสถานะสำหรับแสดงใน UI
  Color get statusColor {
    switch (status) {
      case 'open':
        return const Color(0xFFFF9800); // ส้ม - รอตรวจสอบ
      case 'in_progress':
        return const Color(0xFF2196F3); // น้ำเงิน - กำลังดำเนินการ
      case 'resolved':
        return const Color(0xFF4CAF50); // เขียว - แก้ไขแล้ว
      case 'wont_fix':
        return const Color(0xFF9E9E9E); // เทา - ไม่แก้ไข
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  String toString() {
    return 'BugReport(id: $id, status: $status, activity: $activityDescription)';
  }
}
