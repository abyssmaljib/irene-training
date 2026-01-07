import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image/image.dart' as img;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// หน้า Preview รูปก่อน upload
/// ให้ user ดูรูป หมุนรูป และยืนยันก่อน upload
class PhotoPreviewScreen extends StatefulWidget {
  final File imageFile;
  final String photoType; // '2C' หรือ '3C'
  final String mealLabel; // ชื่อมื้อสำหรับแสดง

  const PhotoPreviewScreen({
    super.key,
    required this.imageFile,
    required this.photoType,
    required this.mealLabel,
  });

  /// แสดงหน้า preview และรอผลลัพธ์
  /// Returns File ที่หมุนแล้ว (ถ้าหมุน) หรือ null ถ้ายกเลิก
  static Future<File?> show({
    required BuildContext context,
    required File imageFile,
    required String photoType,
    required String mealLabel,
  }) async {
    return Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoPreviewScreen(
          imageFile: imageFile,
          photoType: photoType,
          mealLabel: mealLabel,
        ),
      ),
    );
  }

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  int _rotationAngle = 0; // 0, 90, 180, 270
  bool _isProcessing = false;
  late File _currentFile;
  Uint8List? _imageBytes; // สำหรับ Web ที่ใช้ Image.file ไม่ได้

  @override
  void initState() {
    super.initState();
    _currentFile = widget.imageFile;
    _loadImageBytes();
  }

  /// โหลด bytes จากไฟล์สำหรับแสดงบน Web
  Future<void> _loadImageBytes() async {
    // โหลด bytes สำหรับ Web (Image.file ไม่รองรับ)
    // และเก็บไว้ใช้กับทุก platform เผื่อมีปัญหา
    try {
      final bytes = await _currentFile.readAsBytes();
      if (mounted) {
        setState(() => _imageBytes = bytes);
      }
    } catch (e) {
      debugPrint('PhotoPreviewScreen: Failed to load image bytes: $e');
    }
  }

  void _rotateRight() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
    });
  }

  void _rotateLeft() {
    setState(() {
      _rotationAngle = (_rotationAngle - 90) % 360;
      if (_rotationAngle < 0) _rotationAngle += 360;
    });
  }

  Future<void> _confirm() async {
    // ถ้าไม่ได้หมุน ส่งไฟล์เดิมกลับ
    if (_rotationAngle == 0) {
      Navigator.pop(context, _currentFile);
      return;
    }

    // ถ้าหมุน ต้อง process รูป
    setState(() => _isProcessing = true);

    try {
      final rotatedFile = await _rotateImage(_currentFile, _rotationAngle);
      if (mounted) {
        Navigator.pop(context, rotatedFile);
      }
    } catch (e) {
      debugPrint('Error rotating image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถหมุนรูปได้'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  /// หมุนรูปและบันทึกเป็นไฟล์ใหม่
  Future<File> _rotateImage(File file, int angle) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Cannot decode image');
    }

    img.Image rotated;
    switch (angle) {
      case 90:
        rotated = img.copyRotate(image, angle: 90);
        break;
      case 180:
        rotated = img.copyRotate(image, angle: 180);
        break;
      case 270:
        rotated = img.copyRotate(image, angle: 270);
        break;
      default:
        rotated = image;
    }

    // Encode เป็น JPEG
    final rotatedBytes = img.encodeJpg(rotated, quality: 85);

    // บันทึกเป็นไฟล์ใหม่
    final newPath = file.path.replaceAll('.jpg', '_rotated.jpg');
    final newFile = File(newPath);
    await newFile.writeAsBytes(Uint8List.fromList(rotatedBytes));

    return newFile;
  }

  /// สร้าง Image widget ที่รองรับทั้ง Web และ Mobile/Desktop
  Widget _buildImageWidget() {
    // ใช้ Image.memory เป็นหลักเพราะรองรับทุก platform
    // Image.file ไม่รองรับ Web
    if (_imageBytes != null) {
      return Image.memory(
        _imageBytes!,
        fit: BoxFit.contain,
      );
    }

    // กำลังโหลด bytes
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    // กำหนดสีและ label ตาม photoType
    Color borderColor;
    String typeLabel;
    switch (widget.photoType) {
      case '2C':
        borderColor = const Color(0xFF0EA5E9);
        typeLabel = 'จัดยา';
        break;
      case '3C':
        borderColor = const Color(0xFF10B981);
        typeLabel = 'เสิร์ฟยา';
        break;
      case 'task':
        borderColor = const Color(0xFF0D9488); // Primary teal
        typeLabel = 'ถ่ายรูปงาน';
        break;
      default:
        borderColor = const Color(0xFF0D9488);
        typeLabel = 'ถ่ายรูป';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '$typeLabel - ${widget.mealLabel}',
          style: AppTypography.title.copyWith(color: Colors.white),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context, null),
          icon: HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // รูป Preview
            Expanded(
              child: Center(
                child: Transform.rotate(
                  angle: _rotationAngle * 3.14159 / 180,
                  child: _buildImageWidget(),
                ),
              ),
            ),

            // Controls
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.black87,
                border: Border(
                  top: BorderSide(color: Colors.white24),
                ),
              ),
              child: Column(
                children: [
                  // ปุ่มหมุน
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRotateButton(
                        icon: HugeIcons.strokeRoundedRotateLeft01,
                        label: 'หมุนซ้าย',
                        onTap: _isProcessing ? null : _rotateLeft,
                      ),
                      SizedBox(width: AppSpacing.xl),
                      _buildRotateButton(
                        icon: HugeIcons.strokeRoundedRotateRight01,
                        label: 'หมุนขวา',
                        onTap: _isProcessing ? null : _rotateRight,
                      ),
                    ],
                  ),

                  SizedBox(height: AppSpacing.lg),

                  // ปุ่มยืนยัน/ยกเลิก
                  Row(
                    children: [
                      // ยกเลิก
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () => Navigator.pop(context, null),
                          icon: HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle),
                          label: const Text('ถ่ายใหม่'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(color: Colors.white30),
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      // ยืนยัน
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _confirm,
                          icon: _isProcessing
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkSquare02),
                          label: Text(_isProcessing ? 'กำลังประมวลผล...' : 'ยืนยัน'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: borderColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRotateButton({
    required dynamic icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, color: Colors.white, size: AppIconSize.xl),
            SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
