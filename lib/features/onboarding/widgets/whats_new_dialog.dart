import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../models/feature_announcement.dart';

/// Dialog แสดง Feature ใหม่เมื่อ app อัปเดต
/// แสดง changelog พร้อม icon ตามประเภทของ change
class WhatsNewDialog extends StatelessWidget {
  /// ข้อมูล announcement ที่จะแสดง
  final FeatureAnnouncement announcement;

  const WhatsNewDialog({
    super.key,
    required this.announcement,
  });

  /// แสดง dialog และรอให้ user กด "เข้าใจแล้ว"
  static Future<void> show(
    BuildContext context,
    FeatureAnnouncement announcement,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false, // ต้องกดปุ่มเท่านั้น
      builder: (context) => WhatsNewDialog(announcement: announcement),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header พร้อม gradient
            _buildHeader(),

            // Changelog items
            Flexible(
              child: _buildChangelogList(),
            ),

            // Close button
            _buildCloseButton(context),
          ],
        ),
      ),
    );
  }

  /// สร้าง header พร้อม gradient และ icon
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Sparkles icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedSparkles,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.sm),

          // Title
          Text(
            'มีอะไรใหม่',
            style: AppTypography.heading3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),

          // Version
          Text(
            'Version ${announcement.version}',
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// สร้าง list ของ changelog items
  Widget _buildChangelogList() {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.all(AppSpacing.md),
      itemCount: announcement.items.length,
      separatorBuilder: (context, index) => SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final item = announcement.items[index];
        return _buildChangelogItem(item);
      },
    );
  }

  /// สร้าง changelog item แต่ละรายการ
  Widget _buildChangelogItem(ChangelogItem item) {
    // กำหนด icon และสีตามประเภท
    final (icon, color) = switch (item.type) {
      ChangeType.newFeature => (
          HugeIcons.strokeRoundedSparkles,
          AppColors.success,
        ),
      ChangeType.improved => (
          HugeIcons.strokeRoundedArrowUp01,
          AppColors.primary,
        ),
      ChangeType.fixed => (
          HugeIcons.strokeRoundedCheckmarkCircle02,
          AppColors.warning,
        ),
    };

    // กำหนด label ตามประเภท
    final label = switch (item.type) {
      ChangeType.newFeature => 'ใหม่',
      ChangeType.improved => 'ปรับปรุง',
      ChangeType.fixed => 'แก้ไข',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon พร้อม background
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: HugeIcon(
              icon: icon,
              color: color,
              size: 16,
            ),
          ),
        ),
        SizedBox(width: AppSpacing.sm),

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              SizedBox(height: 4),

              // Text
              Text(
                item.text,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primaryText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// สร้างปุ่มปิด dialog
  Widget _buildCloseButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: PrimaryButton(
        text: 'เข้าใจแล้ว',
        width: double.infinity,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }
}
