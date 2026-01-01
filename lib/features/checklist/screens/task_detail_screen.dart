import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../medicine/models/medicine_summary.dart';
import '../../medicine/screens/photo_preview_screen.dart';
import '../../medicine/services/camera_service.dart';
import '../../medicine/services/medicine_service.dart';
import '../../medicine/widgets/medicine_photo_item.dart';
import '../models/task_log.dart';
import '../providers/task_provider.dart';
import '../services/task_service.dart';
import '../widgets/problem_input_sheet.dart';

/// หน้ารายละเอียด Task แบบ Full Page
class TaskDetailScreen extends ConsumerStatefulWidget {
  final TaskLog task;

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
  bool get _showCompleteButton => !_requiresPhoto || _hasConfirmImage;

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

                    // Confirm image (ถ้ามี)
                    if (_task.confirmImage != null ||
                        _uploadedImageUrl != null) ...[
                      AppSpacing.verticalGapMd,
                      _buildConfirmImage(),
                    ],

                    // Descript (หมายเหตุ) - ถ้า task มีปัญหา
                    if (_task.descript != null &&
                        _task.descript!.isNotEmpty) ...[
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
            icon: const Icon(Iconsax.arrow_left),
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
    IconData icon;

    if (_task.isDone) {
      bgColor = AppColors.tagPassedBg;
      textColor = AppColors.tagPassedText;
      text = 'เสร็จแล้ว';
      icon = Iconsax.tick_circle;
    } else if (_task.isProblem) {
      bgColor = AppColors.error.withValues(alpha: 0.1);
      textColor = AppColors.error;
      text = 'ติดปัญหา';
      icon = Iconsax.warning_2;
    } else if (_task.isPostponed) {
      bgColor = AppColors.warning.withValues(alpha: 0.2);
      textColor = AppColors.warning;
      text = 'เลื่อนแล้ว';
      icon = Iconsax.calendar_1;
    } else if (_task.isReferred) {
      bgColor = AppColors.secondary.withValues(alpha: 0.2);
      textColor = AppColors.secondary;
      text = 'ไม่อยู่ศูนย์';
      icon = Iconsax.hospital;
    } else {
      bgColor = AppColors.tagPendingBg;
      textColor = AppColors.tagPendingText;
      text = 'รอดำเนินการ';
      icon = Iconsax.clock;
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
          Icon(icon, size: 14, color: textColor),
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
            icon: Iconsax.user,
            text: _task.residentName!,
            color: AppColors.primary,
          ),

        // Task type
        if (_task.taskType != null)
          _buildBadge(
            icon: Iconsax.category,
            text: _task.taskType!,
            color: AppColors.secondary,
          ),

        // Expected time
        if (_task.expectedDateTime != null)
          _buildBadge(
            icon: Iconsax.clock,
            text: DateFormat('HH:mm').format(_task.expectedDateTime!),
            color: AppColors.tagPendingText,
          ),

        // Time block
        if (_task.timeBlock != null)
          _buildBadge(
            icon: Iconsax.timer_1,
            text: _task.timeBlock!,
            color: AppColors.secondaryText,
          ),

        // Completed by
        if (_task.completedByNickname != null && _task.completedAt != null)
          _buildBadge(
            icon: Iconsax.tick_circle,
            text:
                '${_task.completedByNickname} (${DateFormat('HH:mm').format(_task.completedAt!)})',
            color: AppColors.tagPassedText,
          ),
      ],
    );
  }

  Widget _buildBadge({
    required IconData icon,
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
          Icon(icon, size: 14, color: color),
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
          Icon(Iconsax.info_circle, color: AppColors.error, size: 20),
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
          // Profile image
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: _task.residentPictureUrl != null
                ? Image.network(
                    _task.residentPictureUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildProfilePlaceholder();
                    },
                    errorBuilder: (_, error, stackTrace) =>
                        _buildProfilePlaceholder(),
                  )
                : _buildProfilePlaceholder(),
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

  Widget _buildProfilePlaceholder() {
    return Container(
      width: 50,
      height: 50,
      color: AppColors.accent1,
      child: Icon(Iconsax.user, color: AppColors.primary, size: 24),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รายการยา (${_medicines!.length} รายการ)',
          style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.w600),
        ),
        AppSpacing.verticalGapSm,
        // ใช้ MedicinePhotoItem จากหน้าจัดยา
        // showFoiled = false → แสดง frontNude (รูปเม็ดยาตอนเสิร์ฟ)
        // showOverlay = true → แสดง overlay จำนวนเม็ดยา
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75, // ปรับให้รูปแนวตั้งดูดีขึ้น
          ),
          itemCount: _medicines!.length,
          itemBuilder: (context, index) {
            final med = _medicines![index];
            return MedicinePhotoItem(
              medicine: med,
              showFoiled: false, // ใช้ frontNude (รูปเม็ดยา 3C)
              showOverlay: true, // แสดง overlay จำนวนเม็ดยา
            );
          },
        ),
      ],
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
        GestureDetector(
          onTap: () => _showExpandedImage(_task.sampleImageUrl!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _task.sampleImageUrl!,
              width: double.infinity,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                final total = loadingProgress.expectedTotalBytes;
                final loaded = loadingProgress.cumulativeBytesLoaded;
                final progress = total != null ? loaded / total : null;
                // แสดงขนาดที่โหลดแล้ว (KB/MB)
                String loadedText;
                if (loaded < 1024) {
                  loadedText = '$loaded B';
                } else if (loaded < 1024 * 1024) {
                  loadedText = '${(loaded / 1024).toStringAsFixed(0)} KB';
                } else {
                  loadedText =
                      '${(loaded / (1024 * 1024)).toStringAsFixed(1)} MB';
                }
                return Container(
                  height: 300,
                  color: AppColors.background,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          progress != null
                              ? '${(progress * 100).toInt()}%'
                              : 'กำลังโหลด... $loadedText',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 300,
                  color: AppColors.background,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Iconsax.image,
                          size: 32,
                          color: AppColors.secondaryText,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'โหลดรูปไม่สำเร็จ',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _task.sampleImageCreatorPhotoUrl != null
                        ? Image.network(
                            _task.sampleImageCreatorPhotoUrl!,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildCreatorPlaceholderGold(),
                          )
                        : _buildCreatorPlaceholderGold(),
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
                  child: const Icon(
                    Iconsax.medal_star5,
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
              const Icon(
                Iconsax.info_circle,
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

  /// Placeholder สำหรับรูป profile ผู้ถ่ายรูปตัวอย่าง (Gold theme)
  Widget _buildCreatorPlaceholderGold() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(0xFFFEF3C7), // amber-100
            Color(0xFFFDE68A), // amber-200
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Iconsax.user,
        size: 18,
        color: Color(0xFFB45309), // amber-700
      ),
    );
  }

  Widget _buildConfirmImage() {
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
                icon: Icon(Iconsax.trash, color: AppColors.error, size: 20),
                tooltip: 'ลบรูป',
              ),
          ],
        ),
        AppSpacing.verticalGapSm,
        GestureDetector(
          onTap: () => _showExpandedImage(imageUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                final total = loadingProgress.expectedTotalBytes;
                final loaded = loadingProgress.cumulativeBytesLoaded;
                final progress = total != null ? loaded / total : null;
                String loadedText;
                if (loaded < 1024) {
                  loadedText = '$loaded B';
                } else if (loaded < 1024 * 1024) {
                  loadedText = '${(loaded / 1024).toStringAsFixed(0)} KB';
                } else {
                  loadedText =
                      '${(loaded / (1024 * 1024)).toStringAsFixed(1)} MB';
                }
                return Container(
                  height: 300,
                  color: AppColors.background,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          progress != null
                              ? '${(progress * 100).toInt()}%'
                              : 'กำลังโหลด... $loadedText',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 300,
                  color: AppColors.background,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Iconsax.image,
                          size: 32,
                          color: AppColors.secondaryText,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'โหลดรูปไม่สำเร็จ',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                  : const Icon(Iconsax.gallery_edit, size: 20),
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

  Widget _buildDescriptNote() {
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
              Icon(Iconsax.message_text, color: AppColors.warning, size: 18),
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
          Icon(Iconsax.calendar_1, color: AppColors.secondary, size: 20),
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
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: InteractiveViewer(
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  final progress = loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                        if (progress != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  );
                },
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
                child: Icon(Iconsax.more, color: AppColors.secondaryText),
              ),
            ),
            AppSpacing.horizontalGapSm,

            // Camera button (ถ้าต้องถ่ายรูป)
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
                        : const Icon(Iconsax.camera),
                    label: Text('ถ่ายรูปงาน', style: AppTypography.button),
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
                        : const Icon(Iconsax.tick_circle),
                    label: Text('เรียบร้อย', style: AppTypography.button),
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
                child: Icon(Iconsax.arrow_left, color: AppColors.secondaryText),
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
                  icon: const Icon(Iconsax.warning_2),
                  label: Text('แจ้งติดปัญหา', style: AppTypography.button),
                ),
              ),
            ),
          ],
        ),
        AppSpacing.verticalGapSm,

        // Postpone + Refer buttons
        Row(
          children: [
            // Postpone button
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handlePostpone,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.warning),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Iconsax.calendar_1, color: AppColors.warning),
                  label: Text(
                    'เลื่อนวันพรุ่งนี้',
                    style: AppTypography.button.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ),
            ),
            AppSpacing.horizontalGapSm,

            // Refer button
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleRefer,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.secondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Iconsax.hospital, color: AppColors.secondary),
                  label: Text(
                    'ไม่อยู่ศูนย์',
                    style: AppTypography.button.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
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
            : Icon(Iconsax.close_circle, color: AppColors.error),
        label: Text(
          'ยกเลิกการรับทราบ',
          style: AppTypography.button.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  // Action handlers
  Future<void> _handleComplete() async {
    setState(() => _isLoading = true);

    final service = ref.read(taskServiceProvider);
    final userId = ref.read(currentUserIdProvider);

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final success = await service.markTaskComplete(
      _task.logId,
      userId,
      imageUrl: _uploadedImageUrl,
    );

    if (success) {
      refreshTasks(ref);
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถบันทึกได้ กรุณาลองใหม่')),
        );
      }
    }
  }

  Future<void> _handleProblem() async {
    final description = await ProblemInputSheet.show(context);
    if (description == null || description.isEmpty) return;

    setState(() => _isLoading = true);

    final service = ref.read(taskServiceProvider);
    final success = await service.markTaskProblem(_task.logId, description);

    if (success) {
      refreshTasks(ref);
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถบันทึกได้ กรุณาลองใหม่')),
        );
      }
    }
  }

  Future<void> _handlePostpone() async {
    setState(() => _isLoading = true);

    final service = ref.read(taskServiceProvider);
    final userId = ref.read(currentUserIdProvider);

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final success = await service.postponeTask(_task.logId, userId, _task);

    if (success) {
      refreshTasks(ref);
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเลื่อนงานได้ กรุณาลองใหม่')),
        );
      }
    }
  }

  Future<void> _handleRefer() async {
    setState(() => _isLoading = true);

    final service = ref.read(taskServiceProvider);
    final userId = ref.read(currentUserIdProvider);

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final success = await service.markTaskRefer(_task.logId, userId);

    if (success) {
      refreshTasks(ref);
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _isLoading = false);
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

    setState(() => _isLoading = true);

    final service = ref.read(taskServiceProvider);
    bool success;

    // ถ้าเป็น postpone ต้องลบ postponed log ก่อน
    if (_task.isPostponed && _task.postponeTo != null) {
      success = await service.cancelPostpone(_task.logId, _task.postponeTo!);
    } else {
      // ส่ง confirmImage URL ไปด้วยเพื่อลบจาก storage
      final imageUrl = _task.confirmImage ?? _uploadedImageUrl;
      success = await service.unmarkTask(
        _task.logId,
        confirmImageUrl: imageUrl,
      );
    }

    if (success) {
      refreshTasks(ref);
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _isLoading = false);
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
