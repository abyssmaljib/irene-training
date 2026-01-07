import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Widget สำหรับแสดง preview รูปภาพที่เลือก
class ImagePreviewGrid extends StatelessWidget {
  final List<File> localImages;
  final List<String> uploadedUrls;
  final void Function(int index)? onRemoveLocal;
  final void Function(int index)? onRemoveUploaded;
  final VoidCallback? onAddMore;
  final int maxImages;

  const ImagePreviewGrid({
    super.key,
    this.localImages = const [],
    this.uploadedUrls = const [],
    this.onRemoveLocal,
    this.onRemoveUploaded,
    this.onAddMore,
    this.maxImages = 5,
  });

  int get totalImages => localImages.length + uploadedUrls.length;
  bool get canAddMore => totalImages < maxImages;

  @override
  Widget build(BuildContext context) {
    if (totalImages == 0 && onAddMore == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Uploaded images first
          ...uploadedUrls.asMap().entries.map((entry) {
            return _buildUploadedImage(entry.key, entry.value);
          }),

          // Local images
          ...localImages.asMap().entries.map((entry) {
            return _buildLocalImage(entry.key, entry.value);
          }),

          // Add more button
          if (canAddMore && onAddMore != null) _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildLocalImage(int index, File file) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 80,
                  height: 80,
                  color: AppColors.alternate,
                  child: Center(
                    child: HugeIcon(icon: HugeIcons.strokeRoundedImage01, color: AppColors.secondaryText),
                  ),
                );
              },
            ),
          ),

          // Loading overlay (optional - for upload progress)
          // Positioned.fill(
          //   child: Container(
          //     color: Colors.black26,
          //     child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          //   ),
          // ),

          // Remove button
          if (onRemoveLocal != null)
            Positioned(
              top: 4,
              right: 4,
              child: _buildRemoveButton(() => onRemoveLocal!(index)),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadedImage(int index, String url) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppColors.alternate,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.alternate,
                child: Center(
                  child: HugeIcon(icon: HugeIcons.strokeRoundedImage01, color: AppColors.secondaryText),
                ),
              ),
            ),
          ),

          // Uploaded indicator
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(4),
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: Colors.white,
                size: AppIconSize.xs,
              ),
            ),
          ),

          // Remove button
          if (onRemoveUploaded != null)
            Positioned(
              top: 4,
              right: 4,
              child: _buildRemoveButton(() => onRemoveUploaded!(index)),
            ),
        ],
      ),
    );
  }

  Widget _buildRemoveButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedCancelCircle,
          color: Colors.white,
          size: AppIconSize.sm,
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: onAddMore,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.alternate,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              color: AppColors.secondaryText,
              size: AppIconSize.xl,
            ),
            const SizedBox(height: 4),
            Text(
              '$totalImages/$maxImages',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact version สำหรับแสดงใน bottom sheet
class ImagePreviewCompact extends StatelessWidget {
  final List<File> localImages;
  final List<String> uploadedUrls;
  final void Function(int index)? onRemoveLocal;
  final void Function(int index)? onRemoveUploaded;

  const ImagePreviewCompact({
    super.key,
    this.localImages = const [],
    this.uploadedUrls = const [],
    this.onRemoveLocal,
    this.onRemoveUploaded,
  });

  int get totalImages => localImages.length + uploadedUrls.length;

  @override
  Widget build(BuildContext context) {
    if (totalImages == 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Uploaded images first
          ...uploadedUrls.asMap().entries.map((entry) {
            return _buildThumbnail(
              child: CachedNetworkImage(
                imageUrl: entry.value,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
              onRemove:
                  onRemoveUploaded != null ? () => onRemoveUploaded!(entry.key) : null,
              isUploaded: true,
            );
          }),

          // Local images
          ...localImages.asMap().entries.map((entry) {
            return _buildThumbnail(
              child: Image.file(
                entry.value,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
              onRemove:
                  onRemoveLocal != null ? () => onRemoveLocal!(entry.key) : null,
              isUploaded: false,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildThumbnail({
    required Widget child,
    VoidCallback? onRemove,
    bool isUploaded = false,
  }) {
    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: child,
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, color: Colors.white, size: AppIconSize.xs),
                ),
              ),
            ),
          if (isUploaded)
            Positioned(
              bottom: 2,
              left: 2,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: Colors.white, size: AppIconSize.xs),
              ),
            ),
        ],
      ),
    );
  }
}
