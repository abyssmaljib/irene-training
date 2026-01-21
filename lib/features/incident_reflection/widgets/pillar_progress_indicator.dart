// Widget แสดงความคืบหน้าของ 4 Pillars
// แสดงเป็น 4 จุดพร้อม icon และ label

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/reflection_pillars.dart';

/// Widget แสดงความคืบหน้าของ 4 Pillars
class PillarProgressIndicator extends StatelessWidget {
  final ReflectionPillars progress;

  const PillarProgressIndicator({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border(
          bottom: BorderSide(
            color: AppColors.alternate,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPillarDot(
            label: 'ความสำคัญ',
            icon: HugeIcons.strokeRoundedTarget02,
            isCompleted: progress.whyItMattersCompleted,
          ),
          _buildConnector(progress.whyItMattersCompleted),
          _buildPillarDot(
            label: 'สาเหตุ',
            icon: HugeIcons.strokeRoundedSearch01,
            isCompleted: progress.rootCauseCompleted,
          ),
          _buildConnector(progress.rootCauseCompleted),
          _buildPillarDot(
            label: 'Core Values',
            icon: HugeIcons.strokeRoundedBook02,
            isCompleted: progress.coreValuesCompleted,
          ),
          _buildConnector(progress.coreValuesCompleted),
          _buildPillarDot(
            label: 'การป้องกัน',
            icon: HugeIcons.strokeRoundedShield01,
            isCompleted: progress.preventionPlanCompleted,
          ),
        ],
      ),
    );
  }

  /// สร้าง pillar dot พร้อม icon และ label
  Widget _buildPillarDot({
    required String label,
    required dynamic icon,
    required bool isCompleted,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circle with icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.primary
                : AppColors.alternate.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: HugeIcon(
              icon: icon,
              size: 18,
              color: isCompleted ? Colors.white : AppColors.secondaryText,
            ),
          ),
        ),
        AppSpacing.verticalGapXs,
        // Label
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            color: isCompleted ? AppColors.primary : AppColors.secondaryText,
            fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// สร้างเส้นเชื่อมระหว่าง pillars
  Widget _buildConnector(bool isPreviousCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: isPreviousCompleted
            ? AppColors.primary.withValues(alpha: 0.5)
            : AppColors.alternate.withValues(alpha: 0.3),
      ),
    );
  }
}

/// Compact version สำหรับแสดงใน card
class PillarProgressCompact extends StatelessWidget {
  final ReflectionPillars progress;

  const PillarProgressCompact({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 4 dots
        for (int i = 0; i < 4; i++) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isCompleted(i)
                  ? AppColors.primary
                  : AppColors.alternate,
              shape: BoxShape.circle,
            ),
          ),
          if (i < 3) AppSpacing.horizontalGapXs,
        ],
        AppSpacing.horizontalGapSm,
        // Progress text
        Text(
          '${progress.completedCount}/4',
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  bool _isCompleted(int index) {
    switch (index) {
      case 0:
        return progress.whyItMattersCompleted;
      case 1:
        return progress.rootCauseCompleted;
      case 2:
        return progress.coreValuesCompleted;
      case 3:
        return progress.preventionPlanCompleted;
      default:
        return false;
    }
  }
}
