import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/blocking_check_dialog.dart';
import '../../../core/widgets/buttons.dart';
import '../../incident_reflection/models/incident.dart';
import '../../incident_reflection/services/incident_service.dart';
import '../../learning/services/badge_service.dart';
import '../../points/services/points_service.dart';
import '../models/shift_leader.dart';
import '../services/clock_service.dart';
import '../services/home_service.dart';
import '../services/shift_summary_service.dart';
import 'clock_out_summary_modal.dart';
import 'clock_out_survey_form.dart';

/// Step ในการลงเวร
enum ClockOutStep {
  checking,           // กำลังตรวจสอบ
  hasPendingTasks,    // มี tasks ค้าง
  hasPendingIncidents,// มี incidents ที่ยังไม่ถอดบทเรียน
  hasUnreadPosts,     // มีโพสไม่ได้อ่าน
  noHandover,         // ยังไม่ handover
  survey,             // แสดง survey form
  submitting,         // กำลัง submit
  success,            // ลงเวรสำเร็จ (แสดง confetti)
}

/// Dialog สำหรับยืนยันการลงเวร พร้อมเช็ค tasks, posts, handover, incidents และ survey
class ClockOutDialog extends StatefulWidget {
  final int clockRecordId;
  final String shift;
  final List<int> residentIds;
  final DateTime? clockInTime;
  final VoidCallback onCreateHandover;
  final VoidCallback onViewPosts;

  /// Callback เมื่อต้องไปถอดบทเรียน - รับ incident ที่ต้องการถอดบทเรียน
  /// ถ้าไม่ส่งมา จะไปหน้า list แทน
  final void Function(Incident incident) onViewIncidents;

  /// User ID สำหรับเช็ค incidents
  final String userId;

  /// Nursinghome ID สำหรับเช็ค incidents
  final int nursinghomeId;

  const ClockOutDialog({
    super.key,
    required this.clockRecordId,
    required this.shift,
    required this.residentIds,
    this.clockInTime,
    required this.onCreateHandover,
    required this.onViewPosts,
    required this.onViewIncidents,
    required this.userId,
    required this.nursinghomeId,
  });

  /// Show the clock out dialog
  static Future<bool?> show(
    BuildContext context, {
    required int clockRecordId,
    required String shift,
    required List<int> residentIds,
    DateTime? clockInTime,
    required VoidCallback onCreateHandover,
    required VoidCallback onViewPosts,
    required void Function(Incident incident) onViewIncidents,
    required String userId,
    required int nursinghomeId,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClockOutDialog(
        clockRecordId: clockRecordId,
        shift: shift,
        residentIds: residentIds,
        clockInTime: clockInTime,
        onCreateHandover: onCreateHandover,
        onViewPosts: onViewPosts,
        onViewIncidents: onViewIncidents,
        userId: userId,
        nursinghomeId: nursinghomeId,
      ),
    );
  }

  @override
  State<ClockOutDialog> createState() => _ClockOutDialogState();
}

class _ClockOutDialogState extends State<ClockOutDialog> {
  final _clockService = ClockService.instance;
  final _homeService = HomeService.instance;
  final _badgeService = BadgeService();
  final _incidentService = IncidentService.instance;
  final _pointsService = PointsService();
  final _shiftSummaryService = ShiftSummaryService.instance;
  late ConfettiController _confettiController;

  ClockOutStep _step = ClockOutStep.checking;
  int _remainingTasksCount = 0;
  List<Map<String, dynamic>> _remainingTasks = [];
  int _pendingIncidentsCount = 0;
  List<Incident> _pendingIncidents = [];
  int _unreadPostsCount = 0;
  bool _hasHandover = false;
  bool _isSubmitting = false;
  ShiftLeader? _shiftLeader; // หัวหน้าเวรของเวรปัจจุบัน (ถ้ามี)

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _runChecks();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _runChecks() async {
    setState(() => _step = ClockOutStep.checking);

    // 1. Check remaining tasks
    _remainingTasksCount = await _homeService.getRemainingTasksCount(
      shift: widget.shift,
      clockInTime: widget.clockInTime,
    );

    if (_remainingTasksCount > 0) {
      _remainingTasks = await _homeService.getRemainingTasks(
        shift: widget.shift,
        clockInTime: widget.clockInTime,
        limit: 5,
      );
      setState(() => _step = ClockOutStep.hasPendingTasks);
      return;
    }

    // 2. Check pending incidents
    final allIncidents = await _incidentService.getMyIncidents(
      widget.userId,
      widget.nursinghomeId,
      forceRefresh: true,
    );

    _pendingIncidents = allIncidents
        .where((i) => i.reflectionStatus != ReflectionStatus.completed)
        .toList();
    _pendingIncidentsCount = _pendingIncidents.length;

    if (_pendingIncidentsCount > 0) {
      setState(() => _step = ClockOutStep.hasPendingIncidents);
      return;
    }

    // 3. Check unread posts
    _unreadPostsCount = await _clockService.getUnreadAnnouncementsCount();

    if (_unreadPostsCount > 0) {
      setState(() => _step = ClockOutStep.hasUnreadPosts);
      return;
    }

    // 4. Check handover
    _hasHandover = await _clockService.hasHandoverPost();

    if (!_hasHandover) {
      setState(() => _step = ClockOutStep.noHandover);
      return;
    }

    // 5. Load shift leader info (ถ้ามี)
    _shiftLeader = await _clockService.getShiftLeader();

    // All checks passed - show survey
    setState(() => _step = ClockOutStep.survey);
  }

  Future<void> _handleSurveySubmit({
    required int shiftScore,
    required int selfScore,
    required String shiftSurvey,
    String? bugSurvey,
    int? leaderScore,
  }) async {
    setState(() => _isSubmitting = true);

    // 1. คำนวณ Dead Air และบันทึก penalty (ถ้ามี)
    int deadAirMinutes = 0;
    if (widget.clockInTime != null) {
      // ดึง break times ที่เลือก
      final currentShift = await _clockService.getCurrentShift();
      final breakTimeIds = currentShift?.selectedBreakTime ?? [];
      final breakTimes = await _clockService.getBreakTimeOptions();
      final selectedBreakTimes =
          breakTimes.where((b) => breakTimeIds.contains(b.id)).toList();

      // ดึง shift activity stats
      // ใช้ deadAirMinutes จาก backend (database trigger calculation) ถ้ามี
      final stats = await _homeService.getShiftActivityStats(
        residentIds: widget.residentIds,
        clockInTime: widget.clockInTime!,
        selectedBreakTimes: selectedBreakTimes,
        deadAirMinutes: currentShift?.deadAirMinutes,
      );

      deadAirMinutes = stats.deadAirMinutes;

      // บันทึก dead air penalty (ถ้ามี)
      if (deadAirMinutes > 0) {
        await _pointsService.recordDeadAirPenalty(
          userId: widget.userId,
          clockRecordId: widget.clockRecordId,
          deadAirMinutes: deadAirMinutes,
          nursinghomeId: widget.nursinghomeId,
        );
      }
    }

    // 2. Clock out
    final success = await _clockService.clockOutWithSurvey(
      clockRecordId: widget.clockRecordId,
      shiftScore: shiftScore,
      selfScore: selfScore,
      shiftSurvey: shiftSurvey,
      bugSurvey: bugSurvey,
      leaderScore: leaderScore,
      leaderId: _shiftLeader?.id,
    );

    if (mounted && success) {
      // 3. ตรวจสอบและ award shift badges
      if (widget.clockInTime != null) {
        await _badgeService.checkAndAwardShiftBadges(
          clockRecordId: widget.clockRecordId,
          nursinghomeId: widget.nursinghomeId,
          clockIn: widget.clockInTime!,
          clockOut: DateTime.now(),
          assignedResidentIds: widget.residentIds,
        );
      }

      // 4. Query shift summary
      final summary = await _shiftSummaryService.getShiftSummary(
        userId: widget.userId,
        nursinghomeId: widget.nursinghomeId,
        clockInTime: widget.clockInTime ?? DateTime.now(),
        clockOutTime: DateTime.now(),
        deadAirMinutes: deadAirMinutes,
      );

      // 5. ปิด dialog นี้ก่อน
      if (mounted) {
        Navigator.of(context).pop(true);
      }

      // 6. แสดง ClockOutSummaryModal (ใน parent context)
      // ignore: use_build_context_synchronously
      if (mounted) {
        await ClockOutSummaryModal.show(
          context,
          summary: summary,
        );
      }
    } else if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  /// แสดงปุ่มปิดหรือไม่ (ไม่แสดงตอน checking, submitting, success)
  bool get _showCloseButton =>
      _step != ClockOutStep.checking &&
      _step != ClockOutStep.submitting &&
      _step != ClockOutStep.success;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.largeRadius,
          ),
          child: Container(
            width: 380,
            constraints: const BoxConstraints(maxHeight: 700),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button row
                if (_showCloseButton)
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancelCircle,
                        color: AppColors.secondaryText,
                        size: 28,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  )
                else
                  const SizedBox(height: 28), // Placeholder for spacing
                // Content
                Flexible(child: _buildContent()),
              ],
            ),
          ),
        ),
        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2, // ลงล่าง
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [
              Color(0xFFFF6B6B), // Red
              Color(0xFFFFE66D), // Yellow
              Color(0xFF4ECDC4), // Teal
              Color(0xFF95E1D3), // Mint
              Color(0xFFF38181), // Pink
              Color(0xFFAA96DA), // Purple
              Color(0xFFFCBF49), // Orange
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_step) {
      case ClockOutStep.checking:
        return _buildCheckingContent();
      case ClockOutStep.hasPendingTasks:
        return _buildPendingTasksContent();
      case ClockOutStep.hasPendingIncidents:
        return _buildPendingIncidentsContent();
      case ClockOutStep.hasUnreadPosts:
        return _buildUnreadPostsContent();
      case ClockOutStep.noHandover:
        return _buildNoHandoverContent();
      case ClockOutStep.survey:
        return _buildSurveyContent();
      case ClockOutStep.submitting:
        return _buildCheckingContent();
      case ClockOutStep.success:
        return _buildSuccessContent();
    }
  }

  Widget _buildCheckingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          'กำลังตรวจสอบ...',
          style: AppTypography.heading3,
          textAlign: TextAlign.center,
        ),
        AppSpacing.verticalGapMd,
        // Cat image
        Image.asset(
          'assets/images/checking_cat.webp',
          width: 200,
          height: 200,
        ),
        AppSpacing.verticalGapMd,
        const CircularProgressIndicator(),
      ],
    );
  }

  Widget _buildPendingTasksContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            'ยังมีงานค้าง',
            style: AppTypography.heading3,
            textAlign: TextAlign.center,
          ),

          AppSpacing.verticalGapMd,

          // Cat image
          Image.asset(
            'assets/images/checking_cat.webp',
            width: 160,
            height: 160,
          ),

          AppSpacing.verticalGapMd,

          // Message
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
              children: [
                const TextSpan(text: 'ยังมี '),
                TextSpan(
                  text: '$_remainingTasksCount งาน',
                  style: AppTypography.body.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' ที่ยังไม่เสร็จ'),
              ],
            ),
          ),

          AppSpacing.verticalGapMd,

          // Task List
          if (_remainingTasks.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _remainingTasks.length,
                itemBuilder: (context, index) {
                  final task = _remainingTasks[index];
                  return _buildTaskItem(task);
                },
              ),
            ),
            if (_remainingTasksCount > 5) ...[
              AppSpacing.verticalGapSm,
              Text(
                'และอีก ${_remainingTasksCount - 5} งาน...',
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ],

          AppSpacing.verticalGapLg,

          // Close Button
          SecondaryButton(
            text: 'ปิด',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final taskTitle = task['task_title'] as String? ?? 'งาน';
    final residentName = task['resident_name'] as String? ?? '-';
    final timeBlock = task['timeBlock'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tagFailedBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.tagFailedText.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedTask01,
            color: AppColors.tagFailedText,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taskTitle,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$residentName • $timeBlock',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// UI สำหรับแสดง pending incidents ที่ยังไม่ได้ถอดบทเรียน
  /// ใช้ BlockingCheckDialog reusable widget
  Widget _buildPendingIncidentsContent() {
    // แปลง incidents เป็น BlockingItemData
    final items = _pendingIncidents.map((incident) {
      // กำหนด status และ text ตาม reflectionStatus
      final (status, statusText) = switch (incident.reflectionStatus) {
        ReflectionStatus.pending => (
            BlockingItemStatus.pending,
            'รอถอดบทเรียน',
          ),
        ReflectionStatus.inProgress => (
            BlockingItemStatus.inProgress,
            'กำลังดำเนินการ',
          ),
        _ => (BlockingItemStatus.pending, 'รอถอดบทเรียน'),
      };

      return BlockingItemData(
        title: incident.description ?? 'ไม่มีรายละเอียด',
        subtitle: incident.residentName,
        status: status,
        statusText: statusText,
        icon: HugeIcons.strokeRoundedAlert02,
      );
    }).toList();

    // สร้าง rich message พร้อมจำนวนที่เน้น
    final richMessage = RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTypography.body.copyWith(
          color: AppColors.secondaryText,
        ),
        children: [
          const TextSpan(text: 'มี '),
          TextSpan(
            text: '$_pendingIncidentsCount เหตุการณ์',
            style: AppTypography.body.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(text: ' ที่ต้องถอดบทเรียน\nกรุณาทำให้เสร็จก่อนลงเวร'),
        ],
      ),
    );

    return BlockingCheckContent(
      title: 'มี Incident ที่ต้องถอดบทเรียน',
      imageAsset: 'assets/images/checking_cat.webp',
      imageSize: 160,
      richMessage: richMessage,
      items: items,
      totalCount: _pendingIncidentsCount,
      displayLimit: 5,
      primaryButtonText: 'ไปถอดบทเรียน',
      primaryButtonIcon: HugeIcons.strokeRoundedArrowRight01,
      onPrimaryPressed: () {
        Navigator.of(context).pop(false);
        // ส่ง incident แรกที่ยังไม่เสร็จไปให้ callback
        if (_pendingIncidents.isNotEmpty) {
          widget.onViewIncidents(_pendingIncidents.first);
        }
      },
      cancelButtonText: 'ยกเลิก',
      onCancelPressed: () => Navigator.of(context).pop(false),
    );
  }

  Widget _buildUnreadPostsContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          'ยังไม่ได้อ่านประกาศ',
          style: AppTypography.heading3,
          textAlign: TextAlign.center,
        ),

        AppSpacing.verticalGapMd,

        // Cat image
        Image.asset(
          'assets/images/checking_cat.webp',
          width: 200,
          height: 200,
        ),

        AppSpacing.verticalGapMd,

        // Message
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
            children: [
              const TextSpan(text: 'มี '),
              TextSpan(
                text: '$_unreadPostsCount โพส',
                style: AppTypography.body.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: ' ที่ยังไม่ได้อ่าน\nกรุณาอ่านให้ครบก่อนลงเวร'),
            ],
          ),
        ),

        AppSpacing.verticalGapLg,

        // View Posts Button
        PrimaryButton(
          text: 'ไปอ่านโพส',
          onPressed: () {
            Navigator.of(context).pop(false);
            widget.onViewPosts();
          },
          icon: HugeIcons.strokeRoundedArrowRight01,
        ),

        AppSpacing.verticalGapSm,

        // Cancel Button
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'ยกเลิก',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoHandoverContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          'ยังไม่ได้ Handover',
          style: AppTypography.heading3,
          textAlign: TextAlign.center,
        ),

        AppSpacing.verticalGapMd,

        // Cat image
        Image.asset(
          'assets/images/checking_cat.webp',
          width: 200,
          height: 200,
        ),

        AppSpacing.verticalGapMd,

        // Message
        Text(
          'กรุณาสร้างโพสต์ Handover ก่อนลงเวร\nเพื่อส่งต่อข้อมูลให้เวรถัดไป',
          style: AppTypography.body.copyWith(
            color: AppColors.secondaryText,
          ),
          textAlign: TextAlign.center,
        ),

        AppSpacing.verticalGapLg,

        // Create Handover Button
        PrimaryButton(
          text: 'สร้างโพสต์ Handover',
          onPressed: () {
            Navigator.of(context).pop(false);
            widget.onCreateHandover();
          },
          icon: HugeIcons.strokeRoundedFileEdit,
        ),

        AppSpacing.verticalGapSm,

        // Skip and continue
        SecondaryButton(
          text: 'ลงเวรโดยไม่ Handover',
          onPressed: () {
            setState(() => _step = ClockOutStep.survey);
          },
        ),

        AppSpacing.verticalGapSm,

        // Cancel Button
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'ยกเลิก',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSurveyContent() {
    return ClockOutSurveyForm(
      onSubmit: _handleSurveySubmit,
      isLoading: _isSubmitting,
      shiftLeader: _shiftLeader,
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success Icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            color: AppColors.success,
            size: 64,
          ),
        ),

        AppSpacing.verticalGapLg,

        // Title
        Text(
          'ลงเวรสำเร็จ! 🎉',
          style: AppTypography.heading2.copyWith(
            color: AppColors.success,
          ),
          textAlign: TextAlign.center,
        ),

        AppSpacing.verticalGapMd,

        // Message
        Text(
          'ขอบคุณที่ทำงานอย่างดีในวันนี้\nพักผ่อนให้เต็มที่นะ!',
          style: AppTypography.body.copyWith(
            color: AppColors.secondaryText,
          ),
          textAlign: TextAlign.center,
        ),

        AppSpacing.verticalGapLg,

        // Cat image
        Image.asset(
          'assets/images/graceful_cat.webp',
          width: 200,
          height: 200,
        ),
      ],
    );
  }
}
