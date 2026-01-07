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

class MainNavigationScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  /// Navigate to a specific tab
  static void navigateToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainNavigationScreenState>();
    state?.setTab(index);
  }

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
                ),
                _buildNavItem(
                  index: 1,
                  icon: HugeIcons.strokeRoundedTask01,
                  activeIcon: HugeIcons.strokeRoundedTask01,
                  label: 'เช็คลิสต์',
                ),
                _buildNavItem(
                  index: 2,
                  icon: HugeIcons.strokeRoundedUserGroup,
                  activeIcon: HugeIcons.strokeRoundedUserGroup,
                  label: 'คนไข้',
                ),
                _buildNavItem(
                  index: 3,
                  icon: HugeIcons.strokeRoundedNews01,
                  activeIcon: HugeIcons.strokeRoundedNews01,
                  label: 'กระดานข่าว',
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
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.secondaryText,
              size: AppIconSize.xl,
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

  /// Build profile nav item with notification badge for pending absences
  Widget _buildProfileNavItem() {
    final pendingAbsenceAsync = ref.watch(pendingAbsenceCountProvider);
    final hasPendingAbsence = pendingAbsenceAsync.maybeWhen(
      data: (count) => count > 0,
      orElse: () => false,
    );

    final isSelected = _currentIndex == 4;

    return GestureDetector(
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
                // Red notification dot for pending absences
                if (hasPendingAbsence)
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
