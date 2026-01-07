import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Base shell component สำหรับ Filter Drawer
/// ใช้เป็น wrapper ให้ drawer ทุกหน้ามี consistency
class FilterDrawerShell extends StatelessWidget {
  /// Title ของ drawer
  final String title;

  /// จำนวน filter ที่เลือกอยู่ (สำหรับแสดง badge)
  final int filterCount;

  /// Content ที่จะแสดงใน drawer (scrollable)
  final Widget content;

  /// Callback เมื่อกดปุ่มล้างตัวกรอง (ถ้า null จะไม่แสดงปุ่ม)
  final VoidCallback? onClear;

  /// Footer widget เพิ่มเติม (optional, แสดงก่อนปุ่มล้าง)
  final Widget? footer;

  const FilterDrawerShell({
    super.key,
    this.title = 'ตัวกรอง',
    this.filterCount = 0,
    required this.content,
    this.onClear,
    this.footer,
  });

  bool get _hasFilters => filterCount > 0;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          // Header
          _buildHeader(context),

          // Content (scrollable)
          Expanded(child: content),

          // Footer
          if (footer != null || (_hasFilters && onClear != null))
            _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.of(context).padding.top + AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          // Filter icon with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: HugeIcon(icon: HugeIcons.strokeRoundedFilterHorizontal, color: AppColors.primary, size: AppIconSize.lg),
              ),
              if (_hasFilters)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$filterCount',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.horizontalGapMd,
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.heading3.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_hasFilters)
                  Text(
                    'เลือก $filterCount รายการ',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Custom footer widget
          if (footer != null) ...[
            footer!,
            if (_hasFilters && onClear != null) AppSpacing.verticalGapSm,
          ],

          // Clear button
          if (_hasFilters && onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedDelete01,
                      size: AppIconSize.sm,
                      color: AppColors.error,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ล้างตัวกรอง',
                      style: AppTypography.body.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
