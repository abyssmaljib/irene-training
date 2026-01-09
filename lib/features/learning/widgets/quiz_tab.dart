import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/quiz_history_item.dart';
import '../models/topic_detail.dart';
import '../models/thinking_skill_data.dart';
import 'quiz_history_card.dart';
// TODO: Temporarily hidden - import 'skill_visualization_section.dart';

class QuizTab extends StatelessWidget {
  final TopicDetail topicDetail;
  final List<QuizHistoryItem> quizHistory;
  final bool isLoading;
  final VoidCallback onStartQuiz;
  final ThinkingSkillsData? skillsData;

  const QuizTab({
    super.key,
    required this.topicDetail,
    required this.quizHistory,
    this.isLoading = false,
    required this.onStartQuiz,
    this.skillsData,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Quiz info header
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingMd,
          color: AppColors.primaryBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildInfoChip(
                    icon: HugeIcons.strokeRoundedFileEdit,
                    label: '10 ข้อ',
                  ),
                  AppSpacing.horizontalGapSm,
                  _buildInfoChip(
                    icon: HugeIcons.strokeRoundedTimer01,
                    label: '10 นาที',
                  ),
                  AppSpacing.horizontalGapSm,
                  _buildInfoChip(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    label: 'ผ่าน 8/10',
                  ),
                ],
              ),
              if (topicDetail.isPassed) ...[
                AppSpacing.verticalGapSm,
                Container(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.tagPassedBg,
                    borderRadius: AppRadius.smallRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: AppColors.success, size: AppIconSize.md),
                      AppSpacing.horizontalGapSm,
                      Text(
                        'ผ่านแล้ว! คะแนนสูงสุด ${topicDetail.posttestScore ?? 0}/10',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // History list with skill visualization
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : quizHistory.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: AppSpacing.paddingMd,
                      itemCount: _getItemCount(),
                      itemBuilder: (context, index) {
                        // TODO: Skill visualization section temporarily hidden for review
                        // if (skillsData != null && skillsData!.hasData && index == 0) {
                        //   return SkillVisualizationSection(
                        //     skillsData: skillsData,
                        //   );
                        // }

                        // Skill visualization hidden - use direct index
                        final adjustedIndex = index;

                        // History header
                        if (adjustedIndex == 0) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Text(
                              'ประวัติการทำแบบทดสอบ',
                              style: AppTypography.title,
                            ),
                          );
                        }
                        // History items
                        return Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.sm),
                          child: QuizHistoryCard(item: quizHistory[adjustedIndex - 1]),
                        );
                      },
                    ),
        ),

        // Start quiz button
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            boxShadow: AppShadows.cardShadow,
          ),
          child: SafeArea(
            child: Column(
              children: [
                if (!topicDetail.hasQuestions)
                  Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'ยังไม่มีคำถามในหัวข้อนี้',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                if (topicDetail.isInCooldown)
                  Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tagPendingBg,
                        borderRadius: AppRadius.smallRadius,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedTimer01,
                            size: AppIconSize.sm,
                            color: AppColors.tagPendingText,
                          ),
                          AppSpacing.horizontalGapXs,
                          Text(
                            'รอ ${topicDetail.cooldownRemainingText} ก่อนทำแบบทดสอบอีกครั้ง',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.tagPendingText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: topicDetail.hasQuestions && !topicDetail.isInCooldown
                        ? onStartQuiz
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.alternate,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.smallRadius,
                      ),
                    ),
                    icon: HugeIcon(
                      icon: topicDetail.isPassed ? HugeIcons.strokeRoundedRefresh : HugeIcons.strokeRoundedEdit02,
                      color: AppColors.surface,
                    ),
                    label: Text(
                      topicDetail.isPassed ? 'ทำแบบทดสอบอีกครั้ง' : 'ทำแบบทดสอบ',
                      style: AppTypography.button.copyWith(
                        color: AppColors.surface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _getItemCount() {
    // quizHistory.length + 1 for header
    // NOTE: Skill visualization temporarily hidden
    return quizHistory.length + 1; // +1 for history header
  }

  Widget _buildInfoChip({required dynamic icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: AppColors.alternate),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: AppIconSize.sm, color: AppColors.secondaryText),
          AppSpacing.horizontalGapXs,
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget(
      message: 'ยังไม่มีประวัติการทำแบบทดสอบ',
      subMessage: 'กดปุ่มด้านล่างเพื่อเริ่มทำแบบทดสอบ',
    );
  }
}
