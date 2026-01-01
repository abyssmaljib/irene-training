import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

/// Main tabs for the board screen - V3: เหลือ 2 tabs
enum PostMainTab {
  announcement, // ประกาศ (Critical + Policy)
  handover, // ส่งเวร
}

/// Extension for PostMainTab
extension PostMainTabExtension on PostMainTab {
  String get label {
    switch (this) {
      case PostMainTab.announcement:
        return 'ประกาศ';
      case PostMainTab.handover:
        return 'ส่งเวร';
    }
  }

  IconData get icon {
    switch (this) {
      case PostMainTab.announcement:
        return Iconsax.notification;
      case PostMainTab.handover:
        return Iconsax.refresh;
    }
  }

  /// Maps to database tab values
  List<String> get dbTabValues {
    switch (this) {
      case PostMainTab.announcement:
        return [
          'Announcements-Critical',
          'Announcements-Policy',
        ];
      case PostMainTab.handover:
        // ส่งเวร tab ใช้ logic พิเศษใน post_service
        // - Posts จากหัวหน้าเวร
        // - Calendar posts
        // - Posts ที่มี is_handover = true (future)
        return ['Calendar']; // fallback สำหรับ legacy
    }
  }
}

/// Filter types for post list
enum PostFilterType {
  all, // ทั้งหมด
  unacknowledged, // รอรับทราบ
  myPosts, // โพสต์ของฉัน
}

/// Extension for PostFilterType
extension PostFilterTypeExtension on PostFilterType {
  String get label {
    switch (this) {
      case PostFilterType.all:
        return 'ทั้งหมด';
      case PostFilterType.unacknowledged:
        return 'รอรับทราบ';
      case PostFilterType.myPosts:
        return 'โพสต์ของฉัน';
    }
  }
}
