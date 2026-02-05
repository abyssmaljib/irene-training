import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/app_version_service.dart';
import '../services/bug_report_service.dart';

/// Form สำหรับรายงานปัญหา/Bug
/// แสดงเป็น dialog หรือ bottom sheet
/// - เลือกเวลาที่เกิดบัค (DateTime Picker)
/// - กรอกกิจกรรมที่ทำให้เกิดบัค (required)
/// - กรอกรายละเอียดเพิ่มเติม (optional)
/// - แนบไฟล์ภาพ/วิดีโอ (optional)
/// - แสดงข้อมูล device อัตโนมัติ
class BugReportForm extends StatefulWidget {
  /// Callback เมื่อ submit สำเร็จ
  final VoidCallback? onSubmitSuccess;

  const BugReportForm({
    super.key,
    this.onSubmitSuccess,
  });

  @override
  State<BugReportForm> createState() => _BugReportFormState();
}

class _BugReportFormState extends State<BugReportForm> {
  // Form controllers
  final _activityController = TextEditingController();
  final _notesController = TextEditingController();

  // State
  DateTime _bugOccurredAt = DateTime.now();
  final List<File> _attachments = [];
  bool _isLoading = false;

  // Device info (auto-captured)
  String _platform = '';
  String _appVersion = '';
  String _buildNumber = '';

  // Validate form
  bool get _isValid => _activityController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  @override
  void dispose() {
    _activityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// โหลดข้อมูล device เพื่อแสดงใน form
  Future<void> _loadDeviceInfo() async {
    final packageInfo = await AppVersionService.instance.getPackageInfo();
    final platform = AppVersionService.instance.getPlatformName();

    if (mounted) {
      setState(() {
        _platform = platform;
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    }
  }

  /// เปิด DateTime Picker เพื่อเลือกเวลาที่เกิดบัค
  Future<void> _pickDateTime() async {
    // เลือกวันที่ก่อน
    final date = await showDatePicker(
      context: context,
      initialDate: _bugOccurredAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      locale: const Locale('th', 'TH'),
    );

    if (date == null || !mounted) return;

    // เลือกเวลา
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_bugOccurredAt),
    );

    if (time == null || !mounted) return;

    setState(() {
      _bugOccurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  /// เปิด Image Picker เพื่อเลือกไฟล์แนบ
  Future<void> _pickAttachments() async {
    final picker = ImagePicker();

    // แสดง bottom sheet ให้เลือกประเภทไฟล์
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('เลือกประเภทไฟล์', style: AppTypography.subtitle),
            AppSpacing.verticalGapMd,
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                color: AppColors.primary,
                size: AppIconSize.lg,
              ),
              title: const Text('รูปภาพ'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedVideo01,
                color: AppColors.primary,
                size: AppIconSize.lg,
              ),
              title: const Text('วิดีโอ'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedAlbum01,
                color: AppColors.primary,
                size: AppIconSize.lg,
              ),
              title: const Text('หลายรูป'),
              onTap: () => Navigator.pop(context, 'multi'),
            ),
          ],
        ),
      ),
    );

    if (type == null || !mounted) return;

    try {
      if (type == 'image') {
        final image = await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          setState(() {
            _attachments.add(File(image.path));
          });
        }
      } else if (type == 'video') {
        final video = await picker.pickVideo(source: ImageSource.gallery);
        if (video != null) {
          setState(() {
            _attachments.add(File(video.path));
          });
        }
      } else if (type == 'multi') {
        final images = await picker.pickMultiImage();
        if (images.isNotEmpty) {
          setState(() {
            _attachments.addAll(images.map((img) => File(img.path)));
          });
        }
      }
    } catch (e) {
      debugPrint('BugReportForm: pickAttachments error: $e');
    }
  }

  /// ลบไฟล์แนบ
  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  /// Submit bug report
  Future<void> _handleSubmit() async {
    if (!_isValid || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final result = await BugReportService.instance.submitBugReport(
      bugOccurredAt: _bugOccurredAt,
      activityDescription: _activityController.text.trim(),
      additionalNotes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      attachmentFiles: _attachments.isNotEmpty ? _attachments : null,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result != null) {
      // Success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่งรายงานปัญหาเรียบร้อยแล้ว'),
          backgroundColor: AppColors.primary,
        ),
      );
      widget.onSubmitSuccess?.call();
    } else {
      // Error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedBug01,
                  color: AppColors.error,
                  size: 48,
                ),
                AppSpacing.verticalGapSm,
                Text('รายงานปัญหา/Bug', style: AppTypography.heading3),
                Text(
                  'ช่วยเราปรับปรุงแอปให้ดีขึ้น',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.verticalGapLg,

          // Device Info (read-only)
          _buildDeviceInfoSection(),

          AppSpacing.verticalGapMd,

          // DateTime Picker
          Text('เวลาที่เกิดปัญหา *', style: AppTypography.subtitle),
          AppSpacing.verticalGapSm,
          _buildDateTimePicker(),

          AppSpacing.verticalGapMd,

          // Activity Description (required)
          Text('กิจกรรมที่ทำอยู่ตอนเกิดปัญหา *', style: AppTypography.subtitle),
          AppSpacing.verticalGapSm,
          _buildTextField(
            controller: _activityController,
            hintText: 'เช่น กำลังบันทึกงาน, กำลังดูรายงาน...',
            maxLines: 2,
          ),

          AppSpacing.verticalGapMd,

          // Additional Notes (optional)
          Text('รายละเอียดเพิ่มเติม', style: AppTypography.subtitle),
          AppSpacing.verticalGapSm,
          _buildTextField(
            controller: _notesController,
            hintText: 'อธิบายปัญหาที่พบเพิ่มเติม (ถ้ามี)',
            maxLines: 3,
          ),

          AppSpacing.verticalGapMd,

          // Attachments
          _buildAttachmentsSection(),

          AppSpacing.verticalGapLg,

          // Submit Button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _activityController,
            builder: (context, value, child) {
              return _buildSubmitButton();
            },
          ),
        ],
      ),
    );
  }

  /// แสดงข้อมูล Device (อ่านอย่างเดียว)
  Widget _buildDeviceInfoSection() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: AppRadius.smallRadius,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedSmartPhone01,
                color: AppColors.primary,
                size: AppIconSize.md,
              ),
              AppSpacing.horizontalGapSm,
              Text(
                'ข้อมูลอุปกรณ์',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapSm,
          // Platform + Version + Build
          Text(
            '$_platform • v$_appVersion${_buildNumber.isNotEmpty ? " ($_buildNumber)" : ""}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  /// ปุ่มเลือก DateTime
  Widget _buildDateTimePicker() {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm', 'th');

    return InkWell(
      onTap: _pickDateTime,
      borderRadius: AppRadius.smallRadius,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadius.smallRadius,
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar01,
              color: AppColors.primary,
              size: AppIconSize.md,
            ),
            AppSpacing.horizontalGapMd,
            Expanded(
              child: Text(
                dateFormat.format(_bugOccurredAt),
                style: AppTypography.body,
              ),
            ),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowDown01,
              color: AppColors.secondaryText,
              size: AppIconSize.md,
            ),
          ],
        ),
      ),
    );
  }

  /// TextField ทั่วไป
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.secondaryText,
        ),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: AppRadius.smallRadius,
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smallRadius,
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smallRadius,
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.all(AppSpacing.md),
      ),
      maxLines: maxLines,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
    );
  }

  /// Section สำหรับไฟล์แนบ
  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('แนบไฟล์', style: AppTypography.subtitle),
            AppSpacing.horizontalGapSm,
            Text(
              '(ไม่จำกัดจำนวน)',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        AppSpacing.verticalGapSm,

        // แสดง attachments ที่เลือกแล้ว
        if (_attachments.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: List.generate(
              _attachments.length,
              (index) => _buildAttachmentThumbnail(index),
            ),
          ),
          AppSpacing.verticalGapSm,
        ],

        // ปุ่มเพิ่มไฟล์
        InkWell(
          onTap: _pickAttachments,
          borderRadius: AppRadius.smallRadius,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.smallRadius,
              border: Border.all(
                color: AppColors.inputBorder,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAttachment01,
                  color: AppColors.primary,
                  size: AppIconSize.md,
                ),
                AppSpacing.horizontalGapSm,
                Text(
                  'เพิ่มรูป/วิดีโอ',
                  style: AppTypography.body.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Thumbnail ของไฟล์แนบ พร้อมปุ่มลบ
  Widget _buildAttachmentThumbnail(int index) {
    final file = _attachments[index];
    final isVideo = _isVideoFile(file.path);

    return Stack(
      children: [
        // Thumbnail
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.smallRadius,
            border: Border.all(color: AppColors.alternate),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.smallRadius,
            child: isVideo
                ? Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedVideo01,
                      color: AppColors.primary,
                      size: AppIconSize.xl,
                    ),
                  )
                : Image.file(
                    file,
                    fit: BoxFit.cover,
                    cacheWidth: 160,
                    errorBuilder: (context, error, stack) {
                      return Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedImage01,
                          color: AppColors.secondaryText,
                          size: AppIconSize.lg,
                        ),
                      );
                    },
                  ),
          ),
        ),

        // ปุ่มลบ
        Positioned(
          right: -4,
          top: -4,
          child: InkWell(
            onTap: () => _removeAttachment(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ตรวจสอบว่าเป็น video file หรือไม่
  bool _isVideoFile(String path) {
    const videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'];
    final ext = path.toLowerCase().split('.').last;
    return videoExtensions.contains('.$ext');
  }

  /// ปุ่ม Submit
  Widget _buildSubmitButton() {
    final isEnabled = _isValid && !_isLoading;

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: isEnabled ? AppColors.error : AppColors.alternate,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? _handleSubmit : null,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedSent,
                        color: isEnabled ? Colors.white : AppColors.secondaryText,
                        size: AppIconSize.md,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ส่งรายงาน',
                        style: AppTypography.button.copyWith(
                          color: isEnabled ? Colors.white : AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Helper function เพื่อแสดง BugReportForm เป็น Dialog
/// ใช้ได้ทั้งจาก ClockOutSurveyForm และ Settings
Future<void> showBugReportDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: EdgeInsets.all(AppSpacing.md),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header พร้อมปุ่มปิด
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    color: AppColors.secondaryText,
                    size: AppIconSize.md,
                  ),
                ),
              ],
            ),
            // BugReportForm
            Flexible(
              child: BugReportForm(
                onSubmitSuccess: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
