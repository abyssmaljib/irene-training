import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards.dart';

class ExplanationCard extends StatelessWidget {
  final bool isCorrect;
  final String correctAnswer;
  final String? explanation;
  final String? explanationImageUrl;
  final VoidCallback onNext;
  final bool isLastQuestion;

  const ExplanationCard({
    super.key,
    required this.isCorrect,
    required this.correctAnswer,
    this.explanation,
    this.explanationImageUrl,
    required this.onNext,
    this.isLastQuestion = false,
  });

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      margin: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Result header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCorrect
                      ? AppColors.tagPassedBg
                      : AppColors.tagFailedBg,
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: isCorrect ? HugeIcons.strokeRoundedCheckmarkCircle02 : HugeIcons.strokeRoundedCancelCircle,
                  color: isCorrect ? AppColors.success : AppColors.error,
                  size: 28,
                ),
              ),
              AppSpacing.horizontalGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCorrect ? 'ถูกต้อง!' : 'ไม่ถูกต้อง',
                      style: AppTypography.title.copyWith(
                        color: isCorrect ? AppColors.success : AppColors.error,
                      ),
                    ),
                    Text(
                      'คำตอบที่ถูกต้อง: $correctAnswer',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Explanation
          if (explanation != null && explanation!.isNotEmpty) ...[
            AppSpacing.verticalGapMd,
            Divider(color: AppColors.alternate),
            AppSpacing.verticalGapMd,
            Text(
              'คำอธิบาย:',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            AppSpacing.verticalGapSm,
            Text(
              explanation!,
              style: AppTypography.bodySmall.copyWith(
                height: 1.5,
                color: AppColors.secondaryText,
              ),
            ),
          ],

          // Explanation image
          if (explanationImageUrl != null) ...[
            AppSpacing.verticalGapMd,
            ClipRRect(
              borderRadius: AppRadius.smallRadius,
              child: Image.network(
                explanationImageUrl!,
                width: double.infinity,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 150,
                    color: AppColors.primaryBackground,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],

          AppSpacing.verticalGapLg,

          // Next button
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.smallRadius,
                ),
              ),
              child: Text(
                isLastQuestion ? 'ดูผลสอบ' : 'ข้อถัดไป →',
                style: AppTypography.button.copyWith(
                  color: AppColors.surface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
