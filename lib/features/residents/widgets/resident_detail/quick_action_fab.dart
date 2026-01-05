import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

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
      child: Icon(Iconsax.add, color: Colors.white),
    );
  }

  void _showQuickActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              child: Row(
                children: [
                  Text(
                    'ทำงานด่วน',
                    style: AppTypography.heading3,
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Iconsax.close_circle, color: AppColors.secondaryText),
                  ),
                ],
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
                    icon: Iconsax.heart,
                    iconColor: AppColors.error,
                    title: 'วัดสัญญาณชีพ',
                    subtitle: 'บันทึก BP, Pulse, SpO2, Temp',
                    onTap: () => _handleAction(context, 'vital_sign'),
                  ),
                  AppSpacing.verticalGapSm,
                  _buildActionItem(
                    context: context,
                    icon: Iconsax.document_text,
                    iconColor: AppColors.warning,
                    title: 'บันทึกการขับถ่าย',
                    subtitle: 'Bristol Score, จำนวน',
                    onTap: () => _handleAction(context, 'bowel_movement'),
                  ),
                  AppSpacing.verticalGapSm,
                  _buildActionItem(
                    context: context,
                    icon: Iconsax.camera,
                    iconColor: AppColors.secondary,
                    title: 'ถ่ายรูป',
                    subtitle: 'บันทึกรูปภาพกิจกรรม',
                    onTap: () => _handleAction(context, 'photo'),
                  ),
                  AppSpacing.verticalGapSm,
                  _buildActionItem(
                    context: context,
                    icon: Iconsax.note_2,
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
    required IconData icon,
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
                child: Icon(icon, color: iconColor, size: 24),
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
              Icon(
                Iconsax.arrow_right_3,
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

    // Placeholder - แสดง SnackBar
    String message;
    switch (action) {
      case 'vital_sign':
        message = 'วัดสัญญาณชีพ - เร็วๆ นี้';
        break;
      case 'bowel_movement':
        message = 'บันทึกการขับถ่าย - เร็วๆ นี้';
        break;
      case 'photo':
        message = 'ถ่ายรูป - เร็วๆ นี้';
        break;
      case 'quick_note':
        message = 'โน้ตด่วน - เร็วๆ นี้';
        break;
      default:
        message = 'เร็วๆ นี้';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
