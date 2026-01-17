import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/question.dart';
import 'choice_button.dart';

class QuestionCard extends StatelessWidget {
  final Question question;
  final int questionNumber;
  final int totalQuestions;
  final String? selectedChoice;
  final bool isAnswered;
  final ValueChanged<String> onChoiceSelected;

  const QuestionCard({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    this.selectedChoice,
    this.isAnswered = false,
    required this.onChoiceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4, vertical: AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadius.mediumRadius,
            ),
            child: Text(
              'ข้อที่ $questionNumber/$totalQuestions',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          AppSpacing.verticalGapMd,

          // Question text
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
          ),

          // Question image (if any)
          if (question.questionImageUrl != null) ...[
            AppSpacing.verticalGapMd,
            ClipRRect(
              borderRadius: AppRadius.mediumRadius,
              child: Image.network(
                question.questionImageUrl!,
                width: double.infinity,
                fit: BoxFit.contain,
                // จำกัดขนาดใน memory เพื่อป้องกัน crash บน iOS/Android สเปคต่ำ
                cacheWidth: 600,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    color: AppColors.primaryBackground,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    color: AppColors.primaryBackground,
                    child: const Center(
                      child: HugeIcon(icon: HugeIcons.strokeRoundedImageNotFound01, color: AppColors.secondaryText),
                    ),
                  );
                },
              ),
            ),
          ],

          AppSpacing.verticalGapLg,

          // Choices
          ...question.choices.map((choice) {
            final state = _getChoiceState(choice);
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm + 4),
              child: ChoiceButton(
                choiceKey: choice.key,
                text: choice.text,
                state: state,
                onTap: isAnswered ? null : () => onChoiceSelected(choice.key),
              ),
            );
          }),
        ],
      ),
    );
  }

  ChoiceState _getChoiceState(Choice choice) {
    if (!isAnswered) {
      if (selectedChoice == choice.key) {
        return ChoiceState.selected;
      }
      return ChoiceState.normal;
    }

    // After answered
    if (choice.isCorrect) {
      return ChoiceState.correct;
    }
    if (selectedChoice == choice.key && !choice.isCorrect) {
      return ChoiceState.incorrect;
    }
    return ChoiceState.disabled;
  }
}
