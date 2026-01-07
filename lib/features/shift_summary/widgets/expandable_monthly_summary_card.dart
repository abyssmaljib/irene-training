import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/monthly_summary.dart';

/// Expandable card แสดงสรุปเวรรายเดือนแบบพับได้
/// - Collapsed state: แสดงแค่ เดือน, รวม, WD และปุ่ม chevron
/// - Expanded state: แสดง 3 กลุ่มข้อมูล (Shift Breakdown, Carry-over & Special, Attendance & Adjustments)
class ExpandableMonthlySummaryCard extends StatefulWidget {
  final MonthlySummary summary;
  final VoidCallback onTap;

  const ExpandableMonthlySummaryCard({
    super.key,
    required this.summary,
    required this.onTap,
  });

  @override
  State<ExpandableMonthlySummaryCard> createState() =>
      _ExpandableMonthlySummaryCardState();
}

class _ExpandableMonthlySummaryCardState
    extends State<ExpandableMonthlySummaryCard> {
  bool isExpanded = false;

  /// Check if this is current month (can still submit evidence)
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return widget.summary.month == now.month &&
        widget.summary.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: widget.onTap, // Opens detail popup - covers ENTIRE card
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: widget.summary.hasIssues
                ? Border.all(
                    color: AppColors.warning.withValues(alpha: 0.5), width: 1)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCollapsedRow(),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: isExpanded
                    ? _buildExpandedContent()
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Collapsed row แสดง: เดือน | รวม | WD | DD | OT | S | A | Sup | Net | chevron
  Widget _buildCollapsedRow() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: เดือน | รวม | WD | chevron
          Row(
            children: [
              // เดือน/ปี (flex: 2)
              Expanded(
                flex: 2,
                child: Text(
                  widget.summary.monthYearDisplay,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // รวม (Total shifts) - with label
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'รวม: ',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Text(
                      '${widget.summary.totalShifts}',
                      style: AppTypography.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // WD (Required workdays 26-25) - with label
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'WD: ',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Text(
                      '${widget.summary.requiredWorkdays26To25 ?? "-"}',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron button
              SizedBox(
                width: 40,
                child: _buildChevronButton(),
              ),
            ],
          ),
          // Row 2: DD | OT | S | A | Sup | Net
          SizedBox(height: AppSpacing.xs),
          _buildKeyMetricsRow(),
        ],
      ),
    );
  }

  /// Row แสดง key metrics: DD | OT | S | A | Sup | Net (แสดงเฉพาะค่า > 0)
  Widget _buildKeyMetricsRow() {
    final netAmount = widget.summary.netAdditional;
    final netValue = netAmount >= 0 ? '+${netAmount.toInt()}' : '${netAmount.toInt()}';
    final netColor = netAmount > 0
        ? AppColors.success
        : netAmount < 0
            ? AppColors.error
            : null;

    final metrics = <Widget>[];

    // DD - แสดงเมื่อ > 0
    if ((widget.summary.pdd ?? 0) > 0) {
      metrics.add(_buildMetricChip(
        label: 'DD',
        value: '${widget.summary.pdd}',
        color: const Color(0xFFE67E22),
      ));
    }

    // OT - แสดงเมื่อ > 0
    if ((widget.summary.pot ?? 0) > 0) {
      metrics.add(_buildMetricChip(
        label: 'OT',
        value: '${widget.summary.pot}',
        color: AppColors.success,
      ));
    }

    // S - แสดงเมื่อ > 0
    if (widget.summary.sickCount > 0) {
      metrics.add(_buildMetricChip(
        label: 'S',
        value: '${widget.summary.sickCount}',
        color: AppColors.primary,
      ));
    }

    // A - แสดงเมื่อ > 0
    if (widget.summary.absentCount > 0) {
      metrics.add(_buildMetricChipWithBadge(
        label: 'A',
        value: '${widget.summary.absentCount}',
        color: AppColors.error,
        showBadge: _isCurrentMonth,
      ));
    }

    // Sup - แสดงเมื่อ > 0
    if (widget.summary.supportCount > 0) {
      metrics.add(_buildMetricChip(
        label: 'Sup',
        value: '${widget.summary.supportCount}',
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

  /// Chevron button ที่กดแล้ว toggle expansion (ไม่ trigger popup)
  Widget _buildChevronButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          isExpanded = !isExpanded;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.alternate.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: HugeIcon(
          icon: isExpanded ? HugeIcons.strokeRoundedArrowUp02 : HugeIcons.strokeRoundedArrowDown02,
          size: AppIconSize.lg,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }

  /// Expanded content แสดง 3 กลุ่มข้อมูล
  Widget _buildExpandedContent() {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group 1: Shift Breakdown
          _buildShiftBreakdown(),
          SizedBox(height: AppSpacing.xs),
          Divider(height: 1, color: AppColors.alternate),
          SizedBox(height: AppSpacing.xs),
          // Group 2: Carry-over & Special
          _buildCarryOverSection(),
          SizedBox(height: AppSpacing.xs),
          Divider(height: 1, color: AppColors.alternate),
          SizedBox(height: AppSpacing.xs),
          // Group 3: Attendance & Adjustments
          _buildAttendanceSection(),
        ],
      ),
    );
  }

  /// Group 1: Shift Breakdown (เช้า, ดึก)
  Widget _buildShiftBreakdown() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        _buildMetricChip(
          label: 'เช้า',
          value: '${widget.summary.totalDayShifts}',
          color: AppColors.primaryText,
        ),
        _buildMetricChip(
          label: 'ดึก',
          value: '${widget.summary.totalNightShifts}',
          color: AppColors.primaryText,
        ),
      ],
    );
  }

  /// Group 2: Carry-over & Special (OT, DD, Inc)
  Widget _buildCarryOverSection() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        _buildMetricChip(
          label: 'OT',
          value: '${widget.summary.pot ?? 0}',
          color: (widget.summary.pot ?? 0) > 0 ? AppColors.success : null,
        ),
        _buildMetricChip(
          label: 'DD',
          value: '${widget.summary.pdd ?? 0}',
          color: (widget.summary.pdd ?? 0) > 0
              ? const Color(0xFFE67E22)
              : null, // Orange
        ),
        _buildMetricChip(
          label: 'Inc',
          value: '${widget.summary.inchargeCount}',
          color: widget.summary.inchargeCount > 0 ? AppColors.success : null,
        ),
      ],
    );
  }

  /// Group 3: Attendance & Adjustments (S, A, Sup, Net)
  Widget _buildAttendanceSection() {
    // Calculate net additional/deduction
    final netAmount = widget.summary.netAdditional;
    final netLabel = netAmount >= 0 ? 'Net' : 'Net';
    final netValue = netAmount >= 0 ? '+${netAmount.toInt()}' : '${netAmount.toInt()}';
    final netColor = netAmount > 0
        ? AppColors.success
        : netAmount < 0
            ? AppColors.error
            : null;

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        _buildMetricChip(
          label: 'S',
          value: '${widget.summary.sickCount}',
          color: widget.summary.sickCount > 0 ? AppColors.primary : null,
        ),
        _buildMetricChipWithBadge(
          label: 'A',
          value: '${widget.summary.absentCount}',
          color: widget.summary.absentCount > 0 ? AppColors.error : null,
          showBadge: widget.summary.absentCount > 0 && _isCurrentMonth,
        ),
        _buildMetricChip(
          label: 'Sup',
          value: '${widget.summary.supportCount}',
          color: widget.summary.supportCount > 0 ? AppColors.warning : null,
        ),
        if (netAmount != 0)
          _buildMetricChip(
            label: netLabel,
            value: netValue,
            color: netColor,
          ),
      ],
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
