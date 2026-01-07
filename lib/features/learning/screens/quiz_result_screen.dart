import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';

class QuizResultScreen extends StatelessWidget {
  final String topicName;
  final int score;
  final int totalQuestions;
  final int passingScore;
  final bool isPassed;
  final VoidCallback onBackToTopic;
  final VoidCallback? onTryAgain;

  const QuizResultScreen({
    super.key,
    required this.topicName,
    required this.score,
    required this.totalQuestions,
    required this.passingScore,
    required this.isPassed,
    required this.onBackToTopic,
    this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isPassed ? AppColors.resultPassedBg : AppColors.resultFailedBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Result icon/animation
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: isPassed
                          ? AppColors.tagPassedBg
                          : AppColors.tagFailedBg,
                      shape: BoxShape.circle,
                    ),
                    child: HugeIcon(
                      icon: isPassed ? HugeIcons.strokeRoundedChampion : HugeIcons.strokeRoundedSad01,
                      size: 64,
                      color: isPassed ? AppColors.success : AppColors.error,
                    ),
                  ),
                  AppSpacing.verticalGapXl,

                  // Score display
                  Text(
                    '$score/$totalQuestions',
                    style: AppTypography.heading1.copyWith(
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      color: isPassed ? AppColors.success : AppColors.error,
                    ),
                  ),
                  AppSpacing.verticalGapSm,

                  // Result message
                  Text(
                    isPassed ? 'ผ่าน!' : 'ไม่ผ่าน',
                    style: AppTypography.heading1.copyWith(
                      color: isPassed ? AppColors.success : AppColors.error,
                    ),
                  ),
                  AppSpacing.verticalGapSm,

                  Text(
                    'เกณฑ์ผ่าน: $passingScore/$totalQuestions คะแนน',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  AppSpacing.verticalGapMd,

                  // Topic name
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBackground,
                      borderRadius: AppRadius.smallRadius,
                    ),
                    child: Text(
                      topicName,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Buttons
                  if (!isPassed && onTryAgain != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: onTryAgain,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.smallRadius,
                          ),
                        ),
                        child: Text(
                          'ลองใหม่อีกครั้ง',
                          style: AppTypography.button.copyWith(
                            color: AppColors.surface,
                          ),
                        ),
                      ),
                    ),
                    AppSpacing.verticalGapSm,
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: onBackToTopic,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isPassed ? AppColors.success : AppColors.primary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.smallRadius,
                        ),
                      ),
                      child: Text(
                        'กลับไปหน้าหัวข้อ',
                        style: AppTypography.button.copyWith(
                          color: isPassed ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
