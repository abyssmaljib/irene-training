import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../services/medicine_service.dart';

/// Card แสดงสถานะการให้ยาวันนี้ (7 มื้อ)
/// กดเพื่อเข้าไปหน้า MedicinePhotosScreen
class MedicinePhotosCard extends StatefulWidget {
  final int residentId;
  final VoidCallback? onTap;

  const MedicinePhotosCard({
    super.key,
    required this.residentId,
    this.onTap,
  });

  @override
  State<MedicinePhotosCard> createState() => _MedicinePhotosCardState();
}

class _MedicinePhotosCardState extends State<MedicinePhotosCard> {
  final _medicineService = MedicineService.instance;
  Map<String, MealStatus> _mealStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final status = await _medicineService.getMealStatusForDate(
        widget.residentId,
        DateTime.now(),
      );
      setState(() {
        _mealStatus = status;
        _isLoading = false;
      });
    } catch (_) {
      // Error loading meal status - แสดง empty state แทน
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: AppShadows.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AppRadius.mediumRadius,
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),

                AppSpacing.verticalGapMd,

                // Meal Status Grid (สถานะการให้ยาวันนี้)
                _buildMealSlots(),

                AppSpacing.verticalGapMd,

                // Footer - View All
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'ดูทั้งหมด',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: AppIconSize.sm,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final thaiMonths = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    final dateStr = '${now.day} ${thaiMonths[now.month]}';

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accent1,
            borderRadius: AppRadius.smallRadius,
          ),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar01,
            size: AppIconSize.lg,
            color: AppColors.primary,
          ),
        ),
        AppSpacing.horizontalGapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'วันนี้ ($dateStr)',
                style: AppTypography.title,
              ),
              Text(
                'สถานะการให้ยา',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMealSlots() {
    if (_isLoading) {
      return SizedBox(
        height: 60,
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

    // 7 meal slots
    final slots = MedicineService.mealSlots;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.smallRadius,
      ),
      padding: EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: slots.map((slot) {
          final mealKey = slot['mealKey']!;
          final status = _mealStatus[mealKey];
          return _buildMealSlot(
            slot['label']!,
            status,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMealSlot(String label, MealStatus? status) {
    // แยกชื่อมื้อและก่อน/หลัง
    String mealName;
    String? beforeAfter;

    if (label.contains('(')) {
      final parts = label.split(' ');
      mealName = parts[0];
      beforeAfter = parts[1].replaceAll('(', '').replaceAll(')', '');
    } else {
      mealName = label;
    }

    // กำหนด icon และสี
    Widget statusIcon;
    Color bgColor;

    if (status == null || status.isEmpty) {
      // ไม่มียาในมื้อนี้
      statusIcon = Text(
        '-',
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
        ),
      );
      bgColor = AppColors.background;
    } else if (status.isCompleted) {
      // ให้ยาแล้ว (มีรูป 3C)
      statusIcon = HugeIcon(
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        size: AppIconSize.sm,
        color: AppColors.tagPassedText,
      );
      bgColor = AppColors.tagPassedBg;
    } else {
      // ยังไม่ได้ให้ (pending)
      statusIcon = Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.tagFailedText,
          shape: BoxShape.circle,
        ),
      );
      bgColor = AppColors.tagFailedBg;
    }

    return Expanded(
      child: Column(
        children: [
          Text(
            mealName,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          // ใส่ placeholder สำหรับ slot ที่ไม่มี beforeAfter เพื่อให้ height เท่ากัน
          Text(
            beforeAfter ?? '',
            style: AppTypography.caption.copyWith(
              fontSize: 9,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Center(child: statusIcon),
          ),
        ],
      ),
    );
  }
}
