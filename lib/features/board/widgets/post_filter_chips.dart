import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/post_tab.dart';

/// Filter chips row: ทั้งหมด / รอรับทราบ / โพสต์ของฉัน
class PostFilterChips extends StatelessWidget {
  final PostFilterType selectedFilter;
  final ValueChanged<PostFilterType> onFilterChanged;

  const PostFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: 16),
        child: Row(
          children: PostFilterType.values.map((filter) {
            final isSelected = filter == selectedFilter;

            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onFilterChanged(filter),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.inputBorder,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    filter.label,
                    style: AppTypography.bodySmall.copyWith(
                      color: isSelected ? Colors.white : AppColors.secondaryText,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
    );
  }
}
