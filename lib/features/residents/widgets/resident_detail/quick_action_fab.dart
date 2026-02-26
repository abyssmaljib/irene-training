import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../screens/create_vital_sign_screen.dart';

/// Quick Action FAB สำหรับหน้า Resident Detail
class QuickActionFab extends StatelessWidget {
  final int residentId;
  final String residentName;

  const QuickActionFab({
    super.key,
    required this.residentId,
    required this.residentName,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showQuickActionSheet(context),
      backgroundColor: AppColors.primary,
      child: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.white),
    );
  }

  void _showQuickActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // ให้ modal ขยายได้ตาม content
      builder: (context) => _QuickActionSheet(
        residentId: residentId,
        residentName: residentName,
      ),
    );
  }
}

class _QuickActionSheet extends StatelessWidget {
  final int residentId;
  final String residentName;

  const _QuickActionSheet({
    required this.residentId,
    required this.residentName,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.alternate,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'ทำงานด่วน',
                style: AppTypography.heading3,
              ),
            ),

            Divider(height: 1, color: AppColors.background),

            // Action buttons
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _buildActionItem(
                    context: context,
                    icon: HugeIcons.strokeRoundedFavourite,
                    iconColor: AppColors.error,
                    title: 'วัดสัญญาณชีพ',
                    subtitle: 'บันทึก BP, Pulse, SpO2, Temp',
                    onTap: () => _handleAction(context, 'vital_sign'),
                  ),
                  AppSpacing.verticalGapSm,
                  _buildActionItem(
                    context: context,
                    icon: HugeIcons.strokeRoundedFileEdit,
                    iconColor: AppColors.warning,
                    title: 'บันทึกการขับถ่าย',
                    subtitle: 'Bristol Score, จำนวน',
                    onTap: () => _handleAction(context, 'bowel_movement'),
                  ),
                  AppSpacing.verticalGapSm,
                  _buildActionItem(
                    context: context,
                    icon: HugeIcons.strokeRoundedCamera01,
                    iconColor: AppColors.secondary,
                    title: 'ถ่ายรูป',
                    subtitle: 'บันทึกรูปภาพกิจกรรม',
                    onTap: () => _handleAction(context, 'photo'),
                  ),
                  AppSpacing.verticalGapSm,
                  _buildActionItem(
                    context: context,
                    icon: HugeIcons.strokeRoundedNote,
                    iconColor: AppColors.primary,
                    title: 'โน้ตด่วน',
                    subtitle: 'จดบันทึกสั้นๆ',
                    onTap: () => _handleAction(context, 'quick_note'),
                  ),
                ],
              ),
            ),

            // Extra bottom padding
            SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required dynamic icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mediumRadius,
        child: Container(
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.mediumRadius,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: HugeIcon(icon: icon, color: iconColor, size: AppIconSize.xl),
                ),
              ),
              AppSpacing.horizontalGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.title),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    Navigator.pop(context);

    switch (action) {
      case 'vital_sign':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateVitalSignScreen(
              residentId: residentId,
              residentName: residentName,
            ),
          ),
        );
        return;
      case 'bowel_movement':
        _showComingSoon(context, 'บันทึกการขับถ่าย');
        break;
      case 'photo':
        _showComingSoon(context, 'ถ่ายรูป');
        break;
      case 'quick_note':
        _showComingSoon(context, 'โน้ตด่วน');
        break;
      default:
        _showComingSoon(context, 'ฟีเจอร์นี้');
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    AppSnackbar.info(context, '$feature - เร็วๆ นี้');
  }
}
