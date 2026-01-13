import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/task_log.dart';

/// Widget แสดงประวัติการแก้ปัญหาที่ผ่านมา
/// แสดงก่อนที่ user จะเลือกประเภทปัญหาใน ProblemInputSheet
/// เพื่อให้ user เห็นว่าปัญหาลักษณะนี้เคยแก้อย่างไร
class ResolutionHistorySection extends StatelessWidget {
  /// รายการ task ที่มี resolution note (ประวัติการแก้ปัญหา)
  final List<TaskLog> resolutionHistory;

  /// กำลังโหลดข้อมูลหรือไม่
  final bool isLoading;

  /// Callback เมื่อกดดูรายละเอียด task
  final void Function(TaskLog task)? onTaskTap;

  const ResolutionHistorySection({
    super.key,
    required this.resolutionHistory,
    this.isLoading = false,
    this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    // ไม่แสดงถ้ากำลังโหลดหรือไม่มีประวัติ
    if (isLoading) {
      return _buildLoadingState();
    }

    if (resolutionHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedClock01, // ใช้ Clock แทน History
              color: AppColors.secondaryText,
              size: 18,
            ),
            AppSpacing.horizontalGapSm,
            Text(
              'ประวัติการแก้ปัญหา',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.horizontalGapSm,
            // Badge แสดงจำนวน
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${resolutionHistory.length}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        AppSpacing.verticalGapSm,

        // Resolution History List - แสดงแค่ 3 รายการล่าสุด
        ...resolutionHistory.take(3).map((task) => _buildResolutionItem(task)),
        AppSpacing.verticalGapMd,

        // Divider
        Divider(
          color: AppColors.inputBorder,
          thickness: 1,
        ),
        AppSpacing.verticalGapMd,
      ],
    );
  }

  /// สร้าง Loading State
  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shimmer header
        Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            AppSpacing.horizontalGapSm,
            Container(
              width: 100,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        AppSpacing.verticalGapSm,

        // Shimmer items
        ...List.generate(2, (index) => _buildShimmerItem()),
        AppSpacing.verticalGapMd,
      ],
    );
  }

  /// Shimmer item placeholder
  Widget _buildShimmerItem() {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            AppSpacing.verticalGapXs,
            Container(
              width: 120,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// สร้าง Resolution Item
  Widget _buildResolutionItem(TaskLog task) {
    // Format วันที่
    final dateStr = task.resolvedAt != null
        ? DateFormat('d MMM', 'th').format(task.resolvedAt!)
        : '';
    final timeStr = task.resolvedAt != null
        ? DateFormat('HH:mm').format(task.resolvedAt!)
        : '';

    // สี background ตามประเภท resolution
    Color bgColor;
    Color textColor;
    dynamic statusIcon; // ใช้ dynamic เพราะ HugeIcons ไม่ใช่ IconData

    switch (task.resolutionStatus) {
      case 'resolved':
        bgColor = AppColors.success.withValues(alpha: 0.1);
        textColor = AppColors.success;
        statusIcon = HugeIcons.strokeRoundedCheckmarkCircle02;
        break;
      case 'ticket':
        bgColor = AppColors.info.withValues(alpha: 0.1);
        textColor = AppColors.info;
        statusIcon = HugeIcons.strokeRoundedStar; // ใช้ Star แทน Ticket
        break;
      case 'dismiss':
        bgColor = AppColors.inputBorder.withValues(alpha: 0.3);
        textColor = AppColors.secondaryText;
        statusIcon = HugeIcons.strokeRoundedCancel01;
        break;
      default:
        bgColor = AppColors.background;
        textColor = AppColors.primaryText;
        statusIcon = HugeIcons.strokeRoundedAlert02;
    }

    return GestureDetector(
      onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.sm),
        padding: EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: textColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + title + date
            Row(
              children: [
                HugeIcon(
                  icon: statusIcon,
                  color: textColor,
                  size: 14,
                ),
                AppSpacing.horizontalGapXs,
                Expanded(
                  child: Text(
                    task.title ?? 'ไม่ระบุชื่องาน',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (dateStr.isNotEmpty) ...[
                  AppSpacing.horizontalGapSm,
                  Text(
                    '$dateStr $timeStr',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),

            // Resolution note (ถ้ามี)
            if (task.resolutionNote != null &&
                task.resolutionNote!.isNotEmpty) ...[
              AppSpacing.verticalGapXs,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'วิธีแก้: ',
                    style: AppTypography.caption.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      task.resolutionNote!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Resolved by (ถ้ามี)
            if (task.resolvedByNickname != null) ...[
              AppSpacing.verticalGapXs,
              Text(
                'แก้โดย: ${task.resolvedByNickname}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}