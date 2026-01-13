import 'package:hugeicons/hugeicons.dart';

/// Main tabs for the board screen - V3: เหลือ 2 tabs
enum PostMainTab {
  announcement, // ศูนย์ (posts ไม่มี resident_id)
  resident, // ผู้พัก (posts ที่มี resident_id)
}

/// Extension for PostMainTab
extension PostMainTabExtension on PostMainTab {
  String get label {
    switch (this) {
      case PostMainTab.announcement:
        return 'ศูนย์';
      case PostMainTab.resident:
        return 'ผู้พัก';
    }
  }

  dynamic get icon {
    switch (this) {
      case PostMainTab.announcement:
        return HugeIcons.strokeRoundedFileEdit;
      case PostMainTab.resident:
        return HugeIcons.strokeRoundedUser;
    }
  }

  /// Maps to database tab values
  List<String> get dbTabValues {
    switch (this) {
      case PostMainTab.announcement:
        // ศูนย์ = posts ที่ไม่มี resident_id
        return [];
      case PostMainTab.resident:
        // ผู้พัก = posts ที่มี resident_id
        return [];
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
