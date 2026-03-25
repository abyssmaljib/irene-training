import 'dart:io';
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/network_image.dart';

/// SplitScreenCameraScreen — หน้ากล้อง split-screen สำหรับถ่ายรูป task เทียบกับรูปตัวอย่าง
///
/// Layout:
/// ┌─────────────────────────┐
/// │   รูปตัวอย่าง (zoom ได้)  │  ← ครึ่งบน
/// ├─────────────────────────┤
/// │   Live Camera Preview   │  ← ครึ่งล่าง
/// ├─────────────────────────┤
/// │  ⚡  [◉ ถ่ายรูป]  🔄    │  ← Controls
/// └─────────────────────────┘
///
/// ใช้เฉพาะ task ที่มี sampleImageUrl เท่านั้น
/// ถ้าไม่มี → ใช้กล้อง native ปกติ (image_picker)
class SplitScreenCameraScreen extends StatefulWidget {
  final String sampleImageUrl;

  const SplitScreenCameraScreen({
    super.key,
    required this.sampleImageUrl,
  });

  /// เปิดหน้ากล้อง split-screen
  /// Returns File ที่ถ่ายได้ หรือ null ถ้ายกเลิก
  static Future<File?> show({
    required BuildContext context,
    required String sampleImageUrl,
  }) async {
    return Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (context) => SplitScreenCameraScreen(
          sampleImageUrl: sampleImageUrl,
        ),
      ),
    );
  }

  @override
  State<SplitScreenCameraScreen> createState() =>
      _SplitScreenCameraScreenState();
}

class _SplitScreenCameraScreenState extends State<SplitScreenCameraScreen>
    with WidgetsBindingObserver {
  // กล้อง
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;

  // สถานะ
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Flash mode: cycle auto → on → off
  FlashMode _flashMode = FlashMode.auto;

  // บังคับ 1:1 เสมอ — ทุกรูปใน task detail ใช้อัตราส่วนสี่เหลี่ยมจัตุรัส
  final double _sampleAspectRatio = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ปล่อย memory จาก image cache ก่อนเปิดกล้อง (iOS ใช้ memory สูง)
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // ไม่ต้อง detect ratio อีกแล้ว — บังคับ 1:1 เสมอ
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// จัดการเมื่อแอปถูก pause/resume (เช่น user กด home แล้วกลับมา)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      // ปล่อยกล้องเมื่อแอป inactive
      controller.dispose();
      _controller = null;
      if (mounted) setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      // เปิดกล้องใหม่เมื่อแอปกลับมา
      _initCamera();
    }
  }

  /// เริ่มต้นกล้อง — ค้นหากล้องที่ใช้ได้แล้ว setup controller
  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('ไม่พบกล้องบนอุปกรณ์นี้');
        return;
      }

      // เลือกกล้องหลัง (back camera) เป็นค่าเริ่มต้น
      _currentCameraIndex = 0;
      for (int i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == CameraLensDirection.back) {
          _currentCameraIndex = i;
          break;
        }
      }

      await _setupController(_cameras[_currentCameraIndex]);
    } on CameraException catch (e) {
      _handleCameraException(e);
    } catch (e) {
      _showError('เกิดข้อผิดพลาดกับกล้อง: $e');
    }
  }

  /// ตั้งค่า CameraController สำหรับกล้องที่เลือก
  Future<void> _setupController(CameraDescription camera) async {
    // Dispose controller เก่าก่อน (ป้องกัน race condition)
    final old = _controller;
    _controller = null;
    await old?.dispose();

    final controller = CameraController(
      camera,
      ResolutionPreset.high, // ใช้ high (ไม่ใช่ max) เพื่อ balance quality/memory
      enableAudio: false, // ไม่ต้องการเสียง — ถ่ายรูปอย่างเดียว
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    try {
      await controller.initialize();

      // ล็อค orientation เป็น portrait ระหว่างถ่ายรูป
      // เพื่อให้ EXIF data ถูกต้อง + layout ไม่เพี้ยน
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

      // ตั้ง flash mode ตาม state ปัจจุบัน
      await controller.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } on CameraException catch (e) {
      _handleCameraException(e);
    }
  }

  /// จัดการ CameraException — แปลงเป็นข้อความภาษาไทย
  void _handleCameraException(CameraException e) {
    String message;
    switch (e.code) {
      case 'CameraAccessDenied':
        message = 'ไม่ได้รับอนุญาตให้ใช้กล้อง กรุณาเปิดสิทธิ์ในตั้งค่า';
        break;
      case 'CameraAccessDeniedWithoutPrompt':
        message = 'กรุณาไปที่ตั้งค่า > Irene Training > เปิดสิทธิ์กล้อง';
        break;
      case 'CameraAccessRestricted':
        message = 'สิทธิ์กล้องถูกจำกัด ไม่สามารถใช้งานได้';
        break;
      default:
        message = 'เกิดข้อผิดพลาดกับกล้อง: ${e.description}';
    }
    _showError(message);
  }

  /// แสดง error state — กลับไปหน้าเดิมพร้อมแสดงข้อความ
  void _showError(String message) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = message;
      });
    }
  }

  // ==========================
  // ACTIONS
  // ==========================

  /// ถ่ายรูป → crop เป็น 1:1 (สี่เหลี่ยมจัตุรัส) → return File
  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !_isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final XFile xfile = await controller.takePicture();
      final bytes = await File(xfile.path).readAsBytes();

      // Crop รูปเป็น 1:1 สี่เหลี่ยมจัตุรัส (รันใน isolate ไม่ block UI)
      final croppedBytes = await compute(
        _cropToAspectRatio,
        _CropParams(bytes: bytes, targetAspectRatio: _sampleAspectRatio),
      );

      // บันทึกรูปที่ crop แล้ว
      final dir = await getTemporaryDirectory();
      final croppedFile = File(
        '${dir.path}/split_cam_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await croppedFile.writeAsBytes(croppedBytes);

      if (mounted) {
        // คืน File กลับไป → _handleTakePhoto จะส่งต่อไป PhotoPreviewScreen
        Navigator.pop(context, croppedFile);
      }
    } on CameraException catch (e) {
      debugPrint('SplitScreenCamera: capture error: $e');
      if (mounted) {
        AppToast.error(context, 'ถ่ายรูปไม่สำเร็จ กรุณาลองใหม่');
        setState(() => _isCapturing = false);
      }
    } catch (e) {
      debugPrint('SplitScreenCamera: crop error: $e');
      if (mounted) {
        AppToast.error(context, 'ประมวลผลรูปไม่สำเร็จ กรุณาลองใหม่');
        setState(() => _isCapturing = false);
      }
    }
  }

  /// สลับ flash mode: auto → on → off → auto ...
  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    // Cycle: auto → on → off
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
      default:
        nextMode = FlashMode.auto;
    }

    try {
      await controller.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } on CameraException catch (e) {
      debugPrint('SplitScreenCamera: flash error: $e');
    }
  }

  /// สลับกล้องหน้า/หลัง
  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return; // ถ้ามีกล้องเดียว ไม่ต้อง flip

    setState(() => _isInitialized = false);

    // หากล้องอีกฝั่ง (front ↔ back)
    final currentDirection = _cameras[_currentCameraIndex].lensDirection;
    final targetDirection = currentDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    for (int i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == targetDirection) {
        _currentCameraIndex = i;
        break;
      }
    }

    await _setupController(_cameras[_currentCameraIndex]);
  }

  // ==========================
  // UI HELPERS
  // ==========================

  /// Icon สำหรับ flash mode ปัจจุบัน
  dynamic get _flashIcon {
    switch (_flashMode) {
      case FlashMode.auto:
        return HugeIcons.strokeRoundedFlash;
      case FlashMode.always:
        return HugeIcons.strokeRoundedFlash;
      case FlashMode.off:
        return HugeIcons.strokeRoundedFlashOff;
      default:
        return HugeIcons.strokeRoundedFlash;
    }
  }

  /// Label สำหรับ flash mode ปัจจุบัน
  String get _flashLabel {
    switch (_flashMode) {
      case FlashMode.auto:
        return 'อัตโนมัติ';
      case FlashMode.always:
        return 'เปิด';
      case FlashMode.off:
        return 'ปิด';
      default:
        return 'อัตโนมัติ';
    }
  }

  // ==========================
  // BUILD
  // ==========================

  @override
  Widget build(BuildContext context) {
    // ถ้า error ร้ายแรง → แสดงหน้า error พร้อมปุ่มกลับ
    if (_hasError) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar แบบ custom (เพื่อไม่ให้ใช้พื้นที่มากเกินไป)
            _buildTopBar(),

            // ===== ครึ่งบน: รูปตัวอย่าง =====
            Expanded(
              flex: 1,
              child: _buildSampleImageSection(),
            ),

            // เส้นแบ่ง
            Container(height: 1, color: Colors.white24),

            // ===== ครึ่งล่าง: กล้อง Live Preview =====
            Expanded(
              flex: 1,
              child: _buildCameraPreviewSection(),
            ),

            // ===== Controls Bar =====
            _buildControlsBar(),
          ],
        ),
      ),
    );
  }

  /// Top bar — ปุ่มกลับ + title
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      color: Colors.black,
      child: Row(
        children: [
          // ปุ่มกลับ
          IconButton(
            onPressed: () => Navigator.pop(context, null),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Title
          Expanded(
            child: Text(
              'ถ่ายรูปเทียบตัวอย่าง',
              style: AppTypography.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ครึ่งบน — รูปตัวอย่าง 1:1 (zoom ได้ด้วย InteractiveViewer)
  Widget _buildSampleImageSection() {
    return Stack(
      children: [
        // รูปตัวอย่าง 1:1 — InteractiveViewer ให้ user ซูมดูรายละเอียดได้
        Center(
          child: AspectRatio(
            aspectRatio: 1, // 1:1 สี่เหลี่ยมจัตุรัส
            child: ClipRect(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 3.0, // ซูมได้สูงสุด 3 เท่า
                child: IreneNetworkImage(
                  imageUrl: widget.sampleImageUrl,
                  fit: BoxFit.cover, // cover เพื่อเติมเต็ม 1:1
                  memCacheWidth: 800, // จำกัด memory ไม่ให้โหลดรูปใหญ่เกินไป
                ),
              ),
            ),
          ),
        ),

        // Label "รูปตัวอย่าง" มุมบนซ้าย
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Text(
              'รูปตัวอย่าง',
              style: AppTypography.caption.copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  /// ครึ่งล่าง — Live camera preview (แสดงเป็น 1:1 สี่เหลี่ยมจัตุรัส)
  Widget _buildCameraPreviewSection() {
    final controller = _controller;

    // ยังไม่พร้อม → แสดง loading
    if (!_isInitialized || controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // แสดง camera preview เป็น 1:1 (สี่เหลี่ยมจัตุรัส)
    // ใช้ AspectRatio + ClipRect + FittedBox.cover เพื่อ crop ส่วนที่เกินออก
    return Center(
      child: AspectRatio(
        aspectRatio: _sampleAspectRatio, // 1:1 สี่เหลี่ยมจัตุรัส
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                // ใช้ขนาดจริงของกล้อง เพื่อไม่ให้ภาพบิด
                width: controller.value.previewSize?.height ?? 1,
                height: controller.value.previewSize?.width ?? 1,
                child: CameraPreview(controller),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Controls bar — flash, capture, flip camera
  Widget _buildControlsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: Colors.black87,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Flash toggle
          _buildControlButton(
            icon: _flashIcon,
            label: _flashLabel,
            onTap: _toggleFlash,
          ),

          // ปุ่มถ่ายรูป (วงกลมใหญ่)
          _buildCaptureButton(),

          // Camera flip
          _buildControlButton(
            icon: HugeIcons.strokeRoundedCameraRotated01,
            label: 'กลับกล้อง',
            onTap: _cameras.length >= 2 ? _flipCamera : null,
          ),
        ],
      ),
    );
  }

  /// ปุ่มควบคุม — flash / flip
  Widget _buildControlButton({
    required dynamic icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDisabled ? 0.3 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ปุ่มถ่ายรูป — วงกลมใหญ่ตรงกลาง
  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isCapturing ? null : _capturePhoto,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: _isCapturing
              // กำลังถ่ายอยู่ → แสดง loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              // ปกติ → แสดงวงกลมขาวเต็ม
              : Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  /// หน้า error — แสดงเมื่อกล้อง init ไม่สำเร็จ
  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCamera02,
                  color: Colors.white54,
                  size: 64,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage,
                  style: AppTypography.body.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                // ปุ่มกลับ
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, null),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  label: Text(
                    'กลับ',
                    style: AppTypography.body.copyWith(
                      color: AppColors.primary,
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

// ==========================
// ISOLATE FUNCTIONS (top-level เพราะ compute() ต้องการ top-level function)
// ==========================

/// Parameters สำหรับส่งเข้า isolate (ต้อง serializable)
class _CropParams {
  final Uint8List bytes;
  final double targetAspectRatio; // width / height

  _CropParams({required this.bytes, required this.targetAspectRatio});
}

/// Crop รูปเป็น 1:1 สี่เหลี่ยมจัตุรัส (รันใน isolate ไม่ block UI)
/// ตัดจากตรงกลางของรูป เพื่อให้ได้ส่วนที่สำคัญที่สุด
Uint8List _cropToAspectRatio(_CropParams params) {
  final original = img.decodeImage(params.bytes);
  if (original == null) return params.bytes; // decode ไม่ได้ → คืนรูปเดิม

  final origW = original.width;
  final origH = original.height;
  final origRatio = origW / origH;
  final targetRatio = params.targetAspectRatio;

  // ถ้า ratio ใกล้เคียงกันอยู่แล้ว (ต่างไม่เกิน 5%) → ไม่ต้อง crop
  if ((origRatio - targetRatio).abs() / targetRatio < 0.05) {
    // แค่ resize ถ้าใหญ่เกินไป แล้วคืนเลย
    final resized = origW > 1280
        ? img.copyResize(original, width: 1280)
        : original;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  // คำนวณขนาด crop area ตรงกลาง
  int cropW, cropH;
  if (origRatio > targetRatio) {
    // รูปกว้างเกินไป → ตัดซ้าย-ขวา
    cropH = origH;
    cropW = (origH * targetRatio).round();
  } else {
    // รูปสูงเกินไป → ตัดบน-ล่าง
    cropW = origW;
    cropH = (origW / targetRatio).round();
  }

  // Crop จากตรงกลาง
  final x = ((origW - cropW) / 2).round();
  final y = ((origH - cropH) / 2).round();
  var cropped = img.copyCrop(original, x: x, y: y, width: cropW, height: cropH);

  // Resize ถ้าใหญ่เกินไป (จำกัด 1280px เพื่อประหยัด storage)
  if (cropped.width > 1280) {
    cropped = img.copyResize(cropped, width: 1280);
  }

  return Uint8List.fromList(img.encodeJpg(cropped, quality: 85));
}
