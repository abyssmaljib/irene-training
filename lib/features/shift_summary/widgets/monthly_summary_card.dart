import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/monthly_summary.dart';

/// Card แสดงสรุปเวรรายเดือน
class MonthlySummaryCard extends StatelessWidget {
  final MonthlySummary summary;
  final VoidCallback onTap;

  const MonthlySummaryCard({
    super.key,
    required this.summary,
    required this.onTap,
  });

  /// Check if this is current month (can still submit evidence)
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return summary.month == now.month && summary.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: summary.hasIssues
                ? Border.all(
                    color: AppColors.warning.withValues(alpha: 0.5), width: 1)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // เดือน/ปี
              Expanded(
                flex: 2,
                child: Text(
                  summary.monthYearDisplay,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // รวม (Total shifts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'รวม: ',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    '${summary.totalShifts}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(width: AppSpacing.md),
              // WD (Required workdays 26-25)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'WD: ',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    '${summary.requiredWorkdays26To25 ?? "-"}',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(width: AppSpacing.md),
              // Metrics (แสดงเฉพาะค่า > 0)
              Expanded(
                flex: 3,
                child: _buildKeyMetricsRow(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Row แสดง key metrics: pDD | pOT | S | A | Sup | Net (แสดงเฉพาะค่า > 0)
  Widget _buildKeyMetricsRow() {
    final netAmount = summary.netAdditional;
    final netValue =
        netAmount >= 0 ? '+${netAmount.toInt()}' : '${netAmount.toInt()}';
    final netColor = netAmount > 0
        ? AppColors.success
        : netAmount < 0
            ? AppColors.error
            : null;

    final metrics = <Widget>[];

    // pDD - แสดงเมื่อ > 0
    if ((summary.pdd ?? 0) > 0) {
      metrics.add(_buildMetricChip(
        label: 'pDD',
        value: '${summary.pdd}',
        color: const Color(0xFFE67E22),
      ));
    }

    // pOT - แสดงเมื่อ > 0
    if ((summary.pot ?? 0) > 0) {
      metrics.add(_buildMetricChip(
        label: 'pOT',
        value: '${summary.pot}',
        color: AppColors.success,
      ));
    }

    // S - แสดงเมื่อ > 0
    if (summary.sickCount > 0) {
      metrics.add(_buildMetricChip(
        label: 'S',
        value: '${summary.sickCount}',
        color: AppColors.primary,
      ));
    }

    // A - แสดงเมื่อ > 0
    if (summary.absentCount > 0) {
      metrics.add(_buildMetricChipWithBadge(
        label: 'A',
        value: '${summary.absentCount}',
        color: AppColors.error,
        showBadge: _isCurrentMonth,
      ));
    }

    // Sup - แสดงเมื่อ > 0
    if (summary.supportCount > 0) {
      metrics.add(_buildMetricChip(
        label: 'Sup',
        value: '${summary.supportCount}',
        color: AppColors.warning,
      ));
    }

    // Net - แสดงเมื่อ != 0
    if (netAmount != 0) {
      metrics.add(_buildMetricChip(
        label: 'Net',
        value: netValue,
        color: netColor,
      ));
    }

    // ถ้าไม่มีค่าเลย แสดงข้อความ "-"
    if (metrics.isEmpty) {
      return Text(
        '-',
        style: AppTypography.caption.copyWith(
          color: AppColors.secondaryText,
        ),
      );
    }

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.start,
      children: metrics,
    );
  }

  /// Reusable metric chip component
  Widget _buildMetricChip({
    required String label,
    required String value,
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: AppTypography.caption.copyWith(
            color: color ?? AppColors.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Metric chip with optional notification badge
  Widget _buildMetricChipWithBadge({
    required String label,
    required String value,
    Color? color,
    bool showBadge = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              value,
              style: AppTypography.caption.copyWith(
                color: color ?? AppColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showBadge)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.surface,
                      width: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
