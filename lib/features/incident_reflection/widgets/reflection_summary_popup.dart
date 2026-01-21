// Popup แสดงสรุปผลการถอดบทเรียน 4 Pillars
// แสดงอัตโนมัติเมื่อ AI ประเมินว่าครบทุกหัวข้อ (ครั้งแรกเท่านั้น)
// User สามารถเลือก "แก้ไข" เพื่อคุยต่อ หรือ "ยืนยัน" เพื่อบันทึกและจบ

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../models/reflection_pillars.dart';

/// Popup แสดงสรุปผลการถอดบทเรียน 4 Pillars
/// ใช้ showDialog() เพื่อแสดง
class ReflectionSummaryPopup extends StatelessWidget {
  /// ข้อมูลสรุปจาก AI
  final ReflectionSummary summary;

  /// Callback เมื่อ user กด "แก้ไข" - กลับไปคุยต่อ
  final VoidCallback onEdit;

  /// Callback เมื่อ user กด "ยืนยันและบันทึก"
  final VoidCallback onConfirm;

  /// กำลังบันทึกอยู่หรือไม่ (แสดง loading)
  final bool isLoading;

  /// โหมดดูอย่างเดียว (สำหรับดูสรุปที่บันทึกแล้ว)
  /// แสดงปุ่ม "เสร็จสิ้น" อย่างเดียว ไม่มีปุ่ม "แก้ไข"
  final bool isViewMode;

  const ReflectionSummaryPopup({
    super.key,
    required this.summary,
    required this.onEdit,
    required this.onConfirm,
    this.isLoading = false,
    this.isViewMode = false,
  });

  /// แสดง Popup และรอผลลัพธ์
  /// Returns:
  /// - `true` = user กด "ยืนยันและบันทึก"
  /// - `false` = user กด "แก้ไข" หรือปิด popup
  static Future<bool> show(
    BuildContext context, {
    required ReflectionSummary summary,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      // ไม่ให้ปิดโดยกด backdrop (ต้องเลือก action)
      barrierDismissible: false,
      builder: (dialogContext) {
        // ใช้ StatefulBuilder เพื่อจัดการ loading state ภายใน dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isLoading = false;

            return ReflectionSummaryPopup(
              summary: summary,
              isLoading: isLoading,
              onEdit: () {
                // กลับไปคุยต่อ
                Navigator.of(dialogContext).pop(false);
              },
              onConfirm: () {
                // บันทึกและจบ
                Navigator.of(dialogContext).pop(true);
              },
            );
          },
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeRadius,
      ),
      backgroundColor: AppColors.surface,
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: AppSpacing.md),

              // Icon success
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.tagPassedBg,
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  color: AppColors.tagPassedText,
                  size: AppIconSize.lg,
                ),
              ),

              SizedBox(height: AppSpacing.sm),

              // Title
              Text(
                'สรุปการถอดบทเรียน',
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppSpacing.xs),

              // Subtitle - แสดงข้อความต่างกันตาม mode
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  isViewMode
                      ? 'สรุปผลการถอดบทเรียนที่บันทึกไว้'
                      : 'ตรวจสอบความถูกต้องก่อนบันทึก\nหากต้องการแก้ไข กด "แก้ไข" เพื่อคุยเพิ่มเติม',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: AppSpacing.md),

              // 4 Pillars content
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  children: [
                    // Pillar 1: ความสำคัญ
                    _buildPillarSection(
                      icon: HugeIcons.strokeRoundedAlert02,
                      iconColor: AppColors.warning,
                      title: '1. ความสำคัญ/ผลกระทบ',
                      content: summary.whyItMatters,
                    ),

                    SizedBox(height: AppSpacing.sm),

                    // Pillar 2: สาเหตุ
                    _buildPillarSection(
                      icon: HugeIcons.strokeRoundedSearchFocus,
                      iconColor: AppColors.info,
                      title: '2. สาเหตุที่แท้จริง',
                      content: summary.rootCause,
                    ),

                    SizedBox(height: AppSpacing.sm),

                    // Pillar 3: Core Values
                    _buildPillarSection(
                      icon: HugeIcons.strokeRoundedFavourite,
                      iconColor: AppColors.error,
                      title: '3. Core Values ที่เกี่ยวข้อง',
                      content: summary.violatedCoreValues.isNotEmpty
                          ? summary.violatedCoreValues
                              .map((v) => '• ${v.displayName}')
                              .join('\n')
                          : '-',
                    ),

                    SizedBox(height: AppSpacing.sm),

                    // Pillar 4: แนวทางป้องกัน
                    _buildPillarSection(
                      icon: HugeIcons.strokeRoundedShield01,
                      iconColor: AppColors.primary,
                      title: '4. แนวทางป้องกัน',
                      content: summary.preventionPlan,
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.md),

              // Action buttons - แตกต่างตาม mode
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: isViewMode
                    // โหมดดูอย่างเดียว - แสดงปุ่ม "เสร็จสิ้น" อย่างเดียว
                    ? SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          text: 'เสร็จสิ้น',
                          onPressed: onConfirm,
                        ),
                      )
                    // โหมดปกติ - แสดง 2 ปุ่ม
                    : Row(
                        children: [
                          // ปุ่มแก้ไข (กลับไปคุยต่อ)
                          Expanded(
                            child: SecondaryButton(
                              text: 'แก้ไข',
                              onPressed: isLoading ? null : onEdit,
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          // ปุ่มยืนยัน
                          Expanded(
                            child: PrimaryButton(
                              text: 'ยืนยันและบันทึก',
                              isLoading: isLoading,
                              onPressed: isLoading ? null : onConfirm,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// สร้าง section สำหรับแต่ละ Pillar
  Widget _buildPillarSection({
    required dynamic icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingSm,
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.smallRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            children: [
              HugeIcon(
                icon: icon,
                color: iconColor,
                size: 18,
              ),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.xs),

          // Content
          Text(
            content.isNotEmpty ? content : '-',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
