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
                ? Border.all(color: AppColors.warning.withValues(alpha: 0.5), width: 1)
                : null,
          ),
          child: Row(
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
              // เช้า
              _buildCell('${summary.totalDayShifts}'),
              // ดึก
              _buildCell('${summary.totalNightShifts}'),
              // รวม
              _buildCell(
                '${summary.totalShifts}',
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              // WD (Required Workdays 26-25)
              _buildCell('${summary.requiredWorkdays26To25 ?? "-"}'),
              // OT (Previous OT - ยกมาจากเดือนก่อน)
              _buildCell(
                '${summary.pot ?? 0}',
                color: (summary.pot ?? 0) > 0
                    ? AppColors.success
                    : null,
              ),
              // DD (Previous DD - ยกมาจากเดือนก่อน)
              _buildCell(
                '${summary.pdd ?? 0}',
                color: (summary.pdd ?? 0) > 0 ? const Color(0xFFE67E22) : null, // Orange สีเข้ม
              ),
              // Inc (Incharge)
              _buildCell(
                '${summary.inchargeCount}',
                color: summary.inchargeCount > 0 ? AppColors.success : null,
              ),
              // S (Sick)
              _buildCell(
                '${summary.sickCount}',
                color: summary.sickCount > 0 ? AppColors.primary : null,
              ),
              // A (Absent) - with notification dot only for current month
              _buildCellWithBadge(
                '${summary.absentCount}',
                color: summary.absentCount > 0 ? AppColors.error : null,
                showBadge: summary.absentCount > 0 && _isCurrentMonth,
              ),
              // Sup (Support)
              _buildCell(
                '${summary.supportCount}',
                color: summary.supportCount > 0 ? AppColors.warning : null,
              ),
              // (+) Total Additional
              _buildCell(
                '${summary.totalAdditional ?? 0}',
                color: (summary.totalAdditional ?? 0) > 0 ? AppColors.success : null,
              ),
              // (-) Total Deduction
              _buildCell(
                '${summary.totalDeduction?.toInt() ?? 0}',
                color: (summary.totalDeduction ?? 0) > 0 ? AppColors.error : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(
    String value, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return Expanded(
      child: Text(
        value,
        style: AppTypography.caption.copyWith(
          color: color ?? AppColors.primaryText,
          fontWeight: fontWeight ?? FontWeight.normal,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Cell with optional notification badge
  Widget _buildCellWithBadge(
    String value, {
    Color? color,
    FontWeight? fontWeight,
    bool showBadge = false,
  }) {
    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Text(
            value,
            style: AppTypography.caption.copyWith(
              color: color ?? AppColors.primaryText,
              fontWeight: fontWeight ?? FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
          if (showBadge)
            Positioned(
              right: 4,
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
    );
  }
}
