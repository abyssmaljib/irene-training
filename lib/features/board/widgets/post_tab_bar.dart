import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/post_tab.dart';

/// Tab bar หลัก 2 แท็บ: ประกาศ, ส่งเวร (V3)
class PostTabBar extends StatelessWidget {
  final PostMainTab selectedTab;
  final Map<PostMainTab, int> unreadCounts;
  final ValueChanged<PostMainTab> onTabChanged;

  const PostTabBar({
    super.key,
    required this.selectedTab,
    this.unreadCounts = const {},
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: PostMainTab.values.map((tab) {
          final isSelected = tab == selectedTab;
          final unreadCount = unreadCounts[tab] ?? 0;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(tab),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: tab.icon,
                      size: AppIconSize.md,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.secondaryText,
                    ),
                    SizedBox(width: 6),
                    Text(
                      tab.label,
                      style: AppTypography.body.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.secondaryText,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      SizedBox(width: 6),
                      _buildUnreadBadge(unreadCount),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: BoxConstraints(minWidth: 18),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: AppTypography.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
