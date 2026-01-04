import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/post.dart';
import '../providers/edit_post_provider.dart';
import '../providers/post_provider.dart';
import '../services/post_media_service.dart';
import '../screens/advanced_edit_post_screen.dart';
import 'image_picker_bar.dart';
import 'create_post_bottom_sheet.dart' show navigateToAdvancedPostScreen;

/// Bottom Sheet สำหรับแก้ไขโพส (พื้นฐาน)
class EditPostBottomSheet extends ConsumerStatefulWidget {
  final Post post;
  final VoidCallback? onPostUpdated;
  final VoidCallback? onAdvancedTap;

  const EditPostBottomSheet({
    super.key,
    required this.post,
    this.onPostUpdated,
    this.onAdvancedTap,
  });

  @override
  ConsumerState<EditPostBottomSheet> createState() =>
      _EditPostBottomSheetState();
}

class _EditPostBottomSheetState extends ConsumerState<EditPostBottomSheet> {
  final _textController = TextEditingController();
  final _titleController = TextEditingController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing post data
    _textController.text = widget.post.text ?? '';
    _titleController.text = widget.post.title ?? '';

    // Initialize provider state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(editPostProvider(widget.post.id).notifier)
          .initFromPost(widget.post);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editPostProvider(widget.post.id));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.alternate,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            _buildHeader(),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title input (optional)
                    if (widget.post.title != null &&
                        widget.post.title!.isNotEmpty)
                      _buildTitleInput(),

                    // Text input
                    _buildTextInput(),
                    AppSpacing.verticalGapMd,

                    // Read-only info (tag, resident)
                    _buildReadOnlyInfo(),
                    AppSpacing.verticalGapMd,

                    // Existing images
                    if (state.existingImageUrls.isNotEmpty)
                      _buildExistingImages(state),

                    // New images
                    if (state.newImages.isNotEmpty) _buildNewImages(state),

                    // Error message
                    if (state.error != null) ...[
                      AppSpacing.verticalGapSm,
                      Text(
                        state.error!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],

                    AppSpacing.verticalGapMd,
                  ],
                ),
              ),
            ),

            // Bottom bar
            _buildBottomBar(state),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Text(
            'แก้ไขโพส',
            style: AppTypography.title,
          ),
          const Spacer(),

          // Advanced button
          if (widget.onAdvancedTap != null)
            TextButton.icon(
              onPressed: () {
                // Navigate to advanced edit screen
                navigateToAdvancedPostScreen(
                  context,
                  advancedScreen: AdvancedEditPostScreen(
                    post: widget.post,
                    onPostUpdated: widget.onPostUpdated,
                  ),
                );
              },
              icon: const Icon(Iconsax.edit_2, size: 16),
              label: const Text('แบบละเอียด'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: AppTypography.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'หัวข้อ',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        AppSpacing.verticalGapSm,
        TextField(
          controller: _titleController,
          maxLines: 1,
          decoration: InputDecoration(
            hintText: 'หัวข้อโพส',
            hintStyle: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          onChanged: (value) {
            ref
                .read(editPostProvider(widget.post.id).notifier)
                .setTitle(value.isEmpty ? null : value);
          },
        ),
        AppSpacing.verticalGapMd,
      ],
    );
  }

  Widget _buildTextInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'เนื้อหา',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        AppSpacing.verticalGapSm,
        TextField(
          controller: _textController,
          maxLines: 5,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'เขียนข้อความที่นี่...',
            hintStyle: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: AppTypography.body,
          onChanged: (value) {
            ref.read(editPostProvider(widget.post.id).notifier).setText(value);
          },
        ),
      ],
    );
  }

  Widget _buildReadOnlyInfo() {
    final hasTag =
        widget.post.postTags.isNotEmpty || widget.post.postTagsString != null;
    final hasResident =
        widget.post.residentName != null && widget.post.residentName!.isNotEmpty;

    if (!hasTag && !hasResident) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ข้อมูลที่แก้ไขไม่ได้',
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          AppSpacing.verticalGapSm,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Tag
              if (hasTag)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent1,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.tag, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        widget.post.postTagsString ??
                            widget.post.postTags.join(', '),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              // Resident
              if (hasResident)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent1,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.user, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        widget.post.residentName!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExistingImages(EditPostState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รูปภาพเดิม',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        AppSpacing.verticalGapSm,
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: state.existingImageUrls.length,
            itemBuilder: (context, index) {
              final url = state.existingImageUrls[index];
              final isRemoved = state.removedExistingIndexes.contains(index);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    // Image
                    Opacity(
                      opacity: isRemoved ? 0.3 : 1.0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 100,
                            height: 100,
                            color: AppColors.background,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 100,
                            height: 100,
                            color: AppColors.background,
                            child: Icon(
                              Iconsax.image,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Remove/Restore button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          if (isRemoved) {
                            ref
                                .read(
                                    editPostProvider(widget.post.id).notifier)
                                .restoreExistingImage(index);
                          } else {
                            ref
                                .read(
                                    editPostProvider(widget.post.id).notifier)
                                .removeExistingImage(index);
                          }
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isRemoved
                                ? AppColors.success
                                : Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isRemoved ? Iconsax.refresh : Iconsax.close_circle,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                    // Removed overlay
                    if (isRemoved)
                      Positioned.fill(
                        child: Center(
                          child: Icon(
                            Iconsax.trash,
                            color: AppColors.error,
                            size: 32,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        AppSpacing.verticalGapMd,
      ],
    );
  }

  Widget _buildNewImages(EditPostState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รูปภาพใหม่',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        AppSpacing.verticalGapSm,
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: state.newImages.length,
            itemBuilder: (context, index) {
              final file = state.newImages[index];

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        file,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Remove button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          ref
                              .read(editPostProvider(widget.post.id).notifier)
                              .removeNewImage(index);
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Iconsax.close_circle,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        AppSpacing.verticalGapMd,
      ],
    );
  }

  Widget _buildBottomBar(EditPostState state) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.alternate),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Image picker buttons
          Wrap(
            spacing: 8,
            children: [
              _buildIconButton(
                icon: Iconsax.camera,
                onTap: _isUploading || state.isSubmitting || !state.canAddMoreImages
                    ? null
                    : _pickFromCamera,
                tooltip: 'ถ่ายรูป',
              ),
              _buildIconButton(
                icon: Iconsax.gallery,
                onTap: _isUploading || state.isSubmitting || !state.canAddMoreImages
                    ? null
                    : _pickFromGallery,
                tooltip: 'เลือกจากแกลเลอรี่',
              ),
            ],
          ),

          // Submit button
          ElevatedButton(
            onPressed: state.isSubmitting || !_canSubmit()
                ? null
                : () => _handleSubmit(state),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.alternate,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: state.isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'บันทึก',
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

  bool _canSubmit() {
    return _textController.text.trim().isNotEmpty;
  }

  Future<void> _pickFromCamera() async {
    final file = await ImagePickerHelper.pickFromCamera();
    if (file != null) {
      ref.read(editPostProvider(widget.post.id).notifier).addNewImages([file]);
    }
  }

  Future<void> _pickFromGallery() async {
    final state = ref.read(editPostProvider(widget.post.id));
    final remaining = state.remainingImageSlots;

    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เลือกรูปได้สูงสุด 5 รูป')),
      );
      return;
    }

    final files = await ImagePickerHelper.pickFromGallery(maxImages: remaining);
    if (files.isNotEmpty) {
      ref
          .read(editPostProvider(widget.post.id).notifier)
          .addNewImages(files);
    }
  }

  Future<void> _handleSubmit(EditPostState state) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    ref.read(editPostProvider(widget.post.id).notifier).setSubmitting(true);

    try {
      final actionService = ref.read(postActionServiceProvider);
      final userId = ref.read(currentUserIdProvider);

      if (userId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      // Upload new images if any
      List<String> finalImageUrls = [...state.finalExistingUrls];

      if (state.newImages.isNotEmpty) {
        setState(() => _isUploading = true);

        final newUrls = await PostMediaService.instance.uploadImages(
          state.newImages,
          userId: userId,
        );
        finalImageUrls.addAll(newUrls);

        setState(() => _isUploading = false);
      }

      // Update post
      final success = await actionService.updatePost(
        postId: widget.post.id,
        text: text,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        multiImgUrl: finalImageUrls.isEmpty ? null : finalImageUrls,
      );

      if (success) {
        // Refresh posts
        refreshPosts(ref);
        ref.invalidate(postDetailProvider(widget.post.id));

        if (mounted) {
          Navigator.pop(context);
          widget.onPostUpdated?.call();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกสำเร็จ')),
          );
        }
      } else {
        throw Exception('ไม่สามารถบันทึกได้');
      }
    } catch (e) {
      ref
          .read(editPostProvider(widget.post.id).notifier)
          .setError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      ref.read(editPostProvider(widget.post.id).notifier).setSubmitting(false);
    }
  }
}

/// Helper function to show edit post bottom sheet
void showEditPostBottomSheet(
  BuildContext context,
  Post post, {
  VoidCallback? onPostUpdated,
  VoidCallback? onAdvancedTap,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => EditPostBottomSheet(
        post: post,
        onPostUpdated: onPostUpdated,
        onAdvancedTap: onAdvancedTap,
      ),
    ),
  );
}

/// Navigate to advanced edit post screen (for posts with title/quiz)
void navigateToAdvancedEditPostScreen(
  BuildContext context,
  Post post, {
  VoidCallback? onPostUpdated,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AdvancedEditPostScreen(
        post: post,
        onPostUpdated: onPostUpdated,
      ),
    ),
  );
}
