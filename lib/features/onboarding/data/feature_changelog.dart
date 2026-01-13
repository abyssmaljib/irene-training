import '../models/feature_announcement.dart';

/// Static data สำหรับ Feature Changelog
/// เก็บประกาศ feature ใหม่ของแต่ละ version
///
/// วิธีเพิ่ม changelog ใหม่:
/// 1. เพิ่ม FeatureAnnouncement ใน _announcements map
/// 2. ใช้ version string เป็น key (ต้องตรงกับ AppVersion.current)
/// 3. กำหนด relatedTabId ถ้าต้องการแสดง NEW badge
class FeatureChangelog {
  /// Map เก็บ announcements ทั้งหมด
  /// Key = version string, Value = FeatureAnnouncement
  static const Map<String, FeatureAnnouncement> _announcements = {
    // ตัวอย่าง: version 1.0.1
    // '1.0.1': FeatureAnnouncement(
    //   version: '1.0.1',
    //   title: 'อัปเดตใหม่!',
    //   items: [
    //     ChangelogItem(
    //       text: 'เพิ่มการบันทึกปัญหาพร้อมรูปภาพในเช็คลิสต์',
    //       type: ChangeType.newFeature,
    //       relatedTabId: 'checklist', // จะแสดง NEW badge บน Checklist tab
    //     ),
    //     ChangelogItem(
    //       text: 'ปรับปรุงการโหลดรูปภาพให้เร็วขึ้น',
    //       type: ChangeType.improved,
    //     ),
    //     ChangelogItem(
    //       text: 'แก้ไขปัญหาการแสดงผลบนหน้าจอเล็ก',
    //       type: ChangeType.fixed,
    //     ),
    //   ],
    // ),

    // Version 1.0.0 - Initial release (ไม่ต้องมี announcement)
    // เพิ่ม announcements ใหม่ที่นี่เมื่อมี release
  };

  /// ดึง FeatureAnnouncement สำหรับ version ที่กำหนด
  /// Returns null ถ้าไม่มี announcement สำหรับ version นั้น
  static FeatureAnnouncement? getAnnouncementForVersion(String version) {
    return _announcements[version];
  }

  /// ดึง versions ทั้งหมดที่มี announcement
  /// เรียงจากใหม่ไปเก่า
  static List<String> getAllVersions() {
    final versions = _announcements.keys.toList();
    versions.sort((a, b) => _compareVersions(b, a)); // Descending
    return versions;
  }

  /// เปรียบเทียบ version strings
  /// Returns: negative ถ้า a < b, positive ถ้า a > b, 0 ถ้าเท่ากัน
  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < partsA.length && i < partsB.length; i++) {
      if (partsA[i] != partsB[i]) {
        return partsA[i].compareTo(partsB[i]);
      }
    }

    return partsA.length.compareTo(partsB.length);
  }
}
