import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
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
  final VoidCallback? onTapViewAll;

  const VitalSignSnapshot({
    super.key,
    this.vitalSign,
    this.onTapBP,
    this.onTapPulse,
    this.onTapSpO2,
    this.onTapTemp,
    this.onTapViewAll,
  });

  /// Format datetime to Thai time string (convert to Bangkok timezone +7)
  String _formatThaiTime(DateTime dt) {
    // Convert to local time (Bangkok +7)
    final localDt = dt.toLocal();
    return '${localDt.hour.toString().padLeft(2, '0')}:${localDt.minute.toString().padLeft(2, '0')} น.';
  }

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
              if (onTapViewAll != null)
                GestureDetector(
                  onTap: onTapViewAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ดูทั้งหมด',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 2),
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowRight01,
                        size: AppIconSize.sm,
                        color: AppColors.primary,
                      ),
                    ],
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
                icon: HugeIcons.strokeRoundedFavourite,
                iconColor: AppColors.error,
                label: 'ความดัน',
                value: vitalSign?.bpDisplay ?? '-',
                unit: 'mmHg',
                status: vitalSign?.bpStatus ?? VitalStatus.normal,
                onTap: onTapBP,
                isBP: true,
              ),
              AppSpacing.horizontalGapSm,
              _buildVitalCard(
                icon: HugeIcons.strokeRoundedActivity01,
                iconColor: AppColors.tertiary,
                label: 'ชีพจร',
                value: vitalSign?.pulseDisplay ?? '-',
                unit: 'bpm',
                status: vitalSign?.pulseStatus ?? VitalStatus.normal,
                onTap: onTapPulse,
              ),
              AppSpacing.horizontalGapSm,
              _buildVitalCard(
                icon: HugeIcons.strokeRoundedCloud,
                iconColor: AppColors.secondary,
                label: 'SpO2',
                value: vitalSign?.spO2Display ?? '-',
                unit: '',
                status: vitalSign?.spO2Status ?? VitalStatus.normal,
                onTap: onTapSpO2,
              ),
              AppSpacing.horizontalGapSm,
              _buildVitalCard(
                icon: HugeIcons.strokeRoundedSun01,
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

        // Time at bottom right
        if (vitalSign != null)
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md, top: AppSpacing.xs),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatThaiTime(vitalSign!.createdAt),
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVitalCard({
    required dynamic icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    required VitalStatus status,
    VoidCallback? onTap,
    bool isBP = false,
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
                HugeIcon(icon: icon, size: AppIconSize.sm, color: iconColor),
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

            // Value - แสดงแบบพิเศษสำหรับ BP
            if (isBP)
              _buildBPValue(value, status)
            else
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

  /// Widget แสดงค่า BP แบบแยก sys/dias
  Widget _buildBPValue(String value, VitalStatus status) {
    // แยก systolic/diastolic จาก "110/70"
    final parts = value.split('/');
    final sys = parts.isNotEmpty ? parts[0] : '-';
    final dias = parts.length > 1 ? parts[1] : '-';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Systolic
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  sys,
                  style: AppTypography.title.copyWith(
                    color: status.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '/',
                  style: AppTypography.bodySmall.copyWith(
                    color: status.textColor,
                  ),
                ),
                Text(
                  dias,
                  style: AppTypography.bodySmall.copyWith(
                    color: status.textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        Spacer(),
        Padding(
          padding: EdgeInsets.only(bottom: 2),
          child: Text(
            'mmHg',
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
              fontSize: 9,
            ),
          ),
        ),
      ],
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedFavourite,
                size: AppIconSize.xl,
                color: AppColors.secondaryText,
              ),
            ),
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
              icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: AppIconSize.md),
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
