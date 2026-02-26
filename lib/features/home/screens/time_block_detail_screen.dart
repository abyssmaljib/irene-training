import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../models/time_block_progress.dart';
import '../models/time_block_task.dart';
import '../services/home_service.dart';
import '../widgets/stacked_progress_bar.dart';

/// หน้าแสดงรายละเอียด progress แยกตาม time block
class TimeBlockDetailScreen extends StatefulWidget {
  final List<int> residentIds;

  const TimeBlockDetailScreen({
    super.key,
    required this.residentIds,
  });

  @override
  State<TimeBlockDetailScreen> createState() => _TimeBlockDetailScreenState();
}

class _TimeBlockDetailScreenState extends State<TimeBlockDetailScreen> {
  final _homeService = HomeService.instance;

  List<TimeBlockProgress> _timeBlocks = [];
  bool _isLoading = true;

  // Track expanded time blocks and their tasks
  final Set<String> _expandedBlocks = {};
  final Map<String, List<TimeBlockTask>> _blockTasks = {};
  final Set<String> _loadingBlocks = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final timeBlocks = await _homeService.getTimeBlockProgress(
      residentIds: widget.residentIds,
    );

    if (mounted) {
      setState(() {
        _timeBlocks = timeBlocks;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleExpand(String timeBlock) async {
    if (_expandedBlocks.contains(timeBlock)) {
      // Collapse
      setState(() {
        _expandedBlocks.remove(timeBlock);
      });
    } else {
      // Expand and load tasks if not loaded
      setState(() {
        _expandedBlocks.add(timeBlock);
      });

      if (!_blockTasks.containsKey(timeBlock)) {
        setState(() {
          _loadingBlocks.add(timeBlock);
        });

        final tasks = await _homeService.getTasksByTimeBlock(
          residentIds: widget.residentIds,
          timeBlock: timeBlock,
        );

        if (mounted) {
          setState(() {
            _blockTasks[timeBlock] = tasks;
            _loadingBlocks.remove(timeBlock);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: IreneSecondaryAppBar(
        title: 'สรุปงานตามช่วงเวลา',
        backgroundColor: AppColors.surface,
        centerTitle: true,
      ),
      // Wrap ทั้ง body ด้วย RefreshIndicator เพื่อให้ pull to refresh ได้ทุกสถานะ
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? _buildLoadingScrollable()
            : _timeBlocks.isEmpty
                ? _buildEmptyScrollable()
                : _buildContent(),
      ),
    );
  }

  /// Loading state ที่ scrollable ได้ เพื่อให้ RefreshIndicator ทำงาน
  Widget _buildLoadingScrollable() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ShimmerWrapper(
          isLoading: true,
          child: Column(
            children: List.generate(3, (_) => const SkeletonListItem()),
          ),
        ),
      ],
    );
  }

  /// Empty state ที่ scrollable ได้ เพื่อให้ RefreshIndicator ทำงาน
  Widget _buildEmptyScrollable() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        const EmptyStateWidget(message: 'ไม่มีงานในวันนี้'),
      ],
    );
  }

  Widget _buildContent() {
    // Calculate overall stats
    int totalTasks = 0;
    int completedTasks = 0;
    for (final block in _timeBlocks) {
      totalTasks += block.totalTasks;
      completedTasks += block.completedTasks;
    }

    return ListView(
      // เพิ่ม AlwaysScrollableScrollPhysics เพื่อให้ pull to refresh ทำงานได้
      // แม้ content จะไม่เต็มหน้าจอ
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.paddingMd,
      children: [
        // Overall Summary Card
        _buildSummaryCard(totalTasks, completedTasks),

        AppSpacing.verticalGapMd,

        // Time Blocks List
        ..._timeBlocks.map((block) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTimeBlockItem(block),
            )),
      ],
    );
  }

  Widget _buildSummaryCard(int total, int completed) {
    final progress = total > 0 ? completed / total : 0.0;
    final percent = (progress * 100).toStringAsFixed(0);

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: const [AppShadows.subtle],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smallRadius,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedChart,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              AppSpacing.horizontalGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ความคืบหน้ารวม',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Text(
                      '$completed/$total งาน ($percent%)',
                      style: AppTypography.title,
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.alternate,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBlockItem(TimeBlockProgress block) {
    final isComplete = block.isComplete;
    final hasStarted = block.hasStarted;
    final isExpanded = _expandedBlocks.contains(block.timeBlock);
    final isLoadingTasks = _loadingBlocks.contains(block.timeBlock);
    final tasks = _blockTasks[block.timeBlock] ?? [];

    Color bgColor;
    dynamic statusIcon;
    final timeIcon = _getTimeIcon(block.timeBlock);

    if (isComplete) {
      bgColor = AppColors.tagPassedBg;
      statusIcon = HugeIcons.strokeRoundedCheckmarkCircle02;
    } else if (hasStarted) {
      bgColor = AppColors.tagPendingBg;
      statusIcon = HugeIcons.strokeRoundedClock01;
    } else {
      bgColor = AppColors.alternate.withValues(alpha: 0.3);
      statusIcon = HugeIcons.strokeRoundedPauseCircle;
    }

    return GestureDetector(
      onTap: () => _toggleExpand(block.timeBlock),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          border: isComplete
              ? Border.all(
                  color: AppColors.progressOnTime.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          children: [
            // Header Row
            Row(
              children: [
                // Icon + Time Block
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: AppRadius.smallRadius,
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: timeIcon,
                      size: 22,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),

                AppSpacing.horizontalGapMd,

                // Time Block Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            block.timeBlock,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          AppSpacing.horizontalGapSm,
                          Text(
                            block.label,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.verticalGapXs,
                      // Stacked Progress Bar (ตามความตรงเวลา)
                      Row(
                        children: [
                          Expanded(
                            child: StackedProgressBar(
                              onTimePercent: block.onTimePercent,
                              slightlyLatePercent: block.slightlyLatePercent,
                              veryLatePercent: block.veryLatePercent,
                              deadAirPercent: 0,
                              height: 6,
                              borderRadius: 3,
                            ),
                          ),
                          AppSpacing.horizontalGapSm,
                          Text(
                            block.progressText,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                AppSpacing.horizontalGapSm,

                // Status Icon + Expand Arrow
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: statusIcon,
                      color: isComplete
                          ? AppColors.progressOnTime
                          : hasStarted
                              ? AppColors.progressSlightlyLate
                              : AppColors.secondaryText.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    AppSpacing.horizontalGapXs,
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowDown01,
                        color: AppColors.secondaryText,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Expanded Task List
            if (isExpanded) ...[
              AppSpacing.verticalGapMd,
              Divider(color: AppColors.alternate, height: 1),
              AppSpacing.verticalGapSm,

              if (isLoadingTasks)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'ไม่มีงานในช่วงเวลานี้',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                )
              else
                ...tasks.map((task) => _buildTaskItem(task)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(TimeBlockTask task) {
    final isCompleted = task.isCompleted;
    final timelinessStatus = task.timelinessStatus;

    Color dotColor;
    if (!isCompleted) {
      dotColor = AppColors.alternate;
    } else {
      switch (timelinessStatus) {
        case 'onTime':
          dotColor = AppColors.progressOnTime;
          break;
        case 'slightlyLate':
          dotColor = AppColors.progressSlightlyLate;
          break;
        case 'veryLate':
          dotColor = AppColors.progressVeryLate;
          break;
        default:
          dotColor = AppColors.alternate;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status dot
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),

          AppSpacing.horizontalGapSm,

          // Time (if completed)
          if (task.formattedCompletedTime != null)
            SizedBox(
              width: 40,
              child: Text(
                task.formattedCompletedTime!,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            )
          else
            SizedBox(
              width: 40,
              child: Text(
                '--:--',
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText.withValues(alpha: 0.5),
                ),
              ),
            ),

          AppSpacing.horizontalGapXs,

          // Task title
          Expanded(
            child: Text(
              task.displayText,
              style: AppTypography.bodySmall.copyWith(
                color: isCompleted
                    ? AppColors.primaryText
                    : AppColors.secondaryText,
                decoration:
                    isCompleted ? null : TextDecoration.none,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Status badge
          if (!isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.alternate.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'รอทำ',
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// คืน icon ตามช่วงเวลา (เหมือนหน้า checklist)
  dynamic _getTimeIcon(String timeBlock) {
    // เช้า (05:00-11:00)
    if (timeBlock.contains('05:00') ||
        timeBlock.contains('07:00') ||
        timeBlock.contains('09:00')) {
      return HugeIcons.strokeRoundedSunrise;
    }
    // กลางวัน (11:00-17:00)
    else if (timeBlock.contains('11:00') ||
        timeBlock.contains('13:00') ||
        timeBlock.contains('15:00')) {
      return HugeIcons.strokeRoundedSun03;
    }
    // เย็น (17:00-23:00)
    else if (timeBlock.contains('17:00') ||
        timeBlock.contains('19:00') ||
        timeBlock.contains('21:00')) {
      return HugeIcons.strokeRoundedSunset;
    }
    // ดึก (23:00-05:00)
    else if (timeBlock.contains('23:00') ||
        timeBlock.contains('01:00') ||
        timeBlock.contains('03:00')) {
      return HugeIcons.strokeRoundedMoon02;
    }
    return HugeIcons.strokeRoundedCloud;
  }
}
