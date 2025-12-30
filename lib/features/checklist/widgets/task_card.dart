import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/task_log.dart';

/// Card สำหรับแสดง Task แต่ละรายการ
class TaskCard extends StatelessWidget {
  final TaskLog task;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onCheckChanged;
  final bool showZone;
  final bool showResident;
  final bool showProblemNote; // แสดงหมายเหตุเมื่อติดปัญหา
  final bool showAssignedRole; // แสดงตำแหน่งที่ได้รับมอบหมาย

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onCheckChanged,
    this.showZone = true,
    this.showResident = true,
    this.showProblemNote = true,
    this.showAssignedRole = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          boxShadow: [AppShadows.subtle],
          border: _getBorder(),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox หรือ Warning icon (สำหรับ problem tasks)
            _buildLeadingWidget(),
            AppSpacing.horizontalGapMd,
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Status badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title ?? 'ไม่มีชื่องาน',
                          style: AppTypography.body.copyWith(
                            decoration:
                                task.isDone ? TextDecoration.lineThrough : null,
                            color: task.isDone
                                ? AppColors.secondaryText
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.isProblem) ...[
                        AppSpacing.horizontalGapSm,
                        _buildStatusBadge(),
                      ],
                    ],
                  ),
                  AppSpacing.verticalGapXs,
                  // Subtitle: resident + zone + time
                  Row(
                    children: [
                      if (showResident && task.residentName != null) ...[
                        Icon(Iconsax.user,
                            size: 12, color: AppColors.secondaryText),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            task.residentName!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.secondaryText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AppSpacing.horizontalGapSm,
                      ],
                      if (showZone && task.zoneName != null) ...[
                        _buildZoneBadge(),
                        AppSpacing.horizontalGapSm,
                      ],
                      if (showAssignedRole && task.assignedRoleName != null) ...[
                        _buildRoleBadge(),
                        AppSpacing.horizontalGapSm,
                      ],
                      if (task.expectedDateTime != null) ...[
                        Icon(Iconsax.clock,
                            size: 12, color: AppColors.secondaryText),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(task.expectedDateTime!),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // recurNote - ข้อความกำกับสำคัญ
                  if (task.recurNote != null && task.recurNote!.isNotEmpty) ...[
                    AppSpacing.verticalGapXs,
                    Text(
                      task.recurNote!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Completed by info (if done)
                  if (task.isDone && task.completedByNickname != null) ...[
                    AppSpacing.verticalGapXs,
                    Row(
                      children: [
                        Icon(Iconsax.tick_circle,
                            size: 12, color: AppColors.tagPassedText),
                        const SizedBox(width: 4),
                        Text(
                          'โดย ${task.completedByNickname}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.tagPassedText,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // หมายเหตุสำหรับ problem tasks (ใช้ descript field)
                  if (showProblemNote &&
                      task.isProblem &&
                      task.descript != null &&
                      task.descript!.isNotEmpty) ...[
                    AppSpacing.verticalGapSm,
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Iconsax.quote_up,
                            size: 14,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.descript!,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          if (task.completedByNickname != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '- ${task.completedByNickname}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Require image indicator
            if (task.requireImage && !task.isDone) ...[
              AppSpacing.horizontalGapSm,
              Icon(Iconsax.camera, size: 18, color: AppColors.tertiary),
            ],
          ],
        ),
      ),
    );
  }

  Border? _getBorder() {
    if (task.isDone) {
      return Border.all(color: AppColors.tagPassedBg, width: 2);
    }
    if (task.isProblem) {
      return Border.all(color: AppColors.tagFailedBg, width: 2);
    }
    return null;
  }

  /// แสดง Checkbox หรือ Warning icon ตามสถานะ
  Widget _buildLeadingWidget() {
    // ถ้าติดปัญหา แสดง warning icon สีเหลือง
    if (task.isProblem) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.tagPendingBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.priority_high,
          color: AppColors.tagPendingText,
          size: 18,
        ),
      );
    }
    // ปกติแสดง checkbox
    return _buildCheckbox();
  }

  Widget _buildCheckbox() {
    return GestureDetector(
      onTap: () {
        if (onCheckChanged != null) {
          onCheckChanged!(!task.isDone);
        }
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: task.isDone ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: task.isDone ? AppColors.primary : AppColors.alternate,
            width: 2,
          ),
        ),
        child: task.isDone
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : null,
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    String text;

    if (task.isProblem) {
      bgColor = AppColors.tagFailedBg;
      textColor = AppColors.tagFailedText;
      text = 'ติดปัญหา';
    } else if (task.isPostponed) {
      bgColor = AppColors.tagPendingBg;
      textColor = AppColors.tagPendingText;
      text = 'เลื่อน';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: textColor,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildZoneBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        task.zoneName!,
        style: AppTypography.caption.copyWith(
          color: AppColors.primary,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildRoleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent3, // สีชมพูอ่อน
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.user_tag, size: 10, color: AppColors.tertiary),
          const SizedBox(width: 2),
          Text(
            task.assignedRoleName!,
            style: AppTypography.caption.copyWith(
              color: AppColors.tertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    // แปลงเป็น local time (timezone ไทย) ก่อนแสดงผล
    final localTime = dateTime.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour.$minute น.';
  }
}
