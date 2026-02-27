import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/network_image.dart';
import '../../medicine/services/camera_service.dart';
import '../../medicine/screens/photo_preview_screen.dart';
import 'split_screen_camera_screen.dart';
import '../models/batch_task_group.dart';
import '../models/task_log.dart';
import '../providers/batch_task_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/co_worker_picker.dart';
import '../widgets/difficulty_rating_dialog.dart';
import 'task_detail_screen.dart';

/// หน้า Batch Task — ทำ task เดียวกันข้ามคนไข้หลายคน
///
/// Layout:
/// ┌─────────────────────────────────────────┐
/// │ ← พลิกตัว - โซน A         3/8 เสร็จ   │
/// │                                         │
/// │ [รูปตัวอย่าง (ถ้ามี)]                   │
/// │                                         │
/// │ เพื่อนร่วมเวร: [+เลือก]               │
/// │   ● สมชาย  ● สมหญิง                   │
/// │                                         │
/// │ ─── รายชื่อคนไข้ ───                   │
/// │ ✅ ลุงสมชาย   [thumb] โดย: สมปอง      │
/// │ ⬜ ยายมาลี            [กดถ่ายรูป]      │
/// └─────────────────────────────────────────┘
class BatchTaskScreen extends ConsumerWidget {
  final BatchTaskGroup group;

  const BatchTaskScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchState = ref.watch(batchTaskProvider(group.groupKey));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppColors.primaryText,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ชื่อ task
            Text(
              batchState.taskTitle,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            // โซน + progress
            Text(
              '${batchState.zoneName} · ${batchState.completedCount}/${batchState.totalCount} เสร็จ',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Progress bar ด้านบน
          LinearProgressIndicator(
            value: batchState.progress,
            minHeight: 3,
            backgroundColor: AppColors.alternate,
            valueColor: AlwaysStoppedAnimation<Color>(
              batchState.completedCount == batchState.totalCount
                  ? AppColors.tagPassedText
                  : AppColors.primary,
            ),
          ),

          // Content — pull to refresh จะ reload task data ทั้งหมด
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                // เพิ่ม counter เพื่อ trigger re-fetch ของ task providers
                ref.read(taskRefreshCounterProvider.notifier).state++;
                // invalidate batch provider ให้สร้าง state ใหม่จาก data ล่าสุด
                ref.invalidate(batchTaskProvider(group.groupKey));
              },
              child: ListView(
                padding: EdgeInsets.all(AppSpacing.md),
                children: [
                  // Co-worker picker section (reusable widget)
                  // sync กับ batch provider: เมื่อ selection เปลี่ยน → update state
                  CoWorkerPickerSection(
                    initialSelection: batchState.selectedCoWorkers,
                    onChanged: (coWorkers) {
                      final notifier = ref.read(
                          batchTaskProvider(group.groupKey).notifier);
                      // clear แล้วเพิ่มใหม่ทั้งหมด
                      for (final cw in batchState.selectedCoWorkers) {
                        notifier.removeCoWorker(cw.userId);
                      }
                      for (final cw in coWorkers) {
                        notifier.addCoWorker(cw);
                      }
                    },
                  ),
                  AppSpacing.verticalGapMd,

                  // Divider + header
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedUserMultiple,
                        color: AppColors.secondaryText,
                        size: 18,
                      ),
                      AppSpacing.horizontalGapSm,
                      Text(
                        'รายชื่อคนไข้',
                        style: AppTypography.title.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalGapSm,

                  // รายชื่อคนไข้
                  ...List.generate(batchState.residents.length, (index) {
                    return _ResidentTile(
                      resident: batchState.residents[index],
                      index: index,
                      groupKey: group.groupKey,
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile แสดงคนไข้แต่ละคนใน batch
///
/// Layout ใหม่:
/// ┌──────────────────────────────────────────────┐
/// │ [รูป 48x48]  ชื่อคนไข้          ⏰ 07:30   │
/// │              ⚠️ recurNote (แดง, ถ้ามี)      │
/// │              ✅ โดย: สมปอง · 08:15    [>]   │
/// └──────────────────────────────────────────────┘
///
/// Tap behavior:
/// - กด card (ส่วน content) → เข้า TaskDetailScreen ทุก status
/// - กดปุ่มกล้อง (ขวา, pending) → ถ่ายรูป + complete
/// - กดปุ่มลองใหม่ (ขวา, failed) → retry
/// - Completing → ไม่ทำอะไร (กำลัง upload อยู่)
class _ResidentTile extends ConsumerWidget {
  final BatchResidentState resident;
  final int index;
  final String groupKey;

  // Format เวลา HH:mm
  static final _timeFormat = DateFormat('HH:mm');

  const _ResidentTile({
    required this.resident,
    required this.index,
    required this.groupKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = resident.task;
    final isCompleted = resident.status == BatchResidentStatus.completed;
    final isFailed = resident.status == BatchResidentStatus.failed;
    final isCompleting = resident.status == BatchResidentStatus.completing;

    // เลือกรูปที่จะแสดง: completed → confirmImage, pending → sampleImage
    final imageUrl = isCompleted
        ? (resident.uploadedImageUrl ?? task.confirmImage ?? task.sampleImageUrl)
        : task.sampleImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return GestureDetector(
      // กด card → ไป TaskDetailScreen เสมอ (ยกเว้นกำลัง upload)
      onTap: isCompleting ? null : () => _navigateToDetail(context),
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.xs),
        // clipBehavior ให้ปุ่มถ่ายรูปชิดขอบขวาถูก clip ตาม border radius
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          border: Border.all(
            color: isCompleted
                ? AppColors.tagPassedBg
                : (isFailed ? AppColors.tagFailedBg : AppColors.alternate),
            width: isCompleted || isFailed ? 1.5 : 0.5,
          ),
        ),
        // IntrinsicHeight ให้ปุ่มขวายืดเต็มความสูงของ tile ได้
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ส่วน content ซ้าย (รูป + ชื่อ + info) มี padding
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    // ถ้าไม่มีรูป → center content แนวตั้ง
                    crossAxisAlignment: hasImage
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      // รูปของคนไข้คนนี้ (ถ้ามี)
                      if (hasImage) ...[
                        _buildLeadingImage(imageUrl),
                        AppSpacing.horizontalGapSm,
                      ],

                      // ชื่อ + ข้อมูลกำกับ
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: hasImage
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            // Row: ชื่อคนไข้ + เวลาที่คาดหวัง
                            Row(
                              children: [
                                // Status dot เล็กๆ หน้าชื่อ
                                _buildStatusDot(),
                                SizedBox(width: 6),
                                // ชื่อ
                                Expanded(
                                  child: Text(
                                    task.residentName ?? 'ไม่ระบุชื่อ',
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: isCompleted
                                          ? AppColors.secondaryText
                                          : AppColors.primaryText,
                                      decoration: isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // เวลา expected (เช่น 07:30)
                                if (task.expectedDateTime != null) ...[
                                  SizedBox(width: 4),
                                  Text(
                                    _timeFormat.format(
                                        task.expectedDateTime!.toLocal()),
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // recurNote — หมายเหตุสำคัญ (สีแดง)
                            if (task.recurNote != null &&
                                task.recurNote!.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  '⚠️ ${task.recurNote}',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.error,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                            // แสดงสถานะจริงจาก task.status + batch status
                            _buildStatusText(task),

                            // Completing (batch UI): กำลังบันทึก
                            if (isCompleting)
                              Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  'กำลังบันทึก...',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.secondaryText,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),

                            // Failed (batch UI): แสดง error message
                            if (isFailed)
                              Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  resident.errorMessage ?? 'เกิดข้อผิดพลาด',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Trailing: ปุ่มถ่ายรูปเต็มความสูง / chevron / retry
              _buildTrailing(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  /// แสดงสถานะจริงจาก task.status (Supabase)
  /// ใช้สี + label เดียวกับ _buildStatusBadge ในหน้า task_card.dart
  Widget _buildStatusText(TaskLog task) {
    final status = task.status;

    // pending — ยังไม่ได้ทำ
    if (status == null) {
      return Padding(
        padding: EdgeInsets.only(top: 2),
        child: Text(
          'รอดำเนินการ',
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
      );
    }

    // complete — เสร็จแล้ว + ชื่อผู้ทำ + เวลา
    if (status == 'complete') {
      final nickname =
          resident.completedByNickname ?? task.completedByNickname ?? '';
      final completedAt = task.completedAt;
      final timeStr = completedAt != null
          ? ' · ${_timeFormat.format(completedAt.toLocal())}'
          : '';
      return Padding(
        padding: EdgeInsets.only(top: 2),
        child: Text(
          'เสร็จแล้ว โดย: $nickname$timeStr',
          style: AppTypography.caption.copyWith(
            color: AppColors.tagPassedText,
          ),
        ),
      );
    }

    // problem, refer, postpone → แสดงเป็น badge เหมือนหน้า task card
    Color bgColor;
    Color textColor;
    String text;
    dynamic icon;

    if (status == 'problem') {
      // สีเดียวกับ task_card: tagFailedBg + tagFailedText
      bgColor = AppColors.tagFailedBg;
      textColor = AppColors.tagFailedText;
      text = 'ติดปัญหา';
      icon = HugeIcons.strokeRoundedAlert02;
    } else if (status == 'postpone') {
      // สีเดียวกับ task_card: tagPendingBg + tagPendingText
      bgColor = AppColors.tagPendingBg;
      textColor = AppColors.tagPendingText;
      text = 'เลื่อน';
      icon = HugeIcons.strokeRoundedCalendar01;
    } else if (status == 'refer') {
      // สีเดียวกับ task_card: secondary
      bgColor = AppColors.secondary.withValues(alpha: 0.2);
      textColor = AppColors.secondary;
      text = 'ไม่อยู่ศูนย์';
      icon = HugeIcons.strokeRoundedHospital01;
    } else {
      // fallback — status อื่นที่ไม่รู้จัก
      return Padding(
        padding: EdgeInsets.only(top: 2),
        child: Text(
          status,
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
      );
    }

    // Badge แบบเดียวกับ _buildStatusBadge ใน task_card.dart
    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, size: 12, color: textColor),
            SizedBox(width: 4),
            Text(
              text,
              style: AppTypography.caption.copyWith(
                color: textColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// รูป leading 48x48 (sample หรือ confirm ของคนไข้คนนี้)
  Widget _buildLeadingImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      // ไม่มีรูป → แสดง placeholder icon
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.tagNeutralBg,
          borderRadius: AppRadius.smallRadius,
        ),
        child: Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedImage01,
            color: AppColors.secondaryText,
            size: 20,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: AppRadius.smallRadius,
      child: IreneNetworkImage(
        imageUrl: imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        memCacheWidth: 96, // 2x สำหรับ high DPI
        compact: true,
      ),
    );
  }

  /// จุดสถานะเล็กๆ หน้าชื่อ (8x8)
  Widget _buildStatusDot() {
    final Color color;
    switch (resident.status) {
      case BatchResidentStatus.completed:
        color = AppColors.tagPassedText;
      case BatchResidentStatus.completing:
        color = AppColors.primary;
      case BatchResidentStatus.failed:
        color = AppColors.error;
      case BatchResidentStatus.pending:
        color = AppColors.alternate;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  /// Trailing widget:
  /// - Pending: ปุ่มถ่ายรูปเต็มความสูง ชิดขอบขวา (clip ตาม tile border radius)
  /// - Completing: loading spinner
  /// - Failed: ปุ่มลองใหม่เต็มความสูง
  /// - Completed: chevron (กดเข้า TaskDetailScreen)
  Widget _buildTrailing(BuildContext context, WidgetRef ref) {
    switch (resident.status) {
      case BatchResidentStatus.pending:
        // ถ้า task มี status แล้ว (problem/refer/postpone) → แสดง chevron เหมือน completed
        // แสดงปุ่มกล้องเฉพาะเมื่อ status == null (ยังไม่ได้ทำจริงๆ)
        if (resident.task.status != null) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: AppColors.secondaryText,
                size: 18,
              ),
            ),
          );
        }
        // ปุ่มถ่ายรูป — เต็มความสูง ชิดขอบขวาของ tile
        // GestureDetector แยกจาก card เพื่อให้กดกล้องได้โดยไม่ไป TaskDetail
        return GestureDetector(
          onTap: () => _handleTakePhotoAndComplete(context, ref),
          child: Container(
            color: AppColors.primary,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCamera01,
                  color: Colors.white,
                  size: 16,
                ),
                AppSpacing.horizontalGapXs,
                Text(
                  'ถ่ายรูป',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      case BatchResidentStatus.completing:
        // กำลัง upload — แสดง spinner กลาง
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
        );
      case BatchResidentStatus.failed:
        // ปุ่มลองใหม่ — เต็มความสูง ชิดขอบขวา
        // GestureDetector แยกจาก card เพื่อให้กด retry ได้โดยไม่ไป TaskDetail
        return GestureDetector(
          onTap: () =>
              ref.read(batchTaskProvider(groupKey).notifier).retryResident(index),
          child: Container(
            color: AppColors.tagFailedBg,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            alignment: Alignment.center,
            child: Text(
              'ลองใหม่',
              style: AppTypography.caption.copyWith(
                color: AppColors.tagFailedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      case BatchResidentStatus.completed:
        // Chevron → กดเข้า TaskDetailScreen
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: AppColors.secondaryText,
              size: 18,
            ),
          ),
        );
    }
  }

  /// กด card → เข้า TaskDetailScreen ของผู้พักคนนั้นเสมอ
  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(task: resident.task),
      ),
    );
  }

  /// Flow: กดถ่ายรูป → camera → preview → difficulty rating → upload + complete
  Future<void> _handleTakePhotoAndComplete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // DEV MODE: ถ้าเป็น debug mode บน desktop ใช้รูป dummy
    final bool isDesktopOrWeb =
        kIsWeb ||
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux));

    if (kDebugMode && isDesktopOrWeb) {
      // Dev mode: ข้าม camera → ใช้รูป dummy
      // แสดง difficulty rating dialog ก่อน
      final diffResult = await DifficultyRatingDialog.show(
        context,
        taskTitle: resident.task.title,
        allowSkip: true,
        avgScore: resident.task.avgDifficultyScore30d,
      );
      if (diffResult == null) return;

      // Dev mode: แสดง snackbar แจ้ง
      if (!context.mounted) return;
      AppToast.info(context, 'Dev mode: ข้ามการถ่ายรูป');
      return;
    }

    // 1. เปิดกล้อง — ถ้ามีรูปตัวอย่าง ใช้ split-screen เทียบรูป
    File? file;
    if (resident.task.hasSampleImage) {
      // Split-screen camera: ครึ่งบนรูปตัวอย่าง ครึ่งล่างกล้อง
      if (!context.mounted) return;
      file = await SplitScreenCameraScreen.show(
        context: context,
        sampleImageUrl: resident.task.sampleImageUrl!,
      );
    } else {
      // กล้อง native ปกติ
      final cameraService = CameraService.instance;
      file = await cameraService.takePhoto();
    }
    if (file == null) return; // user ยกเลิก

    // 2. แสดง PhotoPreviewScreen (หมุนรูปได้)
    if (!context.mounted) return;
    final confirmedFile = await PhotoPreviewScreen.show(
      context: context,
      imageFile: file,
      photoType: 'task',
      mealLabel: resident.task.title ?? 'งาน',
    );
    if (confirmedFile == null) return; // user ยกเลิกจาก preview

    // 3. แสดง DifficultyRatingDialog (1-10 หรือข้าม)
    if (!context.mounted) return;
    final diffResult = await DifficultyRatingDialog.show(
      context,
      taskTitle: resident.task.title,
      allowSkip: true,
      avgScore: resident.task.avgDifficultyScore30d,
    );
    // ถ้า user กด back → ยกเลิกทั้งหมด (ไม่ complete)
    if (diffResult == null) return;

    // 4. Upload + mark complete ทันที
    final notifier = ref.read(batchTaskProvider(groupKey).notifier);
    final success = await notifier.completeResident(
      residentIndex: index,
      imageFile: confirmedFile,
      difficultyScore: diffResult.score,
    );

    // 5. แสดงผลลัพธ์
    if (!context.mounted) return;
    if (success) {
      AppToast.success(
        context,
        '✓ ${resident.task.residentName ?? "คนไข้"} เสร็จแล้ว',
      );
    } else {
      AppToast.error(context, 'เกิดข้อผิดพลาด กดลองใหม่ได้');
    }
  }
}
