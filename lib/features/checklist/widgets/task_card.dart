import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/nps_scale.dart';
import '../models/problem_type.dart';
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
    // คำนวณว่าต้องแสดง decorative icon หรือไม่ (ลด widget tree depth เมื่อไม่ต้องใช้ Stack)
    final showDecorativeIcon = task.hasSampleImage || task.requireImage || task.mustCompleteByPost || task.taskType == 'จัดยา';

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main card content
          Container(
            padding: EdgeInsets.all(flat ? AppSpacing.sm : AppSpacing.md),
            // ใช้ Clip.hardEdge เฉพาะเมื่อมี decorative icon (ประหยัด GPU)
            clipBehavior: showDecorativeIcon ? Clip.hardEdge : Clip.none,
            decoration: BoxDecoration(
              color: flat ? Colors.transparent : AppColors.surface,
              borderRadius: AppRadius.mediumRadius,
              boxShadow: flat ? null : [AppShadows.subtle],
              border: flat ? Border(bottom: BorderSide(color: AppColors.alternate.withValues(alpha: 0.5))) : _getBorder(),
            ),
            // ใช้ Stack เฉพาะเมื่อมี decorative icon เพื่อลด widget tree depth
            child: showDecorativeIcon
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ใช้ color.withValues(alpha:) แทน Opacity widget
                      // เพราะ Opacity ทำให้เกิด saveLayer ซึ่งกิน GPU หนักมากใน list
                      // decorative icon อยู่กลาง card
                      Positioned(
                        right: -12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: HugeIcon(
                            icon: task.taskType == 'จัดยา'
                                ? HugeIcons.strokeRoundedMedicine02
                                : (task.hasSampleImage || task.requireImage)
                                    ? HugeIcons.strokeRoundedCamera01
                                    : HugeIcons.strokeRoundedFileEdit,
                            size: 80,
                            color: AppColors.tertiary.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      _buildMainContent(),
                    ],
                  )
                : _buildMainContent(),
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

  /// Main content row — แยกออกมาเพื่อใช้ร่วมกันทั้งแบบมี/ไม่มี decorative icon
  Widget _buildMainContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLeadingWidget(),
        AppSpacing.horizontalGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: resident name + taskType
              Row(
                children: [
                  if (showResident && task.residentName != null) ...[
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedUser, size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                task.residentName!,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (task.taskType != null && task.taskType!.isNotEmpty) ...[
                    AppSpacing.horizontalGapSm,
                    _buildTaskTypeBadge(),
                  ],
                ],
              ),
              // Row 2: title
              AppSpacing.verticalGapXs,
              Text(
                task.title ?? 'ไม่มีชื่องาน',
                style: AppTypography.body.copyWith(
                  decoration: task.isDone ? TextDecoration.lineThrough : null,
                  color: task.isDone ? AppColors.secondaryText : AppColors.textPrimary,
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
                    HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 12, color: AppColors.primary),
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
              // recurNote
              if (task.recurNote != null && task.recurNote!.isNotEmpty) ...[
                AppSpacing.verticalGapXs,
                Text(
                  task.recurNote!,
                  style: AppTypography.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Badges row
              if (_hasAnyBadges()) ...[
                AppSpacing.verticalGapSm,
                _buildBadgesRow(),
              ],
              // Completed by info
              if (task.isDone && task.completedByNickname != null) ...[
                AppSpacing.verticalGapXs,
                Row(
                  children: [
                    HugeIcon(
                      icon: task.isReferred ? HugeIcons.strokeRoundedHospital01 : HugeIcons.strokeRoundedCheckmarkCircle02,
                      size: 12,
                      color: task.isReferred ? AppColors.secondary : AppColors.tagPassedText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'โดย ${task.completedByNickname}',
                      style: AppTypography.caption.copyWith(
                        color: task.isReferred ? AppColors.secondary : AppColors.tagPassedText,
                      ),
                    ),
                    if (task.completedAt != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        _formatCompletedTime(task.completedAt!),
                        style: AppTypography.caption.copyWith(
                          color: task.isReferred
                              ? AppColors.secondary
                              : _getCompletedTimeColor(task.completedAt!, task.expectedDateTime),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              // Problem type badge — ใช้ _buildProblemTypeBadge() แทน Builder
              if (showProblemNote && task.isProblem && task.problemType != null) ...[
                AppSpacing.verticalGapSm,
                _buildProblemTypeBadge(),
              ],
              // Problem description
              if (showProblemNote && task.isProblem && task.descript != null && task.descript!.isNotEmpty) ...[
                AppSpacing.verticalGapXs,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedQuoteUp, size: 14, color: AppColors.secondaryText),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.descript!,
                              style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      if (task.completedByNickname != null) ...[
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '- ${task.completedByNickname}',
                            style: AppTypography.caption.copyWith(color: AppColors.secondaryText, fontSize: 10),
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
        _buildRightColumn(),
      ],
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

  /// Badge สำหรับ problemType — แทน Builder widget เพื่อลด widget tree depth
  Widget _buildProblemTypeBadge() {
    final problemType = ProblemType.fromValue(task.problemType);
    if (problemType == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(problemType.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            problemType.label,
            style: AppTypography.caption.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        // wrap Center เพื่อให้ icon อยู่ตรงกลาง Container
        child: Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            color: AppColors.tagPendingText,
            size: 18,
          ),
        ),
      );
    }
    // ถ้าไม่อยู่ศูนย์ (refer) แสดง icon โรงพยาบาล
    if (task.isReferred) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(6),
        ),
        // wrap Center เพื่อให้ icon อยู่ตรงกลาง Container
        child: Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedHospital01,
            color: Colors.white,
            size: 16,
          ),
        ),
      );
    }
    // ปกติแสดง checkbox
    return _buildCheckbox();
  }

  Widget _buildCheckbox() {
    // Visual only - ไม่ให้ interaction จากหน้าการ์ด
    // ต้องกดเข้าไปหน้า detail เพื่อทำงาน
    final isComplete = task.isComplete; // เฉพาะ complete ไม่รวม refer
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isComplete ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isComplete ? AppColors.primary : AppColors.alternate,
          width: 2,
        ),
      ),
      // wrap Center เพื่อให้ icon อยู่ตรงกลาง Container
      child: isComplete
          ? Center(
              child: HugeIcon(icon: HugeIcons.strokeRoundedTick01, color: Colors.white, size: AppIconSize.sm),
            )
          : null,
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    String text;
    dynamic icon;

    if (task.isProblem) {
      bgColor = AppColors.tagFailedBg;
      textColor = AppColors.tagFailedText;
      text = 'ติดปัญหา';
      icon = HugeIcons.strokeRoundedAlert02;
    } else if (task.isPostponed) {
      bgColor = AppColors.tagPendingBg;
      textColor = AppColors.tagPendingText;
      text = 'เลื่อน';
      icon = HugeIcons.strokeRoundedCalendar01;
    } else if (task.isReferred) {
      bgColor = AppColors.secondary.withValues(alpha: 0.2);
      textColor = AppColors.secondary;
      text = 'ไม่อยู่ศูนย์';
      icon = HugeIcons.strokeRoundedHospital01;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: AppIconSize.xs, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontSize: 10,
            ),
          ),
        ],
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
          HugeIcon(icon: HugeIcons.strokeRoundedUserAccount, size: AppIconSize.xs, color: Color(0xFF6750A4)),
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

  /// สร้าง column ด้านขวา (status badge + task type icons + difficulty)
  Widget _buildRightColumn() {
    final items = <Widget>[];

    // Status badge (ติดปัญหา, เลื่อน, ไม่อยู่ศูนย์)
    if (task.isProblem || task.isPostponed || task.isReferred) {
      items.add(_buildStatusBadge());
    }

    // Difficulty badge (คะแนนความยากที่ user ให้ไว้)
    final difficultyBadge = _buildDifficultyBadge();
    if (difficultyBadge != null) {
      items.add(
        Padding(
          padding: EdgeInsets.only(top: items.isEmpty ? 0 : 6),
          child: difficultyBadge,
        ),
      );
    }

    // icon กล้อง/โพส ย้ายไปเป็น decorative background ที่มุมขวาล่างแล้ว

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: items,
    );
  }

  /// ตรวจสอบว่ามี badges ที่ต้องแสดงหรือไม่ (ไม่รวม taskType ที่ย้ายไป row บน)
  bool _hasAnyBadges() {
    return _shouldShowRecurrence() ||
        task.daysOfWeek.isNotEmpty ||
        task.recurringDates.isNotEmpty ||
        task.postponeFrom != null ||
        task.postponeTo != null;
  }

  /// ตรวจสอบว่าควรแสดง recurrence badge หรือไม่
  /// ซ่อน "ทุก 1 วัน" เพราะเป็นค่า default
  bool _shouldShowRecurrence() {
    if (task.recurrenceInterval == null) return false;
    // ซ่อนถ้าเป็น "ทุก 1 วัน"
    if (task.recurrenceInterval == 1 && (task.recurrenceType == 'วัน' || task.recurrenceType == null)) {
      return false;
    }
    return true;
  }

  /// สร้าง row สำหรับแสดง badges ต่างๆ (ไม่รวม taskType ที่ย้ายไป row บน)
  Widget _buildBadgesRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // 1. Recurrence badge (สีเหลือง) - ซ่อน "ทุก 1 วัน"
        if (_shouldShowRecurrence()) _buildRecurrenceBadge(),
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
          HugeIcon(icon: HugeIcons.strokeRoundedRepeat, size: AppIconSize.xs, color: const Color(0xFF5D4A00)),
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
    // สีสำหรับแต่ละวัน (รองรับทุกรูปแบบชื่อวันที่อาจเก็บใน DB)
    const dayColors = {
      'จันทร์': Color(0xFFF1EF99),
      'อังคาร': Color(0xFFFFB6C1),
      'พุธ': Color(0xFF90EE90),
      'พฤหัสบดี': Color(0xFFFFD4B2),
      'พฤหัส': Color(0xFFFFD4B2),
      'ศุกร์': Color(0xFFADD8E6),
      'เสาร์': Color(0xFFDDA0DD),
      'อาทิตย์': Color(0xFFFF6B6B),
      'จ': Color(0xFFF1EF99),
      'อ': Color(0xFFFFB6C1),
      'พ': Color(0xFF90EE90),
      'พฤ': Color(0xFFFFD4B2),
      'ศ': Color(0xFFADD8E6),
      'ส': Color(0xFFDDA0DD),
      'อา': Color(0xFFFF6B6B),
    };

    const dayAbbr = {
      'จันทร์': 'จ',
      'อังคาร': 'อ',
      'พุธ': 'พ',
      'พฤหัสบดี': 'พฤ',
      'พฤหัส': 'พฤ',
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
          HugeIcon(icon: HugeIcons.strokeRoundedArrowTurnBackward, size: AppIconSize.sm, color: AppColors.textPrimary),
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
          HugeIcon(icon: HugeIcons.strokeRoundedArrowTurnForward, size: AppIconSize.sm, color: AppColors.textPrimary),
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

  /// Emoji สำหรับแต่ละคะแนน (1-10)
  static const _scoreEmojis = {
    1: '😎',
    2: '🤗',
    3: '🙂',
    4: '😀',
    5: '😃',
    6: '🤔',
    7: '😥',
    8: '😫',
    9: '😱',
    10: '🤯',
  };

  /// Badge แสดงคะแนนความยากที่ user ให้ไว้
  /// แสดงเฉพาะเมื่อ task.difficultyRatedBy == currentUserId
  Widget? _buildDifficultyBadge() {
    // ต้องมีคะแนน และ user ปัจจุบันเป็นคนให้คะแนน
    if (task.difficultyScore == null) return null;
    if (currentUserId == null || task.difficultyRatedBy != currentUserId) {
      return null;
    }

    final score = task.difficultyScore!;
    final emoji = _scoreEmojis[score] ?? '🤔';

    // หาสีจาก kDifficultyThresholds
    Color color = AppColors.secondaryText;
    for (final threshold in kDifficultyThresholds) {
      if (score >= threshold.from && score <= threshold.to) {
        color = threshold.color;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 2),
          Text(
            '$score',
            style: AppTypography.caption.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
