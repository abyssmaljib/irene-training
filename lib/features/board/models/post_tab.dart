import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

/// Main tabs for the board screen - V3: เหลือ 2 tabs
enum PostMainTab {
  announcement, // นโยบาย (Policy only)
  handover, // ส่งเวร (is_handover = true + Critical)
}

/// Extension for PostMainTab
extension PostMainTabExtension on PostMainTab {
  String get label {
    switch (this) {
      case PostMainTab.announcement:
        return 'นโยบาย';
      case PostMainTab.handover:
        return 'ส่งเวร';
    }
  }

  IconData get icon {
    switch (this) {
      case PostMainTab.announcement:
        return Iconsax.document_text;
      case PostMainTab.handover:
        return Iconsax.refresh;
    }
  }

  /// Maps to database tab values
  List<String> get dbTabValues {
    switch (this) {
      case PostMainTab.announcement:
        // นโยบาย = Policy เท่านั้น
        return ['Announcements-Policy'];
      case PostMainTab.handover:
        // ส่งเวร tab ใช้ logic พิเศษใน post_service
        // - is_handover = true
        // - Critical posts (รวมมาด้วย)
        return ['Announcements-Critical']; // fallback
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
