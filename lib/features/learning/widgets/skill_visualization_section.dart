import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/thinking_skill_data.dart';
import 'skill_radar_chart.dart';

class SkillVisualizationSection extends StatelessWidget {
  final ThinkingSkillsData? skillsData;
  final String? topicName;

  const SkillVisualizationSection({
    super.key,
    this.skillsData,
    this.topicName,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show if no data
    if (skillsData == null || !skillsData!.hasData) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title (outside card)
        Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            topicName != null ? 'ทักษะการคิด: $topicName' : 'ทักษะการคิด',
            style: AppTypography.title,
          ),
        ),

        // Card with chart
        Container(
          margin: EdgeInsets.only(bottom: AppSpacing.lg),
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadius.mediumRadius,
            border: Border.all(color: AppColors.alternate),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSpacing.verticalGapMd,
              // Chart and badge row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Radar chart (takes most space)
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: SkillRadarChart(
                        skillsData: skillsData!,
                        size: 180,
                      ),
                    ),
                  ),

                  // Knowledge badge section
                  if (skillsData!.hasKnowledge)
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ความรู้',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          AppSpacing.verticalGapSm,
                          _KnowledgeBadge(
                            percent: skillsData!.knowledgePercent,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              AppSpacing.verticalGapMd,

              // Legend for categories
              AppSpacing.verticalGapSm,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: skillsData!.pentagonCategories.map((cat) {
                  return _buildLegendItem(
                    label: SkillRadarChart.thaiLabels[cat.type] ?? cat.type,
                    percent: cat.percent,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({required String label, required double percent}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: AppRadius.smallRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          AppSpacing.horizontalGapXs,
          Text(
            '$label: ${percent.toInt()}%',
            style: AppTypography.caption.copyWith(
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeBadge extends StatelessWidget {
  final double percent;

  const _KnowledgeBadge({
    required this.percent,
  });

  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.tagPassedBg,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary,
          width: 3,
        ),
      ),
      child: Center(
        child: Text(
          '${percent.toInt()}%',
          style: AppTypography.title.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
