import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/medicine_summary.dart';

/// Medicine Card - แสดงข้อมูลยาแต่ละตัว
class MedicineCard extends StatelessWidget {
  final MedicineSummary medicine;
  final VoidCallback? onTap;

  /// Callback เมื่อกดค้าง → เปิด On/Off bottom sheet
  /// ส่งมาเฉพาะ user ที่มีสิทธิ์ (canQC)
  final VoidCallback? onLongPress;

  const MedicineCard({
    super.key,
    required this.medicine,
    this.onTap,
    this.onLongPress,
  });

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
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: AppRadius.smallRadius,
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name + Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicine.displayName,
                            style: AppTypography.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (medicine.brandName != null &&
                              medicine.brandName != medicine.genericName) ...[
                            SizedBox(height: 2),
                            Text(
                              medicine.brandName!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    AppSpacing.horizontalGapSm,
                    _buildStatusBadge(),
                  ],
                ),

                AppSpacing.verticalGapSm,

                // Dosage details: strength + take_tab + unit + route
                _buildDosageInfo(),

                // Dosage frequency
                if (medicine.dosageFrequency != null) ...[
                  AppSpacing.verticalGapSm,
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedClock01,
                        size: AppIconSize.sm,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          medicine.dosageFrequency!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                AppSpacing.verticalGapMd,

                // Meal times badges + hint (ถ้าไม่มี daysOfWeek)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // Before/After food badges
                          if (medicine.isBeforeFood)
                            _buildMealBadge('ก่อนอาหาร', AppColors.tagPendingBg, AppColors.tagPendingText),
                          if (medicine.isAfterFood)
                            _buildMealBadge('หลังอาหาร', AppColors.tagReadBg, AppColors.tagReadText),

                          // Time of day badges
                          if (medicine.isMorning)
                            _buildTimeBadge('เช้า'),
                          if (medicine.isNoon)
                            _buildTimeBadge('กลางวัน'),
                          if (medicine.isEvening)
                            _buildTimeBadge('เย็น'),
                          if (medicine.isBedtime)
                            _buildTimeBadge('ก่อนนอน'),
                        ],
                      ),
                    ),
                    // Hint อยู่บรรทัดเดียวกับ badges (เฉพาะเมื่อไม่มี daysOfWeek)
                    if (onLongPress != null && medicine.daysOfWeek.isEmpty)
                      _buildOnOffHint(),
                  ],
                ),

                // Days of week + hint (if specific days)
                if (medicine.daysOfWeek.isNotEmpty) ...[
                  AppSpacing.verticalGapSm,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _buildDaysOfWeek()),
                      // Hint อยู่บรรทัดเดียวกับ daysOfWeek
                      if (onLongPress != null)
                        _buildOnOffHint(),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// สร้างข้อความ dosage info: strength + take_tab + unit + route
  Widget _buildDosageInfo() {
    final parts = <String>[];

    // Strength (str)
    if (medicine.str != null && medicine.str!.isNotEmpty) {
      parts.add(medicine.str!);
    }

    // Take tab + unit (e.g., "1 เม็ด")
    if (medicine.takeTab != null) {
      final tabStr = medicine.takeTab! % 1 == 0
          ? medicine.takeTab!.toInt().toString()
          : medicine.takeTab.toString();
      final unitStr = medicine.unit ?? 'เม็ด';
      parts.add('$tabStr $unitStr');
    }

    // Route (e.g., "รับประทาน")
    if (medicine.route != null && medicine.route!.isNotEmpty) {
      parts.add(medicine.route!);
    }

    if (parts.isEmpty) {
      return SizedBox.shrink();
    }

    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedMedicine01,
          size: AppIconSize.sm,
          color: AppColors.primary,
        ),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            parts.join(' • '),
            style: AppTypography.body.copyWith(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final isActive = medicine.isActive;
    final isWaiting = medicine.status == 'waiting';

    Color bgColor;
    Color textColor;
    String label;

    if (isWaiting) {
      bgColor = AppColors.tagPendingBg;
      textColor = AppColors.tagPendingText;
      label = 'รอเริ่ม';
    } else if (isActive) {
      bgColor = AppColors.tagPassedBg;
      textColor = AppColors.tagPassedText;
      label = 'ใช้อยู่';
    } else {
      bgColor = AppColors.tagNeutralBg;
      textColor = AppColors.tagNeutralText;
      label = 'หยุดใช้';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.fullRadius,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMealBadge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.fullRadius,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTimeBadge(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: AppRadius.fullRadius,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Hint เล็กๆ มุมขวาล่าง บอก user ว่ากดค้างเพื่อ on/off ได้
  Widget _buildOnOffHint() {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedTouch01,
            size: 12,
            color: AppColors.secondaryText.withValues(alpha: 0.5),
          ),
          SizedBox(width: 4),
          Text(
            'กดค้างเพื่อ on/off',
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              color: AppColors.secondaryText.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeek() {
    const allDays = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    const dayMapping = {
      'จันทร์': 'จ',
      'อังคาร': 'อ',
      'พุธ': 'พ',
      'พฤหัสบดี': 'พฤ',
      'ศุกร์': 'ศ',
      'เสาร์': 'ส',
      'อาทิตย์': 'อา',
    };

    // Convert full day names to short names
    final activeDays = medicine.daysOfWeek.map((d) {
      return dayMapping[d] ?? d;
    }).toSet();

    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedCalendar01,
          size: AppIconSize.sm,
          color: AppColors.textSecondary,
        ),
        SizedBox(width: 6),
        ...allDays.map((day) {
          final isActive = activeDays.contains(day);
          return Container(
            width: 24,
            height: 24,
            margin: EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                day,
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
