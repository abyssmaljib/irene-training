import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/shift_activity_item.dart';
import '../models/shift_activity_stats.dart';
import '../models/break_time_option.dart';
import '../services/home_service.dart';
import 'stacked_progress_bar.dart';

/// Card รวม "งานในเวรนี้" - แสดงทั้ง task progress + stacked bar + recent activities
class ShiftActivityCard extends StatefulWidget {
  final List<int> residentIds;
  final DateTime clockInTime;
  final List<BreakTimeOption> selectedBreakTimes;
  final int recentItemsLimit;
  final VoidCallback? onViewAllTap;
  final VoidCallback? onCardTap; // กดที่ card เพื่อดูรายละเอียด time block
  /// Dead Air minutes จาก backend (ClockInOut.deadAirMinutes)
  /// ถ้ามีค่าจะใช้ค่าจาก backend แทนการคำนวณใน frontend
  final int? deadAirMinutes;

  const ShiftActivityCard({
    super.key,
    required this.residentIds,
    required this.clockInTime,
    required this.selectedBreakTimes,
    this.recentItemsLimit = 3,
    this.onViewAllTap,
    this.onCardTap,
    this.deadAirMinutes,
  });

  @override
  State<ShiftActivityCard> createState() => _ShiftActivityCardState();
}

class _ShiftActivityCardState extends State<ShiftActivityCard> {
  final _homeService = HomeService.instance;

  ShiftActivityStats? _stats;
  List<ShiftActivityItem> _recentActivities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(ShiftActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when residentIds, selectedBreakTimes, or deadAirMinutes change
    // This fixes the race condition where break times load after initial build
    if (oldWidget.residentIds != widget.residentIds ||
        oldWidget.selectedBreakTimes.length != widget.selectedBreakTimes.length ||
        oldWidget.deadAirMinutes != widget.deadAirMinutes) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // ถ้ามี deadAirMinutes จาก backend ให้ใช้ค่านั้น
    final stats = await _homeService.getShiftActivityStats(
      residentIds: widget.residentIds,
      clockInTime: widget.clockInTime,
      selectedBreakTimes: widget.selectedBreakTimes,
      deadAirMinutes: widget.deadAirMinutes, // ค่าจาก backend
    );

    final recentActivities = await _homeService.getRecentShiftActivities(
      residentIds: widget.residentIds,
      limit: widget.recentItemsLimit,
    );

    if (mounted) {
      setState(() {
        _stats = stats;
        _recentActivities = recentActivities;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onCardTap,
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          boxShadow: const [AppShadows.subtle],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - "งานในเวรนี้"
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedTask01,
                    color: AppColors.primary, size: AppIconSize.lg),
                AppSpacing.horizontalGapSm,
                Expanded(
                  child: Text(
                    'งานในเวรนี้',
                    style: AppTypography.title,
                  ),
                ),
                if (!_isLoading && _stats != null)
                  Text(
                    '${_stats!.teamTotalCompleted}/${_stats!.totalTasks}',
                    style: AppTypography.body.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                AppSpacing.horizontalGapSm,
                // Arrow icon to indicate tappable
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: AppColors.secondaryText.withValues(alpha: 0.5),
                  size: AppIconSize.sm,
                ),
              ],
            ),

            AppSpacing.verticalGapMd,

            // Task Progress Bar (เขียว)
            _buildTaskProgressBar(),

            AppSpacing.verticalGapMd,

            // Content - Stacked Bar + Stats + Activities
            if (_isLoading)
              _buildLoadingSkeleton()
            else
              _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskProgressBar() {
    final progress = _stats != null && _stats!.totalTasks > 0
        ? _stats!.teamTotalCompleted / _stats!.totalTasks
        : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: _isLoading ? null : progress,
        backgroundColor: AppColors.alternate,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        minHeight: 8,
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: [
        // Stacked bar skeleton
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.alternate.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        AppSpacing.verticalGapMd,
        // Stats skeleton
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            3,
            (index) => Container(
              width: 60,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.alternate.withValues(alpha: 0.3),
                borderRadius: AppRadius.smallRadius,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    // ถ้ายังไม่มี activity แสดง empty state แทน stacked bar
    if (_stats == null || !_stats!.hasActivities) {
      return _buildEmptyActivitiesState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title - ความตรงเวลา
        Text(
          'ความตรงเวลา',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        AppSpacing.verticalGapSm,

        // Stacked Progress Bar
        StackedProgressBar(
          onTimePercent: _stats!.onTimePercent,
          slightlyLatePercent: _stats!.slightlyLatePercent,
          veryLatePercent: _stats!.veryLatePercent,
          deadAirPercent: _stats!.deadAirPercent,
          height: 12,
        ),

        AppSpacing.verticalGapSm,

        // Stats Row
        _buildStatsRow(),

        // Dead Air Row (ถ้ามี)
        if (_stats!.deadAirMinutes > 0) ...[
          AppSpacing.verticalGapXs,
          _buildDeadAirRow(),
        ],

        // "ดูรายละเอียด" link
        AppSpacing.verticalGapSm,
        _buildViewDetailButton(),

        // Recent Activities Section
        if (_recentActivities.isNotEmpty) ...[
          AppSpacing.verticalGapMd,
          Divider(color: AppColors.alternate, height: 1),
          AppSpacing.verticalGapMd,

          // Recent Activities Header
          Text(
            'ล่าสุด:',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
          AppSpacing.verticalGapSm,

          // Recent Activity List
          ..._recentActivities.map((activity) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildActivityItem(activity),
              )),

          // View All Button
          if (_stats!.totalCompleted > widget.recentItemsLimit) ...[
            AppSpacing.verticalGapSm,
            _buildViewAllButton(),
          ],
        ],

        // View All Button (ถ้าไม่มี recent activities แต่มี completed)
        if (_recentActivities.isEmpty && _stats!.totalCompleted > 0) ...[
          AppSpacing.verticalGapMd,
          _buildViewAllButton(),
        ],
      ],
    );
  }

  Widget _buildEmptyActivitiesState() {
    return Column(
      children: [
        // ความตรงเวลา section
        Text(
          'ความตรงเวลา',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        AppSpacing.verticalGapMd,
        HugeIcon(
          icon: HugeIcons.strokeRoundedChart,
          size: AppIconSize.xxl,
          color: AppColors.secondaryText.withValues(alpha: 0.4),
        ),
        AppSpacing.verticalGapXs,
        Text(
          'ยังไม่มีกิจกรรมในเวรนี้',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        AppSpacing.verticalGapMd,
        // "ดูเช็คลิสต์" button
        _buildViewAllButton(),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        _buildStatChip(
          color: AppColors.progressOnTime,
          count: _stats!.onTimeCount,
          label: 'ตรงเวลา',
        ),
        _buildStatChip(
          color: AppColors.progressSlightlyLate,
          count: _stats!.slightlyLateCount,
          label: 'สาย',
        ),
        _buildStatChip(
          color: AppColors.progressVeryLate,
          count: _stats!.veryLateCount,
          label: 'สายมาก',
        ),
        if (_stats!.kindnessCount > 0)
          _buildKindnessChip(count: _stats!.kindnessCount),
      ],
    );
  }

  Widget _buildKindnessChip({required int count}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            gradient: AppColors.kindnessGradient,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count น้ำใจ',
          style: AppTypography.caption.copyWith(
            color: AppColors.kindnessText,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required Color color,
    required int count,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDeadAirRow() {
    final minutes = _stats!.deadAirMinutes;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    String timeText;
    if (hours > 0) {
      timeText = '$hours ชม. $remainingMinutes นาที';
    } else {
      timeText = '$minutes นาที';
    }

    return InkWell(
      onTap: () => _showDeadAirExplanation(context),
      borderRadius: AppRadius.smallRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.alternate.withValues(alpha: 0.15),
          borderRadius: AppRadius.smallRadius,
          border: Border.all(
            color: AppColors.alternate.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.alternate,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'ทำไรอยู่อ่ะ?: $timeText',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'กดเพื่อดูรายละเอียด',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 4),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: AppIconSize.sm,
              color: AppColors.secondaryText.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeadAirExplanation(BuildContext context) {
    final stats = _stats;
    if (stats == null) return;

    // Format dead air time
    final minutes = stats.deadAirMinutes;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    String timeText;
    if (hours > 0) {
      timeText = remainingMinutes > 0 ? '$hours ชม. $remainingMinutes นาที' : '$hours ชม.';
    } else {
      timeText = '$minutes นาที';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.alternate,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title with peeping cat
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedPauseCircle,
                  color: AppColors.secondaryText,
                  size: AppIconSize.lg,
                ),
                AppSpacing.horizontalGapSm,
                Expanded(
                  child: Text(
                    'ทำไรอยู่อ่ะ?',
                    style: AppTypography.title,
                  ),
                ),
                // Peeping cat
                Image.asset(
                  'assets/images/peep2.webp',
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ],
            ),

            AppSpacing.verticalGapMd,

            // Total Dead Air - แสดงแค่ค่ารวม (คำนวณจาก backend)
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: AppRadius.mediumRadius,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedTime04,
                    color: AppColors.primary,
                    size: AppIconSize.xl,
                  ),
                  AppSpacing.horizontalGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'เวลาที่ห่างหาย',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          timeText,
                          style: AppTypography.heading2.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            AppSpacing.verticalGapMd,

            // Formula explanation - สูตรใหม่ (Backend)
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: AppColors.alternate.withValues(alpha: 0.2),
                borderRadius: AppRadius.mediumRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'วิธีคำนวณ',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.verticalGapSm,
                  Text(
                    'Dead Air = ช่วงห่างระหว่าง tasks - เวลาทำ task - 75 นาที (allowance) - เวลาพักที่ทับ',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  AppSpacing.verticalGapMd,
                  Text(
                    'เวลาทำ task โดยประมาณ:',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  AppSpacing.verticalGapXs,
                  _buildTaskTimeRow('งานง่าย (score 1-3)', '5 นาที'),
                  _buildTaskTimeRow('งานปานกลาง (score 4-6)', '10 นาที'),
                  _buildTaskTimeRow('งานยาก (score 7-10)', '15 นาที'),
                ],
              ),
            ),

            // Guide box
            if (stats.deadAirMinutes > 0) ...[
              AppSpacing.verticalGapMd,
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: AppRadius.mediumRadius,
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedInformationCircle,
                          size: AppIconSize.sm,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ไม่ได้อู้งาน?',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.verticalGapSm,
                    Text(
                      '• ไม่ได้ไปพักตามเวลาที่เลือกไว้ตอนขึ้นเวร',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Text(
                      '• ค้างงานไว้แล้วมากดติดๆ กัน ทำให้มีช่องว่าง',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    AppSpacing.verticalGapSm,
                    Text(
                      'พยายามกดงานตามจริงนะ',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            AppSpacing.verticalGapLg,
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTimeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '• $label',
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(ShiftActivityItem activity) {
    final status = activity.timelinessStatus;
    final isKindness = activity.isKindnessTask(widget.residentIds);
    final dotColor = isKindness ? null : _getStatusColor(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status dot (gradient for kindness tasks)
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: isKindness
              ? Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    gradient: AppColors.kindnessGradient,
                    shape: BoxShape.circle,
                  ),
                )
              : Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
        ),

        AppSpacing.horizontalGapSm,

        // Time
        SizedBox(
          width: 38,
          child: Text(
            activity.formattedTime,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: isKindness ? AppColors.kindnessText : AppColors.secondaryText,
            ),
          ),
        ),

        AppSpacing.horizontalGapXs,

        // Title with resident name
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  activity.displayText,
                  style: AppTypography.bodySmall.copyWith(
                    color: isKindness ? AppColors.kindnessText : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isKindness) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: AppColors.kindnessGradient,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'น้ำใจ',
                    style: AppTypography.caption.copyWith(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewAllButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: widget.onViewAllTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ดูเช็คลิสต์',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
              ),
            ),
            AppSpacing.horizontalGapXs,
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: AppIconSize.sm,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewDetailButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: widget.onCardTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ดูรายละเอียด',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primary,
              ),
            ),
            AppSpacing.horizontalGapXs,
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: AppIconSize.sm,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'onTime':
        return AppColors.progressOnTime;
      case 'slightlyLate':
        return AppColors.progressSlightlyLate;
      case 'veryLate':
        return AppColors.progressVeryLate;
      default:
        return AppColors.tagNeutralText;
    }
  }
}
