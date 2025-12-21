import 'package:flutter/material.dart';
import '../models/topic_with_progress.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards.dart';

class TopicCard extends StatelessWidget {
  final TopicWithProgress topic;
  final VoidCallback? onTap;

  const TopicCard({super.key, required this.topic, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      onTap: onTap,
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic.topicName,
            style: AppTypography.title.copyWith(height: 1.3),
          ),
          AppSpacing.verticalGapSm,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _buildStatusTags(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatusTags(BuildContext context) {
    final List<Widget> tags = [];

    // Read status tag
    if (topic.isRead != true) {
      tags.add(_buildTag(
        context,
        '📖 ยังไม่อ่าน',
        AppColors.tagNeutralBg,
        AppColors.secondaryText,
        FontWeight.w400,
      ));
    } else {
      tags.add(_buildTag(
        context,
        '✅ อ่านแล้ว',
        AppColors.tagReadBg,
        AppColors.success,
        FontWeight.w600,
      ));
    }

    // Quiz status tag
    switch (topic.quizStatus) {
      case 'passed':
        tags.add(_buildTag(
          context,
          '✅ ผ่านแล้ว',
          AppColors.tagReadBg,
          AppColors.success,
          FontWeight.w600,
        ));
        break;
      case 'review_due':
        tags.add(_buildTag(
          context,
          '🔁 ต้องทบทวน',
          AppColors.tagReviewBg,
          AppColors.tagReviewText,
          FontWeight.w600,
        ));
        break;
      case 'not_started':
      default:
        tags.add(_buildTag(
          context,
          '📝 ยังไม่ทำ',
          AppColors.tagNeutralBg,
          AppColors.secondaryText,
          FontWeight.w400,
        ));
        break;
    }

    // Cooldown tag (แสดงเมื่ออยู่ใน cooldown)
    if (topic.isInCooldown) {
      tags.add(_buildTag(
        context,
        '⏳ รอ ${topic.cooldownRemainingText}',
        AppColors.tagPendingBg,
        AppColors.tagPendingText,
        FontWeight.w500,
      ));
    }

    // Content update tag (แสดงเมื่อเนื้อหาถูกอัพเดตหลังจาก user อ่าน)
    if (topic.hasContentUpdate) {
      tags.add(_buildTag(
        context,
        '🔄 เนื้อหาอัพเดต',
        AppColors.tagUpdateBg,
        AppColors.tagUpdateText,
        FontWeight.w600,
      ));
    }

    // Add spacing between tags
    final spacedTags = <Widget>[];
    for (int i = 0; i < tags.length; i++) {
      spacedTags.add(tags[i]);
      if (i < tags.length - 1) {
        spacedTags.add(AppSpacing.horizontalGapSm);
      }
    }

    return spacedTags;
  }

  Widget _buildTag(
    BuildContext context,
    String text,
    Color bgColor,
    Color textColor,
    FontWeight fontWeight,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.mediumRadius,
      ),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: textColor,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}
