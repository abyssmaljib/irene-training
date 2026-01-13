/// Model สำหรับประกาศ Feature ใหม่ในแต่ละ Version
/// ใช้แสดงใน What's New Dialog เมื่อ user อัปเดต app
class FeatureAnnouncement {
  /// Version ของ app (format: major.minor.patch)
  /// ต้องตรงกับ version ใน pubspec.yaml
  final String version;

  /// หัวข้อหลักของ update นี้
  /// เช่น "อัปเดตใหม่!" หรือ "เพิ่มฟีเจอร์ใหม่"
  final String title;

  /// รายการ changes ทั้งหมดใน version นี้
  final List<ChangelogItem> items;

  /// URL ของรูปภาพ hero (optional)
  /// แสดงด้านบนของ dialog
  final String? heroImageUrl;

  const FeatureAnnouncement({
    required this.version,
    required this.title,
    required this.items,
    this.heroImageUrl,
  });
}

/// รายการ change แต่ละข้อใน changelog
class ChangelogItem {
  /// คำอธิบายของ change นี้
  /// ควรเขียนสั้นๆ กระชับ อ่านเข้าใจง่าย
  final String text;

  /// ประเภทของ change
  final ChangeType type;

  /// Tab ID ที่เกี่ยวข้อง (optional)
  /// ถ้ากำหนด จะแสดง NEW badge บน tab นั้น
  /// ค่าที่รองรับ: 'home', 'checklist', 'residents', 'board', 'settings'
  final String? relatedTabId;

  const ChangelogItem({
    required this.text,
    required this.type,
    this.relatedTabId,
  });
}

/// ประเภทของ change
enum ChangeType {
  /// Feature ใหม่ที่เพิ่มเข้ามา
  /// Icon: Sparkles (สีเขียว)
  newFeature,

  /// ปรับปรุง feature ที่มีอยู่
  /// Icon: Arrow Up (สี primary)
  improved,

  /// แก้ไข bug
  /// Icon: Checkmark (สีเหลือง/ส้ม)
  fixed,
}
