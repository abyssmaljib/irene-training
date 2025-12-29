import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/medicine_summary.dart';
import '../services/medicine_service.dart';

/// Medicine Summary Card - แสดงรายการยาแบ่งตามประเภท (ATC Classification)
/// ใช้ใน ClinicalView ของ ResidentDetailScreen
class MedicineSummaryCard extends StatefulWidget {
  final int residentId;
  final VoidCallback? onTap;

  const MedicineSummaryCard({
    super.key,
    required this.residentId,
    this.onTap,
  });

  @override
  State<MedicineSummaryCard> createState() => _MedicineSummaryCardState();
}

class _MedicineSummaryCardState extends State<MedicineSummaryCard> {
  final _medicineService = MedicineService.instance;

  int _medicineCount = 0;
  Map<String, List<MedicineSummary>> _categorizedMedicines = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final medicines = await _medicineService.getActiveMedicines(widget.residentId);

      // Group by ATC Level 1 (main category), fallback to group
      final grouped = <String, List<MedicineSummary>>{};
      for (final med in medicines) {
        final category = med.atcLevel1NameTh ?? med.group ?? 'อื่นๆ';
        grouped.putIfAbsent(category, () => []);
        grouped[category]!.add(med);
      }

      // Sort by count (descending)
      final sortedEntries = grouped.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

      if (mounted) {
        setState(() {
          _medicineCount = medicines.length;
          _categorizedMedicines = Map.fromEntries(sortedEntries);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.smallRadius,
        boxShadow: AppShadows.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AppRadius.smallRadius,
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                AppSpacing.verticalGapMd,
                _buildCategoryList(),
                AppSpacing.verticalGapSm,
                _buildViewAllButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.accent1,
            borderRadius: AppRadius.smallRadius,
          ),
          child: Icon(
            Iconsax.health,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        AppSpacing.horizontalGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'รายการยา',
                style: AppTypography.title,
              ),
              Text(
                'ยาที่ใช้ประจำ',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        ),
        if (_isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          )
        else
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadius.fullRadius,
            ),
            child: Text(
              '$_medicineCount ตัว',
              style: AppTypography.buttonSmall.copyWith(
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryList() {
    if (_isLoading) {
      return SizedBox(
        height: 40,
        child: Center(
          child: Text(
            'กำลังโหลด...',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    if (_categorizedMedicines.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          'ไม่มียาที่ใช้อยู่',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    // แสดง categories เป็น Wrap (chips)
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: _categorizedMedicines.entries.map((entry) {
        return _buildCategoryChip(entry.key, entry.value.length);
      }).toList(),
    );
  }

  Widget _buildCategoryChip(String category, int count) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: AppRadius.fullRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            category,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadius.fullRadius,
            ),
            child: Text(
              '$count',
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'ดูทั้งหมด',
          style: AppTypography.button.copyWith(
            color: AppColors.primary,
          ),
        ),
        AppSpacing.horizontalGapXs,
        Icon(
          Iconsax.arrow_right_3,
          size: 16,
          color: AppColors.primary,
        ),
      ],
    );
  }
}
