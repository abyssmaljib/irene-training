import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

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
import '../../board/providers/post_provider.dart';
import '../../incident_reflection/providers/incident_provider.dart';
import '../../onboarding/models/tutorial_target.dart';
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
  /// NOTE: Tutorial feature ถูกซ่อนไว้ชั่วคราว
  Future<void> _checkAndShowTutorial() async {
    // TODO: Tutorial feature hidden - uncomment to re-enable
    // final userId = Supabase.instance.client.auth.currentUser?.id;
    // if (userId == null) return;
    // final onboardingService = ref.read(onboardingServiceProvider);
    // final shouldShow = onboardingService.shouldShowTutorial(userId);
    // if (shouldShow && mounted) {
    //   await Future.delayed(const Duration(milliseconds: 500));
    //   if (mounted) {
    //     _startTutorial(userId);
    //   }
    // } else {
    //   _checkAndShowWhatsNew(userId);
    // }
  }

  // NOTE: Tutorial feature ถูกซ่อนไว้ชั่วคราว
  // /// เริ่ม tutorial
  // void _startTutorial(String userId) {
  //   startTutorialWithNavigation(
  //     ref: ref,
  //     context: context,
  //     userId: userId,
  //     onNavigate: (tabIndex) {
  //       setState(() {
  //         _currentIndex = tabIndex;
  //       });
  //     },
  //     onFinish: () {
  //       _checkAndShowWhatsNew(userId);
  //     },
  //   );
  // }

  /// เริ่ม tutorial ใหม่ (สำหรับ replay)
  /// NOTE: Tutorial feature ถูกซ่อนไว้ชั่วคราว
  void replayTutorial() {
    // final userId = Supabase.instance.client.auth.currentUser?.id;
    // if (userId == null) return;
    // setState(() {
    //   _currentIndex = 0;
    // });
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _startTutorial(userId);
    // });
  }

  // NOTE: What's New feature ถูกซ่อนไว้ชั่วคราว
  // Future<void> _checkAndShowWhatsNew(String userId) async {
  //   final onboardingService = ref.read(onboardingServiceProvider);
  //   final announcement =
  //       await onboardingService.getNewVersionAnnouncement(userId);
  //   if (announcement != null && mounted) {
  //     await WhatsNewDialog.show(context, announcement);
  //     await onboardingService.updateLastSeenVersion(userId);
  //   }
  // }

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
                _buildBoardNavItem(),
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

    // NOTE: NEW badge feature ถูกซ่อนไว้ชั่วคราว
    // final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    // final newFeatureTabsAsync = ref.watch(newFeatureTabsProvider(userId));
    // final hasNewFeature = tabId != null &&
    //     newFeatureTabsAsync.maybeWhen(
    //       data: (tabs) => tabs.contains(tabId),
    //       orElse: () => false,
    //     );
    const hasNewFeature = false;

    return GestureDetector(
      key: tutorialKey, // ใช้ key สำหรับ tutorial highlight
      onTap: () {
        setState(() {
          _currentIndex = index;
        });

        // NOTE: NEW badge dismiss ถูกซ่อนไว้ชั่วคราว
        // if (hasNewFeature) {
        //   final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
        //   ref.read(onboardingServiceProvider).dismissFeatureTab(userId, tabId!);
        //   ref.invalidate(newFeatureTabsProvider(userId));
        // }
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

  /// Build board nav item with red dot for unread posts
  Widget _buildBoardNavItem() {
    final unreadCountAsync = ref.watch(totalUnreadPostCountProvider);
    final hasUnreadPosts = unreadCountAsync.maybeWhen(
      data: (count) => count > 0,
      orElse: () => false,
    );

    final isSelected = _currentIndex == 3;

    // NOTE: NEW badge feature ถูกซ่อนไว้ชั่วคราว
    // final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    // final newFeatureTabsAsync = ref.watch(newFeatureTabsProvider(userId));
    // final hasNewFeature = newFeatureTabsAsync.maybeWhen(
    //   data: (tabs) => tabs.contains('board'),
    //   orElse: () => false,
    // );
    const hasNewFeature = false;

    return GestureDetector(
      key: _tutorialKeys.boardTabKey,
      onTap: () {
        setState(() {
          _currentIndex = 3;
        });

        // NOTE: NEW badge dismiss ถูกซ่อนไว้ชั่วคราว
        // if (hasNewFeature) {
        //   final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
        //   ref.read(onboardingServiceProvider).dismissFeatureTab(userId, 'board');
        //   ref.invalidate(newFeatureTabsProvider(userId));
        // }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon พร้อม badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                // NEW badge (ถ้ามี feature ใหม่)
                WithNewBadge(
                  showBadge: hasNewFeature,
                  badgeOffset: const Offset(-6, -2),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedNews01,
                    color: isSelected ? AppColors.primary : AppColors.secondaryText,
                    size: AppIconSize.xl,
                  ),
                ),
                // Red dot สำหรับ unread posts (แสดงเมื่อไม่มี NEW badge)
                if (hasUnreadPosts && !hasNewFeature)
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
              'กระดานข่าว',
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

  /// Build profile nav item with notification badge for pending absences, notifications, and incidents
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

    // เพิ่ม: ตรวจสอบ pending incidents (รวม pending + in_progress)
    final pendingIncidentCount = ref.watch(pendingIncidentCountProvider);
    final hasPendingIncidents = pendingIncidentCount > 0;

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
                // Red dot for unread notifications, pending absences, or pending incidents
                if (hasUnreadNotifications || hasPendingAbsence || hasPendingIncidents)
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
