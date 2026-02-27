import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../models/batch_task_group.dart';
import '../models/task_log.dart';
import '../providers/task_provider.dart';
import 'batch_task_card.dart';
import 'task_card.dart';

/// Section สำหรับแสดง tasks ที่ grouped ตาม timeBlock (Expandable)
/// ใช้ isExpanded + onExpandChanged สำหรับ controlled accordion behavior
class TaskTimeSection extends StatefulWidget {
  final String timeBlock;
  final List<TaskLog> tasks;
  final ValueChanged<TaskLog>? onTaskTap;
  final void Function(TaskLog task, bool? checked)? onTaskCheckChanged;
  final bool isExpanded; // controlled from parent
  final VoidCallback? onExpandChanged; // callback when tapped
  final String? currentUserId; // user ID สำหรับตรวจสอบ unseen badge

  /// Batch mode: mixed list ของ BatchTaskCard + TaskCard
  /// ถ้า != null จะ render จาก batchItems แทน tasks
  final List<BatchMixedItem>? batchItems;

  /// Callback เมื่อกด BatchTaskCard (เปิดหน้า BatchTaskScreen)
  final ValueChanged<BatchTaskGroup>? onBatchGroupTap;

  const TaskTimeSection({
    super.key,
    required this.timeBlock,
    required this.tasks,
    this.onTaskTap,
    this.onTaskCheckChanged,
    this.isExpanded = false,
    this.onExpandChanged,
    this.currentUserId,
    this.batchItems,
    this.onBatchGroupTap,
  });

  @override
  State<TaskTimeSection> createState() => _TaskTimeSectionState();
}

class _TaskTimeSectionState extends State<TaskTimeSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  // Cache computed values เพื่อไม่ต้องคำนวณทุกครั้งที่ rebuild
  late Color _headerColor;
  late dynamic _timeIcon;

  // State สำหรับ "ดูเพิ่มเติม" — ใช้ ValueNotifier แทน setState
  // เพื่อ rebuild เฉพาะ content ไม่ต้อง rebuild header + animation ทั้งหมด
  final ValueNotifier<bool> _showAllTasks = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _heightFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Cache header color และ icon
    _headerColor = _getHeaderColor();
    _timeIcon = _getTimeIcon();

    // Set initial animation value based on isExpanded
    if (widget.isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(TaskTimeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate when isExpanded changes from parent
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
        // Reset "ดูเพิ่มเติม" เมื่อปิด section
        _showAllTasks.value = false;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _showAllTasks.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Notify parent to handle accordion behavior
    widget.onExpandChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    // นับงานที่ยังไม่ได้ทำ (status == null)
    // งานติดปัญหา (isProblem) ถือว่าพยายามทำแล้ว ไม่นับเป็น pending
    final pendingCount = widget.tasks.where((t) => t.isPending).length;
    final totalCount = widget.tasks.length;
    final hasTasks = widget.tasks.isNotEmpty;
    final isCurrentTimeBlock = _isCurrentTimeBlock();

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smallRadius,
        boxShadow: [AppShadows.subtle],
        border: isCurrentTimeBlock
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Column(
        children: [
          // Header - always visible, tappable
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasTasks ? _handleTap : null,
              borderRadius: AppRadius.smallRadius,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: _headerColor.withValues(alpha: 0.3),
                  borderRadius: widget.isExpanded
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        )
                      : AppRadius.smallRadius,
                ),
                child: Row(
                  children: [
                    HugeIcon(icon: _timeIcon, size: AppIconSize.md, color: AppColors.textPrimary),
                    AppSpacing.horizontalGapSm,
                    Expanded(
                      child: Text(
                        widget.timeBlock,
                        style: AppTypography.title.copyWith(
                          fontSize: 14,
                          color: hasTasks
                              ? AppColors.textPrimary
                              : AppColors.secondaryText,
                        ),
                      ),
                    ),
                    // Progress badge (pending/total)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getProgressBgColor(pendingCount, totalCount),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _getProgressColor(pendingCount, totalCount),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '$pendingCount/$totalCount',
                        style: AppTypography.caption.copyWith(
                          color: _getProgressColor(pendingCount, totalCount),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    // Expand arrow
                    if (hasTasks) ...[
                      SizedBox(width: 8),
                      RotationTransition(
                        turns: _iconTurns,
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          size: 20,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Expandable content - ใช้ lazy loading
          // ไม่ build content จนกว่า animation จะเริ่ม (value > 0)
          if (hasTasks)
            AnimatedBuilder(
              animation: _heightFactor,
              builder: (context, child) {
                // ถ้า animation = 0 และไม่ได้ expanding ไม่ต้อง build content เลย
                if (_heightFactor.value == 0 && !widget.isExpanded) {
                  return const SizedBox.shrink();
                }
                return ClipRect(
                  child: Align(
                    heightFactor: _heightFactor.value,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                );
              },
              // ใช้ child parameter เพื่อไม่ต้อง rebuild ทุกครั้งที่ animation เปลี่ยน
              child: widget.isExpanded || _controller.isAnimating
                  ? _buildContent()
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // ถ้ามี batchItems (batch mode เปิด) → render mixed list
    if (widget.batchItems != null) {
      return _buildBatchContent();
    }

    final taskCount = widget.tasks.length;
    const int maxInitialItems = 20;
    final hasMoreTasks = taskCount > maxInitialItems;
    final remainingCount = taskCount - maxInitialItems;

    // ใช้ ValueListenableBuilder เพื่อ rebuild เฉพาะ content เมื่อกด "ดูเพิ่มเติม"
    // ไม่ต้อง rebuild header + animation ทั้ง section
    return ValueListenableBuilder<bool>(
      valueListenable: _showAllTasks,
      builder: (context, showAll, _) {
        final displayCount = showAll ? taskCount : (hasMoreTasks ? maxInitialItems : taskCount);

        return Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < displayCount; i++)
                RepaintBoundary(
                  key: ValueKey(widget.tasks[i].logId),
                  child: TaskCard(
                    task: widget.tasks[i],
                    currentUserId: widget.currentUserId,
                    flat: true,
                    onTap: widget.onTaskTap != null
                        ? () => widget.onTaskTap!(widget.tasks[i])
                        : null,
                    onCheckChanged: widget.onTaskCheckChanged != null
                        ? (checked) => widget.onTaskCheckChanged!(widget.tasks[i], checked)
                        : null,
                  ),
                ),
              if (hasMoreTasks)
                Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: AppTextButton(
                    text: showAll ? 'ย่อรายการ' : 'ดูเพิ่มอีก $remainingCount งาน',
                    icon: showAll ? HugeIcons.strokeRoundedArrowUp02 : HugeIcons.strokeRoundedArrowDown01,
                    onPressed: () {
                      _showAllTasks.value = !_showAllTasks.value;
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Render mixed list สำหรับ batch mode
  /// แสดง BatchTaskCard สำหรับ groups (2+ คนไข้)
  /// และ TaskCard ปกติสำหรับ tasks ที่ไม่เข้า group
  Widget _buildBatchContent() {
    final items = widget.batchItems!;
    final itemCount = items.length;
    const int maxInitialItems = 20;
    final hasMore = itemCount > maxInitialItems;
    final remainingCount = itemCount - maxInitialItems;

    // ใช้ ValueListenableBuilder เช่นเดียวกับ _buildContent
    return ValueListenableBuilder<bool>(
      valueListenable: _showAllTasks,
      builder: (context, showAll, _) {
        final displayCount = showAll ? itemCount : (hasMore ? maxInitialItems : itemCount);

        return Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < displayCount; i++)
                // BatchTaskCard มีหน้าตาเป็น card (มีขอบ/เงา) ต่างจาก TaskCard ที่ซ้อนกันได้
                // จึงต้องเพิ่มช่องว่างด้านล่างเพื่อแยก card ออกจากกัน
                Padding(
                  padding: EdgeInsets.only(
                    bottom: items[i].isBatch ? AppSpacing.sm : 0,
                  ),
                  child: RepaintBoundary(
                    key: ValueKey(items[i].isBatch
                        ? 'batch_${items[i].batchGroup!.groupKey}'
                        : 'task_${items[i].singleTask!.logId}'),
                    child: items[i].isBatch
                        ? BatchTaskCard(
                            group: items[i].batchGroup!,
                            flat: true,
                            onTap: widget.onBatchGroupTap != null
                                ? () => widget.onBatchGroupTap!(items[i].batchGroup!)
                                : null,
                          )
                        : TaskCard(
                            task: items[i].singleTask!,
                            currentUserId: widget.currentUserId,
                            flat: true,
                            onTap: widget.onTaskTap != null
                                ? () => widget.onTaskTap!(items[i].singleTask!)
                                : null,
                            onCheckChanged: widget.onTaskCheckChanged != null
                                ? (checked) => widget.onTaskCheckChanged!(
                                    items[i].singleTask!, checked)
                                : null,
                          ),
                  ),
                ),
              if (hasMore)
                Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: AppTextButton(
                    text: showAll ? 'ย่อรายการ' : 'ดูเพิ่มอีก $remainingCount รายการ',
                    icon: showAll
                        ? HugeIcons.strokeRoundedArrowUp02
                        : HugeIcons.strokeRoundedArrowDown01,
                    onPressed: () {
                      _showAllTasks.value = !_showAllTasks.value;
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _getHeaderColor() {
    // Map timeBlock to color
    // ใช้ startsWith เพื่อตรวจสอบเวลาเริ่มต้นของ timeBlock อย่างแม่นยำ
    final timeBlock = widget.timeBlock.trim();

    // เวรดึก (23:00 - 05:00)
    if (timeBlock.startsWith('23:00') ||
        timeBlock.startsWith('01:00') ||
        timeBlock.startsWith('03:00')) {
      return AppColors.pastelPurple; // ม่วงพาสเทลสำหรับเวรดึก
    }
    // เวรเช้า (05:00 - 11:00)
    if (timeBlock.startsWith('05:00') ||
        timeBlock.startsWith('07:00') ||
        timeBlock.startsWith('09:00')) {
      return AppColors.pastelYellow1;
    }
    // เวรกลางวัน (11:00 - 15:00)
    if (timeBlock.startsWith('11:00') || timeBlock.startsWith('13:00')) {
      return AppColors.pastelOrange1;
    }
    // เวรบ่าย (15:00 - 19:00)
    if (timeBlock.startsWith('15:00') || timeBlock.startsWith('17:00')) {
      return AppColors.pastelLightGreen1;
    }
    // เวรเย็น (19:00 - 23:00)
    if (timeBlock.startsWith('19:00') || timeBlock.startsWith('21:00')) {
      return AppColors.pastelDarkGreen1;
    }
    return AppColors.accent1;
  }

  dynamic _getTimeIcon() {
    // เช้า (05:00-11:00)
    if (widget.timeBlock.contains('05:00') ||
        widget.timeBlock.contains('07:00') ||
        widget.timeBlock.contains('09:00')) {
      return HugeIcons.strokeRoundedSunrise;
    }
    // กลางวัน (11:00-17:00)
    else if (widget.timeBlock.contains('11:00') ||
        widget.timeBlock.contains('13:00') ||
        widget.timeBlock.contains('15:00')) {
      return HugeIcons.strokeRoundedSun03;
    }
    // เย็น (17:00-23:00)
    else if (widget.timeBlock.contains('17:00') ||
        widget.timeBlock.contains('19:00') ||
        widget.timeBlock.contains('21:00')) {
      return HugeIcons.strokeRoundedSunset;
    }
    // ดึก (23:00-05:00)
    else if (widget.timeBlock.contains('23:00') ||
        widget.timeBlock.contains('01:00') ||
        widget.timeBlock.contains('03:00')) {
      return HugeIcons.strokeRoundedMoon02;
    }
    return HugeIcons.strokeRoundedCloud;
  }

  /// คำนวณสี badge ตาม pending count
  /// - เขียว: ทำครบ (pending = 0)
  /// - เหลืองทอง: ยังทำไม่ครบ (pending > 0)
  /// - ฟ้าอ่อน: ไม่มีงาน
  Color _getProgressColor(int pending, int total) {
    if (total == 0) return AppColors.secondary.withValues(alpha: 0.6);
    if (pending == 0) return AppColors.tagPassedText; // เขียว - ทำครบแล้ว
    return AppColors.progressPendingText; // เหลืองทองเข้ม - ยังมีงานค้าง
  }

  /// คำนวณสี background ของ badge ตาม pending count
  Color _getProgressBgColor(int pending, int total) {
    if (total == 0) return AppColors.secondary.withValues(alpha: 0.2);
    if (pending == 0) return AppColors.tagPassedBg; // เขียวอ่อน - ทำครบแล้ว
    return AppColors.progressPendingBg; // เหลืองครีม - ยังมีงานค้าง
  }

  /// ตรวจสอบว่า timeBlock นี้ครอบคลุมเวลาปัจจุบันหรือไม่
  /// timeBlock format: "07:00 - 09:00", "09:00 - 11:00", etc.
  bool _isCurrentTimeBlock() {
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentMinute = now.minute;

    // Parse timeBlock เช่น "07:00 - 09:00"
    final parts = widget.timeBlock.split(' - ');
    if (parts.length != 2) return false;

    try {
      final startParts = parts[0].split(':');
      final endParts = parts[1].split(':');

      final startHour = int.parse(startParts[0]);
      final endHour = int.parse(endParts[0]);

      // แปลงเวลาปัจจุบันเป็นนาทีทั้งหมด
      final currentTotalMinutes = currentHour * 60 + currentMinute;
      final startTotalMinutes = startHour * 60;
      final endTotalMinutes = endHour * 60;

      // กรณีข้ามวัน (เช่น 23:00 - 01:00)
      if (endHour < startHour) {
        // ถ้าเวลาปัจจุบันหลังเที่ยงคืน (0-endHour) หรือ ก่อนเที่ยงคืน (startHour-24)
        return currentTotalMinutes >= startTotalMinutes ||
            currentTotalMinutes < endTotalMinutes;
      }

      // กรณีปกติ
      return currentTotalMinutes >= startTotalMinutes &&
          currentTotalMinutes < endTotalMinutes;
    } catch (e) {
      return false;
    }
  }
}

/// Section สำหรับ view mode ที่ไม่ได้ grouped (upcoming, problem, myDone)
class TaskListSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final dynamic icon;
  final List<TaskLog> tasks;
  final ValueChanged<TaskLog>? onTaskTap;
  final void Function(TaskLog task, bool? checked)? onTaskCheckChanged;
  final Widget? emptyState;

  const TaskListSection({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.tasks,
    this.onTaskTap,
    this.onTaskCheckChanged,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        if (title.isNotEmpty) ...[
          Row(
            children: [
              if (icon != null) ...[
                HugeIcon(icon: icon, size: AppIconSize.lg, color: AppColors.primary),
                AppSpacing.horizontalGapSm,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.heading3,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                  ],
                ),
              ),
              // Task count
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tasks.length}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
        ],
        // Tasks list
        if (tasks.isEmpty)
          emptyState ??
              Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedTask01,
                        size: AppIconSize.xxxl,
                        color: AppColors.secondaryText.withValues(alpha: 0.5),
                      ),
                      AppSpacing.verticalGapMd,
                      Text(
                        'ไม่มีงาน',
                        style: AppTypography.body.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              )
        else
          ...tasks.map((task) => Padding(
                // Key ช่วยให้ Flutter reuse TaskCard ตาม logId
                key: ValueKey(task.logId),
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: TaskCard(
                  task: task,
                  onTap: onTaskTap != null ? () => onTaskTap!(task) : null,
                  onCheckChanged: onTaskCheckChanged != null
                      ? (checked) => onTaskCheckChanged!(task, checked)
                      : null,
                ),
              )),
      ],
    );
  }
}
