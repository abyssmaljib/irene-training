import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../models/new_tag.dart';
import '../models/post_draft.dart';
import '../providers/create_post_provider.dart';
import '../providers/post_provider.dart';
import '../services/post_action_service.dart';
import '../services/post_media_service.dart';
import '../services/post_draft_service.dart';
import '../widgets/tag_picker_widget.dart';
import '../widgets/resident_picker_widget.dart';
import '../widgets/image_picker_bar.dart' show ImagePickerHelper;
import '../widgets/image_preview_grid.dart';
import '../widgets/quiz_form_widget.dart';
import '../widgets/ai_summary_widget.dart';

/// Advanced Create Post Screen - Full page version for supervisors+
/// Features: Title, AI summarize, Quiz, Tag, Resident, Images/Video
class AdvancedCreatePostScreen extends ConsumerStatefulWidget {
  const AdvancedCreatePostScreen({super.key});

  @override
  ConsumerState<AdvancedCreatePostScreen> createState() =>
      _AdvancedCreatePostScreenState();
}

class _AdvancedCreatePostScreenState
    extends ConsumerState<AdvancedCreatePostScreen> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Draft auto-save state
  Timer? _autoSaveTimer;
  static const _autoSaveDelay = Duration(seconds: 2);
  PostDraftService? _draftService;
  bool _isRestoringDraft = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize draft service
      final prefs = ref.read(sharedPreferencesProvider);
      _draftService = PostDraftService(prefs);

      final state = ref.read(createPostProvider);
      // ถ้ามี text จาก simple modal ให้โหลดมาใส่ใน controller
      if (state.text.isNotEmpty) {
        _textController.text = state.text;
      }
      // ถ้ามี title ให้โหลดมาด้วย
      if (state.title != null && state.title!.isNotEmpty) {
        _titleController.text = state.title!;
      }

      // ถ้า provider ว่างเปล่า ให้ตรวจสอบ draft
      if (state.text.isEmpty && state.title == null) {
        _checkAndRestoreDraft();
      }
    });

    // Listen for text changes เพื่อ auto-save draft
    _titleController.addListener(_onContentChanged);
    _textController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.removeListener(_onContentChanged);
    _textController.removeListener(_onContentChanged);
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ============================================================
  // Draft Management Functions
  // ============================================================

  /// Callback เมื่อ content เปลี่ยน - debounce แล้ว auto-save draft
  void _onContentChanged() {
    if (_isRestoringDraft) return;

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, _saveDraft);
  }

  /// ตรวจสอบว่ามีข้อมูลที่ยังไม่ได้บันทึกหรือไม่
  bool _hasUnsavedData() {
    final state = ref.read(createPostProvider);
    return _textController.text.trim().isNotEmpty ||
        _titleController.text.trim().isNotEmpty ||
        state.selectedTag != null ||
        state.selectedResidentId != null ||
        state.selectedImages.isNotEmpty ||
        state.selectedVideo != null ||
        state.hasQuiz;
  }

  /// บันทึก draft ลง SharedPreferences
  Future<void> _saveDraft() async {
    if (_draftService == null) return;

    final userId = UserService().effectiveUserId;
    if (userId == null) return;

    final state = ref.read(createPostProvider);
    final draft = PostDraft(
      title: _titleController.text,
      text: _textController.text,
      tagId: state.selectedTag?.id,
      tagName: state.selectedTag?.name,
      tagEmoji: state.selectedTag?.emoji,
      tagHandoverMode: state.selectedTag?.handoverMode,
      isHandover: state.isHandover,
      sendToFamily: state.sendToFamily,
      residentId: state.selectedResidentId,
      residentName: state.selectedResidentName,
      imagePaths: state.selectedImages.map((f) => f.path).toList(),
      videoPath: state.selectedVideo?.path,
      savedAt: DateTime.now(),
      isAdvanced: true,
    );

    await _draftService!.saveDraft(userId.toString(), draft);
  }

  /// ตรวจสอบและ restore draft ถ้ามี
  Future<void> _checkAndRestoreDraft() async {
    if (_draftService == null) return;

    final userId = UserService().effectiveUserId;
    if (userId == null) return;

    final userIdStr = userId.toString();
    if (!_draftService!.hasDraft(userIdStr)) return;

    final draft = _draftService!.loadDraft(userIdStr);
    if (draft == null || !draft.hasContent) return;

    // แสดง dialog ถามว่าจะใช้ draft หรือไม่
    if (!mounted) return;
    final shouldRestore = await _showRestoreDraftDialog();

    if (shouldRestore == true) {
      _restoreDraft(draft);
    } else {
      await _draftService!.clearDraft(userIdStr);
    }
  }

  /// แสดง dialog ถามว่าจะ restore draft หรือไม่
  /// ใช้ RestoreDraftDialog จาก reusable widget
  Future<bool?> _showRestoreDraftDialog() async {
    return RestoreDraftDialog.show(context);
  }

  /// Restore draft ไปยัง form
  void _restoreDraft(PostDraft draft) {
    _isRestoringDraft = true;

    // Restore title และ text
    _titleController.text = draft.title ?? '';
    _textController.text = draft.text;

    // Restore tag (ถ้ามี)
    if (draft.tagId != null) {
      final tag = NewTag(
        id: draft.tagId!,
        name: draft.tagName ?? '',
        emoji: draft.tagEmoji,
        handoverMode: draft.tagHandoverMode ?? 'none',
      );
      ref.read(createPostProvider.notifier).selectTag(tag);
    }

    // Restore resident
    if (draft.residentId != null) {
      ref.read(createPostProvider.notifier).selectResident(
            draft.residentId!,
            draft.residentName ?? '',
          );
    }

    // Restore handover and sendToFamily
    ref.read(createPostProvider.notifier).setHandover(draft.isHandover);
    ref.read(createPostProvider.notifier).setSendToFamily(draft.sendToFamily);

    _isRestoringDraft = false;
  }

  /// จัดการเมื่อ user พยายามปิด screen
  /// ใช้ ExitCreateDialog จาก reusable widget (3 ปุ่ม)
  Future<bool> _handleCloseAttempt() async {
    if (!_hasUnsavedData()) return true;

    // ใช้ ExitCreateDialog.show() สำหรับ 3 ปุ่ม
    final result = await ExitCreateDialog.show(context);

    switch (result) {
      case ExitCreateResult.continueEditing:
        return false;
      case ExitCreateResult.saveDraft:
        await _saveDraft();
        return true;
      case ExitCreateResult.discard:
        final userId = UserService().effectiveUserId;
        if (userId != null && _draftService != null) {
          await _draftService!.clearDraft(userId.toString());
        }
        return true;
      default:
        return false;
    }
  }

  /// ลบ draft หลังจาก submit สำเร็จ
  Future<void> _clearDraftAfterSubmit() async {
    final userId = UserService().effectiveUserId;
    if (userId != null && _draftService != null) {
      await _draftService!.clearDraft(userId.toString());
    }
  }

  Future<void> _pickFromCamera() async {
    final file = await ImagePickerHelper.pickFromCamera();
    if (file != null && mounted) {
      ref.read(createPostProvider.notifier).addImages([file]);
    }
  }

  Future<void> _pickFromGallery() async {
    final currentCount = ref.read(createPostProvider).selectedImages.length +
        ref.read(createPostProvider).uploadedImageUrls.length;
    final remaining = 5 - currentCount;

    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สูงสุด 5 รูป')),
      );
      return;
    }

    final files = await ImagePickerHelper.pickFromGallery(maxImages: remaining);
    if (files.isNotEmpty && mounted) {
      ref.read(createPostProvider.notifier).addImages(files);
    }
  }

  Future<void> _pickVideo() async {
    if (ref.read(createPostProvider).hasVideo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สามารถเลือกได้ 1 วีดีโอ')),
      );
      return;
    }

    final file = await ImagePickerHelper.pickVideoFromGallery();
    if (file != null && mounted) {
      ref.read(createPostProvider.notifier).setVideo(file);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(createPostProvider);
    final text = _textController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณาใส่รายละเอียด')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = UserService().effectiveUserId;
      if (userId == null) throw Exception('Not authenticated');

      // Get user's nursinghome_id
      final userInfo = await Supabase.instance.client
          .from('user_info')
          .select('nursinghome_id')
          .eq('id', userId)
          .single();
      final nursinghomeId = userInfo['nursinghome_id'] as int;

      // Upload images if any
      List<String> imageUrls = [...state.uploadedImageUrls];
      if (state.selectedImages.isNotEmpty) {
        final uploadedUrls = await PostMediaService.instance.uploadImages(
          state.selectedImages,
        );
        imageUrls.addAll(uploadedUrls);
      }

      // Upload video if any
      String? videoUrl;
      if (state.selectedVideo != null) {
        videoUrl = await PostMediaService.instance.uploadVideo(
          state.selectedVideo!,
          userId: userId,
        );
      }

      // Build tag topics list
      List<String>? tagTopics;
      if (state.selectedTag != null) {
        tagTopics = [state.selectedTag!.name];
      }
      // เพิ่ม "ส่งให้หัวหน้าเวร" ถ้าเลือก
      if (state.sendToFamily) {
        tagTopics = [...?tagTopics, 'ส่งให้หัวหน้าเวร'];
      }

      // Create post
      final postId = await PostActionService.instance.createPost(
        userId: userId,
        nursinghomeId: nursinghomeId,
        text: text,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        tagTopics: tagTopics,
        isHandover: state.isHandover,
        residentId: state.selectedResidentId,
        imageUrls: imageUrls.isEmpty ? null : imageUrls,
        youtubeUrl: videoUrl,
        // Quiz fields
        qaQuestion: state.qaQuestion,
        qaChoiceA: state.qaChoiceA,
        qaChoiceB: state.qaChoiceB,
        qaChoiceC: state.qaChoiceC,
        qaAnswer: state.qaAnswer,
        // DD Record link
        ddId: state.ddId,
      );

      if (postId != null) {
        // Refresh posts
        ref.invalidate(postsProvider);

        // Clear draft หลังจาก submit สำเร็จ
        await _clearDraftAfterSubmit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('โพสสำเร็จ')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to create post');
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
    final state = ref.watch(createPostProvider);

    return PopScope(
      // ไม่ให้ pop อัตโนมัติ - เราจะจัดการเอง
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
          title: 'สร้างประกาศใหม่',
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
                onChanged: (value) {
                  ref.read(createPostProvider.notifier).setTitle(value);
                },
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
                onChanged: (value) {
                  ref.read(createPostProvider.notifier).setText(value);
                },
              ),

              AppSpacing.verticalGapMd,

              // AI Summary widget
              AiSummaryWidget(
                textController: _textController,
                onReplaceText: () {
                  // Already handled in the widget
                },
              ),

              AppSpacing.verticalGapLg,

              // Divider
              Divider(color: AppColors.alternate, height: 1),

              AppSpacing.verticalGapLg,

              // Quiz form
              QuizFormWidget(postText: _textController.text),

              AppSpacing.verticalGapLg,

              // Divider
              Divider(color: AppColors.alternate, height: 1),

              AppSpacing.verticalGapLg,

              // Resident & Tag pickers
              _buildSectionLabel('ตั้งค่าเพิ่มเติม'),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Resident picker
                  ResidentPickerWidget(
                    selectedResidentId: state.selectedResidentId,
                    selectedResidentName: state.selectedResidentName,
                    onResidentSelected: (id, name) {
                      ref
                          .read(createPostProvider.notifier)
                          .selectResident(id, name);
                    },
                    onResidentCleared: () {
                      ref.read(createPostProvider.notifier).clearResident();
                    },
                  ),
                  const SizedBox(width: 8),
                  // Tag picker
                  TagPickerCompact(
                    selectedTag: state.selectedTag,
                    isHandover: state.isHandover,
                    onTagSelected: (tag) {
                      ref.read(createPostProvider.notifier).selectTag(tag);
                    },
                    onTagCleared: () {
                      ref.read(createPostProvider.notifier).clearTag();
                    },
                    onHandoverChanged: (value) {
                      ref.read(createPostProvider.notifier).setHandover(value);
                    },
                  ),
                ],
              ),

              // Handover toggle
              if (state.selectedTag != null) ...[
                AppSpacing.verticalGapSm,
                _buildHandoverToggle(state),
              ],

              // Send to family toggle (แสดงเมื่อเลือก resident แล้ว)
              if (state.selectedResidentId != null) ...[
                AppSpacing.verticalGapSm,
                _buildSendToFamilyToggle(state),
              ],

              AppSpacing.verticalGapLg,

              // Image preview
              if (state.hasImages) ...[
                AppSpacing.verticalGapMd,
                ImagePreviewCompact(
                  localImages: state.selectedImages,
                  uploadedUrls: state.uploadedImageUrls,
                  onRemoveLocal: (index) {
                    ref.read(createPostProvider.notifier).removeImage(index);
                  },
                  onRemoveUploaded: (index) {
                    ref
                        .read(createPostProvider.notifier)
                        .removeUploadedImage(index);
                  },
                ),
              ],

              // Video preview
              if (state.hasVideo) ...[
                AppSpacing.verticalGapMd,
                _buildVideoPreview(state),
              ],

              // Error message
              if (state.error != null) ...[
                AppSpacing.verticalGapMd,
                Text(
                  state.error!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.error,
                  ),
                ),
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

  Widget _buildBottomBar(CreatePostState state) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canSubmit = _textController.text.trim().isNotEmpty && !_isSubmitting;

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
                  onTap: _isSubmitting || state.hasVideo ? null : _pickFromCamera,
                  tooltip: 'ถ่ายรูป',
                ),
                _buildIconButton(
                  icon: HugeIcons.strokeRoundedImageComposition,
                  onTap: _isSubmitting || state.hasVideo ? null : _pickFromGallery,
                  tooltip: 'เลือกจากแกลเลอรี่',
                ),
                _buildIconButton(
                  icon: HugeIcons.strokeRoundedVideo01,
                  onTap: _isSubmitting || state.hasImages ? null : _pickVideo,
                  tooltip: 'เลือกวีดีโอ',
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? SizedBox(
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
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedFloppyDisk,
                          size: AppIconSize.md,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'โพส',
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

  Widget _buildHandoverToggle(CreatePostState state) {
    final canToggle = state.selectedTag?.isOptionalHandover ?? false;
    final isForce = state.selectedTag?.isForceHandover ?? false;
    final isHandover = state.isHandover;

    return SwitchListTile(
      value: isHandover,
      onChanged: canToggle
          ? (value) {
              ref.read(createPostProvider.notifier).setHandover(value);
            }
          : null,
      title: Text(
        'ส่งเวร',
        style: AppTypography.body.copyWith(
          color: AppColors.primaryText,
        ),
      ),
      subtitle: Text(
        isForce
            ? 'Tag นี้บังคับส่งเวร'
            : isHandover
                ? 'โพสนี้จะถูกส่งต่อให้เวรถัดไป'
                : 'โพสนี้จะไม่ถูกส่งต่อ',
        style: AppTypography.caption.copyWith(
          color: AppColors.secondaryText,
        ),
      ),
      activeTrackColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildSendToFamilyToggle(CreatePostState state) {
    final sendToFamily = state.sendToFamily;

    return SwitchListTile(
      value: sendToFamily,
      onChanged: (value) {
        ref.read(createPostProvider.notifier).setSendToFamily(value);
      },
      title: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedUserGroup,
            size: AppIconSize.lg,
            color: sendToFamily ? AppColors.primary : AppColors.secondaryText,
          ),
          const SizedBox(width: 8),
          Text(
            'ส่งให้หัวหน้าเวร',
            style: AppTypography.body.copyWith(
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
      subtitle: Text(
        'ส่งให้หัวหน้าเวรตรวจสอบและส่งให้ญาติ',
        style: AppTypography.caption.copyWith(
          color: AppColors.secondaryText,
        ),
      ),
      activeTrackColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildVideoPreview(CreatePostState state) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Video thumbnail or placeholder
          Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedVideo01,
              size: AppIconSize.xxxl,
              color: AppColors.secondaryText,
            ),
          ),
          // Video path indicator
          Positioned(
            left: 8,
            bottom: 8,
            right: 40,
            child: Text(
              state.selectedVideo?.path.split('/').last ?? 'Video',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: AppColors.error),
              onPressed: () {
                ref.read(createPostProvider.notifier).clearVideo();
              },
              iconSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}
