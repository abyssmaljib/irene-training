import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../providers/shift_summary_provider.dart';
import '../widgets/monthly_summary_card.dart';
import '../widgets/shift_detail_popup.dart';

class ShiftSummaryScreen extends ConsumerStatefulWidget {
  /// DD record ID to highlight (optional)
  final int? highlightDDRecordId;

  /// Month/Year to auto-open popup (optional)
  final int? autoOpenMonth;
  final int? autoOpenYear;

  const ShiftSummaryScreen({
    super.key,
    this.highlightDDRecordId,
    this.autoOpenMonth,
    this.autoOpenYear,
  });

  @override
  ConsumerState<ShiftSummaryScreen> createState() => _ShiftSummaryScreenState();
}

class _ShiftSummaryScreenState extends ConsumerState<ShiftSummaryScreen> {
  bool _hasAutoOpened = false;

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(monthlySummariesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: IreneSecondaryAppBar(
        title: 'เวรของฉัน',
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: summariesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (error, stack) => _buildErrorState(error.toString()),
          data: (summaries) {
            if (summaries.isEmpty) {
              return _buildEmptyState();
            }
            // Auto-open popup if specified
            _autoOpenPopupIfNeeded();
            return _buildContent(summaries);
          },
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    // Invalidate cache and refresh
    ref.read(shiftSummaryServiceProvider).invalidateCache();
    ref.read(shiftSummaryRefreshCounterProvider.notifier).state++;
    await ref.read(monthlySummariesProvider.future);
  }

  Widget _buildContent(List summaries) {
    return Column(
      children: [
        // Table header
        _buildTableHeader(),
        // List
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            itemCount: summaries.length,
            separatorBuilder: (context, index) => SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) {
              final summary = summaries[index];
              return MonthlySummaryCard(
                summary: summary,
                onTap: () => _showDetailPopup(
                  summary.month,
                  summary.year,
                  monthlySummary: summary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.alternate, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // เดือน
          Expanded(
            flex: 2,
            child: Text(
              'เดือน',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // รวม
          SizedBox(
            width: 50,
            child: Text(
              'รวม',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          // WD
          SizedBox(
            width: 50,
            child: Text(
              'WD',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          // Empty space for metrics
          Expanded(flex: 3, child: SizedBox()),
        ],
      ),
    );
  }

  void _showDetailPopup(
    int month,
    int year, {
    int? highlightDDRecordId,
    dynamic monthlySummary,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShiftDetailPopup(
        month: month,
        year: year,
        highlightDDRecordId: highlightDDRecordId,
        monthlySummary: monthlySummary,
      ),
    );
  }

  void _autoOpenPopupIfNeeded() {
    if (_hasAutoOpened) return;
    if (widget.autoOpenMonth == null || widget.autoOpenYear == null) return;

    _hasAutoOpened = true;

    // Use post frame callback to show popup after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showDetailPopup(
          widget.autoOpenMonth!,
          widget.autoOpenYear!,
          highlightDDRecordId: widget.highlightDDRecordId,
        );
      }
    });
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget(message: 'ยังไม่มีข้อมูลเวร');
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: AppIconSize.display,
            color: AppColors.error,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'เกิดข้อผิดพลาด',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _onRefresh,
            child: Text(
              'ลองใหม่',
              style: AppTypography.body.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
