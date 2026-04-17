import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/input_fields.dart';
import '../../../core/widgets/keyboard_dismiss_scope.dart';
import '../../../core/widgets/network_image.dart';
import '../../medicine/screens/photo_preview_screen.dart';
import '../models/measurement_config.dart';
import '../screens/square_camera_screen.dart';

/// ผลลัพธ์จาก MeasurementInputSection / MeasurementInputDialog
/// - null = user ยังไม่กรอก หรือกดยกเลิก
/// - MeasurementResult = user กรอกค่าแล้ว
class MeasurementResult {
  /// ค่าที่วัดได้ เช่น 65.5 (kg) หรือ 165 (cm)
  final double value;

  /// URL ของรูปตาชั่ง/อุปกรณ์วัด (ถ้าถ่ายรูป)
  final String? photoUrl;

  const MeasurementResult({
    required this.value,
    this.photoUrl,
  });
}

// ============================================================
// MeasurementInputSection — Inline section สำหรับ task detail body
// ============================================================

/// Section กรอกค่า measurement แสดงอยู่ใน body ของ task detail
/// ใช้แทน dialog — user กรอกค่าไว้ก่อนได้เลยไม่ต้องรอกด complete
///
/// ค่าที่กรอกจะถูกอ่านจาก [controller] โดย parent widget
/// ส่ง [onValueChanged] callback เพื่อให้ parent อัพเดต state (enable/disable ปุ่ม)
class MeasurementInputSection extends StatefulWidget {
  /// Config กำหนด type, unit, label, min/max
  final MeasurementConfig config;

  /// Controller สำหรับ TextField — parent เป็นเจ้าของ เพื่ออ่านค่าตอน complete
  final TextEditingController controller;

  /// Task log ID — ใช้สร้าง storage path สำหรับรูป
  final int taskLogId;

  /// Callback เมื่อค่าเปลี่ยน — parent ใช้เพื่อ enable/disable ปุ่ม complete
  final ValueChanged<String> onValueChanged;

  /// Callback เมื่อ photo URL เปลี่ยน (ถ่ายรูปใหม่ หรือ null เมื่อยังไม่ถ่าย)
  final ValueChanged<String?> onPhotoChanged;

  /// Task เสร็จแล้วหรือยัง — ถ้าเสร็จจะ disable input
  final bool isCompleted;

  /// Photo URL ที่ถ่ายไว้แล้ว — ใช้ restore หลัง realtime rebuild
  /// เพราะ State ของ section ถูกสร้างใหม่เมื่อ parent rebuild
  final String? initialPhotoUrl;

  const MeasurementInputSection({
    super.key,
    required this.config,
    required this.controller,
    required this.taskLogId,
    required this.onValueChanged,
    required this.onPhotoChanged,
    this.isCompleted = false,
    this.initialPhotoUrl,
  });

  @override
  State<MeasurementInputSection> createState() =>
      _MeasurementInputSectionState();
}

class _MeasurementInputSectionState extends State<MeasurementInputSection> {
  /// URL ของรูปที่ถ่ายแล้ว upload
  late String? _photoUrl;

  /// กำลัง upload รูปอยู่
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Restore photo URL จาก parent — ป้องกันหายเมื่อ realtime rebuild
    _photoUrl = widget.initialPhotoUrl;
  }

  /// ข้อความเตือนถ้าค่านอก min-max (soft validation)
  String? _warningText;

  /// ตรวจสอบค่าว่าอยู่ใน range ที่สมเหตุสมผลหรือไม่
  /// **Perf:** setState เฉพาะตอนที่ _warningText เปลี่ยนจริง
  /// ลด rebuild ทุกตัวอักษรตอนกรอก → ช่วยให้ keyboard animate ไม่กระตุก
  void _validateValue(String text) {
    final value = double.tryParse(text);
    String? newWarning;

    if (value == null || text.isEmpty) {
      newWarning = null;
    } else if (value < widget.config.min) {
      newWarning =
          'ค่าต่ำกว่าปกติ (ต่ำสุด ${widget.config.min} ${widget.config.unit})';
    } else if (value > widget.config.max) {
      newWarning =
          'ค่าสูงกว่าปกติ (สูงสุด ${widget.config.max} ${widget.config.unit})';
    } else {
      newWarning = null;
    }

    if (newWarning != _warningText) {
      setState(() => _warningText = newWarning);
    }
  }

  /// เปิดกล้องถ่ายรูปตาชั่ง/อุปกรณ์วัด
  Future<void> _handleTakePhoto() async {
    if (_isUploading || widget.isCompleted) return;

    // Dev dummy สำหรับทดสอบบน desktop
    if (kDebugMode &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final url =
          'https://amthgthvrxhlxpttioxu.supabase.co/storage/v1/object/public/med-photos/dummy.jpg';
      setState(() => _photoUrl = url);
      widget.onPhotoChanged(url);
      return;
    }

    // จัดการ memory ก่อนเปิดกล้อง (ป้องกัน iOS crash)
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    final savedMaxSize = PaintingBinding.instance.imageCache.maximumSize;
    final savedMaxBytes = PaintingBinding.instance.imageCache.maximumSizeBytes;
    PaintingBinding.instance.imageCache.maximumSize = 0;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 0;

    final File? file = await SquareCameraScreen.show(context: context);

    PaintingBinding.instance.imageCache.maximumSize = savedMaxSize;
    PaintingBinding.instance.imageCache.maximumSizeBytes = savedMaxBytes;

    if (file == null || !mounted) return;

    final confirmedFile = await PhotoPreviewScreen.show(
      context: context,
      imageFile: file,
      photoType: 'measurement',
      mealLabel: widget.config.label,
    );

    if (confirmedFile == null || !mounted) return;

    // Upload ไป Supabase Storage
    setState(() => _isUploading = true);
    try {
      final storagePath =
          'measurements/${widget.taskLogId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await confirmedFile.readAsBytes();

      await Supabase.instance.client.storage
          .from('med-photos')
          .uploadBinary(storagePath, bytes);

      final url = Supabase.instance.client.storage
          .from('med-photos')
          .getPublicUrl(storagePath);

      if (mounted) {
        setState(() {
          _photoUrl = url;
          _isUploading = false;
        });
        widget.onPhotoChanged(url);
      }
    } catch (e) {
      debugPrint('Error uploading measurement photo: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        AppToast.error(context, 'ไม่สามารถอัพโหลดรูปได้ กรุณาลองใหม่');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final isDisabled = widget.isCompleted;

    // ใช้ pattern เดียวกับ ResolutionHistorySection — Column + Padding
    // ไม่ wrap ด้วย Container+border เพราะ sections อื่นใน task detail ไม่มี
    // ใช้ card shadow แทนเพื่อ visual hierarchy
    return Container(
      margin: AppSpacing.screenPadding, // 16px horizontal เหมือน screenPadding
      padding: AppSpacing.cardPadding, // 16px all เหมือน card
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smallRadius, // 8px เหมือน resolution card
        boxShadow: AppShadows.cardShadow, // subtle shadow เหมือน TaskTimeSection
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — pattern เดียวกับ ResolutionHistorySection:
          // icon (secondaryText) + title (bodySmall/w600/secondaryText)
          Row(
            children: [
              HugeIcon(
                icon: config.measurementType == 'weight'
                    ? HugeIcons.strokeRoundedWeightScale01
                    : HugeIcons.strokeRoundedRuler,
                color: AppColors.secondaryText,
                size: AppIconSize.md, // 18px — ใช้ token แทน hardcode
              ),
              AppSpacing.horizontalGapSm,
              Text(
                'ค่าวัดร่างกาย',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),

          AppSpacing.verticalGapSm,

          // Label — บอก user ว่ากรอกอะไร (เช่น "น้ำหนัก (กก.)")
          Text(
            config.label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),

          AppSpacing.verticalGapSm,

          // Input กรอกค่า — ใช้ AppTextField (design system) แทน raw TextField
          // font ใหญ่ (heading2) + center align + suffix แสดงหน่วย
          // warning ใช้ errorText ของ AppTextField (แสดง icon + ข้อความแดง)
          AppTextField(
            controller: widget.controller,
            enabled: !isDisabled,
            hintText: config.placeholder,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              _SingleDotFormatter(),
            ],
            textAlign: TextAlign.center,
            textStyle: AppTypography.heading2.copyWith(
              fontWeight: FontWeight.w700,
            ),
            suffixText: config.unit,
            suffixTextStyle: AppTypography.title.copyWith(
              color: AppColors.textSecondary,
            ),
            // ใช้ default fillColor (AppColors.background สีเทาอ่อน)
            // เพื่อให้เห็นขอบเขต input ชัดบน card สีขาว
            onChanged: (text) {
              _validateValue(text);
              widget.onValueChanged(text);
            },
          ),

          // Soft warning — สีส้ม ไม่ใช่ error (ยังบันทึกได้)
          // แยกจาก AppTextField.errorText เพราะ errorText เป็นสีแดง block feel
          if (_warningText != null) ...[
            AppSpacing.verticalGapXs,
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  color: AppColors.warning,
                  size: AppIconSize.sm,
                ),
                AppSpacing.horizontalGapXs,
                Flexible(
                  child: Text(
                    _warningText!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],

          AppSpacing.verticalGapSm,

          // ปุ่มถ่ายรูป / preview
          _buildPhotoSection(isDisabled),
        ],
      ),
    );
  }

  /// สร้าง section ถ่ายรูป — ใช้ design tokens ทั้งหมด
  Widget _buildPhotoSection(bool isDisabled) {
    // กำลัง upload — แสดง spinner + ข้อความ
    if (_isUploading) {
      return Row(
        children: [
          SizedBox(
            width: AppIconSize.sm,
            height: AppIconSize.sm,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          AppSpacing.horizontalGapSm,
          Text(
            'กำลังอัพโหลดรูป...',
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      );
    }

    // มีรูปแล้ว — แสดง thumbnail + สถานะ + ปุ่มถ่ายใหม่
    if (_photoUrl != null) {
      return Row(
        children: [
          // Thumbnail 36x36 — ใช้ IreneNetworkImage ตาม CLAUDE.md
          ClipRRect(
            borderRadius: AppRadius.smallRadius,
            child: IreneNetworkImage(
              imageUrl: _photoUrl!,
              width: AppSpacing.xxxl - AppSpacing.unit, // 40px (ใกล้สุดกับ 36)
              height: AppSpacing.xxxl - AppSpacing.unit,
              fit: BoxFit.cover,
              memCacheWidth: 80, // 2x สำหรับ retina
              compact: true,
            ),
          ),
          AppSpacing.horizontalGapSm,
          Text(
            'ถ่ายรูปแล้ว',
            style: AppTypography.caption.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (!isDisabled)
            GestureDetector(
              onTap: _handleTakePhoto,
              child: Text(
                'ถ่ายใหม่',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      );
    }

    // ยังไม่มีรูป — แสดง link ถ่ายรูป
    if (isDisabled) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _handleTakePhoto,
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCamera01,
            color: AppColors.primary,
            size: AppIconSize.sm, // 14px — inline icon ตาม token
          ),
          AppSpacing.horizontalGapXs,
          Text(
            'ถ่ายรูปอุปกรณ์วัด (แนะนำ)',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MeasurementInputDialog — ใช้ใน batch flow + completeByPost
// ============================================================

/// Dialog กรอกค่า measurement — ใช้เฉพาะ flow ที่ไม่มี inline section
/// เช่น batch task screen, completeByPost
class MeasurementInputDialog extends StatefulWidget {
  final MeasurementConfig config;
  final int taskLogId;

  const MeasurementInputDialog({
    super.key,
    required this.config,
    required this.taskLogId,
  });

  static Future<MeasurementResult?> show(
    BuildContext context, {
    required MeasurementConfig config,
    required int taskLogId,
  }) async {
    return showDialog<MeasurementResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MeasurementInputDialog(
        config: config,
        taskLogId: taskLogId,
      ),
    );
  }

  @override
  State<MeasurementInputDialog> createState() =>
      _MeasurementInputDialogState();
}

class _MeasurementInputDialogState extends State<MeasurementInputDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _photoUrl;
  bool _isUploading = false;
  bool _hasSaved = false;
  String? _warningText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// **Perf:** setState เฉพาะตอน _warningText เปลี่ยน
  void _validateValue(String text) {
    final value = double.tryParse(text);
    String? newWarning;

    if (value == null || text.isEmpty) {
      newWarning = null;
    } else if (value < widget.config.min) {
      newWarning =
          'ค่าต่ำกว่าปกติ (ต่ำสุด ${widget.config.min} ${widget.config.unit})';
    } else if (value > widget.config.max) {
      newWarning =
          'ค่าสูงกว่าปกติ (สูงสุด ${widget.config.max} ${widget.config.unit})';
    } else {
      newWarning = null;
    }

    if (newWarning != _warningText) {
      setState(() => _warningText = newWarning);
    }
  }

  Future<void> _handleTakePhoto() async {
    if (_isUploading) return;
    if (kDebugMode &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      setState(() => _photoUrl =
          'https://amthgthvrxhlxpttioxu.supabase.co/storage/v1/object/public/med-photos/dummy.jpg');
      return;
    }

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    final savedMaxSize = PaintingBinding.instance.imageCache.maximumSize;
    final savedMaxBytes = PaintingBinding.instance.imageCache.maximumSizeBytes;
    PaintingBinding.instance.imageCache.maximumSize = 0;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 0;

    final File? file = await SquareCameraScreen.show(context: context);

    PaintingBinding.instance.imageCache.maximumSize = savedMaxSize;
    PaintingBinding.instance.imageCache.maximumSizeBytes = savedMaxBytes;

    if (file == null || !mounted) return;

    final confirmedFile = await PhotoPreviewScreen.show(
      context: context,
      imageFile: file,
      photoType: 'measurement',
      mealLabel: widget.config.label,
    );
    if (confirmedFile == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final storagePath =
          'measurements/${widget.taskLogId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await confirmedFile.readAsBytes();
      await Supabase.instance.client.storage
          .from('med-photos')
          .uploadBinary(storagePath, bytes);
      final url = Supabase.instance.client.storage
          .from('med-photos')
          .getPublicUrl(storagePath);
      if (mounted) {
        setState(() {
          _photoUrl = url;
          _isUploading = false;
        });
      }
    } catch (e) {
      debugPrint('Error uploading measurement photo: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        AppToast.error(context, 'ไม่สามารถอัพโหลดรูปได้ กรุณาลองใหม่');
      }
    }
  }

  void _handleSave() {
    if (_hasSaved) return;
    final text = _controller.text.trim();
    final value = double.tryParse(text);
    if (value == null || value <= 0 || text.isEmpty) {
      AppToast.warning(context, 'กรุณากรอกค่า${widget.config.label}ที่ถูกต้อง');
      return;
    }
    _hasSaved = true;
    Navigator.pop(context, MeasurementResult(value: value, photoUrl: _photoUrl));
  }

  /// สร้าง section ถ่ายรูปใน dialog
  Widget _buildPhotoSection() {
    if (_isUploading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
          SizedBox(width: AppSpacing.sm),
          Text('กำลังอัพโหลดรูป...', style: AppTypography.caption.copyWith(color: AppColors.secondaryText)),
        ],
      );
    }

    if (_photoUrl != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: AppRadius.smallRadius,
            child: IreneNetworkImage(
              imageUrl: _photoUrl!,
              width: 36, height: 36,
              fit: BoxFit.cover,
              memCacheWidth: 72,
              compact: true,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Text('ถ่ายรูปแล้ว', style: AppTypography.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
          SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: _handleTakePhoto,
            child: Text('ถ่ายใหม่', style: AppTypography.caption.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: _handleTakePhoto,
      icon: HugeIcon(icon: HugeIcons.strokeRoundedCamera01, color: AppColors.primary, size: 18),
      label: Text('ถ่ายรูปอุปกรณ์วัด (แนะนำ)', style: AppTypography.caption.copyWith(color: AppColors.primary)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mediumRadius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeRadius),
      backgroundColor: AppColors.surface,
      contentPadding: EdgeInsets.zero,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      // Wrap ด้วย KeyboardDismissScope (showDoneBar: false) เพื่อ:
      // - แตะพื้นที่ว่างใน dialog → keyboard ปิด
      // - ไม่ใช้ Done bar เพราะ dialog size to content + มีปุ่มบันทึกอยู่แล้ว
      content: KeyboardDismissScope(
        showDoneBar: false,
        child: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: AppSpacing.lg),
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: config.measurementType == 'weight'
                        ? HugeIcons.strokeRoundedWeightScale01
                        : HugeIcons.strokeRoundedRuler,
                    color: AppColors.primary,
                    size: AppIconSize.xl,
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'กรอกค่า${config.label}',
                style: AppTypography.title.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.lg),
              // TextField
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    _SingleDotFormatter(),
                  ],
                  textAlign: TextAlign.center,
                  style: AppTypography.heading2.copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: config.placeholder,
                    hintStyle: AppTypography.heading2.copyWith(
                      color: AppColors.secondaryText.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w400,
                    ),
                    suffixText: config.unit,
                    suffixStyle: AppTypography.title.copyWith(color: AppColors.secondaryText),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mediumRadius,
                      borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mediumRadius,
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                  ),
                  onChanged: _validateValue,
                  onSubmitted: (_) => _handleSave(),
                ),
              ),
              // Warning
              if (_warningText != null) ...[
                SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedAlert02, color: AppColors.warning, size: 16),
                      SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(_warningText!, style: AppTypography.caption.copyWith(color: AppColors.warning)),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: AppSpacing.md),
              // ถ่ายรูปอุปกรณ์วัด
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _buildPhotoSection(),
              ),
              SizedBox(height: AppSpacing.lg),
              // ปุ่มบันทึก
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.mediumRadius),
                    ),
                    child: Text('บันทึกค่า', style: AppTypography.button),
                  ),
                ),
              ),
              // ปุ่มยกเลิก
              Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: TextButton(
                    onPressed: _isUploading ? null : () => Navigator.pop(context, null),
                    child: Text(
                      _isUploading ? 'กำลังอัพโหลด...' : 'ยกเลิก',
                      style: AppTypography.body.copyWith(color: AppColors.secondaryText),
                    ),
                  ),
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

// ============================================================
// Shared Formatter
// ============================================================

/// TextInputFormatter ที่อนุญาตจุดทศนิยมได้ไม่เกิน 1 จุด
class _SingleDotFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if ('.'.allMatches(text).length > 1) {
      return oldValue;
    }
    return newValue;
  }
}
