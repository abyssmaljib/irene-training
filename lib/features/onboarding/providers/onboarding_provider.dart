import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import '../models/feature_announcement.dart';
import '../models/tutorial_target.dart';
import '../services/onboarding_service.dart';
import '../services/tutorial_service.dart';

// ============================================================
// Service Providers
// ============================================================

/// Provider สำหรับ OnboardingService instance
/// ใช้สำหรับจัดการ state ของ tutorial และ version tracking
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingService(prefs);
});

/// Provider สำหรับ TutorialService instance
/// ใช้สำหรับควบคุม tutorial_coach_mark
final tutorialServiceProvider = Provider<TutorialService>((ref) {
  return TutorialService();
});

/// Provider สำหรับ TutorialKeys (Singleton)
/// เก็บ GlobalKeys ทั้งหมดที่ใช้ใน Tutorial
final tutorialKeysProvider = Provider<TutorialKeys>((ref) {
  return TutorialKeys();
});

// ============================================================
// Tutorial State Providers
// ============================================================

/// ตรวจสอบว่าควรแสดง tutorial ให้ user หรือไม่
/// Returns true ถ้า user ยังไม่เคยดู tutorial
///
/// Usage:
/// ```dart
/// final shouldShow = ref.watch(shouldShowTutorialProvider(userId));
/// if (shouldShow) { startTutorial(); }
/// ```
final shouldShowTutorialProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final service = ref.watch(onboardingServiceProvider);
  return service.shouldShowTutorial(userId);
});

/// ตรวจสอบว่ามี version ใหม่ที่ต้องแสดง What's New หรือไม่
/// Returns FeatureAnnouncement ถ้ามี, null ถ้าไม่มี
///
/// Usage:
/// ```dart
/// final announcement = await ref.read(newVersionAnnouncementProvider(userId).future);
/// if (announcement != null) { showWhatsNewDialog(announcement); }
/// ```
final newVersionAnnouncementProvider =
    FutureProvider.family<FeatureAnnouncement?, String>((ref, userId) async {
  final service = ref.watch(onboardingServiceProvider);
  return service.getNewVersionAnnouncement(userId);
});

/// ดึง Set ของ tab IDs ที่มี feature ใหม่ (สำหรับแสดง NEW badge)
/// Returns Set เช่น {'checklist', 'board'}
///
/// Usage:
/// ```dart
/// final newTabs = ref.watch(newFeatureTabsProvider(userId));
/// newTabs.when(
///   data: (tabs) => tabs.contains('checklist') ? showBadge() : null,
///   ...
/// );
/// ```
final newFeatureTabsProvider =
    FutureProvider.family<Set<String>, String>((ref, userId) async {
  final service = ref.watch(onboardingServiceProvider);
  return service.getNewFeatureTabs(userId);
});

// ============================================================
// Tutorial Control State
// ============================================================

/// State สำหรับ track ว่า tutorial กำลังแสดงอยู่หรือไม่
/// ใช้ป้องกันการเปิด tutorial ซ้ำ
final isTutorialShowingProvider = StateProvider<bool>((ref) => false);

/// State สำหรับ track current tab index ระหว่าง tutorial
/// ใช้สำหรับ navigate ระหว่าง tabs
final tutorialCurrentTabProvider = StateProvider<int>((ref) => 0);

// ============================================================
// Helper Functions (ไม่ใช่ Provider)
// ============================================================

/// เริ่ม tutorial พร้อม automatic navigation
/// เรียกจาก MainNavigationScreen
///
/// Parameters:
/// - ref: WidgetRef สำหรับ access providers
/// - context: BuildContext สำหรับแสดง overlay
/// - userId: User ID สำหรับ tracking
/// - onNavigate: Callback เมื่อต้อง navigate ไป tab อื่น
/// - onFinish: Callback เมื่อ tutorial จบ (optional)
void startTutorialWithNavigation({
  required WidgetRef ref,
  required context,
  required String userId,
  required Function(int tabIndex) onNavigate,
  VoidCallback? onFinish,
}) {
  final tutorialService = ref.read(tutorialServiceProvider);
  final onboardingService = ref.read(onboardingServiceProvider);
  final tutorialKeys = ref.read(tutorialKeysProvider);

  // Mark ว่า tutorial กำลังแสดง
  ref.read(isTutorialShowingProvider.notifier).state = true;

  // Import และใช้ TutorialTargetsData
  // Note: ต้อง import '../data/tutorial_targets_data.dart'
  // แต่เนื่องจากเป็น static data เราจะ pass targets เข้ามาแทน

  tutorialService.startTutorial(
    context: context,
    targets: _getDefaultTargets(tutorialKeys),
    onNavigate: (tabIndex) {
      ref.read(tutorialCurrentTabProvider.notifier).state = tabIndex;
      onNavigate(tabIndex);
    },
    onFinish: () async {
      // Mark tutorial as completed
      await onboardingService.markTutorialCompleted(userId);

      // Reset state
      ref.read(isTutorialShowingProvider.notifier).state = false;

      // Call custom onFinish callback
      onFinish?.call();
    },
    onSkip: () {
      // Skip ก็ถือว่าเสร็จ - จะไม่แสดงอีก
      ref.read(isTutorialShowingProvider.notifier).state = false;
    },
  );
}

/// สร้าง default tutorial targets
/// แยกออกมาเพื่อหลีกเลี่ยง circular dependency
List<TutorialTarget> _getDefaultTargets(TutorialKeys keys) {
  return [
    // Home Tab
    TutorialTarget(
      id: 'home_tab',
      title: 'หน้าหลัก',
      description:
          'นี่คือหน้าหลักของคุณ\nดูสถานะการทำงาน สรุปประจำเดือน และกิจกรรมต่างๆ',
      navigateToTab: 0,
      shape: TutorialShape.circle,
      contentPosition: ContentPosition.bottom,
    ).copyWithKey(keys.homeTabKey),

    // Clock-in Button
    TutorialTarget(
      id: 'clock_in',
      title: 'ลงเวลาเข้า-ออกงาน',
      description:
          'กดที่นี่เพื่อลงเวลาเข้างาน\nเมื่อเลิกงานก็กดอีกครั้งเพื่อลงเวลาออก',
      shape: TutorialShape.rectangle,
      contentPosition: ContentPosition.bottom,
    ).copyWithKey(keys.clockInButtonKey),

    // Zone Selector
    TutorialTarget(
      id: 'zone_selector',
      title: 'เลือกโซน',
      description: 'เลือกโซนที่คุณดูแลวันนี้\nระบบจะแสดงคนไข้และงานของโซนนั้น',
      shape: TutorialShape.rectangle,
      contentPosition: ContentPosition.bottom,
    ).copyWithKey(keys.zoneSelectorKey),

    // Checklist Tab
    TutorialTarget(
      id: 'checklist_tab',
      title: 'เช็คลิสต์',
      description: 'กดที่นี่เพื่อดูรายการงานประจำวัน\nติ๊กเสร็จเมื่อทำงานเสร็จแล้ว',
      navigateToTab: 1,
      shape: TutorialShape.circle,
      contentPosition: ContentPosition.top,
    ).copyWithKey(keys.checklistTabKey),

    // Residents Tab
    TutorialTarget(
      id: 'residents_tab',
      title: 'คนไข้',
      description: 'กดที่นี่เพื่อดูข้อมูลคนไข้\nดูประวัติ ยา และการดูแลพิเศษ',
      navigateToTab: 2,
      shape: TutorialShape.circle,
      contentPosition: ContentPosition.top,
    ).copyWithKey(keys.residentsTabKey),

    // Board Tab
    TutorialTarget(
      id: 'board_tab',
      title: 'กระดานข่าว',
      description: 'กดที่นี่เพื่อดูประกาศและข่าวสาร\nอ่านโพสต์สำคัญจากทีม',
      navigateToTab: 3,
      shape: TutorialShape.circle,
      contentPosition: ContentPosition.top,
    ).copyWithKey(keys.boardTabKey),

    // Settings Tab
    TutorialTarget(
      id: 'settings_tab',
      title: 'โปรไฟล์และตั้งค่า',
      description:
          'กดที่นี่เพื่อจัดการบัญชี\nดู badges ที่สะสม และออกจากระบบ\n\nเสร็จสิ้น! คุณพร้อมใช้งานแล้ว',
      navigateToTab: 4,
      shape: TutorialShape.circle,
      contentPosition: ContentPosition.top,
    ).copyWithKey(keys.settingsTabKey),
  ];
}
