import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards.dart';
import '../models/quiz_history_item.dart';

class QuizHistoryCard extends StatelessWidget {
  final QuizHistoryItem item;
  final VoidCallback? onTap;

  const QuizHistoryCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          // Score circle
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: item.isPassed
                  ? AppColors.tagPassedBg
                  : AppColors.tagFailedBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${item.score}',
                style: AppTypography.heading3.copyWith(
                  fontWeight: FontWeight.w700,
                  color: item.isPassed ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ),
          AppSpacing.horizontalGapMd,

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs / 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.quizType == 'posttest'
                            ? AppColors.accent1
                            : AppColors.accent2,
                        borderRadius: BorderRadius.circular(AppSpacing.xs),
                      ),
                      child: Text(
                        item.quizTypeDisplay,
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: item.quizType == 'posttest'
                              ? AppColors.primary
                              : AppColors.secondary,
                        ),
                      ),
                    ),
                    AppSpacing.horizontalGapSm,
                    Text(
                      'ครั้งที่ ${item.attemptNumber}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                AppSpacing.verticalGapXs,
                Text(
                  '${item.formattedScore} คะแนน',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
                SizedBox(height: AppSpacing.xs / 2),
                Text(
                  '${item.formattedDate} • ${item.formattedDuration} นาที',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),

          // Pass/Fail indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4, vertical: AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: item.isPassed
                  ? AppColors.tagPassedBg
                  : AppColors.tagFailedBg,
              borderRadius: AppRadius.smallRadius,
            ),
            child: Text(
              item.isPassed ? 'ผ่าน' : 'ไม่ผ่าน',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: item.isPassed ? AppColors.success : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
