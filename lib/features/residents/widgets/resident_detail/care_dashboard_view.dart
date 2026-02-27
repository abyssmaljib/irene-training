import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/resident_detail.dart';
import '../../models/vital_sign.dart';
import '../../screens/vital_sign_log_screen.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../screens/create_vital_sign_screen.dart';
import 'vital_sign_snapshot.dart';
import 'activity_log_section.dart';

/// Care Dashboard View - หน้าหลักสำหรับ NA
class CareDashboardView extends StatelessWidget {
  final ResidentDetail resident;
  final VitalSign? vitalSign;
  final bool isLoadingVitalSign;
  final VoidCallback? onVitalSignUpdated;

  const CareDashboardView({
    super.key,
    required this.resident,
    this.vitalSign,
    this.isLoadingVitalSign = false,
    this.onVitalSignUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vital Sign Section
          if (isLoadingVitalSign)
            _buildLoadingVitalSign()
          else if (vitalSign != null && vitalSign!.hasData)
            VitalSignSnapshot(
              vitalSign: vitalSign,
              onTapBP: () => _showVitalDetail(context, 'BP'),
              onTapPulse: () => _showVitalDetail(context, 'Pulse'),
              onTapSpO2: () => _showVitalDetail(context, 'SpO2'),
              onTapTemp: () => _showVitalDetail(context, 'Temp'),
              onTapViewAll: () async {
                final result = await navigateToVitalSignLog(
                  context,
                  residentId: resident.id,
                  residentName: resident.name,
                );
                if (result == true) {
                  onVitalSignUpdated?.call();
                }
              },
            )
          else
            EmptyVitalSign(
              onAdd: () => _showAddVitalSign(context),
            ),

          AppSpacing.verticalGapLg,

          // Status Badges Section
          _buildStatusSection(),

          AppSpacing.verticalGapLg,

          // Activity Log Section - V3: แสดง posts ของ resident
          ActivityLogSection(
            residentId: resident.id,
            residentName: resident.name,
          ),

          // Bottom padding for FAB
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLoadingVitalSign() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: AppShadows.cardShadow,
      ),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
            AppSpacing.verticalGapSm,
            Text(
              'กำลังโหลดสัญญาณชีพ...',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    final List<_StatusItem> statuses = [];

    // Add status based on resident data
    if (resident.status == 'Stay') {
      statuses.add(_StatusItem(
        iconData: HugeIcons.strokeRoundedCheckmarkCircle02,
        label: 'พักอยู่',
        color: AppColors.tagPassedText,
        bgColor: AppColors.tagPassedBg,
      ));
    }

    if (resident.isFallRisk) {
      statuses.add(_StatusItem(
        iconData: HugeIcons.strokeRoundedAlert02,
        label: 'เสี่ยงล้ม',
        color: AppColors.tagPendingText,
        bgColor: AppColors.tagPendingBg,
      ));
    }

    if (resident.isNPO) {
      statuses.add(_StatusItem(
        iconData: HugeIcons.strokeRoundedCancel01,
        label: 'NPO',
        color: AppColors.tagFailedText,
        bgColor: AppColors.tagFailedBg,
      ));
    }

    // โรคประจำตัวย้ายไปแสดงที่ Header แล้ว

    if (statuses.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('สถานะ', style: AppTypography.title),
          AppSpacing.verticalGapSm,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: statuses.map((status) => _buildStatusBadge(status)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(_StatusItem status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: status.iconData, size: AppIconSize.sm, color: status.color),
          SizedBox(width: 4),
          Text(
            status.label,
            style: AppTypography.bodySmall.copyWith(
              color: status.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showVitalDetail(BuildContext context, String type) {
    AppToast.info(context, 'ดูกราฟ $type - เร็วๆ นี้');
  }

  void _showAddVitalSign(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateVitalSignScreen(
          residentId: resident.id,
          residentName: resident.name,
        ),
      ),
    );
  }
}

class _StatusItem {
  final dynamic iconData;
  final String label;
  final Color color;
  final Color bgColor;

  _StatusItem({
    required this.iconData,
    required this.label,
    required this.color,
    required this.bgColor,
  });
}
