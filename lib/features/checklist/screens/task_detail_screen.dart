import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/network_image.dart';
import '../../medicine/models/medicine_summary.dart';
import '../../medicine/screens/photo_preview_screen.dart';
import '../../medicine/services/camera_service.dart';
import '../../medicine/services/medicine_service.dart';
import '../../medicine/widgets/medicine_photo_item.dart';
import '../models/task_log.dart';
import '../providers/task_provider.dart';
import '../services/task_service.dart';
import '../models/problem_type.dart';
import '../widgets/problem_input_sheet.dart';
import '../widgets/difficulty_rating_dialog.dart';
import '../../../core/widgets/nps_scale.dart';
import '../../board/screens/advanced_create_post_screen.dart';
import '../../board/services/post_action_service.dart';
import '../../board/widgets/video_player_widget.dart';

/// หน้ารายละเอียด Task แบบ Full Page
class TaskDetailScreen extends ConsumerStatefulWidget {
  final TaskLog task;

  // Shared constant - ลด object creation สำหรับ border radius 4px
  static const kSmallRadius = BorderRadius.all(Radius.circular(4));

  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late TaskLog _task;
  bool _isOptionOpen = false;
  bool _isLoading = false;
  String? _uploadedImageUrl;

  // สำหรับงานจัดยา
  List<MedicineSummary>? _medicines;
  bool _isLoadingMedicines = false;

  // Realtime subscription
  RealtimeChannel? _taskChannel;

  @override
  void initState() {
    super.initState();
    _task = widget.task;

    // Subscribe to realtime updates for this task
    _subscribeToTaskUpdates();

    // ถ้าเป็นงานจัดยา ให้โหลดข้อมูลยา
    if (_task.taskType == 'จัดยา' && _task.residentId != null) {
      _loadMedicines();
    }
  }

  @override
  void dispose() {
    _unsubscribeFromTaskUpdates();
    super.dispose();
  }

  /// Subscribe to realtime updates สำหรับ task นี้
  void _subscribeToTaskUpdates() {
    final logId = _task.logId;

    _taskChannel = Supabase.instance.client
        .channel('task_detail_$logId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'A_Task_logs_ver2',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: logId,
          ),
          callback: (payload) {
            debugPrint(
              'TaskDetailScreen: received realtime update for task $logId',
            );
            _refreshTaskData();
          },
        )
        .subscribe();

    debugPrint('TaskDetailScreen: subscribed to task $logId updates');
  }

  /// Unsubscribe from realtime updates
  Future<void> _unsubscribeFromTaskUpdates() async {
    if (_taskChannel != null) {
      await _taskChannel!.unsubscribe();
      _taskChannel = null;
      debugPrint('TaskDetailScreen: unsubscribed from task updates');
    }
  }

  /// Refresh task data จาก database
  Future<void> _refreshTaskData() async {
    final logId = _task.logId;

    final updatedTask = await TaskService.instance.getTaskByLogId(logId);
    if (updatedTask != null && mounted) {
      setState(() {
        _task = updatedTask;
        // Clear uploaded image URL if task has been completed by someone else
        if (_task.isDone && _uploadedImageUrl != null) {
          _uploadedImageUrl = null;
        }
      });
      debugPrint('TaskDetailScreen: task refreshed - status: ${_task.status}');
    }
  }

  Future<void> _loadMedicines() async {
    if (_task.residentId == null) return;

    setState(() => _isLoadingMedicines = true);

    try {
      final medicines = await MedicineService.instance.getActiveMedicines(
        _task.residentId!,
      );

      // Filter ตามมื้อจาก task title
      final parsed = _parseMealFromTitle(_task.title ?? '');
      debugPrint('_loadMedicines: title="${_task.title}", parsed=$parsed');

      if (parsed != null && _task.expectedDateTime != null) {
        final filtered = MedicineSummary.filterByDate(
          medicines: medicines,
          selectedDate: _task.expectedDateTime!,
          beforeAfter: parsed['beforeAfter'],
          bldb: parsed['bldb'],
          prn: false,
        );
        debugPrint(
          '_loadMedicines: total=${medicines.length}, filtered=${filtered.length}',
        );

        setState(() {
          _medicines = filtered;
          _isLoadingMedicines = false;
        });
      } else {
        debugPrint(
          '_loadMedicines: no filter applied, showing all ${medicines.length} medicines',
        );
        setState(() {
          _medicines = medicines;
          _isLoadingMedicines = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading medicines: $e');
      setState(() => _isLoadingMedicines = false);
    }
  }

  /// Parse meal info จาก task title ใช้ Regex เหมือน FlutterFlow
  /// Extract beforeAfter และ bldb จาก title string
  Map<String, String?>? _parseMealFromTitle(String title) {
    final beforeAfter = _medBeforeAfterExtract(title);
    final bldb = _medBLDBExtract(title);

    // ถ้าไม่มี bldb = ไม่ใช่ task ยา
    if (bldb == null) return null;

    return {'beforeAfter': beforeAfter, 'bldb': bldb};
  }

  /// แยกคำว่า "ก่อนอาหาร" "หลังอาหาร" ออกมาจากประโยค input
  /// เหมือน medBeforeAfterExtract ใน FlutterFlow
  String? _medBeforeAfterExtract(String? input) {
    if (input == null) return null;
    final regex = RegExp(r'(ก่อนอาหาร|หลังอาหาร)');
    final match = regex.firstMatch(input);
    return match?.group(0);
  }

  /// แยกคำว่า "เช้า" "กลางวัน" "เย็น" "ก่อนนอน" ออกมาจากประโยค input
  /// เหมือน medBLDBExtract ใน FlutterFlow
  String? _medBLDBExtract(String? input) {
    if (input == null) return null;
    final regex = RegExp(r'(เช้า|กลางวัน|เย็น|ก่อนนอน)');
    final match = regex.firstMatch(input);
    return match?.group(0);
  }

  /// Visibility helpers
  bool get _isJudYa => _task.taskType == 'จัดยา';

  bool get _showUnseenBadge {
    final userId = ref.read(currentUserIdProvider);
    return !_isJudYa && !_task.historySeenUsers.contains(userId);
  }

  /// ต้องถ่ายรูปก่อนกด "เรียบร้อย" หรือไม่
  bool get _requiresPhoto =>
      _task.hasSampleImage || _isJudYa || _task.requireImage;

  /// มีรูปยืนยันแล้วหรือยัง (จาก DB หรือเพิ่งถ่าย)
  bool get _hasConfirmImage {
    final hasExistingImage =
        _task.confirmImage != null && _task.confirmImage!.isNotEmpty;
    final hasUploadedImage = _uploadedImageUrl != null;
    return hasExistingImage || hasUploadedImage;
  }

  /// แสดงปุ่มกล้องหรือไม่
  bool get _showCameraButton => !_hasConfirmImage && _requiresPhoto;

  /// แสดงปุ่ม "เรียบร้อย" หรือไม่
  /// ถ้าต้องถ่ายรูป → ต้องมีรูปก่อนจึงจะแสดงปุ่ม
  /// ถ้าเป็น mustCompleteByPost → ไม่แสดงปุ่มเรียบร้อย (ต้องโพสแทน)
  bool get _showCompleteButton =>
      !_task.mustCompleteByPost && (!_requiresPhoto || _hasConfirmImage);

  /// แสดงปุ่ม "สำเร็จด้วยโพส" หรือไม่
  /// แสดงเมื่อ: mustCompleteByPost = true และ (ไม่มี sampleImage หรือ ถ่ายรูปแล้ว)
  bool get _showCompleteByPostButton =>
      _task.mustCompleteByPost && (!_task.hasSampleImage || _hasConfirmImage);

  /// แสดงปุ่มกล้องสำหรับ mustCompleteByPost (ถ่ายรูปก่อนโพส)
  bool get _showCameraForPostButton =>
      _task.mustCompleteByPost && _task.hasSampleImage && !_hasConfirmImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unseen badge
                    if (_showUnseenBadge) _buildUnseenBadge(),

                    // Title
                    _buildTitle(),

                    // Creator info (ผู้สร้าง task) - อยู่ใต้ title
                    if (_task.creatorNickname != null) ...[
                      AppSpacing.verticalGapSm,
                      _buildCreatorInfo(),
                    ],
                    AppSpacing.verticalGapMd,

                    // Info badges
                    _buildInfoBadges(),

                    // Difficulty score badge (แยกบรรทัดเพราะ height ไม่เท่า badge อื่น)
                    if (_shouldShowDifficultyBadge) ...[
                      AppSpacing.verticalGapSm,
                      _buildDifficultyBadge(_task.difficultyScore!),
                    ],
                    AppSpacing.verticalGapMd,

                    // RecurNote (ถ้ามี)
                    if (_task.recurNote != null &&
                        _task.recurNote!.isNotEmpty) ...[
                      _buildRecurNote(),
                      AppSpacing.verticalGapMd,
                    ],

                    // Description section
                    if (_task.description != null &&
                        _task.description!.isNotEmpty) ...[
                      _buildDescriptionSection(),
                      AppSpacing.verticalGapMd,
                    ],

                    // Resident info (ถ้ามี)
                    if (_task.residentId != null && _task.residentId! > 0) ...[
                      _buildResidentCard(),
                      AppSpacing.verticalGapMd,
                    ],

                    // Sample image OR Medicine grid
                    if (_isJudYa)
                      _buildMedicineGrid()
                    else if (_task.hasSampleImage)
                      _buildSampleImage(),

                    // Confirm image (ถ้ามี) - ไม่แสดงสำหรับงานจัดยา เพราะรวมใน side-by-side แล้ว
                    if (!_isJudYa &&
                        (_task.confirmImage != null ||
                            _uploadedImageUrl != null)) ...[
                      AppSpacing.verticalGapMd,
                      _buildConfirmImage(),
                    ],

                    // Confirm video (ถ้ามี)
                    if (_task.hasConfirmVideo) ...[
                      AppSpacing.verticalGapMd,
                      _buildConfirmVideo(),
                    ],

                    // Post images (รูปจากโพสที่ complete task)
                    if (_task.hasPostImages) ...[
                      AppSpacing.verticalGapMd,
                      _buildPostImages(),
                    ],

                    // Post video (วิดีโอจากโพสที่ complete task)
                    if (_task.hasPostVideo) ...[
                      AppSpacing.verticalGapMd,
                      _buildPostVideo(),
                    ],

                    // Descript (หมายเหตุ) - ถ้า task มีปัญหาหรือมี problemType
                    if ((_task.descript != null && _task.descript!.isNotEmpty) ||
                        _task.problemType != null) ...[
                      AppSpacing.verticalGapMd,
                      _buildDescriptNote(),
                    ],

                    // Postpone info (ถ้าถูกเลื่อนมา)
                    if (_task.postponeFrom != null) ...[
                      AppSpacing.verticalGapMd,
                      _buildPostponeInfo(),
                    ],

                    // Bottom padding for action buttons
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Action buttons
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [AppShadows.subtle],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01),
          ),
          Expanded(
            child: Text(
              'รายละเอียดงาน',
              style: AppTypography.title,
              textAlign: TextAlign.center,
            ),
          ),
          // Status badge
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    String text;
    dynamic icon;

    if (_task.isDone) {
      bgColor = AppColors.tagPassedBg;
      textColor = AppColors.tagPassedText;
      text = 'เสร็จแล้ว';
      icon = HugeIcons.strokeRoundedCheckmarkCircle02;
    } else if (_task.isProblem) {
      bgColor = AppColors.error.withValues(alpha: 0.1);
      textColor = AppColors.error;
      text = 'ติดปัญหา';
      icon = HugeIcons.strokeRoundedAlert02;
    } else if (_task.isPostponed) {
      bgColor = AppColors.warning.withValues(alpha: 0.2);
      textColor = AppColors.warning;
      text = 'เลื่อนแล้ว';
      icon = HugeIcons.strokeRoundedCalendar01;
    } else if (_task.isReferred) {
      bgColor = AppColors.secondary.withValues(alpha: 0.2);
      textColor = AppColors.secondary;
      text = 'ไม่อยู่ศูนย์';
      icon = HugeIcons.strokeRoundedHospital01;
    } else {
      bgColor = AppColors.tagPendingBg;
      textColor = AppColors.tagPendingText;
      text = 'รอดำเนินการ';
      icon = HugeIcons.strokeRoundedClock01;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: AppIconSize.sm, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnseenBadge() {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tertiary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'มีอัพเดตจ้า',
        style: AppTypography.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      _task.title ?? 'ไม่ระบุชื่องาน',
      style: AppTypography.heading2.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildInfoBadges() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        // Resident name
        if (_task.residentName != null)
          _buildBadge(
            icon: HugeIcons.strokeRoundedUser,
            text: _task.residentName!,
            color: AppColors.primary,
          ),

        // Task type
        if (_task.taskType != null)
          _buildBadge(
            icon: HugeIcons.strokeRoundedDashboardSquare01,
            text: _task.taskType!,
            color: AppColors.secondary,
          ),

        // Expected time
        if (_task.expectedDateTime != null)
          _buildBadge(
            icon: HugeIcons.strokeRoundedClock01,
            text: DateFormat('HH:mm').format(_task.expectedDateTime!),
            color: AppColors.tagPendingText,
          ),

        // Time block
        if (_task.timeBlock != null)
          _buildBadge(
            icon: HugeIcons.strokeRoundedTimer01,
            text: _task.timeBlock!,
            color: AppColors.secondaryText,
          ),

        // Completed by
        if (_task.completedByNickname != null && _task.completedAt != null)
          _buildBadge(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            text:
                '${_task.completedByNickname} (${DateFormat('HH:mm').format(_task.completedAt!)})',
            color: AppColors.tagPassedText,
          ),
      ],
    );
  }

  /// ตรวจสอบว่าควรแสดง difficulty badge หรือไม่
  bool get _shouldShowDifficultyBadge =>
      _task.difficultyScore != null &&
      _task.difficultyRatedBy == ref.read(currentUserIdProvider);

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

  /// Badge แสดงคะแนนความยากที่ user ให้ไว้ (กดเพื่อแก้ไขได้)
  Widget _buildDifficultyBadge(int score) {
    final emoji = _scoreEmojis[score] ?? '🤔';

    // หาสีและ label จาก kDifficultyThresholds
    Color color = AppColors.secondaryText;
    String label = 'ความยาก';

    for (final threshold in kDifficultyThresholds) {
      if (score >= threshold.from && score <= threshold.to) {
        color = threshold.color;
        label = threshold.label ?? 'ความยาก';
        break;
      }
    }

    return GestureDetector(
      onTap: _handleEditDifficulty,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '$score - $label',
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            // Pencil icon แสดงว่ากดแก้ไขได้
            HugeIcon(
              icon: HugeIcons.strokeRoundedPencilEdit01,
              size: 14,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  /// จัดการเมื่อกด badge ความยาก เพื่อแก้ไขคะแนน
  Future<void> _handleEditDifficulty() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    // แสดง dialog เพื่อแก้ไขคะแนน (เริ่มต้นที่คะแนนเดิม)
    final result = await DifficultyRatingDialog.show(
      context,
      taskTitle: _task.title,
      allowSkip: false, // ไม่ให้ข้ามเพราะเป็นการแก้ไข
      initialScore: _task.difficultyScore, // คะแนนเดิมเป็น default
    );

    // ถ้า user กด back หรือปิด dialog → ไม่ทำอะไร
    if (result == null || result.score == null) return;

    final newScore = result.score!;

    // Optimistic update - อัพเดต UI ทันที
    final optimisticTask = _task.copyWith(
      difficultyScore: newScore,
      difficultyRatedBy: userId,
    );
    setState(() => _task = optimisticTask);

    // เรียก API อัพเดตคะแนน
    final success = await TaskService.instance.updateDifficultyScore(
      _task.logId,
      newScore,
      userId,
    );

    if (success) {
      // Refresh tasks เพื่อ sync กับ server
      refreshTasks(ref);
    } else {
      // Rollback ถ้า error (ใช้ค่าเดิม)
      if (mounted) {
        setState(() {
          _task = _task.copyWith(
            difficultyScore: _task.difficultyScore,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถอัพเดตคะแนนได้')),
        );
      }
    }
  }

  Widget _buildBadge({
    required dynamic icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: AppIconSize.sm, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurNote() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: AppColors.error, size: AppIconSize.lg),
          AppSpacing.horizontalGapSm,
          Expanded(
            child: Text(
              _task.recurNote!,
              style: AppTypography.body.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'รายละเอียด',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          AppSpacing.verticalGapSm,
          Text(_task.description!, style: AppTypography.body),
        ],
      ),
    );
  }

  Widget _buildCreatorInfo() {
    // Format: "ประกาศ โดย ชื่อ กลุ่ม - วันที่"
    final creatorName = _task.creatorNickname ?? '-';
    final groupName = _task.creatorGroupName ?? '-';

    String dateText = '-';
    if (_task.startDate != null) {
      final dt = _task.startDate!;
      dateText = '${dt.day}/${dt.month}/${dt.year}';
    }

    return Text(
      'ประกาศ โดย $creatorName $groupName - $dateText',
      style: AppTypography.caption.copyWith(
        color: AppColors.secondaryText,
        fontSize: 12,
      ),
    );
  }

  Widget _buildResidentCard() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Profile image - ใช้ IreneNetworkAvatar ที่มี timeout และ retry
          IreneNetworkAvatar(
            imageUrl: _task.residentPictureUrl,
            radius: 25,
            backgroundColor: AppColors.accent1,
            fallbackIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedUser,
              size: 24,
              color: AppColors.primary,
            ),
          ),
          AppSpacing.horizontalGapMd,

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _task.residentName ?? 'ไม่ระบุชื่อ',
                  style: AppTypography.subtitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_task.zoneName != null)
                  Text(
                    _task.zoneName!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                // โรคประจำตัว
                if (_task.residentUnderlyingDiseaseList != null &&
                    _task.residentUnderlyingDiseaseList!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'โรคประจำตัว: ${_task.residentUnderlyingDiseaseList}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Special status badge (แสดงเฉพาะเมื่อมีค่าที่มีความหมาย)
          if (_task.residentSpecialStatus != null &&
              _task.residentSpecialStatus!.isNotEmpty &&
              _task.residentSpecialStatus != '-')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _task.residentSpecialStatus == 'New'
                    ? AppColors.success.withValues(alpha: 0.2)
                    : AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _task.residentSpecialStatus!,
                style: AppTypography.caption.copyWith(
                  color: _task.residentSpecialStatus == 'New'
                      ? AppColors.success
                      : AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedicineGrid() {
    if (_isLoadingMedicines) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_medicines == null || _medicines!.isEmpty) {
      return Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/not_found.webp',
                width: 240,
                height: 240,
              ),
              AppSpacing.verticalGapSm,
              Text(
                'ไม่พบรายการยาสำหรับมื้อนี้',
                style: AppTypography.body.copyWith(color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    // ตรวจสอบว่ามีรูปยืนยันหรือยัง
    final imageUrl = _uploadedImageUrl ?? _task.confirmImage;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    // ถ้ามีรูปยืนยัน → แสดง side-by-side (grid ซ้าย, รูปขวา)
    // ถ้ายังไม่มีรูป → แสดงแค่ grid ยา (ปุ่มถ่ายอยู่ด้านล่างเหมือนเดิม)
    if (hasImage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'รายการยา (${_medicines!.length} รายการ)',
            style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.w600),
          ),
          AppSpacing.verticalGapSm,
          // Layout: Side by Side (รูปตัวอย่างยาซ้าย, รูปยืนยันขวา)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ฝั่งซ้าย: Grid รูปตัวอย่างยา (2 คอลัมน์, no spacing)
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 0, // no spacing
                    mainAxisSpacing: 0, // no spacing
                    childAspectRatio: 1.0, // 1:1 สำหรับ side-by-side
                  ),
                  itemCount: _medicines!.length,
                  itemBuilder: (context, index) {
                    final med = _medicines![index];
                    return MedicinePhotoItem(
                      medicine: med,
                      showFoiled: false, // ใช้ frontNude (รูปเม็ดยา 3C)
                      showOverlay: true, // แสดง overlay จำนวนเม็ดยา
                      borderRadius: TaskDetailScreen.kSmallRadius,
                    );
                  },
                ),
              ),

              // ไม่มี spacing - ชิดกันเลย

              // ฝั่งขวา: รูปยืนยัน
              Expanded(
                child: _buildMedicineConfirmImage(imageUrl),
              ),
            ],
          ),
        ],
      );
    }

    // ยังไม่มีรูปยืนยัน → แสดงแค่ grid ยา (ปุ่มถ่ายอยู่ด้านล่างเหมือนเดิม)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รายการยา (${_medicines!.length} รายการ)',
          style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.w600),
        ),
        AppSpacing.verticalGapSm,
        // Grid รูปตัวอย่างยา (2 คอลัมน์, no spacing)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 0, // no spacing
            mainAxisSpacing: 0, // no spacing
            childAspectRatio: 1.0, // 1:1
          ),
          itemCount: _medicines!.length,
          itemBuilder: (context, index) {
            final med = _medicines![index];
            return MedicinePhotoItem(
              medicine: med,
              showFoiled: false, // ใช้ frontNude (รูปเม็ดยา 3C)
              showOverlay: true, // แสดง overlay จำนวนเม็ดยา
              borderRadius: TaskDetailScreen.kSmallRadius,
            );
          },
        ),
      ],
    );
  }

  /// รูปยืนยันสำหรับ layout side-by-side (งานจัดยา)
  Widget _buildMedicineConfirmImage(String imageUrl) {
    // สามารถลบได้ถ้ายังไม่ complete
    final canDelete = _uploadedImageUrl != null && !_task.isDone;

    return GestureDetector(
      onTap: () => _showExpandedImage(imageUrl),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: TaskDetailScreen.kSmallRadius,
          border: Border.all(color: AppColors.tagPassedText, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 1.0, // 1:1 ให้ match กับ grid ฝั่งซ้าย
          child: Stack(
            fit: StackFit.expand,
            children: [
              // รูป
              IreneNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 400,
              ),
              // Label "รูปยืนยัน" ที่มุมบนซ้าย
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.tagPassedText,
                    borderRadius: TaskDetailScreen.kSmallRadius,
                  ),
                  child: Text(
                    'รูปยืนยัน',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              // ปุ่มลบ (ถ้าเป็นรูปที่เพิ่งถ่าย)
              if (canDelete)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: _handleDeletePhoto,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedDelete01,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSampleImage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รูปตัวอย่าง',
          style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.w600),
        ),
        AppSpacing.verticalGapSm,
        // รูปตัวอย่าง - ใช้ IreneNetworkImage ที่มี timeout และ retry
        GestureDetector(
          onTap: () => _showExpandedImage(_task.sampleImageUrl!),
          child: IreneNetworkImage(
            imageUrl: _task.sampleImageUrl!,
            height: 300,
            fit: BoxFit.contain,
            memCacheWidth: 800,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // ผู้ถ่ายรูปตัวอย่าง (ถ้ามี) - Badge เกียรติยศ
        if (_task.sampleImageCreatorId != null &&
            _task.sampleImageCreatorId!.isNotEmpty) ...[
          AppSpacing.verticalGapMd,
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFF7ED), // orange-50
                  const Color(0xFFFFFBEB), // amber-50
                  const Color(0xFFFEFCE8), // yellow-50
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.5), // amber-400
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Profile picture with golden ring
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFBBF24), // amber-400
                        Color(0xFFF59E0B), // amber-500
                        Color(0xFFD97706), // amber-600
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  // Avatar ผู้สร้างสรรค์ - ใช้ IreneNetworkAvatar ที่มี timeout และ retry
                  child: IreneNetworkAvatar(
                    imageUrl: _task.sampleImageCreatorPhotoUrl,
                    radius: 18,
                    backgroundColor: const Color(0xFFFDE68A), // amber-200
                    fallbackIcon: HugeIcon(
                      icon: HugeIcons.strokeRoundedUser,
                      size: 18,
                      color: const Color(0xFFB45309), // amber-700
                    ),
                  ),
                ),
                AppSpacing.horizontalGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '✨ ',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            'ผู้สร้างสรรค์รูปตัวอย่าง',
                            style: AppTypography.caption.copyWith(
                              color: const Color(0xFFB45309), // amber-700
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                          const Text(
                            ' ✨',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _task.sampleImageCreatorNickname ?? 'ไม่ระบุ',
                        style: AppTypography.subtitle.copyWith(
                          color: const Color(0xFF92400E), // amber-800
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                // Medal icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFCD34D), // amber-300
                        Color(0xFFFBBF24), // amber-400
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedAward01,
                    color: Color(0xFF92400E), // amber-800
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],

        // คำแนะนำใต้รูปตัวอย่าง
        AppSpacing.verticalGapSm,
        Container(
          padding: EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedInformationCircle,
                color: Color(0xFF0284C7),
                size: 16,
              ),
              AppSpacing.horizontalGapSm,
              Expanded(
                child: Text(
                  'ศึกษาภาพตัวอย่าง แล้วถ่ายให้ใกล้เคียงที่สุด เพื่อผลลัพธ์ที่ดีที่สุด',
                  style: AppTypography.caption.copyWith(
                    color: const Color(0xFF0369A1),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmImage() {
    // ถ้ามีรูปจาก Post แล้ว ไม่ต้องแสดง confirmImage ซ้ำ
    // เพราะรูปจะแสดงใน _buildPostImages() แทน (ดึงจาก post_id)
    if (_task.postImagesOnly.isNotEmpty) return const SizedBox.shrink();

    final imageUrl = _uploadedImageUrl ?? _task.confirmImage;
    if (imageUrl == null) return const SizedBox.shrink();

    // รูปที่เพิ่งถ่าย (ยังไม่ได้ save) สามารถลบได้
    final canDelete = _uploadedImageUrl != null && !_task.isDone;

    // ปุ่มแทนที่ตัวอย่าง: แสดงเมื่อ
    // 1. task type ไม่ใช่ 'จัดยา'
    // 2. user เป็นหัวหน้าเวรขึ้นไป (canQC)
    // 3. task complete แล้ว (มี confirmImage จาก DB)
    // 4. task มี taskRepeatId
    final systemRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;
    final canReplaceSample = !_isJudYa &&
        systemRole != null &&
        systemRole.canQC &&
        _task.isDone &&
        _task.confirmImage != null &&
        _task.taskRepeatId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'รูปยืนยัน',
                style: AppTypography.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.tagPassedText,
                ),
              ),
            ),
            // ปุ่มลบ (ถ้าเป็นรูปที่เพิ่งถ่าย)
            if (canDelete)
              IconButton(
                onPressed: _handleDeletePhoto,
                icon: HugeIcon(icon: HugeIcons.strokeRoundedDelete01, color: AppColors.error, size: AppIconSize.lg),
                tooltip: 'ลบรูป',
              ),
          ],
        ),
        AppSpacing.verticalGapSm,
        // รูป task - ใช้ IreneNetworkImage ที่มี timeout และ retry
        GestureDetector(
          onTap: () => _showExpandedImage(imageUrl),
          child: IreneNetworkImage(
            imageUrl: imageUrl,
            height: 300,
            fit: BoxFit.contain,
            memCacheWidth: 800,
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        // ปุ่มแทนที่ตัวอย่าง (สำหรับหัวหน้าเวรขึ้นไป)
        if (canReplaceSample) ...[
          AppSpacing.verticalGapMd,
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleReplaceSampleImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : HugeIcon(icon: HugeIcons.strokeRoundedImageComposition, size: AppIconSize.lg),
              label: Text(
                'แทนที่ตัวอย่าง',
                style: AppTypography.button.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmVideo() {
    final videoUrl = _task.confirmVideoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return const SizedBox.shrink();

    final thumbnailUrl = _task.confirmVideoThumbnail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'วิดีโอยืนยัน',
          style: AppTypography.subtitle.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.tagPassedText,
          ),
        ),
        AppSpacing.verticalGapSm,
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () => FullScreenVideoPlayer.show(context, videoUrl),
            child: Stack(
              children: [
                // Thumbnail วิดีโอ - ใช้ IreneNetworkImage ที่มี timeout และ retry
                if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                  IreneNetworkImage(
                    imageUrl: thumbnailUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    errorPlaceholder: _buildVideoPlaceholder(),
                  )
                else
                  _buildVideoPlaceholder(),

                // Play button overlay
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedPlay,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Video label
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedVideo01, size: AppIconSize.sm, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'แตะเพื่อเล่น',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      color: AppColors.background,
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedVideo01,
          size: 64,
          color: AppColors.secondaryText.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// แสดงรูปจาก Post ที่ complete task นี้
  Widget _buildPostImages() {
    final images = _task.postImagesOnly;
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รูปจากโพส (${images.length} รูป)',
          style: AppTypography.subtitle.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.tagPassedText,
          ),
        ),
        AppSpacing.verticalGapSm,
        // ถ้ามี 1 รูป แสดงเต็มความกว้าง - ใช้ IreneNetworkImage ที่มี timeout และ retry
        if (images.length == 1)
          GestureDetector(
            onTap: () => _showExpandedImage(images.first),
            child: IreneNetworkImage(
              imageUrl: images.first,
              height: 200,
              fit: BoxFit.contain,
              memCacheWidth: 800,
              borderRadius: BorderRadius.circular(12),
            ),
          )
        // ถ้ามีหลายรูป แสดงเป็น grid - ใช้ IreneNetworkImage ที่มี timeout และ retry
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _showExpandedImage(images[index]),
                child: IreneNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  memCacheWidth: 400,
                  borderRadius: BorderRadius.circular(8),
                  compact: true,
                ),
              );
            },
          ),
      ],
    );
  }

  /// แสดง video จาก Post ที่ complete task นี้
  Widget _buildPostVideo() {
    final videoUrl = _task.firstPostVideoUrl;
    if (videoUrl == null) return const SizedBox.shrink();

    final thumbnailUrl = _task.postThumbnailUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'วิดีโอจากโพส',
          style: AppTypography.subtitle.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.tagPassedText,
          ),
        ),
        AppSpacing.verticalGapSm,
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () => FullScreenVideoPlayer.show(context, videoUrl),
            child: Stack(
              children: [
                // Thumbnail วิดีโอ Post - ใช้ IreneNetworkImage ที่มี timeout และ retry
                if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                  IreneNetworkImage(
                    imageUrl: thumbnailUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    errorPlaceholder: _buildVideoPlaceholder(),
                  )
                else
                  _buildVideoPlaceholder(),

                // Play button overlay
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedPlay,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Video label
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedVideo01, size: AppIconSize.sm, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'แตะเพื่อเล่น',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptNote() {
    // แปลง problemType string เป็น ProblemType enum (ถ้ามี)
    final problemType = ProblemType.fromValue(_task.problemType);

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedMessage01, color: AppColors.warning, size: AppIconSize.md),
              AppSpacing.horizontalGapSm,
              Text(
                'หมายเหตุ',
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapSm,
          // แสดง problemType badge (ถ้ามี)
          if (problemType != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${problemType.emoji} ${problemType.label}',
                style: AppTypography.body.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AppSpacing.verticalGapSm,
          ],
          // แสดง descript (หมายเหตุเพิ่มเติม) ถ้ามี
          if (_task.descript != null && _task.descript!.isNotEmpty)
            Text(_task.descript!, style: AppTypography.body),
        ],
      ),
    );
  }

  Widget _buildPostponeInfo() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, color: AppColors.secondary, size: AppIconSize.lg),
          AppSpacing.horizontalGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'งานถูกเลื่อนมาจากวันก่อน',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_task.expectedDatePostponeFrom != null)
                  Text(
                    'วันที่เดิม: ${DateFormat('dd/MM/yyyy HH:mm').format(_task.expectedDatePostponeFrom!)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExpandedImage(String imageUrl) {
    if (imageUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: IreneSecondaryAppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          // รูปเต็มจอ - ใช้ IreneNetworkImage ที่มี timeout และ retry
          body: InteractiveViewer(
            child: Center(
              child: IreneNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                memCacheWidth: 1200,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child:
            _task.isDone ||
                _task.isPostponed ||
                _task.isReferred ||
                _task.isProblem
            ? _buildCancelButton()
            : _isOptionOpen
            ? _buildOptionsRow()
            : _buildMainActionsRow(),
      ),
    );
  }

  Widget _buildMainActionsRow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ป้ายเตือนสีแดง (แสดงเมื่อถ่ายรูปแล้ว และยังไม่ได้กดเรียบร้อย)
        if (_showCompleteButton && _hasConfirmImage)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  // รูปแอบมอง
                  Image.asset(
                    'assets/images/peep2.webp',
                    width: 100,
                    height: 100,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ตรวจสอบความถูกต้องก่อนส่งรายงาน',
                          style: AppTypography.body.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'รูป ชื่อผู้ทำ และเวลา จะถูกส่งไปไลน์กลุ่มญาติ',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.error.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Action buttons row
        Row(
          children: [
            // Options button (?)
            SizedBox(
              width: 48,
              height: 48,
              child: OutlinedButton(
                onPressed: () => setState(() => _isOptionOpen = true),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: AppColors.inputBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: HugeIcon(icon: HugeIcons.strokeRoundedMoreHorizontal, color: AppColors.secondaryText),
              ),
            ),
            AppSpacing.horizontalGapSm,

            // Camera button (ถ้าต้องถ่ายรูป - สำหรับงานปกติ)
            if (_showCameraButton)
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleTakePhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : HugeIcon(icon: HugeIcons.strokeRoundedCamera01),
                    label: Text('ถ่ายรูปงาน', style: AppTypography.button),
                  ),
                ),
              ),

            // Camera button (สำหรับ mustCompleteByPost - ต้องถ่ายรูปก่อนโพส)
            if (_showCameraForPostButton)
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleTakePhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tertiary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : HugeIcon(icon: HugeIcons.strokeRoundedCamera01),
                    label: Text('ถ่ายรูปก่อนโพส', style: AppTypography.button),
                  ),
                ),
              ),

            // Complete button (แสดงเมื่อไม่ต้องถ่ายรูป หรือถ่ายรูปแล้ว)
            if (_showCompleteButton)
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02),
                    label: Text('เรียบร้อย', style: AppTypography.button),
                  ),
                ),
              ),

            // Complete by post button (สำหรับ task ที่ต้องสำเร็จด้วยโพส)
            if (_showCompleteByPostButton)
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleCompleteByPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tertiary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedFileEdit),
                    label: Text('สำเร็จด้วยโพส', style: AppTypography.button),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionsRow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Back button + Problem button
        Row(
          children: [
            // Back button (<)
            SizedBox(
              width: 48,
              height: 48,
              child: OutlinedButton(
                onPressed: () => setState(() => _isOptionOpen = false),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: AppColors.inputBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: AppColors.secondaryText),
              ),
            ),
            AppSpacing.horizontalGapSm,

            // Problem button
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleProblem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedAlert02),
                  label: Text('แจ้งติดปัญหา', style: AppTypography.button),
                ),
              ),
            ),
          ],
        ),
        AppSpacing.verticalGapSm,

        // Refer button (ปุ่มเลื่อนวันพรุ่งนี้ถูกลบออก - ให้หัวหน้าเวรตัดสินใจแทน)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleRefer,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.secondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: HugeIcon(icon: HugeIcons.strokeRoundedHospital01, color: AppColors.secondary),
            label: Text(
              'ไม่อยู่ศูนย์',
              style: AppTypography.button.copyWith(
                color: AppColors.secondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleCancel,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.error),
                ),
              )
            : HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, color: AppColors.error),
        label: Text(
          'ยกเลิกการรับทราบ',
          style: AppTypography.button.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  // Action handlers
  Future<void> _handleComplete() async {
    final service = ref.read(taskServiceProvider);
    final userId = ref.read(currentUserIdProvider);
    final userNickname = ref.read(currentUserNicknameProvider).valueOrNull;

    if (userId == null) return;

    // === แสดง Dialog ให้ประเมินความยากของงาน ===
    // ถ้า user ปิด dialog (กด back) จะได้ null → ยกเลิก completion
    final difficultyResult = await DifficultyRatingDialog.show(
      context,
      taskTitle: _task.title,
      allowSkip: true, // ให้ข้ามได้
      avgScore: _task.avgDifficultyScore30d, // ค่าเฉลี่ยย้อนหลัง 30 วัน
    );

    // ถ้า user ปิด dialog โดยไม่ทำอะไร → ยกเลิก
    if (difficultyResult == null) return;
    if (!mounted) return;

    // คะแนนความยากที่ user ให้ (null = ข้าม → ใช้ default 5)
    final difficultyScore = difficultyResult.score;

    // === Capture data ก่อน async operations ===
    // เพราะ Realtime event จาก markTaskComplete อาจ trigger _refreshTaskData()
    // ซึ่งจะ clear _uploadedImageUrl = null ก่อนที่ upsertMedLog3C จะได้ทำงาน
    // (race condition: เน็ตยิ่งเร็ว Realtime ยิ่งมาเร็ว ยิ่งเกิดบ่อย)
    final capturedImageUrl = _uploadedImageUrl;
    final capturedTaskType = _task.taskType;
    final capturedResidentId = _task.residentId;
    final capturedExpectedDate = _task.expectedDateTime;
    final capturedTitle = _task.title;
    final capturedLogId = _task.logId;

    // === Optimistic Update ===
    // สร้าง task ใหม่ที่มีสถานะ complete ก่อนรอ server
    final optimisticTask = _task.copyWith(
      status: 'complete',
      completedByUid: userId,
      completedByNickname: userNickname,
      completedAt: DateTime.now(),
      confirmImage: capturedImageUrl,
      difficultyScore: difficultyScore ?? 5, // default 5 ถ้า skip
      difficultyRatedBy: userId,
      difficultyRaterNickname: userNickname,
    );

    // อัพเดต local state ทันที
    setState(() {
      _task = optimisticTask;
      _isLoading = true;
    });

    // อัพเดต provider เพื่อให้ checklist screen เห็นผลทันที
    final rollback = optimisticUpdateTask(ref, optimisticTask);

    // === เรียก Server ===
    final success = await service.markTaskComplete(
      capturedLogId,
      userId,
      imageUrl: capturedImageUrl,
      difficultyScore: difficultyScore, // null = ใช้ default ใน database
      difficultyRatedBy: userId,
    );

    if (success) {
      // === Special logic สำหรับ taskType = 'จัดยา' ===
      // ถ้าเป็นงานจัดยา และมีรูปยืนยัน ให้บันทึกลง A_Med_logs ด้วย
      // ใช้ captured values เพราะ _uploadedImageUrl อาจถูก clear โดย Realtime แล้ว
      if (capturedTaskType == 'จัดยา' &&
          capturedImageUrl != null &&
          capturedResidentId != null &&
          capturedExpectedDate != null) {
        // ดึง meal จาก title (เช่น 'ก่อนอาหารเช้า', 'หลังอาหารกลางวัน')
        final meal = _extractMealFromTitle(capturedTitle ?? '');
        if (meal != null) {
          // บันทึกลง A_Med_logs (3C)
          await MedicineService.instance.upsertMedLog3C(
            residentId: capturedResidentId,
            meal: meal,
            expectedDate: capturedExpectedDate,
            userId: userId,
            pictureUrl: capturedImageUrl,
            taskLogId: capturedLogId,
          );
        }
      }

      // === Optimistic Update Strategy ===
      // ไม่ต้อง commitOptimisticUpdate หรือ refreshTasks ก่อน pop
      // เพื่อให้ ChecklistScreen เห็น optimistic state ทันที
      // Realtime event จะมา trigger refresh และ clear optimistic state ภายหลัง
      if (mounted) Navigator.pop(context);
    } else {
      // Rollback ถ้า server error
      rollback();
      setState(() {
        _task = widget.task; // กลับไปใช้ task เดิม
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถบันทึกได้ กรุณาลองใหม่')),
        );
      }
    }
  }

  /// ดึงมื้อยาจาก task title
  /// เช่น "จัดยาก่อนอาหารเช้า คุณสมชาย" → "ก่อนอาหารเช้า"
  /// เช่น "จัดยาหลังอาหารกลางวัน คุณสมหญิง" → "หลังอาหารกลางวัน"
  /// เช่น "จัดยาก่อนนอน คุณสมศรี" → "ก่อนนอน"
  String? _extractMealFromTitle(String title) {
    final beforeAfter = _medBeforeAfterExtract(title);
    final bldb = _medBLDBExtract(title);

    // ถ้าไม่มี bldb = ไม่ใช่ task ยา
    if (bldb == null) return null;

    // รวม beforeAfter + bldb เป็น meal key
    // เช่น 'ก่อนอาหาร' + 'เช้า' = 'ก่อนอาหารเช้า'
    // เช่น '' + 'ก่อนนอน' = 'ก่อนนอน'
    if (beforeAfter != null && beforeAfter.isNotEmpty) {
      return '$beforeAfter$bldb';
    }
    return bldb;
  }

  Future<void> _handleProblem() async {
    // แสดง bottom sheet ให้ user เลือกประเภทปัญหา
    // ส่ง task เข้าไปเพื่อโหลด resolution history (ประวัติการแก้ปัญหาที่ผ่านมา)
    final problemData = await ProblemInputSheet.show(context, task: _task);
    if (problemData == null) return;

    final service = ref.read(taskServiceProvider);
    final userId = ref.read(currentUserIdProvider);
    final userNickname = ref.read(currentUserNicknameProvider).valueOrNull;

    // ต้องมี userId ถึงจะบันทึกได้
    if (userId == null) return;

    // === Optimistic Update ===
    final optimisticTask = _task.copyWith(
      status: 'problem',
      problemType: problemData.type.value,
      descript: problemData.description,
      completedByUid: userId,
      completedByNickname: userNickname,
      completedAt: DateTime.now(),
    );

    // อัพเดต local state ทันที
    setState(() {
      _task = optimisticTask;
      _isLoading = true;
    });

    // อัพเดต provider เพื่อให้ checklist screen เห็นผลทันที
    final rollback = optimisticUpdateTask(ref, optimisticTask);

    // === เรียก Server ===
    final success = await service.markTaskProblem(
      _task.logId,
      userId,
      problemData.type.value,
      problemData.description,
    );

    if (success) {
      // === Optimistic Update Strategy ===
      // ไม่ต้อง commitOptimisticUpdate หรือ refreshTasks ก่อน pop
      // เพื่อให้ ChecklistScreen เห็น optimistic state ทันที
      // Realtime event จะมา trigger refresh และ clear optimistic state ภายหลัง
      if (mounted) Navigator.pop(context);
    } else {
      // Rollback ถ้า server error
      rollback();
      setState(() {
        _task = widget.task;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถบันทึกได้ กรุณาลองใหม่')),
        );
      }
    }
  }

  Future<void> _handleRefer() async {
    final service = ref.read(taskServiceProvider);
    final userId = ref.read(currentUserIdProvider);
    final userNickname = ref.read(currentUserNicknameProvider).valueOrNull;

    if (userId == null) return;

    // === Optimistic Update ===
    final optimisticTask = _task.copyWith(
      status: 'refer',
      descript: 'อยู่ที่โรงพยาบาล (Refer)',
      completedByUid: userId,
      completedByNickname: userNickname,
      completedAt: DateTime.now(),
    );

    // อัพเดต local state ทันที
    setState(() {
      _task = optimisticTask;
      _isLoading = true;
    });

    // อัพเดต provider เพื่อให้ checklist screen เห็นผลทันที
    final rollback = optimisticUpdateTask(ref, optimisticTask);

    // === เรียก Server ===
    final success = await service.markTaskRefer(_task.logId, userId);

    if (success) {
      // === Optimistic Update Strategy ===
      // ไม่ต้อง commitOptimisticUpdate หรือ refreshTasks ก่อน pop
      // เพื่อให้ ChecklistScreen เห็น optimistic state ทันที
      // Realtime event จะมา trigger refresh และ clear optimistic state ภายหลัง
      if (mounted) Navigator.pop(context);
    } else {
      // Rollback ถ้า server error
      rollback();
      setState(() {
        _task = widget.task;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถบันทึกได้ กรุณาลองใหม่')),
        );
      }
    }
  }

  Future<void> _handleCancel() async {
    // สร้าง message ตามสถานะ
    String message = 'ต้องการยกเลิกสถานะงานนี้หรือไม่?';
    if (_task.isPostponed && _task.postponeTo != null) {
      message = 'การยกเลิกนี้ จะลบงานที่ถูกเลื่อนออกไปด้วยนะ แน่ใจมั้ย?';
    }

    // แสดง confirmation dialog ก่อน
    final confirmed = await ConfirmDialog.show(
      context,
      type: ConfirmDialogType.warning,
      title: 'ยกเลิกการรับทราบ?',
      message: message,
      cancelText: 'ไม่',
      confirmText: 'ยกเลิก',
    );

    // ถ้าไม่ได้กดยืนยัน ไม่ทำอะไร
    if (!confirmed) return;

    final service = ref.read(taskServiceProvider);
    final originalTask = _task; // เก็บ task เดิมสำหรับ rollback

    // === Optimistic Update ===
    // สร้าง task ที่ clear สถานะทั้งหมด
    final optimisticTask = _task.copyWith(
      clearStatus: true,
      clearCompletedAt: true,
      clearCompletedByUid: true,
      clearCompletedByNickname: true,
      clearConfirmImage: true,
      clearProblemType: true,
      clearDescript: true,
      clearDifficultyScore: true,
      clearDifficultyRatedBy: true,
    );

    // อัพเดต local state ทันที
    setState(() {
      _task = optimisticTask;
      _isLoading = true;
      _uploadedImageUrl = null; // Clear uploaded image URL
    });

    // อัพเดต provider เพื่อให้ checklist screen เห็นผลทันที
    final rollback = optimisticUpdateTask(ref, optimisticTask);

    // === เรียก Server ===
    bool success;
    if (originalTask.isPostponed && originalTask.postponeTo != null) {
      success = await service.cancelPostpone(originalTask.logId, originalTask.postponeTo!);
    } else {
      final imageUrl = originalTask.confirmImage ?? _uploadedImageUrl;
      success = await service.unmarkTask(
        originalTask.logId,
        confirmImageUrl: imageUrl,
      );
    }

    if (success) {
      // === Special logic สำหรับ taskType = 'จัดยา' ===
      // ถ้าเป็นงานจัดยาที่ complete แล้ว ให้ clear ข้อมูล 3C ใน A_Med_logs ด้วย
      if (originalTask.taskType == 'จัดยา' &&
          originalTask.isDone &&
          originalTask.residentId != null &&
          originalTask.expectedDateTime != null) {
        // ดึง meal จาก title
        final meal = _extractMealFromTitle(originalTask.title ?? '');

        if (meal != null) {
          // Clear ข้อมูล 3C จาก A_Med_logs
          // - ถ้ามีรูป 2C → clear เฉพาะ 3C fields
          // - ถ้าไม่มีรูป 2C → ลบ row ทั้งหมด
          await MedicineService.instance.clearMedLog3C(
            residentId: originalTask.residentId!,
            meal: meal,
            expectedDate: originalTask.expectedDateTime!,
          );
        }
      }

      // === ลบ Post ที่เชื่อมกับ task นี้ (ถ้ามี) ===
      // เมื่อยกเลิกการรับทราบ task ที่ complete ผ่าน Post ควรลบ Post ด้วย
      // เพราะ Post นั้นถูกสร้างขึ้นเพื่อ complete task โดยเฉพาะ
      if (originalTask.postId != null) {
        final deleted = await PostActionService.instance.deletePost(originalTask.postId!);
        if (deleted) {
          debugPrint('TaskDetailScreen: deleted post ${originalTask.postId} for task ${originalTask.logId}');
        } else {
          debugPrint('TaskDetailScreen: failed to delete post ${originalTask.postId}');
        }
      }

      // === Optimistic Update Strategy ===
      // ไม่ต้อง commitOptimisticUpdate หรือ refreshTasks ก่อน pop
      // เพื่อให้ ChecklistScreen เห็น optimistic state ทันที
      // Realtime event จะมา trigger refresh และ clear optimistic state ภายหลัง
      if (mounted) Navigator.pop(context);
    } else {
      // Rollback ถ้า server error
      rollback();
      setState(() {
        _task = originalTask;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถยกเลิกได้ กรุณาลองใหม่')),
        );
      }
    }
  }

  Future<void> _handleTakePhoto() async {
    // DEV MODE: ถ้าเป็น debug mode บน desktop ใช้รูป dummy แทน
    const bool useDevDummy = kDebugMode;
    final bool isDesktopOrWeb =
        kIsWeb ||
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux));

    if (useDevDummy && isDesktopOrWeb) {
      // ใช้รูป dummy สำหรับทดสอบ (แมวแอบมอง)
      const dummyUrl =
          'https://cdn.pixabay.com/photo/2019/11/08/11/56/cat-4611189_640.jpg';
      setState(() {
        _uploadedImageUrl = dummyUrl;
      });
      return;
    }

    final cameraService = CameraService.instance;

    // ถ่ายรูป
    final file = await cameraService.takePhoto();
    if (file == null) return;

    // แสดงหน้า Preview ให้หมุนรูปได้
    if (!mounted) return;
    final confirmedFile = await PhotoPreviewScreen.show(
      context: context,
      imageFile: file,
      photoType: 'task',
      mealLabel: _task.title ?? 'งาน',
    );

    // ถ้ายกเลิกจาก preview
    if (confirmedFile == null) return;

    // Upload รูป
    setState(() => _isLoading = true);

    try {
      final storagePath =
          'task_confirms/${_task.logId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final bytes = await confirmedFile.readAsBytes();

      await Supabase.instance.client.storage
          .from('med-photos')
          .uploadBinary(storagePath, bytes);

      final url = Supabase.instance.client.storage
          .from('med-photos')
          .getPublicUrl(storagePath);

      setState(() {
        _uploadedImageUrl = url;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถอัพโหลดรูปได้ กรุณาลองใหม่')),
        );
      }
    }
  }

  /// ลบรูปที่ถ่ายไว้
  Future<void> _handleDeletePhoto() async {
    final confirmed = await ConfirmDialog.show(
      context,
      type: ConfirmDialogType.delete,
      title: 'ลบรูป?',
      message: 'ต้องการลบรูปที่ถ่ายไว้หรือไม่?',
      confirmText: 'ลบ',
    );

    if (confirmed) {
      setState(() {
        _uploadedImageUrl = null;
      });
    }
  }

  /// เปิด AdvancedCreatePostScreen พร้อมข้อมูลจาก task
  /// ใช้ full-screen แทน modal เพื่อให้มีพื้นที่พิมพ์ description มากขึ้น
  void _handleCompleteByPost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvancedCreatePostScreen(
          initialTitle: _task.title ?? '', // หัวข้อจาก task (lock ไว้)
          initialResidentId: _task.residentId,
          initialResidentName: _task.residentName,
          initialTagName: 'งานเช็คลิสต์', // ใช้ tag "งานเช็คลิสต์" สำหรับทุก task
          taskLogId: _task.logId,
          taskConfirmImageUrl: _uploadedImageUrl, // รูปที่ถ่ายไว้ (ถ้ามี)
          onPostCreated: () {
            // เมื่อโพสสำเร็จ task จะถูก complete โดย AdvancedCreatePostScreen แล้ว
            // เพียงแค่กลับไปหน้า checklist
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }

  /// แทนที่รูปตัวอย่างด้วยรูป confirm ที่ถ่ายเสร็จแล้ว (สำหรับหัวหน้าเวรขึ้นไป)
  Future<void> _handleReplaceSampleImage() async {
    final taskRepeatId = _task.taskRepeatId;
    final confirmImage = _task.confirmImage;

    if (taskRepeatId == null || confirmImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถแทนที่รูปตัวอย่างได้')),
      );
      return;
    }

    // แสดง confirmation dialog
    final confirmed = await ConfirmDialog.show(
      context,
      type: ConfirmDialogType.warning,
      title: 'แทนที่รูปตัวอย่าง?',
      message: 'รูปยืนยันนี้จะถูกใช้เป็นรูปตัวอย่างใหม่สำหรับงานนี้',
      confirmText: 'แทนที่',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      // ดึง uuid ของ current user
      final userId = ref.read(currentUserIdProvider);

      // Update A_Repeated_Task.sampleImageURL และ sampleImage_creator (uuid)
      await Supabase.instance.client.from('A_Repeated_Task').update({
        'sampleImageURL': confirmImage,
        'sampleImage_creator': userId,
      }).eq('id', taskRepeatId);

      // Refresh task data
      await _refreshTaskData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('แทนที่รูปตัวอย่างเรียบร้อย')),
        );
      }
    } catch (e) {
      debugPrint('Error replacing sample image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถแทนที่รูปตัวอย่างได้ กรุณาลองใหม่')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
