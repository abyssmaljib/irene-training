import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../providers/shift_summary_provider.dart';
import '../widgets/monthly_summary_card.dart';
import '../widgets/shift_detail_popup.dart';

class ShiftSummaryScreen extends ConsumerStatefulWidget {
  const ShiftSummaryScreen({super.key});

  @override
  ConsumerState<ShiftSummaryScreen> createState() => _ShiftSummaryScreenState();
}

class _ShiftSummaryScreenState extends ConsumerState<ShiftSummaryScreen> {
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
                onTap: () => _showDetailPopup(summary.month, summary.year),
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
        children: [
          _buildHeaderCell('เดือน', flex: 2),
          _buildHeaderCell('เช้า'),
          _buildHeaderCell('ดึก'),
          _buildHeaderCell('รวม'),
          _buildHeaderCell('WD'),
          _buildHeaderCell('OT'),
          _buildHeaderCell('DD'),
          _buildHeaderCell('Inc'),
          _buildHeaderCell('S'),
          _buildHeaderCell('A'),
          _buildHeaderCell('Sup'),
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
        textAlign: flex > 1 ? TextAlign.start : TextAlign.center,
      ),
    );
  }

  void _showDetailPopup(int month, int year) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShiftDetailPopup(
        month: month,
        year: year,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: AppColors.secondaryText.withValues(alpha: 0.5),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'ยังไม่มีข้อมูลเวร',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
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
