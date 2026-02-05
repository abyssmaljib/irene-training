import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirm_dialog.dart';
import 'handover_toggle_widget.dart';
import '../models/post.dart';
import '../providers/edit_post_provider.dart';
import '../providers/post_provider.dart';
import '../providers/tag_provider.dart';
import '../services/post_media_service.dart';
import '../screens/advanced_edit_post_screen.dart';
import 'image_picker_bar.dart';
import 'create_post_bottom_sheet.dart' show navigateToAdvancedPostScreen;
import 'resident_tag_picker_row.dart';

// ============================================================
// Edit Post Bottom Sheet - พร้อม confirmation ก่อนปิด
// ============================================================

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
  final _descriptionFocusNode = FocusNode(); // FocusNode สำหรับ focus เมื่อติ๊กส่งเวร
  bool _isUploading = false;

  // Upload progress state - แสดงสถานะการอัพโหลดให้ user ทราบ
  String? _uploadStatusMessage;

  // เก็บค่าเริ่มต้นเพื่อเปรียบเทียบว่ามีการแก้ไขหรือไม่
  String _initialText = '';
  String _initialTitle = '';

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing post data
    _textController.text = widget.post.text ?? '';
    _titleController.text = widget.post.title ?? '';

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
    _textController.dispose();
    _titleController.dispose();
    _descriptionFocusNode.dispose();
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

    // เช็คว่ามีการเปลี่ยนแปลงใน state (รูป, วีดีโอ, tag, resident, handover)
    final stateChanged = state.hasTagChanged ||
        state.hasResidentChanged ||
        state.newImages.isNotEmpty ||
        state.removedExistingIndexes.isNotEmpty ||
        state.newVideos.isNotEmpty ||
        state.removedExistingVideoIndexes.isNotEmpty ||
        state.isHandover != widget.post.isHandover;

    return textChanged || titleChanged || stateChanged;
  }

  /// จัดการเมื่อ user พยายามปิด modal
  /// ใช้ ConfirmDialog.show() จาก reusable widget
  Future<bool> _handleCloseAttempt() async {
    if (!_hasUnsavedChanges()) return true;

    // ใช้ ConfirmDialog.show() กับ exitEdit preset
    final confirmed = await ConfirmDialog.show(
      context,
      type: ConfirmDialogType.exitEdit,
      barrierDismissible: false,
    );

    // confirmed = true หมายถึง user กด "ยกเลิกการแก้ไข" (ปิด modal)
    // confirmed = false หมายถึง user กด "กลับไปแก้ไข" (ไม่ปิด)
    return confirmed;
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
            // Header พร้อมปุ่มกากบาทปิด
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

                    // Existing videos
                    if (state.existingVideoUrls.isNotEmpty)
                      _buildExistingVideos(state),

                    // New videos
                    if (state.newVideos.isNotEmpty) _buildNewVideos(state),

                    // Upload status indicator
                    if (_uploadStatusMessage != null) ...[
                      AppSpacing.verticalGapSm,
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _uploadStatusMessage!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],

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
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
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
              icon: HugeIcon(icon: HugeIcons.strokeRoundedEdit02, size: AppIconSize.sm),
              label: const Text('แบบละเอียด'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: AppTypography.bodySmall,
              ),
            ),

          // ปุ่มกากบาทปิด modal
          IconButton(
            onPressed: () async {
              final shouldClose = await _handleCloseAttempt();
              if (shouldClose && mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              color: AppColors.secondaryText,
              size: AppIconSize.lg,
            ),
            tooltip: 'ปิด',
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
          // ไม่ต้อง sync ทุก keystroke เพราะทำให้ rebuild บ่อย
          // จะ read จาก controller ตอน submit แทน
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
          maxLines: null,
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
          // ไม่ต้อง sync ทุก keystroke เพราะทำให้ rebuild บ่อย
          // จะ read จาก controller ตอน submit แทน
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
                        'คุณ${widget.post.residentName!}',
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

          // Resident and Tag pickers (ใช้ reusable widget)
          ResidentTagPickerRow(
            selectedResidentId: state.residentId,
            selectedResidentName: state.residentName,
            onResidentSelected: (id, name) {
              ref.read(editPostProvider(widget.post.id).notifier).setResident(id, name);
            },
            onResidentCleared: () {
              ref.read(editPostProvider(widget.post.id).notifier).clearResident();
            },
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
            originalTagName: state.originalTagName,
          ),

          // Handover toggle (แสดงตลอดเพื่อให้เลือกได้ไม่ต้องมี tag)
          AppSpacing.verticalGapSm,
          HandoverToggleWidget(
            selectedTag: state.selectedTag,
            isHandover: state.isHandover,
            selectedResidentId: state.residentId, // EditPostState ใช้ residentId
            onHandoverChanged: (value) {
              ref.read(editPostProvider(widget.post.id).notifier).setHandover(value);
            },
            descriptionFocusNode: _descriptionFocusNode,
            descriptionText: _textController.text,
            // Edit mode: ไม่บังคับส่งเวรเมื่อไม่มี resident
            forceHandoverWhenNoResident: false,
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
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancelCircle,
                            color: Colors.white,
                            size: AppIconSize.sm,
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

  /// แสดงวีดีโอเดิมที่มีอยู่ในโพส
  Widget _buildExistingVideos(EditPostState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'วีดีโอเดิม',
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
            itemCount: state.existingVideoUrls.length,
            itemBuilder: (context, index) {
              final isRemoved = state.removedExistingVideoIndexes.contains(index);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    // Video placeholder with icon
                    Opacity(
                      opacity: isRemoved ? 0.3 : 1.0,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.alternate),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedVideo01,
                              color: AppColors.primary,
                              size: AppIconSize.xxl,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'วีดีโอ ${index + 1}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
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
                                .restoreExistingVideo(index);
                          } else {
                            ref
                                .read(editPostProvider(widget.post.id).notifier)
                                .removeExistingVideo(index);
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
                            icon: isRemoved
                                ? HugeIcons.strokeRoundedRefresh
                                : HugeIcons.strokeRoundedCancelCircle,
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
        ),
        AppSpacing.verticalGapMd,
      ],
    );
  }

  /// แสดงวีดีโอใหม่ที่เลือก (ยังไม่ได้อัพโหลด)
  Widget _buildNewVideos(EditPostState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'วีดีโอใหม่',
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
            itemCount: state.newVideos.length,
            itemBuilder: (context, index) {
              final file = state.newVideos[index];

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    // Video placeholder with filename
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.accent1,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedVideo01,
                            color: AppColors.primary,
                            size: AppIconSize.xxl,
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              file.path.split('/').last.split('\\').last,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                              .removeNewVideo(index);
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancelCircle,
                            color: Colors.white,
                            size: AppIconSize.sm,
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
          // Image/Video picker buttons
          Wrap(
            spacing: 8,
            children: [
              // Camera button (images only)
              _buildIconButton(
                icon: HugeIcons.strokeRoundedCamera01,
                onTap: _isUploading || state.isSubmitting || !state.canAddMoreImages
                    ? null
                    : _pickFromCamera,
                tooltip: 'ถ่ายรูป',
              ),
              // Gallery button (images only)
              _buildIconButton(
                icon: HugeIcons.strokeRoundedImageComposition,
                onTap: _isUploading || state.isSubmitting || !state.canAddMoreImages
                    ? null
                    : _pickFromGallery,
                tooltip: 'เลือกจากแกลเลอรี่',
              ),
              // Video button
              _buildIconButton(
                icon: HugeIcons.strokeRoundedVideo01,
                onTap: _isUploading || state.isSubmitting || !state.canAddVideo
                    ? null
                    : _pickVideo,
                tooltip: 'เลือกวีดีโอ',
              ),
            ],
          ),

          // Submit button
          ElevatedButton(
            onPressed: state.isSubmitting || !_canSubmit(state)
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

  bool _canSubmit(EditPostState state) {
    // ต้องมีข้อความ + ต้องมี tag (เดิมหรือเลือกใหม่)
    final hasTag = state.selectedTag != null || state.originalTagName != null;
    return _textController.text.trim().isNotEmpty && hasTag;
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

  /// เลือกวีดีโอจาก gallery (จำกัด 1 ไฟล์, mutual exclusive กับรูปภาพ)
  Future<void> _pickVideo() async {
    final state = ref.read(editPostProvider(widget.post.id));

    // เช็คว่าสามารถเพิ่มวีดีโอได้หรือไม่
    if (!state.canAddVideo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเพิ่มวีดีโอได้ (มีรูปภาพหรือวีดีโออยู่แล้ว)')),
      );
      return;
    }

    final file = await ImagePickerHelper.pickVideoFromGallery();
    if (file != null) {
      ref.read(editPostProvider(widget.post.id).notifier).addNewVideo(file);
    }
  }

  Future<void> _handleSubmit(EditPostState state) async {
    final text = _textController.text.trim();

    // ถ้าติ๊กส่งเวร บังคับต้องกรอกรายละเอียด
    if (text.isEmpty && state.isHandover) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกรายละเอียดเมื่อติ๊กส่งเวร')),
      );
      return;
    }

    if (text.isEmpty) return;

    ref.read(editPostProvider(widget.post.id).notifier).setSubmitting(true);

    try {
      final actionService = ref.read(postActionServiceProvider);
      final userId = ref.read(postCurrentUserIdProvider);

      if (userId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      // Upload new images if any พร้อมแสดง progress
      List<String> finalImageUrls = [...state.finalExistingUrls];

      if (state.newImages.isNotEmpty) {
        setState(() {
          _isUploading = true;
          _uploadStatusMessage = 'กำลังอัพโหลดรูปภาพ...';
        });

        final newUrls = await PostMediaService.instance.uploadImages(
          state.newImages,
          userId: userId,
        );
        finalImageUrls.addAll(newUrls);
      }

      // Upload new videos if any พร้อมแสดง progress และ error handling
      List<String> finalVideoUrls = [...state.finalExistingVideoUrls];

      if (state.newVideos.isNotEmpty) {
        setState(() {
          _isUploading = true;
          _uploadStatusMessage = 'กำลังอัพโหลดวีดีโอ...';
        });

        for (final videoFile in state.newVideos) {
          final result = await PostMediaService.instance.uploadVideoWithThumbnail(
            videoFile,
            userId: userId,
          );

          // ถ้าอัพโหลดไม่สำเร็จ ให้ throw error แทนที่จะ skip
          if (result.videoUrl == null) {
            throw Exception('อัพโหลดวีดีโอไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
          }

          finalVideoUrls.add(result.videoUrl!);
        }
      }

      // Clear upload status
      setState(() {
        _isUploading = false;
        _uploadStatusMessage = null;
      });

      // รวม image และ video URLs เข้าด้วยกัน (เก็บใน multi_img_url เดียวกัน)
      final List<String> allMediaUrls = [...finalImageUrls, ...finalVideoUrls];

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

      // Update post
      final success = await actionService.updatePost(
        postId: widget.post.id,
        text: text,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        multiImgUrl: allMediaUrls.isEmpty ? null : allMediaUrls,
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
      // Clear upload status และ submitting state ทุกกรณี
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusMessage = null;
        });
      }
      ref.read(editPostProvider(widget.post.id).notifier).setSubmitting(false);
    }
  }
}

/// Helper function to show edit post bottom sheet
/// ใช้ _EditPostBottomSheetWrapper เพื่อจัดการ back gesture
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
    // ปิด drag - ใช้ปุ่มกากบาทแทน
    enableDrag: false,
    // isDismissible: false เพื่อป้องกัน tap outside ปิด modal
    isDismissible: false,
    builder: (context) => _EditPostBottomSheetWrapper(
      post: post,
      onPostUpdated: onPostUpdated,
      onAdvancedTap: onAdvancedTap,
    ),
  );
}

/// Wrapper widget ที่จัดการ PopScope สำหรับ back gesture
class _EditPostBottomSheetWrapper extends ConsumerStatefulWidget {
  final Post post;
  final VoidCallback? onPostUpdated;
  final VoidCallback? onAdvancedTap;

  const _EditPostBottomSheetWrapper({
    required this.post,
    this.onPostUpdated,
    this.onAdvancedTap,
  });

  @override
  ConsumerState<_EditPostBottomSheetWrapper> createState() =>
      _EditPostBottomSheetWrapperState();
}

class _EditPostBottomSheetWrapperState
    extends ConsumerState<_EditPostBottomSheetWrapper> {
  final GlobalKey<_EditPostBottomSheetState> _sheetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // คำนวณความสูงของ modal (70% ของหน้าจอ)
    final screenHeight = MediaQuery.of(context).size.height;
    final modalHeight = screenHeight * 0.7;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final sheetState = _sheetKey.currentState;
        if (sheetState != null) {
          final shouldClose = await sheetState._handleCloseAttempt();
          if (shouldClose && context.mounted) {
            Navigator.of(context).pop();
          }
        } else {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: SizedBox(
        height: modalHeight,
        child: EditPostBottomSheet(
          key: _sheetKey,
          post: widget.post,
          onPostUpdated: widget.onPostUpdated,
          onAdvancedTap: widget.onAdvancedTap,
        ),
      ),
    );
  }
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
