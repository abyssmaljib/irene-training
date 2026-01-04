import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/post.dart';
import '../providers/edit_post_provider.dart';
import '../providers/post_provider.dart';
import '../services/post_action_service.dart';
import '../services/post_media_service.dart';
import '../widgets/image_picker_bar.dart' show ImagePickerHelper;
import '../widgets/image_preview_grid.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Advanced Edit Post Screen - Full page version for editing posts with title/quiz
class AdvancedEditPostScreen extends ConsumerStatefulWidget {
  final Post post;
  final VoidCallback? onPostUpdated;

  const AdvancedEditPostScreen({
    super.key,
    required this.post,
    this.onPostUpdated,
  });

  @override
  ConsumerState<AdvancedEditPostScreen> createState() =>
      _AdvancedEditPostScreenState();
}

class _AdvancedEditPostScreenState
    extends ConsumerState<AdvancedEditPostScreen> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing post data
    _titleController.text = widget.post.title ?? '';
    _textController.text = widget.post.text ?? '';

    // Initialize provider state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(editPostProvider(widget.post.id).notifier)
          .initFromPost(widget.post);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    final file = await ImagePickerHelper.pickFromCamera();
    if (file != null && mounted) {
      ref.read(editPostProvider(widget.post.id).notifier).addNewImages([file]);
    }
  }

  Future<void> _pickFromGallery() async {
    final state = ref.read(editPostProvider(widget.post.id));
    final remaining = state.remainingImageSlots;

    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สูงสุด 5 รูป')),
      );
      return;
    }

    final files = await ImagePickerHelper.pickFromGallery(maxImages: remaining);
    if (files.isNotEmpty && mounted) {
      ref.read(editPostProvider(widget.post.id).notifier).addNewImages(files);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(editPostProvider(widget.post.id));
    final text = _textController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาใส่รายละเอียด')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');

      // Upload new images if any
      List<String> finalImageUrls = [...state.finalExistingUrls];
      if (state.newImages.isNotEmpty) {
        final uploadedUrls = await PostMediaService.instance.uploadImages(
          state.newImages,
          userId: userId,
        );
        finalImageUrls.addAll(uploadedUrls);
      }

      // Update post
      final success = await PostActionService.instance.updatePost(
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกสำเร็จ')),
          );
          Navigator.of(context).pop(true);
          widget.onPostUpdated?.call();
        }
      } else {
        throw Exception('Failed to update post');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editPostProvider(widget.post.id));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'แก้ไขโพส',
          style: AppTypography.title.copyWith(color: AppColors.primaryText),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title field
              _buildSectionLabel('หัวข้อ (ถ้ามี)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                maxLength: 30,
                decoration: InputDecoration(
                  hintText: 'หัวข้อประกาศ',
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
                  counterStyle: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                style: AppTypography.body,
              ),

              AppSpacing.verticalGapLg,

              // Description field
              _buildSectionLabel('รายละเอียด', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _textController,
                maxLines: 6,
                minLines: 4,
                decoration: InputDecoration(
                  hintText: 'เขียนรายละเอียดที่นี่...',
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณาใส่รายละเอียด';
                  }
                  return null;
                },
              ),

              AppSpacing.verticalGapLg,

              // Divider
              Divider(color: AppColors.alternate, height: 1),

              AppSpacing.verticalGapLg,

              // Quiz info (read-only if exists)
              if (widget.post.hasQuiz) ...[
                _buildQuizReadOnly(),
                AppSpacing.verticalGapLg,
                Divider(color: AppColors.alternate, height: 1),
                AppSpacing.verticalGapLg,
              ],

              // Read-only info (tag, resident)
              _buildReadOnlyInfo(),

              AppSpacing.verticalGapLg,

              // Existing images
              if (state.existingImageUrls.isNotEmpty) ...[
                _buildSectionLabel('รูปภาพเดิม'),
                const SizedBox(height: 8),
                _buildExistingImages(state),
                AppSpacing.verticalGapMd,
              ],

              // New images
              if (state.newImages.isNotEmpty) ...[
                _buildSectionLabel('รูปภาพใหม่'),
                const SizedBox(height: 8),
                ImagePreviewCompact(
                  localImages: state.newImages,
                  uploadedUrls: const [],
                  onRemoveLocal: (index) {
                    ref
                        .read(editPostProvider(widget.post.id).notifier)
                        .removeNewImage(index);
                  },
                  onRemoveUploaded: (_) {},
                ),
                AppSpacing.verticalGapMd,
              ],

              // Bottom padding for safe area
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(state),
    );
  }

  Widget _buildBottomBar(EditPostState state) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canSubmit =
        _textController.text.trim().isNotEmpty && !_isSubmitting;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.alternate),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Media picker buttons
            Wrap(
              spacing: 8,
              children: [
                _buildIconButton(
                  icon: Iconsax.camera,
                  onTap: _isSubmitting || !state.canAddMoreImages
                      ? null
                      : _pickFromCamera,
                  tooltip: 'ถ่ายรูป',
                ),
                _buildIconButton(
                  icon: Iconsax.gallery,
                  onTap: _isSubmitting || !state.canAddMoreImages
                      ? null
                      : _pickFromGallery,
                  tooltip: 'เลือกจากแกลเลอรี่',
                ),
              ],
            ),
            const Spacer(),
            // Submit button
            ElevatedButton(
              onPressed: canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.alternate,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
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

  Widget _buildSectionLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.subtitle.copyWith(
            color: AppColors.primaryText,
          ),
        ),
        if (required)
          Text(
            ' *',
            style: AppTypography.subtitle.copyWith(
              color: AppColors.error,
            ),
          ),
      ],
    );
  }

  Widget _buildQuizReadOnly() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.message_question, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'คำถาม Quiz (แก้ไขไม่ได้)',
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
          Text(
            widget.post.qaQuestion ?? '',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          AppSpacing.verticalGapSm,
          if (widget.post.qaChoiceA != null)
            _buildQuizChoice('A', widget.post.qaChoiceA!),
          if (widget.post.qaChoiceB != null)
            _buildQuizChoice('B', widget.post.qaChoiceB!),
          if (widget.post.qaChoiceC != null)
            _buildQuizChoice('C', widget.post.qaChoiceC!),
        ],
      ),
    );
  }

  Widget _buildQuizChoice(String label, String text) {
    final isCorrect = widget.post.qaAnswer == label;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCorrect ? AppColors.success : AppColors.alternate,
              shape: BoxShape.circle,
            ),
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isCorrect ? Colors.white : AppColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(
                color: isCorrect ? AppColors.success : AppColors.secondaryText,
              ),
            ),
          ),
          if (isCorrect)
            Icon(Iconsax.verify, color: AppColors.success, size: 16),
        ],
      ),
    );
  }

  Widget _buildReadOnlyInfo() {
    final hasTag =
        widget.post.postTags.isNotEmpty || widget.post.postTagsString != null;
    final hasResident = widget.post.residentName != null &&
        widget.post.residentName!.isNotEmpty;

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
    return SizedBox(
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
                            .read(editPostProvider(widget.post.id).notifier)
                            .restoreExistingImage(index);
                      } else {
                        ref
                            .read(editPostProvider(widget.post.id).notifier)
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
    );
  }
}
