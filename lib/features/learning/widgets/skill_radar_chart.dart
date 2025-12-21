import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/thinking_skill_data.dart';

class SkillRadarChart extends StatelessWidget {
  final ThinkingSkillsData skillsData;
  final double size;

  const SkillRadarChart({
    super.key,
    required this.skillsData,
    this.size = 200,
  });

  /// Thai labels for each thinking category
  static const Map<String, String> thaiLabels = {
    'analysis': 'วิเคราะห์',
    'prioritization': 'จัดลำดับ',
    'risk_assessment': 'ประเมินความเสี่ยง',
    'reasoning': 'ใช้เหตุผล',
    'uncertainty': 'ความไม่แน่นอน',
  };

  @override
  Widget build(BuildContext context) {
    final categories = skillsData.pentagonCategories;

    return SizedBox(
      width: size,
      height: size,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            // Baseline/target (100% for all - shown as outline)
            RadarDataSet(
              fillColor: Colors.transparent,
              borderColor: AppColors.alternate,
              borderWidth: 2,
              dataEntries: List.generate(5, (_) => const RadarEntry(value: 1.0)),
            ),
            // Actual performance (filled area)
            RadarDataSet(
              fillColor: AppColors.primary.withValues(alpha: 0.3),
              borderColor: AppColors.primary,
              borderWidth: 3,
              entryRadius: 4,
              dataEntries: categories
                  .map((cat) => RadarEntry(value: cat.normalizedValue))
                  .toList(),
            ),
          ],
          radarBackgroundColor: Colors.transparent,
          borderData: FlBorderData(show: false),
          radarBorderData: const BorderSide(color: Colors.transparent),
          titlePositionPercentageOffset: 0.2,
          titleTextStyle: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.primaryText,
          ),
          getTitle: (index, angle) {
            final category = categories[index];
            final label = thaiLabels[category.type] ?? category.type;
            return RadarChartTitle(
              text: label,
              angle: angle,
            );
          },
          tickCount: 4,
          ticksTextStyle: const TextStyle(
            color: Colors.transparent,
            fontSize: 0,
          ),
          tickBorderData: BorderSide(
            color: AppColors.alternate.withValues(alpha: 0.3),
            width: 1,
          ),
          gridBorderData: BorderSide(
            color: AppColors.alternate.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
    );
  }
}
