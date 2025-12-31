import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../medicine/models/medicine_summary.dart';
import '../../medicine/screens/photo_preview_screen.dart';
import '../../medicine/services/camera_service.dart';
import '../../medicine/services/medicine_service.dart';
import '../../medicine/widgets/medicine_photo_item.dart';
import '../models/task_log.dart';
import '../providers/task_provider.dart';
import '../widgets/problem_input_sheet.dart';

/// หน้ารายละเอียด Task แบบ Full Page
class TaskDetailScreen extends ConsumerStatefulWidget {
  final TaskLog task;

  const TaskDetailScreen({
    super.key,
    required this.task,
  });

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

  @override
  void initState() {
    super.initState();
    _task = widget.task;

    // ถ้าเป็นงานจัดยา ให้โหลดข้อมูลยา
    if (_task.taskType == 'จัดยา' && _task.residentId != null) {
      _loadMedicines();
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
            '_loadMedicines: total=${medicines.length}, filtered=${filtered.length}');

        setState(() {
          _medicines = filtered;
          _isLoadingMedicines = false;
        });
      } else {
        debugPrint(
            '_loadMedicines: no filter applied, showing all ${medicines.length} medicines');
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
      style: AppTypography.heading2.copyWith(
        fontWeight: FontWeight.w600,
      ),
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
          Text(
            _task.description!,
            style: AppTypography.body,
          ),
        ],
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
                ? CachedNetworkImage(
                    imageUrl: _task.residentPictureUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildProfilePlaceholder(),
                    errorWidget: (_, __, ___) => _buildProfilePlaceholder(),
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
          child: Text(
            'ไม่พบรายการยาสำหรับมื้อนี้',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รายการยา (${_medicines!.length} รายการ)',
          style: AppTypography.subtitle.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
          style: AppTypography.subtitle.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.verticalGapSm,
        GestureDetector(
          onTap: () => _showExpandedImage(_task.sampleImageUrl!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: _task.sampleImageUrl!,
              width: double.infinity,
              fit: BoxFit.contain, // แสดงตามสัดส่วนจริง ไม่ crop
              placeholder: (_, __) => Container(
                height: 300,
                color: AppColors.background,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 300,
                color: AppColors.background,
                child: const Icon(Iconsax.image, size: 48),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmImage() {
    final imageUrl = _uploadedImageUrl ?? _task.confirmImage;
    if (imageUrl == null) return const SizedBox.shrink();

    // รูปที่เพิ่งถ่าย (ยังไม่ได้ save) สามารถลบได้
    final canDelete = _uploadedImageUrl != null && !_task.isDone;

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
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: double.infinity,
              fit: BoxFit.contain, // แสดงตามสัดส่วนจริง ไม่ crop
              placeholder: (_, __) => Container(
                height: 300,
                color: AppColors.background,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 300,
                color: AppColors.background,
                child: const Icon(Iconsax.image, size: 48),
              ),
            ),
          ),
        ),
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
          Text(
            _task.descript!,
            style: AppTypography.body,
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
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
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
        child: _task.isDone || _task.isPostponed || _task.isReferred
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
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.warning_2,
                    color: AppColors.error,
                    size: 18,
                  ),
                  AppSpacing.horizontalGapSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ตรวจสอบความถูกต้องก่อนส่งรายงาน',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'รูป ชื่อผู้ทำ และเวลา จะถูกส่งไปไลน์กลุ่มญาติ',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.error.withValues(alpha: 0.8),
                            fontSize: 11,
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
                    style:
                        AppTypography.button.copyWith(color: AppColors.warning),
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
                    style: AppTypography.button
                        .copyWith(color: AppColors.secondary),
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
    setState(() => _isLoading = true);

    final service = ref.read(taskServiceProvider);
    final success = await service.unmarkTask(_task.logId);

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
  void _handleDeletePhoto() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบรูป?'),
        content: const Text('ต้องการลบรูปที่ถ่ายไว้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _uploadedImageUrl = null;
              });
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }
}
