import 'dart:io'; // ใช้สำหรับ File type ใน camera flow (ไม่รองรับ Web)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/input_fields.dart';
import '../../../core/widgets/network_image.dart';
import '../../medicine/models/medicine_summary.dart';
import '../../medicine/screens/photo_preview_screen.dart';
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
import '../../../core/widgets/webview_screen.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/keyboard_dismiss_scope.dart';
import '../../../core/widgets/mic_button.dart';
import '../../../core/services/stt_service.dart';
import '../../../core/widgets/shimmer_loading.dart';
import 'split_screen_camera_screen.dart';
import 'square_camera_screen.dart';
import '../../points/services/points_service.dart';
import '../providers/batch_task_provider.dart';
import '../widgets/co_worker_picker.dart';
import '../models/measurement_config.dart';
import '../widgets/measurement_input_dialog.dart';
import '../services/measurement_service.dart';
import '../services/assessment_service.dart';
import '../models/assessment_models.dart';
import '../widgets/assessment_inline_section.dart';
import '../../../core/services/retry_queue_service.dart';

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

  // เพื่อนร่วมเวรที่เลือกไว้ (สำหรับหาร point)
  List<CoWorker> _selectedCoWorkers = [];

  // สำหรับงานจัดยา
  List<MedicineSummary>? _medicines;
  bool _isLoadingMedicines = false;

  // สำหรับ expandable details ในหน้าจัดยา (default: ซ่อนไว้เพื่อให้เห็นรูปยาทันที)
  bool _isDetailExpanded = false;

  // สำหรับ measurement task (ชั่งน้ำหนัก, วัดส่วนสูง, DTX, Insulin)
  // ค่าจาก inline section — ใช้ตอน _handleComplete
  MeasurementConfig? _measurementConfig;
  final _measurementController = TextEditingController();
  String? _measurementPhotoUrl;
  bool _hasMeasurementValue = false; // true เมื่อ user กรอกค่าแล้ว

  // Assessment — prefetch subjects ตอน initState, เก็บ ratings จาก inline section
  List<AssessmentSubject> _assessmentSubjects = [];
  List<AssessmentRating> _assessmentRatings = [];
  bool _assessmentComplete = false; // true เมื่อประเมินครบทุกหัวข้อ

  // หมายเหตุเพิ่มเติม (optional) — inline section ในหน้า task detail
  // user พิมพ์ได้ตลอดก่อนกดเสร็จ/ติดปัญหา (ไม่ต้องรอ dialog)
  // เมื่อกดเสร็จ → save ลง Descript (กับ status='complete')
  // เมื่อกดติดปัญหา → ProblemInputSheet มี description ของตัวเอง (ไม่ใช้ _noteController)
  final _noteController = TextEditingController();

  // Realtime subscription
  RealtimeChannel? _taskChannel;

  @override
  void initState() {
    super.initState();
    _task = widget.task;

    // Subscribe to realtime updates for this task
    // (_refreshTaskData จะเรียก _enrichSampleImageCreator เมื่อมี update)
    _subscribeToTaskUpdates();

    // ดึงชื่อ+รูปผู้สร้างสรรค์รูปตัวอย่าง (view ส่ง NULL มา ต้อง fetch แยก)
    // เรียกครั้งเดียวตอน init — realtime refresh จะเรียกซ้ำเมื่อมี DB update
    _enrichSampleImageCreator();

    // Mark ว่า user เห็น update ของ task แล้ว (ถ้ามี unseen update)
    // ไม่ block UI — fire and forget
    _markAsSeenIfNeeded();

    // ถ้าเป็นงานจัดยา ให้โหลดข้อมูลยา
    if (_task.taskType == 'จัดยา' && _task.residentId != null) {
      _loadMedicines();
    }

    // ตรวจว่าเป็น measurement task หรือไม่ (เช่น ชั่งน้ำหนัก, วัดส่วนสูง, DTX, Insulin)
    _measurementConfig = getMeasurementConfig(_task.taskType);

    // Prefetch assessment subjects ล่วงหน้า เพื่อไม่ต้องรอตอนกด complete
    _prefetchAssessmentSubjects();
  }

  /// Mark task ว่า user เห็น update แล้ว (ถ้ามี unseen update)
  /// เงื่อนไข:
  /// - มี historySeenId (ต้องมี update ล่าสุด — ถ้า NULL = task ไม่เคยถูก edit)
  /// - user ยังไม่อยู่ใน historySeenUsers (ยังไม่เคยเห็น)
  /// - ไม่ใช่งานจัดยา (ไม่มี unseen concept)
  Future<void> _markAsSeenIfNeeded() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    if (_task.historySeenId == null) return;
    if (_task.taskType == 'จัดยา') return;
    if (_task.historySeenUsers.contains(userId)) return;

    await TaskService.instance.markTaskAsSeen(
      historySeenId: _task.historySeenId!,
      userId: userId,
    );

    // Update local state ทันที — ไม่ต้อง refetch
    // (badge หายจาก UI นี้, list view parent จะ refetch ผ่าน ref.invalidate ตอน pop)
    if (mounted) {
      setState(() {
        _task = _task.copyWith(
          historySeenUsers: [..._task.historySeenUsers, userId],
        );
      });
    }
  }

  /// โหลดหัวข้อประเมินล่วงหน้าจาก TaskType_Report_Subject
  /// ถ้า taskType ไม่มี subjects กำหนดไว้ก็ได้ list ว่าง — ไม่แสดง dialog
  Future<void> _prefetchAssessmentSubjects() async {
    if (_task.taskType == null || _task.taskType!.isEmpty) return;
    if (_task.residentId == null) return;
    try {
      final nhId = await ref.read(nursinghomeIdProvider.future) ?? 0;
      final subjects = await AssessmentService.instance
          .getSubjectsForTaskType(_task.taskType!, nhId);
      if (mounted) {
        setState(() => _assessmentSubjects = subjects);
      }
    } catch (e) {
      debugPrint('Prefetch assessment subjects failed: $e');
    }
  }

  @override
  void dispose() {
    _measurementController.dispose();
    _noteController.dispose();
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
        // Reset co-workers เมื่อ task status เปลี่ยนผ่าน realtime
        // ป้องกัน stale co-workers ถูกใช้ซ้ำถ้า admin undo แล้ว user complete ใหม่
        if (_task.isDone && _selectedCoWorkers.isNotEmpty) {
          _selectedCoWorkers = [];
        }
      });
      debugPrint('TaskDetailScreen: task refreshed - status: ${_task.status}');

      // Enrich sample image creator info (view ส่ง nickname/photo_url เป็น NULL)
      await _enrichSampleImageCreator();
    }
  }

  /// ดึงชื่อ+รูปของผู้สร้างสรรค์รูปตัวอย่าง จาก user_info
  /// เพราะ view ส่ง sampleimage_creator (UUID) มาจริง
  /// แต่ nickname กับ photo_url เป็น NULL dummy (เพื่อ performance ของ list view)
  Future<void> _enrichSampleImageCreator() async {
    final creatorId = _task.sampleImageCreatorId;
    // ถ้าไม่มี creator UUID หรือมี nickname อยู่แล้ว → ไม่ต้อง fetch
    if (creatorId == null || creatorId.isEmpty) return;
    if (_task.sampleImageCreatorNickname != null) return;

    final userInfo = await TaskService.instance.getUserBasicInfo(creatorId);
    if (userInfo != null && mounted) {
      setState(() {
        _task = _task.copyWith(
          sampleImageCreatorNickname: userInfo['nickname'],
          sampleImageCreatorPhotoUrl: userInfo['photo_url'],
        );
      });
      debugPrint(
        'TaskDetailScreen: enriched sample creator - ${userInfo['nickname']}',
      );
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

  /// ตรวจสอบสิทธิ์การยกเลิก task
  /// อนุญาตเฉพาะ: คนที่ทำ task, หัวหน้าเวรขึ้นไป (level >= 30), แพทย์ (role 6)
  /// ใช้ ref.watch เพื่อ rebuild เมื่อ role โหลดเสร็จ (FutureProvider)
  bool get _canCancelTask {
    final userId = ref.watch(currentUserIdProvider);
    final systemRole = ref.watch(currentUserSystemRoleProvider).valueOrNull;

    // 1. คนที่ complete/postpone/problem task นี้
    if (_task.completedByUid != null && _task.completedByUid == userId) {
      return true;
    }

    // 2. หัวหน้าเวรขึ้นไป (level >= 30) หรือ แพทย์ (role 6)
    if (systemRole != null && systemRole.canCancelTask) return true;

    return false;
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
      // Wrap body ด้วย KeyboardDismissScope เพื่อ:
      // 1. แตะพื้นที่ว่าง → keyboard ปิด (tap-outside-to-dismiss)
      // 2. แสดงแถบ "ตกลง" เหนือ keyboard เมื่อ numeric keyboard เปิด
      //    (iOS numeric keyboard ไม่มีปุ่ม Done → ไม่งั้น user ปิดไม่ได้
      //    + bottomNavigationBar ปุ่ม Complete จะถูกบังอยู่ใต้ keyboard)
      body: KeyboardDismissScope(
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              _buildAppBar(),

              // ถ้าเป็นงานจัดยา: compact header อยู่บน (fixed) + grid ยาขยายเต็มพื้นที่ล่าง
              // ถ้าเป็น task อื่น: layout เดิม (scroll ทั้งหน้า)
              if (_isJudYa) ...[
                // Compact header — ข้อมูล task แบบย่อ (fixed height, ไม่ scroll)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
                  ),
                  child: _buildMedicineCompactHeader(),
                ),
                // Grid ยา + expandable details — ขยายเต็มพื้นที่ที่เหลือ
                Expanded(
                  child: _buildMedicineContent(),
                ),
              ] else
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildDefaultLayout(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      // Action buttons
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  /// Content area สำหรับงานจัดยา — ใช้ LayoutBuilder เพื่อรู้พื้นที่จริง
  /// แล้วคำนวณ aspect ratio ให้ grid ยาขยายเต็มพื้นที่ที่เหลือ
  Widget _buildMedicineContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // constraints.maxHeight = พื้นที่จริงที่เหลือหลังหัก AppBar + compact header
        // หักเฉพาะ element ใน scroll area: title ~32, gap 8, expandToggle ~48, gap 16
        const otherElementsHeight = 104.0;
        final gridAvailableHeight = constraints.maxHeight - otherElementsHeight;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSpacing.verticalGapSm,

              // Medicine grid — ขยายเต็มพื้นที่ที่เหลือ
              _buildMedicineGrid(gridAvailableHeight),
              AppSpacing.verticalGapMd,

              // ข้อมูลเพิ่มเติม (ซ่อนไว้ default — กดเปิดดูได้)
              _buildMedicineExpandableDetails(),

              // Co-worker picker (แสดงเฉพาะ task ที่ยังไม่ done)
              if (!_task.isDone) ...[
                AppSpacing.verticalGapMd,
                CoWorkerPickerSection(
                  initialSelection: _selectedCoWorkers,
                  onChanged: (coWorkers) {
                    _selectedCoWorkers = coWorkers;
                  },
                ),
              ],

              // Bottom padding for action buttons
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  /// Layout เดิมสำหรับ task ทั่วไป (ไม่ใช่จัดยา) — ไม่เปลี่ยนแปลง
  List<Widget> _buildDefaultLayout() {
    return [
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

      // Form URL (ถ้ามี) - ลิงก์เปิดแบบฟอร์มภายในแอป
      if (_task.formUrl != null &&
          _task.formUrl!.isNotEmpty) ...[
        _buildFormUrlSection(),
        AppSpacing.verticalGapMd,
      ],

      // Resident info (ถ้ามี)
      if (_task.residentId != null && _task.residentId! > 0) ...[
        _buildResidentCard(),
        AppSpacing.verticalGapMd,
      ],

      // Sample image
      if (_task.hasSampleImage)
        _buildSampleImage(),

      // Confirm image (ถ้ามี)
      if (_task.confirmImage != null ||
          _uploadedImageUrl != null) ...[
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

      // Assessment inline section (ประเมินสุขภาพ เช่น ทานอาหารกี่ %)
      // แสดงเมื่อ taskType มี subjects กำหนดไว้ และ task ยังไม่ done
      if (_assessmentSubjects.isNotEmpty && !_task.isDone) ...[
        SizedBox(height: AppSpacing.lg),
        AssessmentInlineSection(
          subjects: _assessmentSubjects,
          onChanged: (ratings) => _assessmentRatings = ratings,
          onCompletionChanged: (complete) {
            if (complete != _assessmentComplete) {
              setState(() => _assessmentComplete = complete);
            }
          },
        ),
        AppSpacing.verticalGapMd,
      ],

      // Measurement input section (ชั่งน้ำหนัก/วัดส่วนสูง/DTX/Insulin)
      // อยู่ล่างสุดก่อน co-worker picker — ใกล้ปุ่ม action เพื่อ UX ที่ดี
      if (_measurementConfig != null && !_task.isDone) ...[
        MeasurementInputSection(
          config: _measurementConfig!,
          controller: _measurementController,
          taskLogId: _task.logId,
          isCompleted: _task.isDone,
          initialPhotoUrl: _measurementPhotoUrl,
          onValueChanged: (text) {
            final parsed = double.tryParse(text.trim());
            final hasValue = parsed != null && parsed > 0;
            if (hasValue != _hasMeasurementValue) {
              setState(() => _hasMeasurementValue = hasValue);
            }
          },
          onPhotoChanged: (url) {
            _measurementPhotoUrl = url;
          },
        ),
        AppSpacing.verticalGapMd,
      ],

      // Note input section (หมายเหตุเพิ่มเติม, optional)
      // ใช้สำหรับอธิบายว่าเกิดอะไรขึ้นระหว่างทำงาน — เช่น ทำไม่ตรง instruction
      // จะถูกบันทึกลง Descript เมื่อกด "เสร็จแล้ว" (ถ้ามีข้อความ)
      // กรณีกด "ติดปัญหา" → ใช้ description จาก ProblemInputSheet แทน
      if (!_task.isDone) ...[
        AppSpacing.verticalGapMd,
        _buildNoteSection(),
      ],

      // Co-worker picker (แสดงเฉพาะ task ที่ยังไม่ done — ให้เลือกเพื่อนร่วมเวรเพื่อหาร point)
      if (!_task.isDone) ...[
        AppSpacing.verticalGapMd,
        CoWorkerPickerSection(
          initialSelection: _selectedCoWorkers,
          onChanged: (coWorkers) {
            _selectedCoWorkers = coWorkers;
          },
        ),
      ],

      // Bottom padding for action buttons
      const SizedBox(height: 100),
    ];
  }

  Widget _buildAppBar() {
    // Title 2 บรรทัด: บรรทัดบน = wayfinding context (เวลา · resident · zone)
    //                  บรรทัดล่าง = static "รายละเอียดงาน"
    // ช่วย user ที่เปิดหลาย task แยกได้ทันทีว่าอยู่หน้าไหน
    final time = _task.expectedDateTime != null
        ? DateFormat('HH:mm').format(_task.expectedDateTime!.toLocal())
        : null;
    final contextParts = <String>[
      if (time != null) '$time น.',
      if (_task.residentName != null) _task.residentName!,
    ];
    final contextLine = contextParts.join(' · ');

    // แสดงปุ่ม ⋯ options ใน AppBar เมื่อ task ยัง active
    // (task ที่ isDone/isProblem/isPostponed/isReferred จะแสดงปุ่ม cancel แทน → ไม่ต้องมี options)
    final showOptions = !(_task.isDone ||
        _task.isProblem ||
        _task.isPostponed ||
        _task.isReferred);

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
            tooltip: 'ย้อนกลับ',
            icon: Semantics(
              label: 'ย้อนกลับ',
              button: true,
              child: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (contextLine.isNotEmpty)
                  Text(
                    contextLine,
                    style: AppTypography.title.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  'รายละเอียดงาน',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          _buildStatusBadge(),
          // Options menu (⋯) — ย้ายมาจาก bottom action row เพื่อเปิดพื้นที่ให้ primary action
          if (showOptions)
            IconButton(
              onPressed: () => setState(() => _isOptionOpen = true),
              tooltip: 'ตัวเลือกเพิ่มเติม',
              icon: Semantics(
                label: 'ตัวเลือกเพิ่มเติม เช่น แจ้งติดปัญหา ไม่อยู่ศูนย์',
                button: true,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedMoreHorizontal,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
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

  /// Banner บอกว่ามีอัพเดตที่ user ยังไม่เห็น — ใช้แดงพาสเทล match กับ task card
  /// UX: วาง full-width ด้านบนสุด + icon refresh + ข้อความชัดเจน
  /// ไม่ใช้ "จ้า" (casual เกินไปสำหรับ clinical context)
  Widget _buildUnseenBadge() {
    return Semantics(
      label: 'งานนี้มีข้อมูลอัพเดตใหม่ที่คุณยังไม่เห็น',
      container: true,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: AppSpacing.sm),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.pastelRed,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 16,
              color: Colors.white,
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              'มีอัพเดตใหม่',
              style: AppTypography.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
        // Expected time — ตัวแรก + emphasis เพราะสำคัญสุดใน clinical workflow
        if (_task.expectedDateTime != null)
          _buildBadge(
            icon: HugeIcons.strokeRoundedClock01,
            text: DateFormat('HH:mm').format(_task.expectedDateTime!.toLocal()),
            color: AppColors.tagPendingText,
            emphasis: true,
          ),

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

        // Time block
        if (_task.timeBlock != null)
          _buildBadge(
            icon: HugeIcons.strokeRoundedTimer01,
            text: _task.timeBlock!,
            color: AppColors.secondaryText,
          ),

        // Completed by — แสดงเฉพาะกรณีเสร็จแล้วแบบพิเศษ (problem/postpone/refer)
        // ถ้า isDone ปกติ → ซ้ำกับ StatusBadge "เสร็จแล้ว" ใน AppBar แล้ว
        if (_task.completedByNickname != null &&
            _task.completedAt != null &&
            !_task.isDone)
          _buildBadge(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            text:
                '${_task.completedByNickname} (${DateFormat('HH:mm').format(_task.completedAt!.toLocal())})',
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
        AppToast.error(context,
            'ไม่สามารถอัพเดตคะแนนได้ (DIFFICULTY_UPDATE_ERR)');
      }
    }
  }

  /// InfoBadge — [emphasis] ใช้กับ badge ที่มี visual priority สูง (เช่น เวลา)
  /// Emphasis mode: bg เข้มขึ้น, font ใหญ่ขึ้น, w700 — เตะตาในกลุ่ม badge อื่น
  Widget _buildBadge({
    required dynamic icon,
    required String text,
    required Color color,
    bool emphasis = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: emphasis ? 12 : 10,
        vertical: emphasis ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasis ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            size: emphasis ? AppIconSize.md : AppIconSize.sm,
            color: color,
          ),
          SizedBox(width: emphasis ? 6 : 4),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
              fontSize: emphasis ? 14 : null,
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

  /// Card สำหรับเปิดแบบฟอร์ม (Google Form หรือเว็บอื่นๆ)
  /// กดแล้วจะเปิด WebView ภายในแอป ไม่ต้องออกไป browser ภายนอก
  Widget _buildFormUrlSection() {
    // ดึง domain จาก URL มาแสดงเป็น subtitle เช่น "forms.google.com"
    String displayUrl = _task.formUrl!;
    try {
      final uri = Uri.parse(displayUrl);
      displayUrl = uri.host; // เอาแค่ domain เช่น forms.google.com
    } catch (_) {
      // ถ้า parse ไม่ได้ ใช้ URL เต็ม
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // เปิด WebView ภายในแอป (Android/iOS) หรือ browser ภายนอก (Windows)
          WebViewScreen.openUrl(
            context,
            url: _task.formUrl!,
            title: 'แบบฟอร์ม',
          );
        },
        child: Container(
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            // พื้นหลัง teal อ่อนมากๆ ให้โดดเด่นกว่า card ปกติ
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            // ขอบสี primary ให้เห็นชัดว่ากดได้
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // ไอคอนแบบฟอร์ม
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent1, // พื้นหลัง teal อ่อน
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedNote,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),
              AppSpacing.horizontalGapMd,
              // ข้อความ "เปิดแบบฟอร์ม" + domain URL
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เปิดแบบฟอร์ม',
                      style: AppTypography.subtitle.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      displayUrl,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // ลูกศรชี้ขวา บอกว่ากดได้
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 20,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
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

  /// Compact header สำหรับงานจัดยา — แสดงแค่ title + ชื่อผู้สูงอายุ + ห้อง
  /// เพื่อให้ user เห็นรูปยาทั้งหมดทันทีโดยไม่ต้อง scroll ผ่าน section อื่น
  Widget _buildMedicineCompactHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title (เช่น "จัดยาเช้า (ก่อนอาหาร)")
        Text(
          _task.title ?? 'ไม่ระบุชื่องาน',
          style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // ชื่อผู้สูงอายุ + ห้อง (ถ้ามี)
        if (_task.residentId != null && _task.residentId! > 0)
          Row(
            children: [
              // Avatar เล็ก (radius 12 = 24px diameter)
              IreneNetworkAvatar(
                imageUrl: _task.residentPictureUrl,
                radius: 12,
                backgroundColor: AppColors.accent1,
                fallbackIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedUser,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  // รวมชื่อ + ห้อง เป็นบรรทัดเดียว
                  [
                    _task.residentName ?? 'ไม่ระบุ',
                    if (_task.zoneName != null) _task.zoneName!,
                  ].join(' · '),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Expandable section สำหรับข้อมูลเพิ่มเติมในหน้าจัดยา
  /// ซ่อนไว้ default เพื่อให้รูปยาอยู่ใกล้หัวจอมากที่สุด
  Widget _buildMedicineExpandableDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle button — กดเพื่อเปิด/ปิดข้อมูลเพิ่มเติม
        GestureDetector(
          onTap: () => setState(() => _isDetailExpanded = !_isDetailExpanded),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: _isDetailExpanded
                      ? HugeIcons.strokeRoundedArrowUp01
                      : HugeIcons.strokeRoundedArrowDown01,
                  size: AppIconSize.sm,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 6),
                Text(
                  _isDetailExpanded ? 'ซ่อนข้อมูลเพิ่มเติม' : 'ดูข้อมูลเพิ่มเติม',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // เนื้อหาที่ซ่อนไว้ — แสดงเมื่อกดเปิด
        if (_isDetailExpanded) ...[
          AppSpacing.verticalGapMd,

          // Creator info
          if (_task.creatorNickname != null) ...[
            _buildCreatorInfo(),
            AppSpacing.verticalGapSm,
          ],

          // Info badges (time, type, zone, completed by)
          _buildInfoBadges(),

          // Difficulty score badge
          if (_shouldShowDifficultyBadge) ...[
            AppSpacing.verticalGapSm,
            _buildDifficultyBadge(_task.difficultyScore!),
          ],
          AppSpacing.verticalGapMd,

          // RecurNote (ถ้ามี)
          if (_task.recurNote != null && _task.recurNote!.isNotEmpty) ...[
            _buildRecurNote(),
            AppSpacing.verticalGapMd,
          ],

          // Description
          if (_task.description != null &&
              _task.description!.isNotEmpty) ...[
            _buildDescriptionSection(),
            AppSpacing.verticalGapMd,
          ],

          // Form URL
          if (_task.formUrl != null && _task.formUrl!.isNotEmpty) ...[
            _buildFormUrlSection(),
            AppSpacing.verticalGapMd,
          ],

          // Resident card (full version พร้อมโรคประจำตัว)
          if (_task.residentId != null && _task.residentId! > 0) ...[
            _buildResidentCard(),
            AppSpacing.verticalGapMd,
          ],

          // Confirm video (ถ้ามี)
          if (_task.hasConfirmVideo) ...[
            _buildConfirmVideo(),
            AppSpacing.verticalGapMd,
          ],

          // Post images
          if (_task.hasPostImages) ...[
            _buildPostImages(),
            AppSpacing.verticalGapMd,
          ],

          // Post video
          if (_task.hasPostVideo) ...[
            _buildPostVideo(),
            AppSpacing.verticalGapMd,
          ],

          // Problem notes
          if ((_task.descript != null && _task.descript!.isNotEmpty) ||
              _task.problemType != null) ...[
            _buildDescriptNote(),
            AppSpacing.verticalGapMd,
          ],

          // Postpone info
          if (_task.postponeFrom != null) ...[
            _buildPostponeInfo(),
          ],
        ],
      ],
    );
  }

  /// คำนวณ childAspectRatio แบบ dynamic ให้ยาทุกตัวอยู่ในจอเดียว
  /// [gridAvailableHeight] = ความสูงที่ grid ใช้ได้จริง (LayoutBuilder หักส่วนอื่นแล้ว)
  /// [gridWidth] = ความกว้างของ grid (เต็มจอ หรือ ครึ่งจอ ถ้า side-by-side)
  /// [columns] = จำนวน column ของ grid
  double _calcMedicineAspectRatio(
    double gridAvailableHeight,
    double gridWidth,
    int columns,
  ) {
    if (_medicines == null || _medicines!.isEmpty) return 1.0;

    // จำนวนแถวของ grid
    final rows = (_medicines!.length / columns).ceil();
    if (rows <= 0) return 1.0;

    // คำนวณ: itemWidth / idealItemHeight
    final itemWidth = gridWidth / columns;
    final idealItemHeight = gridAvailableHeight / rows;

    // clamp โดยใช้ minimum item height เป็นตัวกำหนดขอบเขต:
    // - min 0.5 = ยาน้อย ไม่ให้สูงเกินไป (สูงกว่ากว้าง 2x)
    // - max = itemWidth / 50 = ความสูงขั้นต่ำ 50px (ยาเยอะก็ยังเห็นรูปได้)
    const minItemHeight = 50.0;
    final maxAspectRatio = itemWidth / minItemHeight;
    return (itemWidth / idealItemHeight).clamp(0.5, maxAspectRatio);
  }

  /// [gridAvailableHeight] = ความสูงที่ grid ใช้ได้ (จาก LayoutBuilder หักส่วนอื่นแล้ว)
  Widget _buildMedicineGrid(double gridAvailableHeight) {
    if (_isLoadingMedicines) {
      return ShimmerWrapper(
        isLoading: true,
        child: Column(
          children: List.generate(2, (_) => const SkeletonCard()),
        ),
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

    // ความกว้างของ content area (หัก padding ซ้าย-ขวา)
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = screenWidth - (AppSpacing.md * 2);

    // ถ้ามีรูปยืนยัน → แสดง side-by-side (grid ซ้าย, รูปขวา)
    // ถ้ายังไม่มีรูป → แสดงแค่ grid ยา (ปุ่มถ่ายอยู่ด้านล่างเหมือนเดิม)
    if (hasImage) {
      // side-by-side: grid ใช้ครึ่งจอ (Expanded ใน Row)
      final gridWidth = contentWidth / 2;
      final aspectRatio = _calcMedicineAspectRatio(
        gridAvailableHeight, gridWidth, 2,
      );

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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 0, // no spacing
                    mainAxisSpacing: 0, // no spacing
                    childAspectRatio: aspectRatio, // dynamic ตามจำนวนยา
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

    // ยังไม่มีรูปยืนยัน → แสดงแค่ grid ยา เต็มจอ
    final aspectRatio = _calcMedicineAspectRatio(
      gridAvailableHeight, contentWidth, 2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รายการยา (${_medicines!.length} รายการ)',
          style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.w600),
        ),
        AppSpacing.verticalGapSm,
        // Grid รูปตัวอย่างยา (2 คอลัมน์, no spacing, dynamic aspect ratio)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 0, // no spacing
            mainAxisSpacing: 0, // no spacing
            childAspectRatio: aspectRatio, // dynamic ตามจำนวนยา
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
        // รูปตัวอย่าง - บังคับ 1:1 เพื่อความสม่ำเสมอของ layout
        Center(
          child: GestureDetector(
            onTap: () => _showExpandedImage(_task.sampleImageUrl!),
            child: AspectRatio(
              aspectRatio: 1, // 1:1 สี่เหลี่ยมจัตุรัส
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: IreneNetworkImage(
                  imageUrl: _task.sampleImageUrl!,
                  fit: BoxFit.cover, // cover เพื่อเติมเต็มพื้นที่ 1:1
                  memCacheWidth: 800,
                ),
              ),
            ),
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
                  // Avatar ผู้สร้างสรรค์ — แสดง shimmer skeleton ขณะ enrich ยังไม่เสร็จ
                  // (view ส่ง nickname/photo_url เป็น NULL เพื่อ performance ของ list view
                  // แล้ว _enrichSampleImageCreator ค่อย fetch มา set — ระหว่างนั้นโชว์ skeleton)
                  child: _task.sampleImageCreatorNickname == null
                      ? const ShimmerWrapper(
                          isLoading: true,
                          child: ShimmerBox.circle(size: 36),
                        )
                      : IreneNetworkAvatar(
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
                      // Nickname — ถ้ายัง enrich ไม่เสร็จ โชว์ skeleton bar แทน "ไม่ระบุ"
                      // (กัน flash "ไม่ระบุ" ชั่ววินาทีก่อน data มา → สับสน)
                      if (_task.sampleImageCreatorNickname == null)
                        const ShimmerWrapper(
                          isLoading: true,
                          child: ShimmerBox(width: 120, height: 18),
                        )
                      else
                        Text(
                          _task.sampleImageCreatorNickname!,
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
    // เพิ่มเงื่อนไข: ซ่อนปุ่มถ้า confirm image ตรงกับ sample image แล้ว
    // (หมายความว่าเคยกดแทนที่แล้ว — ปุ่มจะหายไปทันทีหลัง optimistic update)
    final canReplaceSample = !_isJudYa &&
        systemRole != null &&
        systemRole.canQC &&
        _task.isDone &&
        _task.confirmImage != null &&
        _task.taskRepeatId != null &&
        _task.confirmImage != _task.sampleImageUrl;

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
        // รูปยืนยัน - บังคับ 1:1 ให้ตรงกับรูปตัวอย่าง
        Center(
          child: GestureDetector(
            onTap: () => _showExpandedImage(imageUrl),
            child: AspectRatio(
              aspectRatio: 1, // 1:1 สี่เหลี่ยมจัตุรัส
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: IreneNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover, // cover เพื่อเติมเต็มพื้นที่ 1:1
                  memCacheWidth: 800,
                ),
              ),
            ),
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
        // ถ้ามี 1 รูป แสดง 1:1 เต็มความกว้าง
        if (images.length == 1)
          GestureDetector(
            onTap: () => _showExpandedImage(images.first),
            child: AspectRatio(
              aspectRatio: 1, // 1:1 สี่เหลี่ยมจัตุรัส
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: IreneNetworkImage(
                  imageUrl: images.first,
                  fit: BoxFit.cover, // cover เพื่อเติมเต็ม 1:1
                  memCacheWidth: 800,
                ),
              ),
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

  /// Inline section สำหรับพิมพ์หมายเหตุเพิ่มเติม (optional)
  /// user กรอกได้ตลอดก่อนกด "เสร็จแล้ว" / "ติดปัญหา"
  /// กด "เสร็จแล้ว" → save ลง Descript (ถ้ามีข้อความ)
  /// กด "ติดปัญหา" → ProblemInputSheet จัดการ description ของตัวเอง (ช่องนี้ไม่ถูกใช้)
  Widget _buildNoteSection() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedNote,
                color: AppColors.secondaryText,
                size: AppIconSize.md,
              ),
              AppSpacing.horizontalGapSm,
              Text(
                'หมายเหตุเพิ่มเติม',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppSpacing.horizontalGapXs,
              Text(
                '(ไม่บังคับ)',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapSm,
          // Note field + MicButton มุมขวาบน
          Stack(
            children: [
              AppTextField(
                controller: _noteController,
                hintText: 'เช่น ทำไม่ครบตาม instruction เพราะ...',
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                fillColor: AppColors.background,
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Consumer(
                  builder: (context, ref, _) {
                    final nhId =
                        ref.watch(nursinghomeIdProvider).valueOrNull;
                    return MicButton(
                      controller: _noteController,
                      context: SttContext.post,
                      nursinghomeId: nhId,
                      residentId: _task.residentId,
                      size: 32,
                    );
                  },
                ),
              ),
            ],
          ),
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
        child: _task.isDone ||
                _task.isPostponed ||
                _task.isReferred ||
                _task.isProblem
            // task ที่ทำแล้ว → แสดงปุ่มยกเลิก (enabled ถ้ามีสิทธิ์, disabled ถ้าไม่มี)
            ? _buildCancelButton(enabled: _canCancelTask)
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
        // UX: ย่อรูป peep2 100→56px + padding เล็กลง — เหลือพื้นที่ให้ปุ่มหลักเห็นชัด
        if (_showCompleteButton && _hasConfirmImage)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  // รูปแอบมอง — ย่อจาก 100 เหลือ 56 ไม่บังพื้นที่
                  Image.asset(
                    'assets/images/peep2.webp',
                    width: 56,
                    height: 56,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ตรวจสอบความถูกต้องก่อนส่งรายงาน',
                          style: AppTypography.body.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'รูป ชื่อผู้ทำ และเวลา จะถูกส่งไปไลน์กลุ่มญาติ',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.error.withValues(alpha: 0.85),
                            height: 1.3,
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
        // Options button (⋯) ย้ายไป AppBar แล้ว — ให้ primary action ใช้พื้นที่เต็ม
        Row(
          children: [
            // Camera button (ถ้าต้องถ่ายรูป - สำหรับงานปกติ)
            if (_showCameraButton)
              Expanded(
                child: SizedBox(
                  height: 56,
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
            // ใช้ secondary (ฟ้า) แยกจาก primary — บอกว่าเป็นขั้นตอนก่อน post
            if (_showCameraForPostButton)
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleTakePhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
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
            // ถ้าเป็น measurement task → disabled ถ้ายังไม่กรอกค่า + เปลี่ยน label
            if (_showCompleteButton)
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : (_measurementConfig != null && !_hasMeasurementValue)
                            ? null // disabled ถ้ายังไม่กรอกค่า measurement
                            : (_assessmentSubjects.isNotEmpty &&
                                    !_assessmentComplete)
                                ? null // disabled ถ้ายังประเมินไม่ครบ
                                : _handleComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primaryDisabled,
                      disabledForegroundColor: Colors.white70,
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
                        : HugeIcon(
                            icon: _measurementConfig != null
                                ? HugeIcons.strokeRoundedFloppyDisk
                                : HugeIcons.strokeRoundedCheckmarkCircle02,
                          ),
                    label: Text(
                      // แสดงข้อความตามสถานะ: ยังประเมินไม่ครบ / ยังไม่กรอกค่า / พร้อม
                      (_assessmentSubjects.isNotEmpty && !_assessmentComplete)
                          ? 'ประเมินให้ครบก่อน'
                          : _measurementConfig != null
                              ? 'บันทึก${_measurementConfig!.label}'
                              : 'เรียบร้อย',
                      style: AppTypography.button,
                    ),
                  ),
                ),
              ),

            // Complete by post button (สำหรับ task ที่ต้องสำเร็จด้วยโพส)
            // ใช้ primary (teal) เหมือนปุ่มเรียบร้อย — เป็น action จบงาน
            if (_showCompleteByPostButton)
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleCompleteByPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
              width: 56,
              height: 56,
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
                height: 56,
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
          height: 56,
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

  Widget _buildCancelButton({bool enabled = true}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DangerOutlinedButton(
          text: 'ยกเลิกการรับทราบ',
          icon: HugeIcons.strokeRoundedCancelCircle,
          isDisabled: !enabled,
          isLoading: _isLoading,
          onPressed: _handleCancel,
          width: double.infinity,
        ),
        // แสดงเหตุผลว่าทำไมกดไม่ได้ — ช่วยให้ user เข้าใจ permission
        if (!enabled)
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'เฉพาะคนที่ทำ หรือหัวหน้าเวรขึ้นไป จึงยกเลิกได้',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ),
      ],
    );
  }

  // Action handlers
  Future<void> _handleComplete() async {
    // Guard double-tap — set _isLoading ทันทีก่อนเปิด dialog
    // (แก้ bug: เดิม set หลัง dialog return ทำให้กดซ้ำได้ระหว่าง dialog เปิด)
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final service = ref.read(taskServiceProvider);
    final userId = ref.read(currentUserIdProvider);
    final userNickname = ref.read(currentUserNicknameProvider).valueOrNull;

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // === ดึงค่า measurement จาก inline section (ถ้าเป็น measurement task) ===
    // ค่ามาจาก _measurementController ที่ user กรอกไว้ก่อนกด complete
    final measurementConfig = _measurementConfig;
    MeasurementResult? measurementResult;

    if (measurementConfig != null) {
      final text = _measurementController.text.trim();
      final value = double.tryParse(text);
      if (value == null || value <= 0) {
        // ไม่ควรเกิด เพราะปุ่ม disabled ถ้ายังไม่กรอก — แต่ guard ไว้
        AppToast.warning(context, 'กรุณากรอกค่า${measurementConfig.label}');
        setState(() => _isLoading = false);
        return;
      }
      measurementResult = MeasurementResult(
        value: value,
        photoUrl: _measurementPhotoUrl,
      );
    }

    // === แสดง Dialog ให้ประเมินความยากของงาน ===
    // ถ้า user ปิด dialog (กด back) จะได้ null → ยกเลิก completion
    // initialScore ใช้ clinicalWeight จากแพทย์เป็น default ของ slider
    final difficultyResult = await DifficultyRatingDialog.show(
      context,
      taskTitle: _task.title,
      allowSkip: false, // ต้องให้คะแนนทุกครั้ง
      avgScore: _task.avgDifficultyScore30d, // ค่าเฉลี่ยย้อนหลัง 30 วัน (แสดงให้ดูเฉยๆ)
      initialScore: _task.clinicalWeight, // ค่าจากแพทย์เป็น default slider
    );

    // ถ้า user ปิด dialog โดยไม่ทำอะไร → ยกเลิก
    if (difficultyResult == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!mounted) return;

    // คะแนนความยากที่ user ให้ (null = ข้าม → ใช้ default 5)
    final difficultyScore = difficultyResult.score;

    // หมายเหตุเพิ่มเติม (optional) จาก inline note section ในหน้า task detail
    // ถ้า user ไม่กรอกจะเป็น null และจะไม่ถูก update ลง DB
    final noteText = _noteController.text.trim();
    final completionNote = noteText.isEmpty ? null : noteText;

    // === Assessment Rating (ประเมินสุขภาพ resident) ===
    // ใช้ _assessmentRatings จาก inline section ที่ user กรอกไว้แล้ว (ไม่มี dialog)
    final assessmentRatings =
        _assessmentRatings.isNotEmpty ? _assessmentRatings : null;

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
      difficultyScore: difficultyScore, // ต้องมีค่าเสมอ (ไม่มีปุ่มข้าม)
      difficultyRatedBy: userId,
      difficultyRaterNickname: userNickname,
      // รวม note ลง optimistic state เพื่อให้ UI แสดงทันที (ถ้ามี)
      descript: completionNote,
    );

    // อัพเดต local state ทันที (_isLoading ถูก set true แล้วตั้งแต่ต้น method)
    setState(() {
      _task = optimisticTask;
    });

    // อัพเดต provider เพื่อให้ checklist screen เห็นผลทันที
    final rollback = optimisticUpdateTask(ref, optimisticTask);

    // === Capture assessment data ก่อน async operations ===
    final capturedAssessmentRatings = assessmentRatings;

    // === เรียก Server ===
    // ถ้ามีเพื่อนร่วมเวร → ข้าม points recording ปกติ แล้วจัดการหาร points แยก
    // ⚠️ Capture ไว้ก่อน เพราะ realtime อาจ reset _selectedCoWorkers = []
    // หลัง markTaskComplete สำเร็จ (task.isDone → clear coworkers)
    final capturedCoWorkers = List<CoWorker>.of(_selectedCoWorkers);
    final hasCoWorkers = capturedCoWorkers.isNotEmpty;
    final completeResult = await service.markTaskComplete(
      capturedLogId,
      userId,
      imageUrl: capturedImageUrl,
      difficultyScore: difficultyScore, // null = ใช้ default ใน database
      difficultyRatedBy: userId,
      skipPointsRecording: hasCoWorkers,
      description: completionNote, // หมายเหตุเพิ่มเติม (optional)
    );

    if (completeResult.success) {
      // === หาร Points กับเพื่อนร่วมเวร (ถ้าเลือกไว้) ===
      // ถ้า recordBatchTaskCompleted fail ก็ไม่ rollback task completion
      // เพราะงานเสร็จจริง แค่ points ยังไม่ได้บันทึก (สามารถ retry ได้ภายหลัง)
      if (hasCoWorkers) {
        try {
          await PointsService().recordBatchTaskCompleted(
            completingUserId: userId,
            taskLogId: capturedLogId,
            taskName: capturedTitle ?? 'งาน',
            residentName: _task.residentName ?? '',
            coWorkerIds: capturedCoWorkers.map((c) => c.userId).toList(),
            difficultyScore: difficultyScore,
          );
        } catch (e) {
          // เก็บใน retry queue แล้ว sync ทีหลัง (ไม่หายเงียบ)
          debugPrint('⚠️ Batch points recording failed, queuing: $e');
          await RetryQueueService.instance.enqueueBatchPoints(
            completingUserId: userId,
            taskLogId: capturedLogId,
            taskName: capturedTitle ?? 'งาน',
            residentName: _task.residentName ?? '',
            coWorkerIds: capturedCoWorkers.map((c) => c.userId).toList(),
            difficultyScore: difficultyScore,
          );
        }
      }

      // === บันทึกผลประเมินสุขภาพ (ถ้ามี) ===
      // ไม่ block flow — ถ้า save fail task ยังเสร็จจริง
      if (capturedAssessmentRatings != null &&
          capturedAssessmentRatings.isNotEmpty &&
          capturedResidentId != null) {
        try {
          await AssessmentService.instance.saveRatings(
            taskLogId: capturedLogId,
            residentId: capturedResidentId,
            ratings: capturedAssessmentRatings,
          );
        } catch (e) {
          // เก็บใน retry queue แล้ว sync ทีหลัง (ไม่หายเงียบ)
          debugPrint('⚠️ Assessment ratings save failed, queuing: $e');
          await RetryQueueService.instance.enqueueAssessmentRatings(
            taskLogId: capturedLogId,
            residentId: capturedResidentId,
            ratings: capturedAssessmentRatings,
          );
        }
      }

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

      // === บันทึกค่า measurement (ถ้าเป็น measurement task) ===
      // Insert เข้า resident_measurements หลัง markTaskComplete สำเร็จ
      // ถ้า insert fail → revert task กลับ pending + แจ้ง error
      if (measurementResult != null &&
          measurementConfig != null &&
          capturedResidentId != null) {
        final nursinghomeId =
            await ref.read(nursinghomeIdProvider.future) ?? 0;
        final measurementSuccess =
            await MeasurementService.instance.insertMeasurement(
          residentId: capturedResidentId,
          nursinghomeId: nursinghomeId,
          recordedBy: userId,
          measurementType: measurementConfig.measurementType,
          numericValue: measurementResult.value,
          unit: measurementConfig.unit,
          taskLogId: capturedLogId,
          photoUrl: measurementResult.photoUrl,
        );

        if (!measurementSuccess) {
          // Measurement insert ล้มเหลว — revert task กลับ pending บน server ด้วย
          // เพราะ task ถูก mark complete ไปแล้ว (line 2539)
          // ถ้าไม่ revert → Realtime จะ push complete กลับมาทำให้ UI ไม่ตรง
          await service.unmarkTask(capturedLogId);
          rollback();
          setState(() {
            _task = widget.task;
            _isLoading = false;
          });
          if (mounted) {
            AppToast.error(context,
                'ไม่สามารถบันทึกค่า${measurementConfig.label}ได้ (MEASUREMENT_SAVE_ERR)');
          }
          return;
        }
      }

      // === Optimistic Update Strategy ===
      // ไม่ต้อง commitOptimisticUpdate หรือ refreshTasks ก่อน pop
      // เพื่อให้ ChecklistScreen เห็น optimistic state ทันที
      // Realtime event จะมา trigger refresh และ clear optimistic state ภายหลัง
      if (mounted) Navigator.pop(context);
    } else {
      // Rollback ถ้า server error — แสดง error code ให้ user cap ส่งมาได้
      rollback();
      setState(() {
        _task = widget.task; // กลับไปใช้ task เดิม
        _isLoading = false;
      });
      if (mounted) {
        AppToast.error(context, completeResult.userMessage);
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
        AppToast.error(
            context, 'ไม่สามารถแจ้งปัญหาได้ กรุณาลองใหม่ (PROBLEM_SAVE_FAIL)');
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
        AppToast.error(
            context, 'ไม่สามารถบันทึก Refer ได้ กรุณาลองใหม่ (REFER_SAVE_FAIL)');
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
      cancelText: 'เก็บไว้',
      confirmText: 'ยกเลิกรับทราบ',
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
        AppToast.error(context,
            'ไม่สามารถยกเลิกได้ กรุณาลองใหม่ (CANCEL_SAVE_FAIL)');
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

    // === iOS crash prevention: ปล่อย memory ก่อนเปิดกล้อง ===
    // Clear image cache เพื่อปล่อย decoded images ออกจาก memory
    // กล้อง iOS ใช้ memory สูง ถ้า cache รูปเยอะจะ crash (OOM kill)
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // ลด cache limit ชั่วคราวเป็น 0 ระหว่างเปิดกล้อง
    final savedMaxSize = PaintingBinding.instance.imageCache.maximumSize;
    final savedMaxBytes = PaintingBinding.instance.imageCache.maximumSizeBytes;
    PaintingBinding.instance.imageCache.maximumSize = 0;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 0;

    File? file;

    // ถ้า task มีรูปตัวอย่าง → เปิดกล้อง split-screen เพื่อถ่ายเทียบรูป
    if (_task.hasSampleImage) {
      file = await SplitScreenCameraScreen.show(
        context: context,
        sampleImageUrl: _task.sampleImageUrl!,
      );
    } else {
      // ใช้กล้อง 1:1 ของเรา — user เห็น preview เป็น 1:1 ตั้งแต่ตอนถ่าย
      file = await SquareCameraScreen.show(context: context);
    }

    // ยังไม่คืน cache limits — รอจน PhotoPreviewScreen ปิดก่อน
    // เพราะ preview ยังต้อง decode รูปอยู่ ถ้าคืน cache ตอนนี้จะกิน memory เพิ่ม

    if (file == null) {
      // คืนค่า cache limits เมื่อไม่ได้ถ่ายรูป
      PaintingBinding.instance.imageCache.maximumSize = savedMaxSize;
      PaintingBinding.instance.imageCache.maximumSizeBytes = savedMaxBytes;
      return;
    }

    // แสดงหน้า Preview ให้หมุนรูปได้
    if (!mounted) {
      PaintingBinding.instance.imageCache.maximumSize = savedMaxSize;
      PaintingBinding.instance.imageCache.maximumSizeBytes = savedMaxBytes;
      return;
    }

    // ใช้ try/finally เพื่อ guarantee ว่า cache limits จะถูกคืนเสมอ
    // แม้ PhotoPreviewScreen จะ throw exception
    File? confirmedFile;
    try {
      confirmedFile = await PhotoPreviewScreen.show(
        context: context,
        imageFile: file,
        photoType: 'task',
        mealLabel: _task.title ?? 'งาน',
        // ถ้ามีรูปตัวอย่าง → แสดงเทียบในหน้า preview ด้วย
        sampleImageUrl:
            _task.hasSampleImage ? _task.sampleImageUrl : null,
      );
    } finally {
      // คืนค่า cache limits หลัง preview ปิดแล้ว (ปลอดภัยแล้ว)
      // ต้องอยู่ใน finally เพื่อคืนแม้เกิด error
      PaintingBinding.instance.imageCache.maximumSize = savedMaxSize;
      PaintingBinding.instance.imageCache.maximumSizeBytes = savedMaxBytes;
    }

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

      // ลบ temp files หลัง upload สำเร็จ เพื่อคืน storage
      try {
        if (await file.exists()) await file.delete();
        if (confirmedFile.path != file.path && await confirmedFile.exists()) {
          await confirmedFile.delete();
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        final short = '$e'.length > 60 ? '${'$e'.substring(0, 60)}…' : '$e';
        AppToast.error(
            context, 'อัพโหลดรูปไม่สำเร็จ: $short (UPLOAD_ERR)');
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
  Future<void> _handleCompleteByPost() async {
    // === ดึงค่า measurement จาก inline section (ถ้ามี) ===
    // ใช้ค่าที่ user กรอกไว้แล้วใน section แทนเปิด dialog ซ้ำ
    final measConfig = _measurementConfig;
    MeasurementResult? measResult;

    if (measConfig != null) {
      final text = _measurementController.text.trim();
      final value = double.tryParse(text);
      if (value != null && value > 0) {
        measResult = MeasurementResult(
          value: value,
          photoUrl: _measurementPhotoUrl,
        );
      }
      // ถ้ายังไม่กรอก → ไม่ block flow (measurement เป็น optional สำหรับ post flow)
    }

    // Capture ไว้เพื่อ insert measurement หลัง post สร้างสำเร็จ
    final capturedMeasResult = measResult;
    final capturedMeasConfig = measConfig;
    final capturedResidentId = _task.residentId;
    final capturedLogId = _task.logId;

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
          onPostCreated: () async {
            // เมื่อโพสสำเร็จ task จะถูก complete โดย AdvancedCreatePostScreen แล้ว
            // บันทึก measurement ถ้ามี
            if (capturedMeasResult != null &&
                capturedMeasConfig != null &&
                capturedResidentId != null) {
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId != null && mounted) {
                final nursinghomeId =
                    await ref.read(nursinghomeIdProvider.future) ?? 0;
                if (!mounted) return;
                await MeasurementService.instance.insertMeasurement(
                  residentId: capturedResidentId,
                  nursinghomeId: nursinghomeId,
                  recordedBy: userId,
                  measurementType: capturedMeasConfig.measurementType,
                  numericValue: capturedMeasResult.value,
                  unit: capturedMeasConfig.unit,
                  taskLogId: capturedLogId,
                  photoUrl: capturedMeasResult.photoUrl,
                );
              }
            }
            // กลับไปหน้า checklist
            if (!context.mounted) return;
            Navigator.pop(context);
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
      AppToast.error(context,
          'ไม่มีรูปยืนยันหรือ task repeat id (SAMPLE_REPLACE_NO_DATA)');
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
      // ผู้สร้างสรรค์รูปตัวอย่าง = คนที่ทำ task (completed_by) ไม่ใช่ admin ที่กดปุ่ม
      final completedBy = _task.completedByUid;
      final taskTitle = _task.title ?? 'งาน';
      final logId = _task.logId;

      // Update A_Repeated_Task.sampleImageURL และ sampleImage_creator
      // sampleImage_creator = completed_by (เจ้าของรูป)
      await Supabase.instance.client.from('A_Repeated_Task').update({
        'sampleImageURL': confirmImage,
        'sampleImage_creator': completedBy,
      }).eq('id', taskRepeatId);

      // Optimistic Update — ใส่ชื่อ+รูปของเจ้าของรูป (completed_by) ทันที
      // ไม่ต้องรอ _refreshTaskData ซึ่ง view จะส่ง nickname กลับมาเป็น NULL
      if (mounted) {
        // ดึงข้อมูล user ของเจ้าของรูป (อาจไม่ใช่ admin ที่กดปุ่ม)
        final ownerInfo = completedBy != null
            ? await TaskService.instance.getUserBasicInfo(completedBy)
            : null;
        setState(() {
          _task = _task.copyWith(
            sampleImageUrl: confirmImage,
            sampleImageCreatorId: completedBy,
            sampleImageCreatorNickname:
                _task.completedByNickname ?? ownerInfo?['nickname'],
            sampleImageCreatorPhotoUrl: ownerInfo?['photo_url'],
          );
        });
      }
      // ให้คะแนน + notification แก่เจ้าของรูป (await เพื่อรู้ผลก่อนแจ้ง admin)
      final ownerNickname = _task.completedByNickname ?? 'ผู้ทำงาน';
      if (completedBy != null && completedBy.isNotEmpty) {
        final pointsGiven = await _rewardSampleImageOwner(
          ownerId: completedBy,
          taskLogId: logId,
          taskTitle: taskTitle,
          imageUrl: confirmImage,
        );

        if (mounted) {
          if (pointsGiven > 0) {
            // แจ้ง admin ว่าให้คะแนนสำเร็จ
            AppToast.success(
              context,
              'แทนที่รูปตัวอย่างเรียบร้อย',
              subtitle: '✨ ส่ง +$pointsGiven คะแนนให้ $ownerNickname แล้ว',
            );
          } else {
            // เคยให้คะแนน task นี้แล้ว
            AppToast.info(
              context,
              'แทนที่รูปตัวอย่างเรียบร้อย',
              subtitle: '$ownerNickname เคยได้รับคะแนนจาก task นี้แล้ว',
            );
          }
        }
      } else {
        if (mounted) {
          AppToast.success(context, 'แทนที่รูปตัวอย่างเรียบร้อย');
        }
      }
    } catch (e) {
      debugPrint('Error replacing sample image: $e');
      if (mounted) {
        final short = '$e'.length > 60 ? '${'$e'.substring(0, 60)}…' : '$e';
        AppToast.error(context,
            'แทนที่รูปตัวอย่างไม่สำเร็จ: $short (SAMPLE_REPLACE_ERR)');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// ให้ 100 คะแนน + ส่ง notification แก่เจ้าของรูปที่ถูกเลือกเป็นตัวอย่าง
  /// ป้องกัน duplicate: PointsService เช็ค reference_type + reference_id
  /// คืน points ที่ให้สำเร็จ (100) หรือ 0 ถ้าเคยให้แล้ว / error
  Future<int> _rewardSampleImageOwner({
    required String ownerId,
    required int taskLogId,
    required String taskTitle,
    required String imageUrl,
  }) async {
    try {
      // 1. ให้ 100 คะแนน (มี duplicate check ใน recordSampleImageSelected)
      final pointsAwarded = await PointsService().recordSampleImageSelected(
        userId: ownerId,
        taskLogId: taskLogId,
        taskTitle: taskTitle,
      );

      // ถ้า pointsAwarded = 0 แปลว่าเคยให้แล้ว → ไม่ต้อง insert notification ซ้ำ
      if (pointsAwarded == 0) {
        debugPrint('Sample image reward already given, skip notification');
        return 0;
      }

      // 2. Insert notification ให้เจ้าของรูป
      // trigger pushNotification จะส่ง push อัตโนมัติ
      await Supabase.instance.client.from('notifications').insert({
        'title': '✨ รูปของคุณถูกเลือกเป็นตัวอย่าง!',
        'body':
            'รูปที่คุณถ่ายใน "$taskTitle" ถูกเลือกเป็นรูปตัวอย่าง +100 คะแนน',
        'user_id': ownerId,
        'type': 'task',
        'reference_table': 'A_Task_logs_ver2',
        'reference_id': taskLogId,
        'image_url': imageUrl,
      });

      debugPrint('Sample image reward + notification sent to $ownerId');
      return pointsAwarded;
    } catch (e) {
      debugPrint('Error rewarding sample image owner: $e');
      return 0;
    }
  }
}
