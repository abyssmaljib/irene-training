import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
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

  /// แสดง DEV badge ข้างๆ title (สำหรับ dev mode)
  final bool showDevBadge;

  const IreneAppBar({
    super.key,
    required this.title,
    this.titleBadge,
    this.actions,
    this.showFilterButton = false,
    this.showProfileButton = false,
    this.isFilterActive = false,
    this.filterCount = 0,
    this.onFilterTap,
    this.onProfileTap,
    this.trailing,
    this.showDevBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final rightActions = _buildRightActions(context);

    return SliverAppBar(
      pinned: false,
      floating: true,
      snap: true,
      backgroundColor: AppColors.secondaryBackground,
      automaticallyImplyLeading: false,
      elevation: 0,
      titleSpacing: 0,
      title: SizedBox(
        height: kToolbarHeight,
        child: Stack(
          children: [
            // Center: Title อยู่ตรงกลางหน้าจอเสมอ (badge อยู่ข้างๆ ไม่นับรวม)
            Positioned.fill(
              child: Row(
                children: [
                  // Spacer ซ้าย - ขยายเท่ากับฝั่งขวา
                  Expanded(child: SizedBox.shrink()),
                  // Title ตรงกลาง
                  Text(
                    title,
                    style: AppTypography.heading2,
                  ),
                  // Spacer ขวา + badges
                  Expanded(
                    child: Row(
                      children: [
                        // Dev mode badge
                        if (showDevBadge) ...[
                          SizedBox(width: 6),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE082),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFFB300),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'DEV',
                              style: AppTypography.caption.copyWith(
                                color: const Color(0xFFE65100),
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                        // Title badge (count)
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
                ],
              ),
            ),

            // Left: Filter button (padding 8px จากขอบ)
            if (showFilterButton)
              Positioned(
                left: AppSpacing.sm,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _FilterButton(
                    isActive: isFilterActive,
                    count: filterCount,
                    onTap: onFilterTap,
                  ),
                ),
              ),

            // Right: Actions (padding 8px จากขอบ)
            if (rightActions.isNotEmpty)
              Positioned(
                right: AppSpacing.sm,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: rightActions,
                  ),
                ),
              ),
          ],
        ),
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
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedFilterHorizontal,
                color: AppColors.primary,
                size: AppIconSize.lg,
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
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedUser,
            color: AppColors.primary,
            size: AppIconSize.lg,
          ),
        ),
      ),
    );
  }
}

/// IreneSecondaryAppBar - AppBar สำหรับหน้ารอง
/// มีปุ่มย้อนกลับ, title ชิดซ้าย, รองรับ actions และ bottom (TabBar)
/// รองรับ titleIcon, titleWidget, backgroundColor, leadingIcon, centerTitle
class IreneSecondaryAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Title text - ถ้าไม่ส่งมาและมี titleIcon จะแสดงแค่ icon
  final String? title;

  /// Icon แสดงก่อน title (optional)
  /// ใช้ dynamic เพื่อรองรับ HugeIcons
  final dynamic titleIcon;

  /// Custom title widget - ถ้าส่งมาจะใช้แทน title และ titleIcon
  /// เหมาะสำหรับกรณีที่ต้องการ title แบบ custom เช่น search field, 2 บรรทัด
  final Widget? titleWidget;

  /// สี background ของ AppBar (default: AppColors.secondaryBackground)
  final Color? backgroundColor;

  /// สี foreground (icon, text) ของ AppBar (default: AppColors.primaryText)
  final Color? foregroundColor;

  /// Icon สำหรับปุ่มย้อนกลับ (default: ArrowLeft01)
  /// ใช้ dynamic เพื่อรองรับ HugeIcons
  final dynamic leadingIcon;

  /// จัดตำแหน่ง title ให้อยู่ตรงกลาง (default: false)
  final bool centerTitle;

  final List<Widget>? actions;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final double? toolbarHeight;

  const IreneSecondaryAppBar({
    super.key,
    this.title,
    this.titleIcon,
    this.titleWidget,
    this.backgroundColor,
    this.foregroundColor,
    this.leadingIcon,
    this.centerTitle = false,
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
    // กำหนดสีที่ใช้
    final bgColor = backgroundColor ?? AppColors.secondaryBackground;
    final fgColor = foregroundColor ?? AppColors.primaryText;

    return AppBar(
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      elevation: 0,
      toolbarHeight: toolbarHeight,
      leading: IconButton(
        onPressed: onBack ?? () => Navigator.pop(context),
        icon: HugeIcon(
          icon: leadingIcon ?? HugeIcons.strokeRoundedArrowLeft01,
          color: fgColor,
        ),
      ),
      title: titleWidget ?? _buildTitle(fgColor),
      centerTitle: centerTitle,
      actions: actions,
      bottom: bottom,
    );
  }

  /// สร้าง title widget ที่รองรับทั้ง icon และ text
  Widget _buildTitle(Color textColor) {
    // ถ้ามีแค่ title ไม่มี icon - แสดง text อย่างเดียว
    if (titleIcon == null && title != null) {
      return Text(
        title!,
        style: AppTypography.title.copyWith(color: textColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // ถ้ามี icon (อาจมีหรือไม่มี title ก็ได้)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (titleIcon != null)
          HugeIcon(
            icon: titleIcon,
            size: AppIconSize.xl,
            color: textColor,
          ),
        if (titleIcon != null && title != null)
          const SizedBox(width: 8),
        if (title != null)
          Flexible(
            child: Text(
              title!,
              style: AppTypography.title.copyWith(color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
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
