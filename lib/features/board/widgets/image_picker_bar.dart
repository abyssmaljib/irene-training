import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';

/// Bottom bar สำหรับเลือกรูปภาพ/วีดีโอ (Camera + Gallery + Video)
class ImagePickerBar extends StatelessWidget {
  final VoidCallback? onCameraTap;
  final VoidCallback? onGalleryTap;
  final VoidCallback? onVideoTap;
  final bool isLoading;
  final bool disabled;

  const ImagePickerBar({
    super.key,
    this.onCameraTap,
    this.onGalleryTap,
    this.onVideoTap,
    this.isLoading = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Camera button
        _buildIconButton(
          icon: Iconsax.camera,
          onTap: disabled || isLoading ? null : onCameraTap,
          tooltip: 'ถ่ายรูป',
        ),
        const SizedBox(width: 8),

        // Gallery button
        _buildIconButton(
          icon: Iconsax.gallery,
          onTap: disabled || isLoading ? null : onGalleryTap,
          tooltip: 'เลือกจากแกลเลอรี่',
        ),
        const SizedBox(width: 8),

        // Video button
        _buildIconButton(
          icon: Iconsax.video,
          onTap: disabled || isLoading ? null : onVideoTap,
          tooltip: 'เลือกวีดีโอ',
        ),

        // Loading indicator
        if (isLoading) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final isDisabled = onTap == null;

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: isDisabled ? AppColors.alternate : AppColors.accent1,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: isDisabled ? AppColors.secondaryText : AppColors.primary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper class สำหรับ pick images
class ImagePickerHelper {
  static final _picker = ImagePicker();

  /// ถ่ายรูปจากกล้อง
  static Future<File?> pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
    }
    return null;
  }

  /// เลือกรูปจาก gallery (หลายรูป)
  static Future<List<File>> pickFromGallery({int maxImages = 5}) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      // Limit number of images
      final limited = images.take(maxImages).toList();
      return limited.map((x) => File(x.path)).toList();
    } catch (e) {
      debugPrint('Error picking images from gallery: $e');
    }
    return [];
  }

  /// เลือกรูปเดียวจาก gallery
  static Future<File?> pickSingleFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
    }
    return null;
  }

  /// เลือกวีดีโอจาก gallery
  static Future<File?> pickVideoFromGallery({
    Duration maxDuration = const Duration(minutes: 3),
  }) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: maxDuration,
      );
      if (video != null) {
        return File(video.path);
      }
    } catch (e) {
      debugPrint('Error picking video from gallery: $e');
    }
    return null;
  }

  /// ถ่ายวีดีโอจากกล้อง
  static Future<File?> pickVideoFromCamera({
    Duration maxDuration = const Duration(minutes: 1),
  }) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: maxDuration,
      );
      if (video != null) {
        return File(video.path);
      }
    } catch (e) {
      debugPrint('Error recording video: $e');
    }
    return null;
  }
}
