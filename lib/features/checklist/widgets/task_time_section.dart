import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../models/task_log.dart';
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

  const TaskTimeSection({
    super.key,
    required this.timeBlock,
    required this.tasks,
    this.onTaskTap,
    this.onTaskCheckChanged,
    this.isExpanded = false,
    this.onExpandChanged,
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
  late IconData _timeIcon;

  // State สำหรับ "ดูเพิ่มเติม"
  bool _showAllTasks = false;

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
        _showAllTasks = false;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Notify parent to handle accordion behavior
    widget.onExpandChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = widget.tasks.where((t) => t.isDone).length;
    final totalCount = widget.tasks.length;
    final hasTasks = widget.tasks.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smallRadius,
        boxShadow: [AppShadows.subtle],
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
                    Icon(_timeIcon, size: 18, color: AppColors.textPrimary),
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
                    // Progress badge
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getProgressColor(completedCount, totalCount),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$completedCount/$totalCount',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Expand arrow
                    if (hasTasks) ...[
                      SizedBox(width: 8),
                      RotationTransition(
                        turns: _iconTurns,
                        child: Icon(
                          Iconsax.arrow_down_1,
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
    final taskCount = widget.tasks.length;

    // สำหรับ tasks จำนวนมาก จำกัด items ที่แสดงครั้งแรก
    // กดปุ่ม "ดูเพิ่มเติม" เพื่อแสดงทั้งหมด
    const int maxInitialItems = 20;
    final hasMoreTasks = taskCount > maxInitialItems;
    final displayCount = _showAllTasks ? taskCount : (hasMoreTasks ? maxInitialItems : taskCount);
    final remainingCount = taskCount - maxInitialItems;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // แสดง tasks (จำกัดจำนวนหรือทั้งหมด)
          for (int i = 0; i < displayCount; i++)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: RepaintBoundary(
                child: TaskCard(
                  task: widget.tasks[i],
                  onTap: widget.onTaskTap != null
                      ? () => widget.onTaskTap!(widget.tasks[i])
                      : null,
                  onCheckChanged: widget.onTaskCheckChanged != null
                      ? (checked) => widget.onTaskCheckChanged!(widget.tasks[i], checked)
                      : null,
                ),
              ),
            ),
          // ปุ่ม "ดูเพิ่มเติม" หรือ "ย่อ"
          if (hasMoreTasks)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: AppTextButton(
                text: _showAllTasks ? 'ย่อรายการ' : 'ดูเพิ่มอีก $remainingCount งาน',
                icon: _showAllTasks ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                onPressed: () {
                  setState(() {
                    _showAllTasks = !_showAllTasks;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Color _getHeaderColor() {
    // Map timeBlock to color
    if (widget.timeBlock.contains('07:00') || widget.timeBlock.contains('09:00')) {
      return AppColors.pastelYellow1;
    } else if (widget.timeBlock.contains('11:00') || widget.timeBlock.contains('13:00')) {
      return AppColors.pastelOrange1;
    } else if (widget.timeBlock.contains('15:00') || widget.timeBlock.contains('17:00')) {
      return AppColors.pastelLightGreen1;
    } else if (widget.timeBlock.contains('19:00') || widget.timeBlock.contains('21:00')) {
      return AppColors.pastelDarkGreen1;
    } else if (widget.timeBlock.contains('23:00') ||
        widget.timeBlock.contains('01:00') ||
        widget.timeBlock.contains('03:00') ||
        widget.timeBlock.contains('05:00')) {
      return AppColors.pastelDarkGreen1;
    }
    return AppColors.accent1;
  }

  IconData _getTimeIcon() {
    if (widget.timeBlock.contains('07:00') ||
        widget.timeBlock.contains('09:00') ||
        widget.timeBlock.contains('11:00')) {
      return Iconsax.sun_1;
    } else if (widget.timeBlock.contains('13:00') ||
        widget.timeBlock.contains('15:00') ||
        widget.timeBlock.contains('17:00')) {
      return Iconsax.sun;
    } else if (widget.timeBlock.contains('19:00') || widget.timeBlock.contains('21:00')) {
      return Iconsax.moon;
    } else {
      return Iconsax.cloud;
    }
  }

  Color _getProgressColor(int completed, int total) {
    if (total == 0) return AppColors.secondaryText;
    if (completed == total) return AppColors.tagPassedText;
    if (completed > 0) return AppColors.tagPendingText;
    return AppColors.secondaryText;
  }
}

/// Section สำหรับ view mode ที่ไม่ได้ grouped (upcoming, problem, myDone)
class TaskListSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
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
                Icon(icon, size: 20, color: AppColors.primary),
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
                      Icon(
                        Iconsax.task_square,
                        size: 48,
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
