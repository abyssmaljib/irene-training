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

  const ShiftActivityCard({
    super.key,
    required this.residentIds,
    required this.clockInTime,
    required this.selectedBreakTimes,
    this.recentItemsLimit = 3,
    this.onViewAllTap,
    this.onCardTap,
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
    // Reload data when residentIds or selectedBreakTimes change
    // This fixes the race condition where break times load after initial build
    if (oldWidget.residentIds != widget.residentIds ||
        oldWidget.selectedBreakTimes.length != widget.selectedBreakTimes.length) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final stats = await _homeService.getShiftActivityStats(
      residentIds: widget.residentIds,
      clockInTime: widget.clockInTime,
      selectedBreakTimes: widget.selectedBreakTimes,
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

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
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

              // Title
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedPauseCircle,
                    color: AppColors.secondaryText,
                    size: AppIconSize.lg,
                  ),
                  AppSpacing.horizontalGapSm,
                  Text(
                    'ทำไรอยู่อ่ะ?',
                    style: AppTypography.title,
                  ),
                ],
              ),

              AppSpacing.verticalGapMd,

              // User's actual calculation
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.mediumRadius,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'การคำนวณของคุณ',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    AppSpacing.verticalGapSm,
                    _buildCalcRow('เวลาทำงานรวม', '${stats.totalWorkMinutes} นาที'),
                    if (stats.totalBreakMinutes > 0)
                      _buildCalcRow('เวลาพักที่เลือก', '${stats.totalBreakMinutes} นาที'),
                    _buildCalcRow('ทำไรอยู่อ่ะ?', '${stats.deadAirMinutes} นาที', highlight: true),
                  ],
                ),
              ),

              // Gap breakdown with peeping cat
              if (stats.deadAirGaps.isNotEmpty) ...[
                AppSpacing.verticalGapMd,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'รายละเอียดช่วงว่าง:',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          AppSpacing.verticalGapSm,
                          ...stats.deadAirGaps.map((gap) => _buildGapItem(gap)),
                        ],
                      ),
                    ),
                    // Peeping cat image
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Image.asset(
                        'assets/images/peep2.webp',
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ],

              AppSpacing.verticalGapMd,
              Divider(color: AppColors.alternate),
              AppSpacing.verticalGapMd,

              // Explanation
              Text(
                'หลักการคำนวณ:',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppSpacing.verticalGapSm,
              _buildExplanationItem(
                '1.',
                'นับช่วงเวลาที่ห่างระหว่างงานแต่ละตัว',
              ),
              _buildExplanationItem(
                '2.',
                'ถ้าช่วงห่าง > 1 ชั่วโมง จะเริ่มนับเป็น "ทำไรอยู่อ่ะ?"',
              ),
              _buildExplanationItem(
                '3.',
                'ไม่นับช่วงเวลาพักที่เลือกไว้ตอนขึ้นเวร',
              ),

              AppSpacing.verticalGapMd,

              // Formula
              Container(
                padding: AppSpacing.paddingSm,
                decoration: BoxDecoration(
                  color: AppColors.alternate.withValues(alpha: 0.3),
                  borderRadius: AppRadius.smallRadius,
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCalculator01,
                      size: AppIconSize.sm,
                      color: AppColors.secondaryText,
                    ),
                    AppSpacing.horizontalGapSm,
                    Expanded(
                      child: Text(
                        'ทำไรอยู่อ่ะ? = (ช่วงห่าง - 1 ชม.) - เวลาพัก',
                        style: AppTypography.bodySmall.copyWith(
                          fontFamily: 'monospace',
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
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
                        'อาจเกิดจากสาเหตุเหล่านี้:',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      AppSpacing.verticalGapXs,
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
                        'พยายามกดงานตามจริง เพื่อให้หัวหน้าเข้าใจการทำงานของเราได้ถูกต้องนะ',
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
      ),
    );
  }

  Widget _buildCalcRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: highlight ? AppColors.primary : AppColors.secondaryText,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: highlight ? AppColors.primary : AppColors.primaryText,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGapItem(DeadAirGap gap) {
    final localStart = gap.gapStart.toLocal();
    final localEnd = gap.gapEnd.toLocal();
    final startTime = '${localStart.hour.toString().padLeft(2, '0')}:${localStart.minute.toString().padLeft(2, '0')}';
    final endTime = '${localEnd.hour.toString().padLeft(2, '0')}:${localEnd.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: AppSpacing.paddingSm,
      decoration: BoxDecoration(
        color: AppColors.alternate.withValues(alpha: 0.2),
        borderRadius: AppRadius.smallRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: AppIconSize.sm, color: AppColors.secondaryText),
              const SizedBox(width: 4),
              Text(
                '$startTime → $endTime',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ช่วงห่าง ${gap.gapMinutes} นาที'
            '${gap.breakMinutes > 0 ? ' - พัก ${gap.breakMinutes} นาที' : ''}'
            ' - 60 นาที = ${gap.deadAirMinutes} นาที',
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              number,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall,
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
