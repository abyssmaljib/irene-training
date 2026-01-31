import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/network_image.dart';
import '../../board/widgets/image_picker_bar.dart';

/// Widget สำหรับเลือกรูปโปรไฟล์
/// แสดงเป็นวงกลม พร้อม icon กล้องมุมขวาล่าง
/// กดแล้วแสดง bottom sheet ให้เลือกจากกล้องหรือ gallery
class ProfilePhotoPicker extends StatelessWidget {
  /// URL รูปปัจจุบัน (จาก network)
  final String? currentPhotoUrl;

  /// ไฟล์รูปที่เลือกใหม่ (ยังไม่ upload)
  final File? selectedPhoto;

  /// Callback เมื่อเลือกรูปใหม่
  final ValueChanged<File?> onPhotoSelected;

  /// กำลัง upload รูปอยู่หรือไม่
  final bool isUploading;

  /// ขนาดของ avatar
  final double size;

  const ProfilePhotoPicker({
    super.key,
    this.currentPhotoUrl,
    this.selectedPhoto,
    required this.onPhotoSelected,
    this.isUploading = false,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : () => _showPicker(context),
      child: Stack(
        children: [
          // รูป avatar
          _buildAvatar(),

          // Icon กล้องมุมขวาล่าง
          Positioned(
            right: 0,
            bottom: 0,
            child: _buildCameraIcon(),
          ),

          // Loading overlay
          if (isUploading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    // ถ้ามีรูปที่เลือกใหม่ แสดงจาก file
    if (selectedPhoto != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary,
            width: 3,
          ),
        ),
        child: ClipOval(
          child: Image.file(
            selectedPhoto!,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // ถ้ามี URL รูปเดิม แสดงจาก network
    if (currentPhotoUrl != null && currentPhotoUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary,
            width: 3,
          ),
        ),
        child: ClipOval(
          child: IreneNetworkImage(
            imageUrl: currentPhotoUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            memCacheWidth: (size * 2).toInt(),
          ),
        ),
      );
    }

    // ถ้าไม่มีรูป แสดง placeholder
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent1,
        border: Border.all(
          color: AppColors.primary,
          width: 3,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedUser,
            color: AppColors.primary,
            size: size * 0.35,
          ),
          const SizedBox(height: 4),
          Text(
            'แตะเพื่อเพิ่มรูป',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraIcon() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
      ),
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedCamera01,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.5),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PhotoPickerSheet(
        onPhotoSelected: (file) {
          Navigator.pop(context);
          onPhotoSelected(file);
        },
        onRemovePhoto: currentPhotoUrl != null || selectedPhoto != null
            ? () {
                Navigator.pop(context);
                onPhotoSelected(null);
              }
            : null,
      ),
    );
  }
}

/// Bottom sheet สำหรับเลือกรูป
class _PhotoPickerSheet extends StatelessWidget {
  final ValueChanged<File?> onPhotoSelected;
  final VoidCallback? onRemovePhoto;

  const _PhotoPickerSheet({
    required this.onPhotoSelected,
    this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.alternate,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AppSpacing.verticalGapMd,

              // Title
              Text(
                'เลือกรูปโปรไฟล์',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              AppSpacing.verticalGapLg,

              // Camera option
              _buildOption(
                icon: HugeIcons.strokeRoundedCamera01,
                label: 'ถ่ายรูป',
                onTap: () async {
                  final file = await ImagePickerHelper.pickFromCamera();
                  if (file != null) {
                    onPhotoSelected(file);
                  }
                },
              ),
              AppSpacing.verticalGapSm,

              // Gallery option
              _buildOption(
                icon: HugeIcons.strokeRoundedImage01,
                label: 'เลือกจากแกลเลอรี่',
                onTap: () async {
                  final file = await ImagePickerHelper.pickSingleFromGallery();
                  if (file != null) {
                    onPhotoSelected(file);
                  }
                },
              ),

              // Remove photo option (ถ้ามีรูปอยู่)
              if (onRemovePhoto != null) ...[
                AppSpacing.verticalGapSm,
                _buildOption(
                  icon: HugeIcons.strokeRoundedDelete02,
                  label: 'ลบรูปโปรไฟล์',
                  onTap: onRemovePhoto!,
                  isDestructive: true,
                ),
              ],

              AppSpacing.verticalGapMd,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : AppColors.primaryText;

    return Material(
      color: AppColors.accent1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
