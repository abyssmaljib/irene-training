import 'dart:convert';
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
import '../../../core/widgets/network_image.dart';
import '../../checklist/models/measurement_config.dart';
import '../../checklist/screens/square_camera_screen.dart';
import '../../medicine/screens/photo_preview_screen.dart';
import '../models/post_measurement_entry.dart';

// ============================================
// PostMeasurementSection — "📊 บันทึกค่าวัด"
// ============================================
// Section แยกสำหรับแนบค่าวัดร่างกายใน post
// แสดงเมื่อเลือก resident แล้ว ทั้ง create + edit
//
// Layout:
// ── 📊 บันทึกค่าวัด ──────────── ▼ ──
//  [⚖ น้ำหนัก] [📏 ส่วนสูง] [🩸 DTX] [💉 อินซูลิน]
//
//  ┌─ น้ำหนัก (กก.) ──────────────┐
//  │   [____65.5____] kg           │
//  │   📷 ถ่ายรูปตาชั่ง            │
//  └───────────────────────────────┘

class PostMeasurementSection extends StatefulWidget {
  /// ค่าวัดที่เลือก/กรอกแล้ว keyed by measurementType
  final Map<String, PostMeasurementEntry> measurements;

  /// Measurement type ที่ pre-select (จาก FAB shortcut)
  /// ถ้ามี → auto-expand + auto-select ตัวนี้
  final String? preSelectedType;

  // === Callbacks ===
  final ValueChanged<String> onMeasurementAdded;
  final ValueChanged<String> onMeasurementRemoved;
  final void Function(String type, double? value) onValueChanged;
  final void Function(String type, String? photoUrl) onPhotoChanged;

  /// Callback เมื่อ upload รูปสำเร็จ → parent เพิ่มเข้า image preview ของ post
  final ValueChanged<String>? onPhotoUploaded;

  /// Callback เมื่อลบรูป → parent ลบออกจาก image preview ของ post
  final ValueChanged<String>? onPhotoRemoved;

  /// Single mode: ซ่อน header + chips แสดงแค่ input card ตัวเดียว
  /// ใช้เมื่อเข้าจาก FAB shortcut → user เห็นแค่ค่าที่เลือก
  final bool singleMode;

  const PostMeasurementSection({
    super.key,
    required this.measurements,
    this.preSelectedType,
    required this.onMeasurementAdded,
    required this.onMeasurementRemoved,
    required this.onValueChanged,
    required this.onPhotoChanged,
    this.onPhotoUploaded,
    this.onPhotoRemoved,
    this.singleMode = false,
  });

  @override
  State<PostMeasurementSection> createState() => _PostMeasurementSectionState();
}

class _PostMeasurementSectionState extends State<PostMeasurementSection> {
  bool _isExpanded = false;

  /// Controllers สำหรับ TextField ของแต่ละ measurement type
  /// จะสร้างเมื่อ measurement ถูกเพิ่ม และลบเมื่อถูกถอด
  final Map<String, TextEditingController> _controllers = {};

  /// จำนวน measurement ที่กรอกค่าแล้ว (สำหรับ badge)
  int get _filledCount =>
      widget.measurements.values.where((e) => e.hasValue).length;

  /// ตรวจว่ามี measurement อย่างน้อย 1 ตัว (สำหรับ highlight header)
  bool get _hasAny => widget.measurements.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Auto-expand ถ้ามี preSelectedType หรือมี measurements อยู่แล้ว (edit)
    if (widget.preSelectedType != null || widget.measurements.isNotEmpty) {
      _isExpanded = true;
    }
    // สร้าง controllers สำหรับ measurements ที่มีอยู่แล้ว (edit mode)
    for (final entry in widget.measurements.entries) {
      final ctrl = TextEditingController(
        text: entry.value.value?.toString() ?? '',
      );
      _controllers[entry.key] = ctrl;
    }
  }

  @override
  void didUpdateWidget(PostMeasurementSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-expand เมื่อมี measurement เข้ามาครั้งแรก (จาก shortcut)
    if (!_isExpanded &&
        widget.measurements.isNotEmpty &&
        oldWidget.measurements.isEmpty) {
      _isExpanded = true;
    }

    // สร้าง controllers ใหม่สำหรับ measurement ที่เพิ่มมา
    for (final type in widget.measurements.keys) {
      if (!_controllers.containsKey(type)) {
        final value = widget.measurements[type]?.value;
        _controllers[type] = TextEditingController(
          text: value?.toString() ?? '',
        );
      }
    }
    // ลบ + dispose controllers ที่ไม่มีแล้ว (ป้องกัน memory leak)
    _controllers.removeWhere((key, ctrl) {
      if (!widget.measurements.containsKey(key)) {
        ctrl.dispose();
        return true;
      }
      return false;
    });
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // === Single mode: แค่ input card ตัวเดียว ไม่มี header/chips ===
    if (widget.singleMode && widget.measurements.isNotEmpty) {
      final entry = widget.measurements.entries.first;
      return _MeasurementInputCard(
        entry: entry.value,
        controller: _controllers[entry.key] ?? TextEditingController(),
        onValueChanged: (value) => widget.onValueChanged(entry.key, value),
        onPhotoChanged: (url) => widget.onPhotoChanged(entry.key, url),
        onPhotoUploaded: widget.onPhotoUploaded,
        onPhotoRemoved: widget.onPhotoRemoved,
        autoFocus: widget.preSelectedType != null,
      );
    }

    // === Normal mode: header + chips + input fields ===
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        // ใช้ if แทน AnimatedCrossFade เพื่อลด widget tree + ลดการ build ซ้ำ
        if (_isExpanded) _buildExpandedContent(),
      ],
    );
  }

  // ============================================
  // Header — tap เพื่อ expand/collapse
  // ============================================
  Widget _buildHeader() {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: _hasAny ? AppColors.primary : AppColors.alternate,
            width: _hasAny ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: _hasAny
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Icon
            HugeIcon(
              icon: HugeIcons.strokeRoundedChart,
              size: AppIconSize.lg,
              color: _hasAny ? AppColors.primary : AppColors.secondaryText,
            ),
            const SizedBox(width: 8),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'บันทึกค่าวัด',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color:
                          _hasAny ? AppColors.primary : AppColors.primaryText,
                    ),
                  ),
                  Text(
                    'น้ำหนัก, ส่วนสูง, DTX, อินซูลิน',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            // Badge count
            if (_filledCount > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.fullRadius,
                ),
                child: Text(
                  '$_filledCount',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            // Arrow
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                size: AppIconSize.md,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // Expanded Content — chips + input fields
  // ============================================
  Widget _buildExpandedContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === Measurement Type Chips ===
          // Toggle เลือกได้หลายตัว (ไม่เหมือน PostExtrasSection ที่เลือกได้ 1)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: postMeasurementTypes.map((type) {
              final config = measurementConfigByType[type]!;
              final isSelected = widget.measurements.containsKey(type);
              return _buildTypeChip(type, config, isSelected);
            }).toList(),
          ),

          // === Input Fields สำหรับ measurement ที่เลือก ===
          if (widget.measurements.isNotEmpty) ...[
            AppSpacing.verticalGapSm,
            ...widget.measurements.entries.toList().asMap().entries.map(
              (indexed) {
                final entry = indexed.value;
                // Auto-focus ตัวแรก ถ้ามี preSelectedType (จาก shortcut)
                final shouldAutoFocus = indexed.key == 0 &&
                    widget.preSelectedType != null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MeasurementInputCard(
                    entry: entry.value,
                    controller:
                        _controllers[entry.key] ?? TextEditingController(),
                    onValueChanged: (value) =>
                        widget.onValueChanged(entry.key, value),
                    onPhotoChanged: (url) =>
                        widget.onPhotoChanged(entry.key, url),
                    onPhotoUploaded: widget.onPhotoUploaded,
                    onPhotoRemoved: widget.onPhotoRemoved,
                    autoFocus: shouldAutoFocus,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ============================================
  // Type Chip — toggle เลือก/ไม่เลือก measurement type
  // ============================================
  Widget _buildTypeChip(
      String type, MeasurementConfig config, bool isSelected) {
    // Icon ตาม measurement type
    final dynamic icon;
    switch (type) {
      case 'weight':
        icon = HugeIcons.strokeRoundedWeightScale01;
        break;
      case 'height':
        icon = HugeIcons.strokeRoundedRuler;
        break;
      case 'dtx':
        icon = HugeIcons.strokeRoundedTestTube;
        break;
      case 'insulin':
        icon = HugeIcons.strokeRoundedInjection;
        break;
      default:
        icon = HugeIcons.strokeRoundedChart;
    }

    return InkWell(
      onTap: () {
        if (isSelected) {
          // แจ้ง parent ลบ → didUpdateWidget จะ dispose controller ให้
          widget.onMeasurementRemoved(type);
        } else {
          widget.onMeasurementAdded(type);
          // controller จะถูกสร้างใน didUpdateWidget
        }
      },
      borderRadius: AppRadius.fullRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: AppRadius.fullRadius,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.alternate,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: icon,
              size: AppIconSize.sm,
              color: isSelected ? AppColors.primary : AppColors.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              config.label.replaceAll(RegExp(r'\s*\(.*\)'), ''), // ตัด unit ออก
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.primaryText,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// _MeasurementInputCard — card สำหรับกรอกค่า 1 measurement
// ============================================
class _MeasurementInputCard extends StatefulWidget {
  final PostMeasurementEntry entry;
  final TextEditingController controller;
  final ValueChanged<double?> onValueChanged;
  final ValueChanged<String?> onPhotoChanged;
  final ValueChanged<String>? onPhotoUploaded;
  final ValueChanged<String>? onPhotoRemoved;

  /// Auto-focus input เมื่อ card แสดงครั้งแรก (สำหรับ shortcut)
  final bool autoFocus;

  const _MeasurementInputCard({
    required this.entry,
    required this.controller,
    required this.onValueChanged,
    required this.onPhotoChanged,
    this.onPhotoUploaded,
    this.onPhotoRemoved,
    this.autoFocus = false,
  });

  @override
  State<_MeasurementInputCard> createState() => _MeasurementInputCardState();
}

class _MeasurementInputCardState extends State<_MeasurementInputCard> {
  String? _warningText;
  bool _isUploading = false;
  bool _isReadingAI = false; // กำลังให้ AI อ่านค่าจากรูป

  /// ตรวจว่าค่าอยู่ใน range ที่สมเหตุสมผล (soft validation)
  void _validateValue(String text) {
    final value = double.tryParse(text);
    if (value == null || text.isEmpty) {
      setState(() => _warningText = null);
      return;
    }

    if (value < widget.entry.config.min) {
      setState(() => _warningText =
          'ค่าต่ำกว่าปกติ (ต่ำสุด ${widget.entry.config.min} ${widget.entry.config.unit})');
    } else if (value > widget.entry.config.max) {
      setState(() => _warningText =
          'ค่าสูงกว่าปกติ (สูงสุด ${widget.entry.config.max} ${widget.entry.config.unit})');
    } else {
      setState(() => _warningText = null);
    }
  }

  /// เปิดกล้องถ่ายรูปอุปกรณ์วัด
  /// ใช้ pattern เดียวกับ MeasurementInputSection ใน task detail
  Future<void> _handleTakePhoto() async {
    if (_isUploading) return;

    // Dev dummy สำหรับทดสอบบน desktop
    if (kDebugMode &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      const url =
          'https://amthgthvrxhlxpttioxu.supabase.co/storage/v1/object/public/med-photos/dummy.jpg';
      widget.onPhotoChanged(url);
      // เรียก AI อ่านค่าจากรูป dummy ด้วย (ทดสอบ flow)
      _readValueFromPhoto(url);
      return;
    }

    // จัดการ memory ก่อนเปิดกล้อง (ป้องกัน iOS crash)
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    final savedMaxSize = PaintingBinding.instance.imageCache.maximumSize;
    final savedMaxBytes = PaintingBinding.instance.imageCache.maximumSizeBytes;
    PaintingBinding.instance.imageCache.maximumSize = 0;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 0;

    // เปิดกล้อง SquareCameraScreen
    final File? capturedFile = await SquareCameraScreen.show(context: context);

    // Restore image cache settings
    PaintingBinding.instance.imageCache.maximumSize = savedMaxSize;
    PaintingBinding.instance.imageCache.maximumSizeBytes = savedMaxBytes;

    if (capturedFile == null || !mounted) return;

    // Preview + หมุนรูปก่อน upload (ใช้ PhotoPreviewScreen เดียวกับ task)
    final File? confirmedFile = await PhotoPreviewScreen.show(
      context: context,
      imageFile: capturedFile,
      photoType: 'measurement',
      mealLabel: widget.entry.config.label,
    );
    if (confirmedFile == null || !mounted) return;

    // Upload ไป Supabase Storage (bucket เดียวกับ task measurement)
    setState(() => _isUploading = true);
    try {
      final bytes = await confirmedFile.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userId =
          Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
      // Path format: measurements/post_{userId}_{timestamp}.jpg
      final storagePath = 'measurements/post_${userId}_$timestamp.jpg';

      await Supabase.instance.client.storage
          .from('med-photos')
          .uploadBinary(storagePath, bytes);

      // ใช้ public URL สำหรับแสดงผลใน app
      final publicUrl = Supabase.instance.client.storage
          .from('med-photos')
          .getPublicUrl(storagePath);

      // ใช้ signed URL สำหรับ AI อ่านค่า (เพราะ bucket อาจไม่ public)
      final signedUrl = await Supabase.instance.client.storage
          .from('med-photos')
          .createSignedUrl(storagePath, 300); // 5 นาที

      if (mounted) {
        // ถ้ามีรูปเก่า → ลบออกจาก preview ก่อน (ป้องกัน duplicate เมื่อถ่ายใหม่)
        final oldPhoto = widget.entry.photoUrl;
        if (oldPhoto != null && oldPhoto.isNotEmpty) {
          widget.onPhotoRemoved?.call(oldPhoto);
        }
        widget.onPhotoChanged(publicUrl);
        // แจ้ง parent เพิ่มรูปใหม่เข้า image preview ของ post
        widget.onPhotoUploaded?.call(publicUrl);
        // === AI อ่านค่าจากรูปอัตโนมัติ ===
        _readValueFromPhoto(signedUrl);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'อัพโหลดรูปไม่สำเร็จ');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  /// เรียก Edge Function ให้ AI อ่านค่าจากรูป → auto-fill ใน input
  Future<void> _readValueFromPhoto(String photoUrl) async {
    if (!mounted) return;
    setState(() => _isReadingAI = true);

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'read-measurement-photo',
        body: {
          'photo_url': photoUrl,
          'measurement_type': widget.entry.measurementType,
        },
      );

      if (!mounted) return;

      final data = response.data;
      debugPrint('AI read-measurement response: $data');
      if (data == null) {
        if (mounted) AppToast.info(context, 'AI ไม่ได้ส่งข้อมูลกลับมา');
        return;
      }

      // parse response — Edge Function return JSON โดยตรง
      final Map<String, dynamic> result = data is String
          ? jsonDecode(data) as Map<String, dynamic>
          : data as Map<String, dynamic>;

      final value = result['value'];
      final confidence = (result['confidence'] as num?)?.toInt() ?? 0;
      final warning = result['warning'] as String?;

      debugPrint('AI read-measurement: value=$value, confidence=$confidence, warning=$warning');

      if (value != null && value is num && confidence >= 50) {
        // Auto-fill ค่าที่ AI อ่านได้
        final valueStr = value is int ? value.toString() : value.toStringAsFixed(1);
        widget.controller.text = valueStr;
        widget.onValueChanged(value.toDouble());
        _validateValue(valueStr);

        if (mounted) {
          AppToast.success(
            context,
            'AI อ่านค่าได้: $valueStr ${widget.entry.config.unit}'
                '${confidence < 70 ? ' (ไม่แน่ใจ กรุณาตรวจสอบ)' : ''}',
          );
        }
      } else if (mounted) {
        // AI อ่านไม่ได้ → แจ้งให้ user กรอกเอง
        AppToast.info(
          context,
          warning ?? 'AI อ่านค่าไม่ได้ กรุณากรอกเอง',
        );
      }
    } catch (e) {
      debugPrint('AI read measurement error: $e');
      if (mounted) {
        AppToast.info(context, 'เชื่อมต่อ AI ไม่ได้ กรุณากรอกค่าเอง');
      }
    } finally {
      if (mounted) {
        setState(() => _isReadingAI = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.entry.config;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === Label ===
          Text(
            config.label,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          AppSpacing.verticalGapSm,

          // === Input + Unit ===
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  autofocus: widget.autoFocus,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    _SingleDotFormatter(),
                  ],
                  style: AppTypography.heading3.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: config.placeholder,
                    hintStyle: AppTypography.heading3.copyWith(
                      color: AppColors.secondaryText.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w400,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.alternate),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.alternate),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  onChanged: (text) {
                    _validateValue(text);
                    final value = double.tryParse(text.trim());
                    widget.onValueChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              // หน่วยวัด
              Text(
                config.unit,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // === Warning (soft validation) ===
          if (_warningText != null) ...[
            AppSpacing.verticalGapXs,
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 14,
                  color: Colors.orange,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _warningText!,
                    style: AppTypography.caption
                        .copyWith(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ],

          // === Photo Section ===
          AppSpacing.verticalGapSm,
          _buildPhotoSection(),
        ],
      ),
    );
  }

  /// Photo section — ถ่ายรูปอุปกรณ์วัด (optional)
  Widget _buildPhotoSection() {
    final photoUrl = widget.entry.photoUrl;

    if (_isUploading) {
      // กำลัง upload — ยังไม่มีรูป
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'กำลังอัพโหลดรูป...',
            style: AppTypography.caption
                .copyWith(color: AppColors.secondaryText),
          ),
        ],
      );
    }

    // AI กำลังอ่านค่า — แสดง preview รูป + spinner ซ้อน
    if (_isReadingAI && photoUrl != null && photoUrl.isNotEmpty) {
      return Row(
        children: [
          // Preview รูป
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: IreneNetworkImage(
              imageUrl: photoUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              memCacheWidth: 96,
              compact: true,
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'AI กำลังอ่านค่า...',
              style: AppTypography.caption
                  .copyWith(color: AppColors.primary),
            ),
          ),
        ],
      );
    }

    if (photoUrl != null && photoUrl.isNotEmpty) {
      // มีรูปแล้ว — แสดง thumbnail + ปุ่มถ่ายใหม่
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: IreneNetworkImage(
              imageUrl: photoUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              memCacheWidth: 96,
              compact: true,
            ),
          ),
          const SizedBox(width: 8),
          HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 4),
          Text(
            'ถ่ายรูปแล้ว',
            style: AppTypography.caption.copyWith(
              color: AppColors.success,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _handleTakePhoto,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'ถ่ายใหม่',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      );
    }

    // ยังไม่มีรูป — แสดงปุ่มถ่ายรูป
    return OutlinedButton.icon(
      onPressed: _handleTakePhoto,
      icon: HugeIcon(
        icon: HugeIcons.strokeRoundedCamera01,
        size: 16,
        color: AppColors.secondaryText,
      ),
      label: Text(
        'ถ่ายรูปอุปกรณ์วัด (แนะนำ)',
        style: AppTypography.caption.copyWith(
          color: AppColors.secondaryText,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        side: BorderSide(color: AppColors.alternate),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// ============================================
// Shared Formatter — อนุญาตจุดทศนิยมได้ไม่เกิน 1 จุด
// ============================================
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
