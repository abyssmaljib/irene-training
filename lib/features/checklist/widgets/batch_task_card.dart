import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/batch_task_group.dart';

/// Card สำหรับแสดง batch group ของ tasks ที่เหมือนกัน
/// แสดง: ชื่อ task, timeBlock, โซน, จำนวน complete/total, progress bar
///
/// ตัวอย่าง UI:
/// ┌─────────────────────────────────────────┐
/// │ 🔄 พลิกตัว              07:00-09:00    │
/// │    โซน A · 2/8 เสร็จ              >    │
/// │    ██████░░░░░░░ 25%                    │
/// └─────────────────────────────────────────┘
class BatchTaskCard extends StatelessWidget {
  final BatchTaskGroup group;
  final VoidCallback? onTap;

  /// แสดงแบบ flat ไม่มี shadow (ใช้ภายใน TaskTimeSection)
  final bool flat;

  const BatchTaskCard({
    super.key,
    required this.group,
    this.onTap,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = group.progress;
    final isAllDone = group.isAllDone;
    // สีของ progress bar ตามสถานะจริง:
    // - เสร็จหมด (ไม่มี problem/postpone) → เขียว
    // - จัดการหมดแต่มี problem/postpone → เหลือง (เตือน)
    // - ยังไม่หมด → primary (teal)
    final Color progressColor;
    final Color borderColor;
    if (isAllDone && !group.hasNonCompleteStatus) {
      // ทุกคนเสร็จสมบูรณ์จริง
      progressColor = AppColors.tagPassedText;
      borderColor = AppColors.tagPassedBg;
    } else if (isAllDone && group.hasNonCompleteStatus) {
      // จัดการหมดแล้วแต่มีบางคนติดปัญหา/เลื่อน
      progressColor = AppColors.tagPendingText;
      borderColor = AppColors.tagPendingBg;
    } else {
      progressColor = AppColors.primary;
      borderColor = flat ? AppColors.alternate : Colors.transparent;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(flat ? AppSpacing.sm : AppSpacing.md),
        decoration: BoxDecoration(
          color: flat ? Colors.transparent : AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          boxShadow: flat ? null : [AppShadows.subtle],
          border: Border.all(
            color: borderColor,
            width: isAllDone ? 1.5 : (flat ? 0.5 : 0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Icon + ชื่อ task + timeBlock
            Row(
              children: [
                // ไอคอน batch (layers) — แสดงว่านี่คือ batch group
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isAllDone
                        ? (group.hasNonCompleteStatus
                            ? AppColors.tagPendingBg
                            : AppColors.tagPassedBg)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smallRadius,
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedLayers01,
                      color: isAllDone
                          ? (group.hasNonCompleteStatus
                              ? AppColors.tagPendingText
                              : AppColors.tagPassedText)
                          : AppColors.primary,
                      size: 18,
                    ),
                  ),
                ),
                AppSpacing.horizontalGapSm,
                // ชื่อ task
                Expanded(
                  child: Text(
                    group.title,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isAllDone
                          ? AppColors.secondaryText
                          : AppColors.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppSpacing.horizontalGapSm,
                // timeBlock (เช่น "07:00-09:00")
                Text(
                  group.timeBlock,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),

            AppSpacing.verticalGapXs,

            // Row 2: โซน + สรุปสถานะ + ลูกศร
            Padding(
              padding: EdgeInsets.only(left: 40), // ชิดกับ text ข้างบน (32 icon + 8 gap)
              child: Row(
                children: [
                  // ชื่อโซน
                  Text(
                    group.zoneName,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Text(
                      '·',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  // สรุปสถานะตามจริง
                  Expanded(child: _buildStatusSummary()),
                  // ลูกศรไปหน้า BatchTaskScreen
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: AppColors.secondaryText,
                    size: 16,
                  ),
                ],
              ),
            ),

            AppSpacing.verticalGapSm,

            // Row 3: Progress bar
            Padding(
              padding: EdgeInsets.only(left: 40),
              child: ClipRRect(
                borderRadius: AppRadius.fullRadius,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: AppColors.alternate,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// สรุปสถานะแบบ inline: "3/6 เสร็จ · 1 ติดปัญหา · 1 เลื่อน"
  Widget _buildStatusSummary() {
    final parts = <InlineSpan>[];

    // จำนวนเสร็จ (complete + refer)
    final doneCount = group.completedCount;
    parts.add(TextSpan(
      text: '$doneCount/${group.totalCount} เสร็จ',
      style: AppTypography.caption.copyWith(
        color: group.isAllDone && !group.hasNonCompleteStatus
            ? AppColors.tagPassedText
            : AppColors.primaryText,
        fontWeight: FontWeight.w500,
      ),
    ));

    // ติดปัญหา
    if (group.problemCount > 0) {
      parts.add(TextSpan(
        text: ' · ${group.problemCount} ติดปัญหา',
        style: AppTypography.caption.copyWith(
          color: AppColors.tagFailedText,
          fontWeight: FontWeight.w500,
        ),
      ));
    }

    // เลื่อน
    if (group.postponedCount > 0) {
      parts.add(TextSpan(
        text: ' · ${group.postponedCount} เลื่อน',
        style: AppTypography.caption.copyWith(
          color: AppColors.tagPendingText,
          fontWeight: FontWeight.w500,
        ),
      ));
    }

    return Text.rich(
      TextSpan(children: parts),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
