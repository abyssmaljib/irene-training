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
  final String? currentUserId; // user ID สำหรับตรวจสอบ unseen badge
  final bool flat; // แสดงแบบ flat ไม่มี shadow (ใช้ภายใน section)

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onCheckChanged,
    this.showZone = true,
    this.showResident = true,
    this.showProblemNote = true,
    this.showAssignedRole = true,
    this.currentUserId,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    final showUnseenBadge = task.hasUnseenUpdate(currentUserId);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main card content
          Container(
            padding: EdgeInsets.all(flat ? AppSpacing.sm : AppSpacing.md),
            decoration: BoxDecoration(
              color: flat ? Colors.transparent : AppColors.surface,
              borderRadius: AppRadius.mediumRadius,
              boxShadow: flat ? null : [AppShadows.subtle],
              border: flat ? Border(bottom: BorderSide(color: AppColors.alternate.withValues(alpha: 0.5))) : _getBorder(),
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
                      // Row 1: resident name + taskType + status badge
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
                          ],
                          if (task.taskType != null && task.taskType!.isNotEmpty) ...[
                            AppSpacing.horizontalGapSm,
                            _buildTaskTypeBadge(),
                          ],
                          const Spacer(),
                          if (task.isProblem) ...[
                            AppSpacing.horizontalGapSm,
                            _buildStatusBadge(),
                          ],
                        ],
                      ),
                      // Row 2: title only
                      AppSpacing.verticalGapXs,
                      Text(
                        task.title ?? 'ไม่มีชื่องาน',
                        style: AppTypography.body.copyWith(
                          decoration:
                              task.isDone ? TextDecoration.lineThrough : null,
                          color: task.isDone
                              ? AppColors.secondaryText
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Row 3: time + zone + role
                      AppSpacing.verticalGapXs,
                      Row(
                        children: [
                          if (task.expectedDateTime != null) ...[
                            Icon(Iconsax.clock,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(task.expectedDateTime!),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.w600,
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
                      // Row สำหรับ badges: taskType, recurrence, daysOfWeek, recurringDates
                      if (_hasAnyBadges()) ...[
                        AppSpacing.verticalGapSm,
                        _buildBadgesRow(),
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
                            // เวลาที่ติ๊ก (สีตามความต่างจาก expectedDateTime)
                            if (task.completedAt != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                _formatCompletedTime(task.completedAt!),
                                style: AppTypography.caption.copyWith(
                                  color: _getCompletedTimeColor(task.completedAt!, task.expectedDateTime),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
                // Task type indicators (icons แสดงประเภทงาน)
                _buildTaskTypeIcons(),
              ],
            ),
          ),
          // Badge "อัพ" - แสดงเมื่อมี update ที่ user ยังไม่เห็น
          if (showUnseenBadge)
            Positioned(
              top: -4,
              right: 12,
              child: _buildUnseenBadge(),
            ),
        ],
      ),
    );
  }

  /// Badge แสดงว่ามีอัพเดตที่ยังไม่เห็น
  Widget _buildUnseenBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tertiary, // สีชมพู (customColor1 ใน FlutterFlow)
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'อัพ',
        style: AppTypography.caption.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
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
    // Visual only - ไม่ให้ interaction จากหน้าการ์ด
    // ต้องกดเข้าไปหน้า detail เพื่อทำงาน
    return Container(
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
        color: const Color(0xFFE8DEF8), // สีม่วงอ่อน pastel
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.user_tag, size: 10, color: Color(0xFF6750A4)),
          const SizedBox(width: 2),
          Text(
            task.assignedRoleName!,
            style: AppTypography.caption.copyWith(
              color: const Color(0xFF6750A4), // สีม่วงเข้ม
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

  /// Format เวลาที่ติ๊กงาน (HH:mm)
  String _formatCompletedTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// คำนวณสีของเวลาที่ติ๊กงาน ตามความต่างจาก expectedDateTime
  /// - ± 30 นาที -> เขียว
  /// - ± 1 ชม. -> ส้ม
  /// - > 1 ชม. ครึ่ง -> แดง
  Color _getCompletedTimeColor(DateTime completedAt, DateTime? expectedDateTime) {
    // ถ้าไม่มี expectedDateTime ให้แสดงสีเขียวปกติ
    if (expectedDateTime == null) {
      return AppColors.tagPassedText;
    }

    final difference = completedAt.difference(expectedDateTime).abs();
    final minutes = difference.inMinutes;

    if (minutes <= 30) {
      // ± 30 นาที -> เขียว
      return AppColors.tagPassedText;
    } else if (minutes <= 60) {
      // ± 1 ชม. -> ส้ม
      return AppColors.tagPendingText;
    } else {
      // > 1 ชม. -> แดง
      return AppColors.error;
    }
  }

  /// สร้าง icons แสดงประเภทงาน (กล้อง, สี่เหลี่ยม)
  Widget _buildTaskTypeIcons() {
    final icons = <Widget>[];

    // กล้อง = งานที่มีรูปตัวอย่าง หรือต้องถ่ายรูป
    if (task.hasSampleImage || task.requireImage) {
      icons.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(
            Iconsax.camera,
            size: 18,
            color: AppColors.tertiary,
          ),
        ),
      );
    }

    // สี่เหลี่ยม = งานที่ต้องทำหลังจากโพสต์
    if (task.mustCompleteByPost) {
      icons.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(
            Iconsax.document_text,
            size: 18,
            color: AppColors.tertiary,
          ),
        ),
      );
    }

    if (icons.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: icons,
    );
  }

  /// ตรวจสอบว่ามี badges ที่ต้องแสดงหรือไม่ (ไม่รวม taskType ที่ย้ายไป row บน)
  bool _hasAnyBadges() {
    return task.recurrenceInterval != null ||
        task.daysOfWeek.isNotEmpty ||
        task.recurringDates.isNotEmpty ||
        task.postponeFrom != null ||
        task.postponeTo != null;
  }

  /// สร้าง row สำหรับแสดง badges ต่างๆ (ไม่รวม taskType ที่ย้ายไป row บน)
  Widget _buildBadgesRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // 1. Recurrence badge (สีเหลือง)
        if (task.recurrenceInterval != null) _buildRecurrenceBadge(),
        // 2. Days of week (วงกลมสี)
        if (task.daysOfWeek.isNotEmpty) _buildDaysOfWeekBadges(),
        // 3. Recurring dates (วงกลมเขียว)
        if (task.recurringDates.isNotEmpty) _buildRecurringDatesBadges(),
        // 4. Postpone from badge (เลื่อนมาจาก)
        if (task.postponeFrom != null) _buildPostponeFromBadge(),
        // 5. Postpone to badge (ถูกเลื่อน)
        if (task.postponeTo != null) _buildPostponeToBadge(),
      ],
    );
  }

  /// Badge สำหรับ taskType (สีชมพู)
  Widget _buildTaskTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent3,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        task.taskType!,
        style: AppTypography.caption.copyWith(
          color: AppColors.tertiary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Badge สำหรับ recurrence (สีเหลือง "ทุก X วัน/สัปดาห์/เดือน")
  Widget _buildRecurrenceBadge() {
    final interval = task.recurrenceInterval ?? 1;
    final type = task.recurrenceType ?? 'วัน';
    final text = 'ทุก $interval $type';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD553), // สีเหลืองจาก FlutterFlow
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.repeat, size: 12, color: const Color(0xFF5D4A00)),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: const Color(0xFF5D4A00), // สีน้ำตาลเข้ม
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Badges สำหรับ daysOfWeek (วงกลมสีแต่ละวัน)
  Widget _buildDaysOfWeekBadges() {
    // สีสำหรับแต่ละวัน
    const dayColors = {
      'จันทร์': Color(0xFFF1EF99), // เหลือง
      'อังคาร': Color(0xFFFFB6C1), // ชมพู
      'พุธ': Color(0xFF90EE90), // เขียว
      'พฤหัสบดี': Color(0xFFFFD4B2), // ส้ม
      'ศุกร์': Color(0xFFADD8E6), // ฟ้า
      'เสาร์': Color(0xFFDDA0DD), // ม่วง
      'อาทิตย์': Color(0xFFFF6B6B), // แดง
    };

    const dayAbbr = {
      'จันทร์': 'จ',
      'อังคาร': 'อ',
      'พุธ': 'พ',
      'พฤหัสบดี': 'พฤ',
      'ศุกร์': 'ศ',
      'เสาร์': 'ส',
      'อาทิตย์': 'อา',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: task.daysOfWeek.map((day) {
        final color = dayColors[day] ?? AppColors.accent1;
        final abbr = dayAbbr[day] ?? day.substring(0, 1);
        return Container(
          margin: const EdgeInsets.only(right: 4),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              abbr,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Badges สำหรับ recurringDates (วงกลมเขียวแสดงวันที่)
  Widget _buildRecurringDatesBadges() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: task.recurringDates.map((date) {
        return Container(
          margin: const EdgeInsets.only(right: 4),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.tagPassedBg,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.tagPassedText, width: 1),
          ),
          child: Center(
            child: Text(
              '$date',
              style: AppTypography.caption.copyWith(
                color: AppColors.tagPassedText,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Badge สำหรับ "เลื่อนมาจาก" (postponeFrom != null)
  Widget _buildPostponeFromBadge() {
    // Format วันเวลาเดิม
    String dateText = '';
    if (task.expectedDatePostponeFrom != null) {
      final dt = task.expectedDatePostponeFrom!;
      dateText = ' - ${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.textPrimary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.arrow_circle_left, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 4),
          Text(
            'เลื่อนมาจาก',
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontSize: 10,
            ),
          ),
          if (dateText.isNotEmpty)
            Text(
              dateText,
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  /// Badge สำหรับ "ถูกเลื่อน" (postponeTo != null)
  Widget _buildPostponeToBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.textPrimary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.arrow_circle_right, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 4),
          Text(
            'ถูกเลื่อน',
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
