import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/shift_summary_provider.dart';
import 'shift_detail_row.dart';

/// Popup แสดงรายละเอียดเวรแต่ละเดือน
class ShiftDetailPopup extends ConsumerWidget {
  final int month;
  final int year;

  const ShiftDetailPopup({
    super.key,
    required this.month,
    required this.year,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthYear = MonthYear(month: month, year: year);
    final detailsAsync = ref.watch(shiftDetailsProvider(monthYear));

    // Thai month names
    final thaiMonths = [
      '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
      'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
    ];
    final buddhistYear = year + 543;
    final title = 'เวร${thaiMonths[month]} $buddhistYear';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context, title),
          // Table header
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
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  itemCount: details.length,
                  itemBuilder: (context, index) {
                    return ShiftDetailRow(
                      clockSummary: details[index],
                      onRefresh: () {
                        ref.read(shiftSummaryRefreshCounterProvider.notifier).state++;
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
            icon: Icon(
              Icons.close,
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
}
