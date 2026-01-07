import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/checkbox_state_provider.dart';
import '../providers/shift_summary_provider.dart';
import 'shift_detail_row.dart';

/// Popup แสดงรายละเอียดเวรแต่ละเดือน
class ShiftDetailPopup extends ConsumerStatefulWidget {
  final int month;
  final int year;
  final int? highlightDDRecordId;
  final dynamic monthlySummary;

  const ShiftDetailPopup({
    super.key,
    required this.month,
    required this.year,
    this.highlightDDRecordId,
    this.monthlySummary,
  });

  @override
  ConsumerState<ShiftDetailPopup> createState() => _ShiftDetailPopupState();
}

class _ShiftDetailPopupState extends ConsumerState<ShiftDetailPopup> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToHighlight = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlightIfNeeded(List details) {
    if (_hasScrolledToHighlight) return;
    if (widget.highlightDDRecordId == null) return;

    final index =
        details.indexWhere((d) => d.ddRecordId == widget.highlightDDRecordId);
    if (index < 0) return;

    _hasScrolledToHighlight = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final offset = index * 50.0;
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthYear = MonthYear(month: widget.month, year: widget.year);
    final detailsAsync = ref.watch(shiftDetailsProvider(monthYear));

    final thaiMonths = [
      '',
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    // แสดงปี ค.ศ. (Christian Era)
    final title = 'เวร${thaiMonths[widget.month]} ${widget.year}';

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context, title),
          // Monthly Summary Section
          if (widget.monthlySummary != null) _buildMonthlySummary(),
          // Table header with checkbox toggle
          _buildTableHeader(),
          // Content
          Expanded(
            child: detailsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, stack) => Center(
                child: Text(
                  'เกิดข้อผิดพลาด',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              data: (details) {
                if (details.isEmpty) {
                  return Center(
                    child: Text(
                      'ไม่มีข้อมูลเวร',
                      style: AppTypography.body.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  );
                }
                _scrollToHighlightIfNeeded(details);

                final checkboxState = ref.watch(checkboxStateProvider);

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  itemCount: details.length,
                  itemBuilder: (context, index) {
                    final detail = details[index];
                    final isHighlighted = widget.highlightDDRecordId != null &&
                        detail.ddRecordId == widget.highlightDDRecordId;

                    final day = detail.clockInTime?.day ?? 0;
                    final key = day > 0
                        ? 'shift_checkbox_${ref.read(currentUserIdProvider)}_${widget.year}_${widget.month}_$day'
                        : '';
                    final isTicked =
                        day > 0 ? (checkboxState[key] ?? false) : false;

                    return ShiftDetailRow(
                      key: ValueKey('row_${detail.ddRecordId ?? index}'),
                      clockSummary: detail,
                      isHighlighted: isHighlighted,
                      isTicked: isTicked,
                      onCheckboxChanged: day > 0
                          ? (_) {
                              ref
                                  .read(checkboxStateProvider.notifier)
                                  .toggle(widget.year, widget.month, day);
                            }
                          : null,
                      onRefresh: () {
                        ref
                            .read(shiftSummaryRefreshCounterProvider.notifier)
                            .state++;
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTypography.heading3.copyWith(
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancelCircle,
              color: Colors.white,
            ),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Consumer(
      builder: (context, ref, child) {
        final detailsAsync = ref.watch(shiftDetailsProvider(
          MonthYear(month: widget.month, year: widget.year),
        ));

        return detailsAsync.when(
          loading: () => _buildTableHeaderContent(ref, const []),
          error: (_, _) => _buildTableHeaderContent(ref, const []),
          data: (details) => _buildTableHeaderContent(ref, details),
        );
      },
    );
  }

  Widget _buildTableHeaderContent(WidgetRef ref, List<dynamic> details) {
    final days = details
        .map((d) => d.clockInTime?.day ?? 0)
        .where((d) => d > 0)
        .cast<int>()
        .toList();

    final checkboxState = ref.watch(checkboxStateProvider);
    final allTicked = days.isNotEmpty &&
        days.every((day) {
          final key =
              'shift_checkbox_${ref.read(currentUserIdProvider)}_${widget.year}_${widget.month}_$day';
          return checkboxState[key] ?? false;
        });

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.alternate, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Checkbox toggle column (Google Sheets style)
          SizedBox(
            width: 40,
            child: Checkbox(
              value: allTicked,
              onChanged: days.isEmpty
                  ? null
                  : (value) {
                      if (value == true) {
                        ref
                            .read(checkboxStateProvider.notifier)
                            .tickAll(widget.year, widget.month, days);
                      } else {
                        ref
                            .read(checkboxStateProvider.notifier)
                            .untickAll(widget.year, widget.month, days);
                      }
                    },
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          _buildHeaderCell('ว/ด/ป', flex: 1),
          _buildHeaderCell('เข้า', flex: 1),
          _buildHeaderCell('ออก', flex: 1),
          _buildHeaderCell('เวร', flex: 1),
          _buildHeaderCell('พิเศษ', flex: 1),
          _buildHeaderCell('note', flex: 1),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.secondaryText,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMonthlySummary() {
    final summary = widget.monthlySummary;
    if (summary == null) return const SizedBox.shrink();

    final netAmount =
        ((summary.totalAdditional ?? 0).toDouble()) - (summary.totalDeduction ?? 0);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.alternate),
      ),
      child: Column(
        children: [
          // Row 1: เช้า, ดึก, รวม, WD
          Row(
            children: [
              _buildSummaryCell('เช้า', '${summary.totalDayShifts}'),
              _buildSummaryCell('ดึก', '${summary.totalNightShifts}'),
              _buildSummaryCell('รวม', '${summary.totalShifts}',
                  isHighlight: true),
              _buildSummaryCell(
                  'WD', '${summary.requiredWorkdays26To25 ?? "-"}'),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Divider(height: 1, color: AppColors.alternate),
          SizedBox(height: AppSpacing.xs),
          // Row 2: pOT, pDD, Inc, S, A, Sup
          Row(
            children: [
              _buildSummaryCell('pOT', '${summary.pot ?? 0}'),
              _buildSummaryCell('pDD', '${summary.pdd ?? 0}'),
              _buildSummaryCell('Inc', '${summary.inchargeCount}'),
              _buildSummaryCell('S', '${summary.sickCount}'),
              _buildSummaryCellWithBadge(
                'A',
                '${summary.absentCount}',
                showBadge: summary.absentCount > 0,
              ),
              _buildSummaryCell('Sup', '${summary.supportCount}'),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Divider(height: 1, color: AppColors.alternate),
          SizedBox(height: AppSpacing.xs),
          // Row 3: +, -, Net
          Row(
            children: [
              _buildSummaryCell('+', '${summary.totalAdditional ?? 0}'),
              _buildSummaryCell('-', '${summary.totalDeduction ?? 0}'),
              if (netAmount != 0)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Net',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        netAmount > 0 ? '+$netAmount' : '$netAmount',
                        style: AppTypography.body.copyWith(
                          color:
                              netAmount > 0 ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              const Expanded(child: SizedBox()),
              const Expanded(child: SizedBox()),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCell(String label, String value,
      {bool isHighlight = false}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isHighlight
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            Text(
              value,
              style: AppTypography.body.copyWith(
                fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Summary cell with notification badge
  Widget _buildSummaryCellWithBadge(String label, String value,
      {bool showBadge = false}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  value,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                if (showBadge)
                  Positioned(
                    right: -8,
                    top: -2,
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
        ),
      ),
    );
  }
}