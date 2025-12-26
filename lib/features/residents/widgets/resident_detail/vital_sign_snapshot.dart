import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/vital_sign.dart';

/// Widget แสดง Vital Signs แบบ Horizontal Scroll Cards
class VitalSignSnapshot extends StatelessWidget {
  final VitalSign? vitalSign;
  final VoidCallback? onTapBP;
  final VoidCallback? onTapPulse;
  final VoidCallback? onTapSpO2;
  final VoidCallback? onTapTemp;

  const VitalSignSnapshot({
    super.key,
    this.vitalSign,
    this.onTapBP,
    this.onTapPulse,
    this.onTapSpO2,
    this.onTapTemp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Text(
                'สัญญาณชีพล่าสุด',
                style: AppTypography.title,
              ),
              Spacer(),
              if (vitalSign != null)
                Text(
                  vitalSign!.timeAgo,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
            ],
          ),
        ),
        AppSpacing.verticalGapSm,

        // Cards
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              _buildVitalCard(
                icon: Iconsax.heart,
                iconColor: AppColors.error,
                label: 'ความดัน',
                value: vitalSign?.bpDisplay ?? '-',
                unit: 'mmHg',
                status: vitalSign?.bpStatus ?? VitalStatus.normal,
                onTap: onTapBP,
              ),
              AppSpacing.horizontalGapSm,
              _buildVitalCard(
                icon: Iconsax.activity,
                iconColor: AppColors.tertiary,
                label: 'ชีพจร',
                value: vitalSign?.pulseDisplay ?? '-',
                unit: 'bpm',
                status: vitalSign?.pulseStatus ?? VitalStatus.normal,
                onTap: onTapPulse,
              ),
              AppSpacing.horizontalGapSm,
              _buildVitalCard(
                icon: Iconsax.cloud,
                iconColor: AppColors.secondary,
                label: 'SpO2',
                value: vitalSign?.spO2Display ?? '-',
                unit: '',
                status: vitalSign?.spO2Status ?? VitalStatus.normal,
                onTap: onTapSpO2,
              ),
              AppSpacing.horizontalGapSm,
              _buildVitalCard(
                icon: Iconsax.sun_1,
                iconColor: AppColors.warning,
                label: 'อุณหภูมิ',
                value: vitalSign?.tempDisplay ?? '-',
                unit: '',
                status: vitalSign?.tempStatus ?? VitalStatus.normal,
                onTap: onTapTemp,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVitalCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    required VitalStatus status,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          boxShadow: AppShadows.cardShadow,
          border: Border.all(
            color: status.backgroundColor,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon + Label
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                AppSpacing.horizontalGapXs,
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Value
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: AppTypography.heading3.copyWith(
                      color: status.textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unit.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Text(
                      unit,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
              ],
            ),

            // Status
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: status.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    status.indicator,
                    style: TextStyle(fontSize: 8),
                  ),
                  SizedBox(width: 2),
                  Text(
                    status.label,
                    style: AppTypography.caption.copyWith(
                      color: status.textColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget แสดงเมื่อไม่มีข้อมูล Vital Sign
class EmptyVitalSign extends StatelessWidget {
  final VoidCallback? onAdd;

  const EmptyVitalSign({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        children: [
          Icon(
            Icons.monitor_heart_outlined,
            size: 48,
            color: AppColors.secondaryText,
          ),
          AppSpacing.verticalGapSm,
          Text(
            'ยังไม่มีข้อมูลสัญญาณชีพ',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          if (onAdd != null) ...[
            AppSpacing.verticalGapMd,
            TextButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.add, size: 18),
              label: Text('เพิ่มสัญญาณชีพ'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
