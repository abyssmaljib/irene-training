import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../home/screens/home_screen.dart';
import '../../checklist/screens/checklist_screen.dart';
import '../../board/screens/board_screen.dart';
import '../../residents/screens/residents_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../shift_summary/providers/shift_summary_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../onboarding/models/tutorial_target.dart';
import '../../onboarding/widgets/whats_new_dialog.dart';
import '../../onboarding/widgets/new_feature_badge.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  /// Navigate to a specific tab
  static void navigateToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainNavigationScreenState>();
    state?.setTab(index);
  }

  /// Replay tutorial from any child widget
  static void replayTutorial(BuildContext context) {
    final state = context.findAncestorStateOfType<_MainNavigationScreenState>();
    state?.replayTutorial();
  }

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  // Tutorial Keys - ใช้สำหรับ highlight navigation items
  late final TutorialKeys _tutorialKeys;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // ดึง TutorialKeys จาก provider
    _tutorialKeys = TutorialKeys();

    // ตรวจสอบและแสดง tutorial หลังจาก build เสร็จ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  /// ตรวจสอบและแสดง tutorial สำหรับ user ใหม่
  Future<void> _checkAndShowTutorial() async {
    // ดึง user ID จาก Supabase
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // ตรวจสอบว่าควรแสดง tutorial หรือไม่
    final onboardingService = ref.read(onboardingServiceProvider);
    final shouldShow = onboardingService.shouldShowTutorial(userId);

    if (shouldShow && mounted) {
      // รอสักครู่ให้ UI พร้อม
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _startTutorial(userId);
      }
    } else {
      // ถ้าไม่ต้องแสดง tutorial ให้ตรวจสอบ What's New
      _checkAndShowWhatsNew(userId);
    }
  }

  /// เริ่ม tutorial
  void _startTutorial(String userId) {
    startTutorialWithNavigation(
      ref: ref,
      context: context,
      userId: userId,
      onNavigate: (tabIndex) {
        // Navigate ไป tab ที่กำหนด
        setState(() {
          _currentIndex = tabIndex;
        });
      },
      onFinish: () {
        // เมื่อ tutorial จบ ให้ตรวจสอบ What's New
        _checkAndShowWhatsNew(userId);
      },
    );
  }

  /// เริ่ม tutorial ใหม่ (สำหรับ replay)
  void replayTutorial() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Navigate กลับไป Home ก่อน
    setState(() {
      _currentIndex = 0;
    });

    // รอให้ UI update แล้วเริ่ม tutorial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTutorial(userId);
    });
  }

  /// ตรวจสอบและแสดง What's New dialog
  Future<void> _checkAndShowWhatsNew(String userId) async {
    final onboardingService = ref.read(onboardingServiceProvider);
    final announcement =
        await onboardingService.getNewVersionAnnouncement(userId);

    if (announcement != null && mounted) {
      // แสดง What's New dialog
      await WhatsNewDialog.show(context, announcement);
      // บันทึกว่า user เห็น version นี้แล้ว
      await onboardingService.updateLastSeenVersion(userId);
    }
  }

  void setTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const ChecklistScreen(),
    const ResidentsScreen(),
    const BoardScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          boxShadow: [AppShadows.subtle],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: HugeIcons.strokeRoundedHome01,
                  activeIcon: HugeIcons.strokeRoundedHome01,
                  label: 'หน้าหลัก',
                  tutorialKey: _tutorialKeys.homeTabKey,
                  tabId: 'home',
                ),
                _buildNavItem(
                  index: 1,
                  icon: HugeIcons.strokeRoundedTask01,
                  activeIcon: HugeIcons.strokeRoundedTask01,
                  label: 'เช็คลิสต์',
                  tutorialKey: _tutorialKeys.checklistTabKey,
                  tabId: 'checklist',
                ),
                _buildNavItem(
                  index: 2,
                  icon: HugeIcons.strokeRoundedUserGroup,
                  activeIcon: HugeIcons.strokeRoundedUserGroup,
                  label: 'คนไข้',
                  tutorialKey: _tutorialKeys.residentsTabKey,
                  tabId: 'residents',
                ),
                _buildNavItem(
                  index: 3,
                  icon: HugeIcons.strokeRoundedNews01,
                  activeIcon: HugeIcons.strokeRoundedNews01,
                  label: 'กระดานข่าว',
                  tutorialKey: _tutorialKeys.boardTabKey,
                  tabId: 'board',
                ),
                _buildProfileNavItem(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required dynamic icon,
    required dynamic activeIcon,
    required String label,
    GlobalKey? tutorialKey,
    String? tabId, // Tab ID สำหรับตรวจสอบ NEW badge
  }) {
    final isSelected = _currentIndex == index;

    // ตรวจสอบว่า tab นี้มี feature ใหม่หรือไม่
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final newFeatureTabsAsync = ref.watch(newFeatureTabsProvider(userId));
    final hasNewFeature = tabId != null &&
        newFeatureTabsAsync.maybeWhen(
          data: (tabs) => tabs.contains(tabId),
          orElse: () => false,
        );

    return GestureDetector(
      key: tutorialKey, // ใช้ key สำหรับ tutorial highlight
      onTap: () {
        setState(() {
          _currentIndex = index;
        });

        // Dismiss NEW badge เมื่อ user tap tab ที่มี feature ใหม่
        // Note: hasNewFeature เป็น true ก็ต่อเมื่อ tabId != null
        if (hasNewFeature) {
          ref.read(onboardingServiceProvider).dismissFeatureTab(userId, tabId);
          ref.invalidate(newFeatureTabsProvider(userId));
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon พร้อม NEW badge (ถ้ามี)
            WithNewBadge(
              showBadge: hasNewFeature,
              badgeOffset: const Offset(-6, -2),
              child: HugeIcon(
                icon: isSelected ? activeIcon : icon,
                color: isSelected ? AppColors.primary : AppColors.secondaryText,
                size: AppIconSize.xl,
              ),
            ),
            AppSpacing.verticalGapXs,
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build profile nav item with notification badge for pending absences and notifications
  Widget _buildProfileNavItem() {
    final pendingAbsenceAsync = ref.watch(pendingAbsenceCountProvider);
    final hasPendingAbsence = pendingAbsenceAsync.maybeWhen(
      data: (count) => count > 0,
      orElse: () => false,
    );

    final unreadNotificationAsync = ref.watch(unreadNotificationCountProvider);
    final hasUnreadNotifications = unreadNotificationAsync.maybeWhen(
      data: (count) => count > 0,
      orElse: () => false,
    );

    final isSelected = _currentIndex == 4;

    return GestureDetector(
      key: _tutorialKeys.settingsTabKey, // ใช้ key สำหรับ tutorial highlight
      onTap: () {
        setState(() {
          _currentIndex = 4;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedUser,
                  color: isSelected ? AppColors.primary : AppColors.secondaryText,
                  size: AppIconSize.xl,
                ),
                // Red dot for unread notifications or pending absences
                if (hasUnreadNotifications || hasPendingAbsence)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.secondaryBackground,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.verticalGapXs,
            Text(
              'โปรไฟล์',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
