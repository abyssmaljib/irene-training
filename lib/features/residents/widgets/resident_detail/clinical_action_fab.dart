import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../medicine/screens/add_medicine_to_resident_screen.dart';

/// Quick Action FAB สำหรับ Clinical Tab ในหน้า Resident Detail
///
/// แสดงตัวเลือก:
/// - เพิ่มยา (ไปหน้า AddMedicineToResidentScreen)
/// - (เพิ่มตัวเลือกอื่นๆ ได้ในอนาคต)
class ClinicalActionFab extends StatelessWidget {
  final int residentId;
  final String residentName;

  const ClinicalActionFab({
    super.key,
    required this.residentId,
    required this.residentName,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showClinicalActionSheet(context),
      backgroundColor: AppColors.primary,
      child: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.white),
    );
  }

  /// แสดง Bottom Sheet สำหรับเลือก action
  void _showClinicalActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClinicalActionSheet(
        residentId: residentId,
        residentName: residentName,
      ),
    );
  }
}

/// Bottom Sheet แสดงรายการ action สำหรับ Clinical Tab
class _ClinicalActionSheet extends StatelessWidget {
  final int residentId;
  final String residentName;

  const _ClinicalActionSheet({
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
            // Handle bar - แถบลากด้านบน
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
                    'ทำงานด่วน (คลินิก)',
                    style: AppTypography.heading3,
                  ),
                  Spacer(),
                  // ปุ่มปิด
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancelCircle,
                      color: AppColors.secondaryText,
                    ),
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
                  // เพิ่มยา
                  _buildActionItem(
                    context: context,
                    icon: HugeIcons.strokeRoundedMedicine01,
                    iconColor: AppColors.secondary,
                    title: 'เพิ่มยา',
                    subtitle: 'เพิ่มยาใหม่ให้คนไข้',
                    onTap: () => _handleAddMedicine(context),
                  ),
                  // สามารถเพิ่ม action อื่นๆ ได้ในอนาคต เช่น:
                  // - นัดหมายพบแพทย์
                  // - บันทึกผล Lab
                  // - ดูประวัติการรักษา
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

  /// สร้าง action item แต่ละรายการ
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
              // Icon container
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
              // Text content
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
              // Arrow icon
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

  /// เปิดหน้าเพิ่มยา
  void _handleAddMedicine(BuildContext context) {
    // ปิด bottom sheet ก่อน
    Navigator.pop(context);

    // Navigate ไปหน้าเพิ่มยา
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicineToResidentScreen(
          residentId: residentId,
          residentName: residentName,
        ),
      ),
    );
  }
}
