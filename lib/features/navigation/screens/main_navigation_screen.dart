import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../home/screens/home_screen.dart';
import '../../checklist/screens/checklist_screen.dart';
import '../../board/screens/board_screen.dart';
import '../../residents/screens/residents_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ChecklistScreen(),
    const BoardScreen(),
    const ResidentsScreen(),
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
                  icon: Iconsax.home_2,
                  activeIcon: Iconsax.home_15,
                  label: 'หน้าหลัก',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Iconsax.task_square,
                  activeIcon: Iconsax.task_square5,
                  label: 'เช็คลิสต์',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Iconsax.document_text,
                  activeIcon: Iconsax.document_text_1,
                  label: 'กระดานข่าว',
                ),
                _buildNavItem(
                  index: 3,
                  icon: Iconsax.health,
                  activeIcon: Iconsax.health5,
                  label: 'คนไข้',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
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
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.secondaryText,
              size: 24,
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
}
