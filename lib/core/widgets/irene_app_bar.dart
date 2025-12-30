import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// IreneAppBar - Reusable SliverAppBar component
/// ใช้ได้ทุกหน้าในแอป ตั้งค่า title และ actions ได้
class IreneAppBar extends StatelessWidget {
  final String title;
  final String? titleBadge; // Badge text next to title (e.g. count)
  final List<Widget>? actions;
  final bool showFilterButton;
  final bool showProfileButton;
  final bool isFilterActive;
  final int filterCount;
  final VoidCallback? onFilterTap;
  final VoidCallback? onProfileTap;
  final Widget? trailing;

  const IreneAppBar({
    super.key,
    required this.title,
    this.titleBadge,
    this.actions,
    this.showFilterButton = false,
    this.showProfileButton = true,
    this.isFilterActive = false,
    this.filterCount = 0,
    this.onFilterTap,
    this.onProfileTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: false,
      floating: true,
      snap: true, // Snap back immediately when scrolling up
      backgroundColor: AppColors.secondaryBackground,
      automaticallyImplyLeading: false,
      elevation: 0,
      title: Row(
        children: [
          // Left: Filter button
          if (showFilterButton)
            _FilterButton(
              isActive: isFilterActive,
              count: filterCount,
              onTap: onFilterTap,
            )
          else
            SizedBox(width: 40), // Placeholder for balance

          // Center: Title with optional badge
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Spacer to offset the badge width for visual centering
                if (titleBadge != null) SizedBox(width: 20),
                Text(
                  title,
                  style: AppTypography.heading2,
                ),
                if (titleBadge != null) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      titleBadge!,
                      style: AppTypography.body.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Right: Actions (custom actions + profile)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildRightActions(context),
          ),
        ],
      ),
      centerTitle: false,
    );
  }

  List<Widget> _buildRightActions(BuildContext context) {
    final List<Widget> actionWidgets = [];

    // Custom actions first
    if (actions != null) {
      actionWidgets.addAll(actions!);
    }

    // Profile button
    if (showProfileButton) {
      actionWidgets.add(
        _ProfileButton(onTap: onProfileTap),
      );
    }

    // Custom trailing widget
    if (trailing != null) {
      actionWidgets.add(trailing!);
    }

    // Add spacing between items
    if (actionWidgets.length > 1) {
      final spacedWidgets = <Widget>[];
      for (int i = 0; i < actionWidgets.length; i++) {
        spacedWidgets.add(actionWidgets[i]);
        if (i < actionWidgets.length - 1) {
          spacedWidgets.add(SizedBox(width: AppSpacing.sm));
        }
      }
      return spacedWidgets;
    }

    return actionWidgets;
  }
}

/// Filter button with active state indicator and badge count
class _FilterButton extends StatelessWidget {
  final bool isActive;
  final int count;
  final VoidCallback? onTap;

  const _FilterButton({
    this.isActive = false,
    this.count = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: isActive ? AppColors.accent1 : AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Iconsax.filter,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
        ),
        // Badge count - งานค้างใน 2 ชม. (แดงพาสเทล)
        if (count > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.tagFailedBg, // แดงพาสเทล
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: AppTypography.caption.copyWith(
                  color: AppColors.tagFailedText, // ตัวอักษรแดงเข้ม
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Profile avatar button
class _ProfileButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _ProfileButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            Iconsax.user,
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// IreneSecondaryAppBar - AppBar สำหรับหน้ารอง
/// มีปุ่มย้อนกลับ, title ชิดซ้าย, รองรับ actions และ bottom (TabBar)
class IreneSecondaryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final double? toolbarHeight;

  const IreneSecondaryAppBar({
    super.key,
    required this.title,
    this.actions,
    this.onBack,
    this.bottom,
    this.toolbarHeight,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        (toolbarHeight ?? kToolbarHeight) + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.secondaryBackground,
      elevation: 0,
      toolbarHeight: toolbarHeight,
      leading: IconButton(
        onPressed: onBack ?? () => Navigator.pop(context),
        icon: const Icon(
          Iconsax.arrow_left,
          color: AppColors.primaryText,
        ),
      ),
      title: Text(
        title,
        style: AppTypography.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: false,
      actions: actions,
      bottom: bottom,
    );
  }
}

/// Helper extension to easily use IreneAppBar in CustomScrollView
extension IreneAppBarHelper on IreneAppBar {
  /// Wraps this SliverAppBar for use in a Scaffold with NestedScrollView
  Widget asScaffoldAppBar({
    required Widget body,
    Color? backgroundColor,
  }) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [this],
        body: body,
      ),
    );
  }
}
