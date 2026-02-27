import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../home/screens/home_screen.dart';
import '../../checklist/screens/checklist_screen.dart';
import '../../board/screens/board_screen.dart';
import '../../residents/screens/residents_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../shift_summary/providers/shift_summary_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../board/providers/post_provider.dart';
import '../../incident_reflection/providers/incident_provider.dart';
import '../../checklist/providers/task_provider.dart'; // for userChangeCounterProvider
import '../../onboarding/models/tutorial_target.dart';
import '../../onboarding/widgets/new_feature_badge.dart';
import '../../profile_setup/providers/profile_setup_provider.dart';

// =============================================================================
// Provider สำหรับตรวจสอบสถานะ employment และสิทธิ์การเข้าถึง
// =============================================================================

/// Provider ตรวจสอบว่า user ปัจจุบันลาออกแล้วหรือยัง
/// ใช้สำหรับซ่อน/แสดง tabs ตามสถานะ
final isUserResignedProvider = FutureProvider<bool>((ref) async {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);
  return await UserService().isResigned();
});

/// Provider ดึง employment type ของ user ปัจจุบัน
/// Returns: 'full_time', 'part_time', 'trainee', 'resigned', หรือ null
final userEmploymentTypeProvider = FutureProvider<String?>((ref) async {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);
  return await UserService().getEmploymentType();
});

/// Provider ตรวจสอบว่า user ควรเห็น tabs เฉพาะ (limited view) หรือไม่
///
/// **กฎการแสดง tabs:**
/// - **ลาออก (resigned)**: แสดงแค่ Home + Settings เสมอ
/// - **Part-time ที่ยังไม่ขึ้นเวร**: แสดงแค่ Home + Settings
/// - **Part-time ที่ขึ้นเวรแล้ว**: แสดงทุก tab
/// - **Full-time/Trainee**: แสดงทุก tab เสมอ
final shouldShowLimitedTabsProvider = FutureProvider<bool>((ref) async {
  // Watch user change counter เพื่อ refresh เมื่อ impersonate
  ref.watch(userChangeCounterProvider);

  final userService = UserService();

  // 1. เช็คว่าลาออกหรือยัง - ถ้าลาออกแล้ว ต้องแสดง limited tabs เสมอ
  final isResigned = await userService.isResigned();
  if (isResigned) return true;

  // 2. เช็ค employment type
  final employmentType = await userService.getEmploymentType();

  // 3. ถ้าเป็น part-time ต้องเช็คว่าขึ้นเวรหรือยัง
  if (employmentType == 'part_time') {
    // ดึงสถานะ clock-in จาก currentShiftProvider
    final currentShiftAsync = ref.watch(currentShiftProvider);
    final currentShift = currentShiftAsync.value;

    // ถ้ายังไม่ขึ้นเวร (shift == null หรือ isClockedIn == false)
    // ให้แสดง limited tabs
    if (currentShift == null || !currentShift.isClockedIn) {
      return true;
    }
  }

  // 4. กรณีอื่นๆ (full_time, trainee, หรือ part-time ที่ขึ้นเวรแล้ว)
  // ให้แสดงทุก tab
  return false;
});

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

  /// สร้าง screens list แบบ dynamic ตามสถานะ employment และ clock-in
  ///
  /// **Limited View (แสดงแค่ Home + Settings):**
  /// - พนักงานที่ลาออกแล้ว
  /// - Part-time ที่ยังไม่ขึ้นเวร
  ///
  /// **Full View (แสดงทุก tab):**
  /// - Full-time, Trainee
  /// - Part-time ที่ขึ้นเวรแล้ว
  List<Widget> _buildScreensList(bool showLimited) {
    if (showLimited) {
      // Limited view: แสดงแค่ Home, Settings (ไม่มี Checklist, Residents, Board)
      return const [
        HomeScreen(),
        SettingsScreen(),
      ];
    } else {
      // Full view: แสดงทุก tab
      return const [
        HomeScreen(),
        ChecklistScreen(),
        ResidentsScreen(),
        BoardScreen(),
        SettingsScreen(),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    // ตรวจสอบว่ากำลัง impersonate อยู่หรือไม่
    // ใช้ watch เพื่อให้ rebuild เมื่อ user change
    ref.watch(userChangeCounterProvider);
    final userService = UserService();
    final isImpersonating = userService.isImpersonating;

    // ตรวจสอบว่าควรแสดง limited tabs หรือไม่
    // (ลาออก หรือ part-time ที่ยังไม่ขึ้นเวร)
    final shouldShowLimitedAsync = ref.watch(shouldShowLimitedTabsProvider);
    final shouldShowLimited = shouldShowLimitedAsync.value ?? false;

    // สร้าง screens list ตามสถานะ
    final screens = _buildScreensList(shouldShowLimited);

    // ถ้า index เกินจำนวน screens (เกิดขึ้นเมื่อเปลี่ยนจากปกติเป็นลาออก)
    // ให้กลับไป Home
    if (_currentIndex >= screens.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentIndex = 0);
        }
      });
    }

    // คำนวณ index ที่ถูกต้องสำหรับ IndexedStack
    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: Column(
        children: [
          // แสดง Impersonation Banner ถ้ากำลัง impersonate
          if (isImpersonating) _buildGlobalImpersonationBanner(userService),
          // แสดง screens
          Expanded(
            child: IndexedStack(index: safeIndex, children: screens),
          ),
        ],
      ),
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
              children: _buildNavItems(shouldShowLimited),
            ),
          ),
        ),
      ),
    );
  }

  /// สร้าง navigation items แบบ dynamic ตามสถานะ employment และ clock-in
  ///
  /// **Limited View:** Home(0), Settings(1)
  /// **Full View:** Home(0), Checklist(1), Residents(2), Board(3), Settings(4)
  List<Widget> _buildNavItems(bool showLimited) {
    if (showLimited) {
      // Limited view: Home(0), Settings(1) - ไม่มี Checklist, Residents, Board
      return [
        _buildNavItem(
          index: 0,
          icon: HugeIcons.strokeRoundedHome01,
          activeIcon: HugeIcons.strokeRoundedHome01,
          label: 'หน้าหลัก',
          tutorialKey: _tutorialKeys.homeTabKey,
          tabId: 'home',
        ),
        _buildProfileNavItem(navIndex: 1),
      ];
    } else {
      // พนักงานปกติ: ทุก tab
      return [
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
        _buildBoardNavItem(navIndex: 3),
        _buildProfileNavItem(navIndex: 4),
      ];
    }
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
  /// [navIndex] คือ index ใน navigation bar (เปลี่ยนได้ตามจำนวน tabs ที่แสดง)
  Widget _buildBoardNavItem({int navIndex = 3}) {
    final unreadCountAsync = ref.watch(totalUnreadPostCountProvider);
    final hasUnreadPosts = unreadCountAsync.maybeWhen(
      data: (count) => count > 0,
      orElse: () => false,
    );

    final isSelected = _currentIndex == navIndex;

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
          _currentIndex = navIndex;
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

  /// Build profile nav item with notification badge for pending absences, notifications, incidents, and incomplete profile
  /// [navIndex] คือ index ใน navigation bar (เปลี่ยนได้ตามจำนวน tabs ที่แสดง)
  Widget _buildProfileNavItem({int navIndex = 4}) {
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

    // เพิ่ม: ตรวจสอบ profile ที่ยังกรอกไม่ครบ (5 sections required)
    final profileCompletionAsync = ref.watch(profileCompletionStatusProvider);
    final hasIncompleteProfile = profileCompletionAsync.maybeWhen(
      data: (status) {
        // ใช้ incompleteCount จาก ProfileCompletionStatus โดยตรง
        return status.incompleteCount > 0;
      },
      orElse: () => false,
    );

    final isSelected = _currentIndex == navIndex;

    return GestureDetector(
      key: _tutorialKeys.settingsTabKey, // ใช้ key สำหรับ tutorial highlight
      onTap: () {
        setState(() {
          _currentIndex = navIndex;
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
                // Red dot for unread notifications, pending absences, pending incidents, or incomplete profile
                if (hasUnreadNotifications || hasPendingAbsence || hasPendingIncidents || hasIncompleteProfile)
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

  /// สร้าง Global Impersonation Banner
  /// แสดงด้านบนสุดของแอปตลอดเวลาเมื่อกำลัง impersonate user อื่น
  Widget _buildGlobalImpersonationBanner(UserService userService) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade600,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Icon แจ้งเตือน
              HugeIcon(
                icon: HugeIcons.strokeRoundedUserSwitch,
                size: AppIconSize.md,
                color: Colors.white,
              ),
              AppSpacing.horizontalGapSm,
              // ข้อความแสดงชื่อ user ที่กำลัง impersonate
              Expanded(
                child: FutureBuilder<String?>(
                  future: _getImpersonatedUserName(userService),
                  builder: (context, snapshot) {
                    final name = snapshot.data ?? 'Unknown User';
                    return Text(
                      'กำลังใช้งานในนาม: $name',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
              // ปุ่มหยุด impersonate
              GestureDetector(
                onTap: _stopImpersonating,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.smallRadius,
                  ),
                  child: Text(
                    'หยุด',
                    style: AppTypography.caption.copyWith(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ดึงชื่อของ user ที่กำลัง impersonate
  Future<String?> _getImpersonatedUserName(UserService userService) async {
    final effectiveUserId = userService.effectiveUserId;
    if (effectiveUserId == null) return null;

    try {
      // ใช้ getUserName() ซึ่งจะดึงชื่อของ effectiveUserId
      return await userService.getUserName();
    } catch (e) {
      return 'Unknown';
    }
  }

  /// หยุด impersonate และกลับมาเป็น user จริง
  void _stopImpersonating() {
    UserService().stopImpersonating();

    // Increment user change counter เพื่อ refresh Riverpod providers
    ref.read(userChangeCounterProvider.notifier).state++;

    // แจ้ง user ว่าหยุด impersonate แล้ว
    if (mounted) {
      AppToast.success(context, 'กลับมาเป็นตัวคุณเองแล้ว');
    }
  }
}
