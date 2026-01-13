import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_version.dart';
import '../data/feature_changelog.dart';
import '../models/feature_announcement.dart';

/// Service สำหรับจัดการ state ของ Onboarding และ Version Tracking
/// ใช้ SharedPreferences เก็บ local state per user
///
/// Keys ที่ใช้:
/// - `tutorial_completed_{userId}`: bool - user ดู tutorial แล้วหรือยัง
/// - `last_seen_version_{userId}`: String - version ล่าสุดที่ user เห็น
/// - `dismissed_feature_tabs_{userId}`: List of String - tabs ที่ user dismiss NEW badge แล้ว
class OnboardingService {
  final SharedPreferences _prefs;

  // SharedPreferences key prefixes
  static const _keyTutorialCompleted = 'tutorial_completed_';
  static const _keyLastSeenVersion = 'last_seen_version_';
  static const _keyDismissedFeatureTabs = 'dismissed_feature_tabs_';

  OnboardingService(this._prefs);

  // ==========================================
  // Tutorial Methods
  // ==========================================

  /// ตรวจสอบว่า user ควรเห็น tutorial หรือไม่
  /// Returns true ถ้า user ยังไม่เคยดู tutorial
  bool shouldShowTutorial(String userId) {
    final key = '$_keyTutorialCompleted$userId';
    // ถ้าไม่มี key หรือ value เป็น false = ยังไม่เคยดู = ควรแสดง
    return !(_prefs.getBool(key) ?? false);
  }

  /// บันทึกว่า user ดู tutorial เสร็จแล้ว
  /// เรียกเมื่อ user ดูจบ หรือกด skip
  Future<void> markTutorialCompleted(String userId) async {
    final key = '$_keyTutorialCompleted$userId';
    await _prefs.setBool(key, true);
  }

  /// Reset tutorial status (สำหรับ replay)
  /// ไม่จำเป็นต้องเรียก เพราะ replay จะเริ่ม tutorial ใหม่โดยไม่ต้อง reset
  Future<void> resetTutorial(String userId) async {
    final key = '$_keyTutorialCompleted$userId';
    await _prefs.remove(key);
  }

  // ==========================================
  // Version Tracking Methods
  // ==========================================

  /// ดึง version ล่าสุดที่ user เคยเห็น
  /// Returns null ถ้าไม่เคยบันทึก (first time user)
  String? getLastSeenVersion(String userId) {
    final key = '$_keyLastSeenVersion$userId';
    return _prefs.getString(key);
  }

  /// บันทึก version ปัจจุบันว่า user เห็นแล้ว
  Future<void> updateLastSeenVersion(String userId) async {
    final key = '$_keyLastSeenVersion$userId';
    await _prefs.setString(key, AppVersion.current);
  }

  /// ตรวจสอบว่ามี version ใหม่ที่ user ยังไม่เคยเห็น
  /// Returns FeatureAnnouncement ถ้ามี version ใหม่ที่ต้องแสดง
  /// Returns null ถ้าไม่มี announcement หรือ user เห็นแล้ว
  Future<FeatureAnnouncement?> getNewVersionAnnouncement(String userId) async {
    final lastSeen = getLastSeenVersion(userId);

    // ถ้าไม่เคยเห็น version ไหนเลย (first time user)
    // บันทึก version ปัจจุบันเป็น baseline แล้วไม่แสดง What's New
    // เพราะ first time user จะเห็น Tutorial แทน
    if (lastSeen == null) {
      await updateLastSeenVersion(userId);
      return null;
    }

    // ถ้า version ปัจจุบันใหม่กว่าที่ user เคยเห็น
    if (AppVersion.isNewerVersion(AppVersion.current, lastSeen)) {
      // หา announcement สำหรับ version ปัจจุบัน
      return FeatureChangelog.getAnnouncementForVersion(AppVersion.current);
    }

    return null;
  }

  // ==========================================
  // NEW Badge Methods
  // ==========================================

  /// ดึง set ของ tab IDs ที่มี feature ใหม่และยังไม่ถูก dismiss
  /// ใช้สำหรับแสดง NEW badge บน navigation
  Future<Set<String>> getNewFeatureTabs(String userId) async {
    final announcement = await getNewVersionAnnouncement(userId);
    if (announcement == null) return {};

    // รวม tab IDs จาก changelog items ที่มี relatedTabId
    final tabs = <String>{};
    for (final item in announcement.items) {
      if (item.relatedTabId != null) {
        tabs.add(item.relatedTabId!);
      }
    }

    // ลบ tabs ที่ user dismiss ไปแล้ว
    final dismissed = _getDismissedFeatureTabs(userId);
    return tabs.difference(dismissed);
  }

  /// Dismiss NEW badge สำหรับ tab ที่กำหนด
  /// เรียกเมื่อ user tap ที่ tab นั้น
  Future<void> dismissFeatureTab(String userId, String tabId) async {
    final key = '$_keyDismissedFeatureTabs$userId';
    final current = _prefs.getStringList(key) ?? [];

    if (!current.contains(tabId)) {
      current.add(tabId);
      await _prefs.setStringList(key, current);
    }
  }

  /// ดึง set ของ tabs ที่ user dismiss แล้ว (internal)
  Set<String> _getDismissedFeatureTabs(String userId) {
    final key = '$_keyDismissedFeatureTabs$userId';
    return (_prefs.getStringList(key) ?? []).toSet();
  }

  /// Clear dismissed tabs (เรียกเมื่อมี version ใหม่)
  /// ทำให้ NEW badges กลับมาแสดงใหม่
  Future<void> clearDismissedFeatureTabs(String userId) async {
    final key = '$_keyDismissedFeatureTabs$userId';
    await _prefs.remove(key);
  }
}
