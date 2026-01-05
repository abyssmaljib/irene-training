import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart' show AppSpacing, AppRadius;
import '../../providers/resident_detail_provider.dart';

/// Segmented Control สำหรับเลือก View (Care, Clinical, Info)
/// มี sliding animation แบบ iOS
class ViewSegmentedControl extends StatelessWidget {
  final DetailViewType selectedView;
  final ValueChanged<DetailViewType> onViewChanged;

  const ViewSegmentedControl({
    super.key,
    required this.selectedView,
    required this.onViewChanged,
  });

  static const _segments = [
    (label: 'ดูแล', icon: Iconsax.heart, type: DetailViewType.care),
    (label: 'คลินิก', icon: Iconsax.health, type: DetailViewType.clinical),
    (label: 'ข้อมูล', icon: Iconsax.user, type: DetailViewType.info),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: AppColors.surface,
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = (constraints.maxWidth - 8) / 3; // -8 for padding
          final selectedIndex = _segments.indexWhere((s) => s.type == selectedView);

          return Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Stack(
              children: [
                // Sliding indicator
                AnimatedPositioned(
                  duration: Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  left: selectedIndex * segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                // Segment labels
                Row(
                  children: _segments.map((segment) {
                    final isSelected = selectedView == segment.type;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onViewChanged(segment.type),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: 'Anuphan',
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? AppColors.primary : AppColors.secondaryText,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  segment.icon,
                                  size: 14,
                                  color: isSelected ? AppColors.primary : AppColors.secondaryText,
                                ),
                                SizedBox(width: 4),
                                Text(segment.label),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// SliverPersistentHeaderDelegate สำหรับ Sticky Segmented Control
class SegmentedControlDelegate extends SliverPersistentHeaderDelegate {
  final DetailViewType selectedView;
  final ValueChanged<DetailViewType> onViewChanged;

  SegmentedControlDelegate({
    required this.selectedView,
    required this.onViewChanged,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ViewSegmentedControl(
      selectedView: selectedView,
      onViewChanged: onViewChanged,
    );
  }

  @override
  double get maxExtent => 60;

  @override
  double get minExtent => 60;

  @override
  bool shouldRebuild(covariant SegmentedControlDelegate oldDelegate) {
    return selectedView != oldDelegate.selectedView;
  }
}
