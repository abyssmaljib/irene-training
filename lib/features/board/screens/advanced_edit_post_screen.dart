import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/checkbox_tile.dart';
import '../models/post.dart';
import '../providers/edit_post_provider.dart';
import '../providers/post_provider.dart';
import '../providers/tag_provider.dart';
import '../services/post_action_service.dart';
import '../services/post_media_service.dart';
import '../widgets/image_picker_bar.dart' show ImagePickerHelper;
import '../widgets/image_preview_grid.dart';
import '../widgets/edit_ai_summary_widget.dart';
import '../widgets/edit_quiz_form_widget.dart';
import '../widgets/tag_picker_widget.dart';
import '../widgets/resident_picker_widget.dart';
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

  // เก็บค่าเริ่มต้นเพื่อเปรียบเทียบว่ามีการแก้ไขหรือไม่
  String _initialText = '';
  String _initialTitle = '';

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing post data
    _titleController.text = widget.post.title ?? '';
    _textController.text = widget.post.text ?? '';

    // เก็บค่าเริ่มต้น
    _initialText = widget.post.text ?? '';
    _initialTitle = widget.post.title ?? '';

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

  // ============================================================
  // Unsaved Changes Detection
  // ============================================================

  /// ตรวจสอบว่ามีการแก้ไขหรือไม่
  bool _hasUnsavedChanges() {
    final state = ref.read(editPostProvider(widget.post.id));

    // เช็คว่า text หรือ title เปลี่ยนไหม
    final textChanged = _textController.text != _initialText;
    final titleChanged = _titleController.text != _initialTitle;

    // เช็คว่ามีการเปลี่ยนแปลงใน state (รูป, tag, resident, handover)
    final stateChanged = state.hasTagChanged ||
        state.hasResidentChanged ||
        state.newImages.isNotEmpty ||
        state.removedExistingIndexes.isNotEmpty ||
        state.isHandover != widget.post.isHandover;

    return textChanged || titleChanged || stateChanged;
  }

  /// จัดการเมื่อ user พยายามปิด screen
  /// ใช้ ConfirmDialog.show() จาก reusable widget
  Future<bool> _handleCloseAttempt() async {
    if (!_hasUnsavedChanges()) return true;

    // ใช้ ConfirmDialog.show() กับ exitEdit preset
    final confirmed = await ConfirmDialog.show(
      context,
      type: ConfirmDialogType.exitEdit,
      barrierDismissible: false,
    );

    // confirmed = true หมายถึง user กด "ยกเลิกการแก้ไข" (ปิด screen)
    // confirmed = false หมายถึง user กด "กลับไปแก้ไข" (ไม่ปิด)
    return confirmed;
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

      // เตรียมข้อมูล tag และ resident (ถ้ามีการเปลี่ยนแปลง)
      // tag: ส่งชื่อ tag ใหม่ ถ้ามีการเปลี่ยนแปลง
      String? tagName;
      if (state.hasTagChanged && state.selectedTag != null) {
        tagName = state.selectedTag!.name;
      }

      // resident: ส่ง -1 ถ้าลบ resident, ส่ง id ใหม่ ถ้าเปลี่ยน, null ถ้าไม่เปลี่ยน
      int? residentId;
      if (state.hasResidentChanged) {
        residentId = state.residentId ?? -1; // -1 = ลบ resident
      }

      // is_handover: ส่งค่าใหม่ถ้ามีการเปลี่ยนแปลง
      bool? isHandover;
      if (state.isHandover != widget.post.isHandover) {
        isHandover = state.isHandover;
      }

      // Update post with quiz fields and tag/resident
      final success = await PostActionService.instance.updatePost(
        postId: widget.post.id,
        text: text,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        multiImgUrl: finalImageUrls.isEmpty ? null : finalImageUrls,
        // Quiz fields
        existingQaId: state.qaId,
        qaQuestion: state.qaQuestion,
        qaChoiceA: state.qaChoiceA,
        qaChoiceB: state.qaChoiceB,
        qaChoiceC: state.qaChoiceC,
        qaAnswer: state.qaAnswer,
        // Tag and Resident updates (for shift leader+)
        tagName: tagName,
        residentId: residentId,
        isHandover: isHandover,
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldClose = await _handleCloseAttempt();
        if (shouldClose && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.surface,
      appBar: IreneSecondaryAppBar(
        title: 'แก้ไขโพส',
        backgroundColor: AppColors.surface,
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
                maxLines: null,
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

              AppSpacing.verticalGapMd,

              // AI Summary widget
              EditAiSummaryWidget(
                postId: widget.post.id,
                textController: _textController,
                onReplaceText: () {
                  // Already handled in the widget
                },
              ),

              AppSpacing.verticalGapLg,

              // Divider
              Divider(color: AppColors.alternate, height: 1),

              AppSpacing.verticalGapLg,

              // Quiz form (editable)
              EditQuizFormWidget(
                postId: widget.post.id,
                postText: _textController.text,
              ),

              AppSpacing.verticalGapLg,

              // Divider
              Divider(color: AppColors.alternate, height: 1),

              AppSpacing.verticalGapLg,

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
    ),
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
                  icon: HugeIcons.strokeRoundedCamera01,
                  onTap: _isSubmitting || !state.canAddMoreImages
                      ? null
                      : _pickFromCamera,
                  tooltip: 'ถ่ายรูป',
                ),
                _buildIconButton(
                  icon: HugeIcons.strokeRoundedImageComposition,
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
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedFloppyDisk, size: AppIconSize.md, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'บันทึก',
                          style: AppTypography.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required dynamic icon,
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
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: HugeIcon(
              icon: icon,
              color: isDisabled ? AppColors.secondaryText : AppColors.primary,
              size: AppIconSize.lg,
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

  /// สร้าง section แสดง/แก้ไข tag และ resident
  /// ถ้า user เป็นหัวหน้าเวรขึ้นไป (level >= 30) = แก้ไขได้
  /// ถ้าไม่ใช่ = แสดงเป็น read-only
  Widget _buildReadOnlyInfo() {
    final state = ref.watch(editPostProvider(widget.post.id));
    final isShiftLeaderAsync = ref.watch(isAtLeastShiftLeaderProvider);

    return isShiftLeaderAsync.when(
      data: (isShiftLeader) {
        if (isShiftLeader) {
          // หัวหน้าเวรขึ้นไป: แสดง pickers ให้แก้ไขได้
          return _buildEditableTagResident(state);
        } else {
          // พนักงานทั่วไป: แสดงแบบ read-only
          return _buildReadOnlyTagResident();
        }
      },
      loading: () => _buildReadOnlyTagResident(),
      error: (_, _) => _buildReadOnlyTagResident(),
    );
  }

  /// Widget แสดง tag/resident แบบ read-only (สำหรับพนักงานทั่วไป)
  Widget _buildReadOnlyTagResident() {
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
                      HugeIcon(icon: HugeIcons.strokeRoundedTag01, size: AppIconSize.sm, color: AppColors.primary),
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
                      HugeIcon(icon: HugeIcons.strokeRoundedUser, size: AppIconSize.sm, color: AppColors.primary),
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

  /// Widget แสดง tag/resident แบบ editable (สำหรับหัวหน้าเวรขึ้นไป)
  Widget _buildEditableTagResident(EditPostState state) {
    final tagsAsync = ref.watch(tagsProvider);

    // หา tag จาก name ถ้ายังไม่มี selectedTag แต่มี originalTagName
    if (state.selectedTag == null && state.originalTagName != null) {
      tagsAsync.whenData((tags) {
        final matchingTag = tags.where(
          (t) => t.name == state.originalTagName,
        ).firstOrNull;
        if (matchingTag != null) {
          // ใช้ addPostFrameCallback เพื่อหลีกเลี่ยงการ update state ระหว่าง build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(editPostProvider(widget.post.id).notifier)
                .setSelectedTag(matchingTag);
          });
        }
      });
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with edit icon
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedEdit02,
                size: AppIconSize.sm,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'แก้ไขหัวข้อและผู้พักอาศัย',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapSm,

          // Tag and Resident pickers
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Tag Picker
              TagPickerCompact(
                selectedTag: state.selectedTag,
                isHandover: state.isHandover,
                onTagSelected: (tag) {
                  ref.read(editPostProvider(widget.post.id).notifier).setTag(tag);
                },
                onTagCleared: () {
                  ref.read(editPostProvider(widget.post.id).notifier).clearTag();
                },
                onHandoverChanged: (value) {
                  ref.read(editPostProvider(widget.post.id).notifier).setHandover(value);
                },
              ),

              // Resident Picker
              ResidentPickerWidget(
                selectedResidentId: state.residentId,
                selectedResidentName: state.residentName,
                onResidentSelected: (id, name) {
                  ref.read(editPostProvider(widget.post.id).notifier).setResident(id, name);
                },
                onResidentCleared: () {
                  ref.read(editPostProvider(widget.post.id).notifier).clearResident();
                },
              ),
            ],
          ),

          // Handover toggle (แสดงตลอดเพื่อให้เลือกได้ไม่ต้องมี tag)
          AppSpacing.verticalGapMd,
          _buildHandoverToggle(state),
        ],
      ),
    );
  }

  /// Toggle สำหรับส่งเวร
  /// - ถ้าไม่มี tag: เลือกได้อิสระ (canToggle = true)
  /// - ถ้ามี tag และเป็น optional handover: เลือกได้
  /// - ถ้ามี tag และเป็น force handover: ถูกบังคับเปิด (canToggle = false)
  Widget _buildHandoverToggle(EditPostState state) {
    final isForce = state.selectedTag?.isForceHandover ?? false;
    // ถ้าไม่มี tag หรือ tag เป็น optional handover = toggle ได้
    final canToggle = state.selectedTag == null ||
        (state.selectedTag?.isOptionalHandover ?? false);

    return CheckboxTile(
      value: state.isHandover,
      onChanged: canToggle
          ? (value) => ref.read(editPostProvider(widget.post.id).notifier).setHandover(value)
          : null,
      icon: HugeIcons.strokeRoundedArrowLeftRight,
      title: 'ส่งเวร',
      subtitle: isForce
          ? 'จำเป็นต้องส่งเวรสำหรับหัวข้อนี้'
          : 'หากมีอาการผิดปกติ ผิดแปลกไปจากเดิม หรือเป็นเรื่องที่สำคัญ',
      subtitleColor: AppColors.error,
      isRequired: isForce,
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
                        child: Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedImage01,
                            color: AppColors.secondaryText,
                          ),
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
                      child: HugeIcon(
                        icon: isRemoved ? HugeIcons.strokeRoundedRefresh : HugeIcons.strokeRoundedCancelCircle,
                        color: Colors.white,
                        size: AppIconSize.sm,
                      ),
                    ),
                  ),
                ),
                // Removed overlay
                if (isRemoved)
                  Positioned.fill(
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedDelete01,
                        color: AppColors.error,
                        size: AppIconSize.xxl,
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
