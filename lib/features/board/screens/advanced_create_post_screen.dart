import 'dart:async';
import 'dart:io';

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
import '../../../core/widgets/checkbox_tile.dart';
import '../providers/tag_provider.dart';
import '../../../core/widgets/success_popup.dart';
import '../../../core/widgets/buttons.dart';
import '../../checklist/services/task_service.dart';
import '../../checklist/providers/task_provider.dart'
    show
        refreshTasks,
        tasksProvider,
        currentUserNicknameProvider,
        optimisticUpdateTask,
        commitOptimisticUpdate;
import '../../checklist/widgets/difficulty_rating_dialog.dart';

/// Advanced Create Post Screen - Full page version for supervisors+
/// Features: Title, AI summarize, Quiz, Tag, Resident, Images/Video
///
/// รองรับทั้งการสร้างโพสปกติ และการสร้างโพสจาก task (complete by post)
class AdvancedCreatePostScreen extends ConsumerStatefulWidget {
  /// Callback เมื่อโพสสำเร็จ
  final VoidCallback? onPostCreated;

  /// Initial values สำหรับ pre-fill form
  final String? initialTitle;
  final String? initialText;
  final int? initialResidentId;
  final String? initialResidentName;
  final String? initialTagName;

  /// Task completion fields (สำหรับ complete task เมื่อโพสสำเร็จ)
  final int? taskLogId;
  final String? taskConfirmImageUrl;

  /// ตรวจสอบว่ามาจาก task หรือไม่
  bool get isFromTask => taskLogId != null;

  const AdvancedCreatePostScreen({
    super.key,
    this.onPostCreated,
    this.initialTitle,
    this.initialText,
    this.initialResidentId,
    this.initialResidentName,
    this.initialTagName,
    this.taskLogId,
    this.taskConfirmImageUrl,
  });

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

    // ถ้ามาจาก task ให้ใส่ค่าใน controller ทันที
    if (widget.isFromTask) {
      // Title จาก task (lock ไว้)
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
      }
      // Text (description) จาก task
      if (widget.initialText != null) {
        _textController.text = widget.initialText!;
      }
    } else if (widget.initialText != null) {
      // กรณีปกติ - ใส่ initialText ถ้ามี
      _textController.text = widget.initialText!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize draft service
      final prefs = ref.read(sharedPreferencesProvider);
      _draftService = PostDraftService(prefs);

      // ถ้ามาจาก task หรือมี initial values ให้ใช้ค่าจาก widget
      if (widget.isFromTask ||
          widget.initialResidentId != null ||
          widget.initialTagName != null) {
        // Initialize provider state จาก task parameters
        ref.read(createPostProvider.notifier).initFromTask(
              text: widget.initialText ?? '',
              residentId: widget.initialResidentId,
              residentName: widget.initialResidentName,
            );

        // Auto-select tag ถ้ามี initialTagName
        if (widget.initialTagName != null) {
          _autoSelectTagByName(widget.initialTagName!);
        }

        // ถ้ามาจาก task ให้ตั้งค่า sendToFamily = true (บังคับส่งให้ญาติ)
        if (widget.isFromTask) {
          ref.read(createPostProvider.notifier).setSendToFamily(true);
        }
      } else {
        // ถ้าไม่ได้มาจาก task ให้ตรวจสอบ state จาก provider หรือ draft
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
      }
    });

    // Listen for text changes เพื่อ auto-save draft
    _titleController.addListener(_onContentChanged);
    _textController.addListener(_onContentChanged);
  }

  /// Auto-select tag by name (ใช้เมื่อมาจาก task)
  Future<void> _autoSelectTagByName(String tagName) async {
    // รอให้ tags โหลดเสร็จก่อน
    final tags = await ref.read(tagsProvider.future);

    // หา tag ที่ชื่อตรงกับ tagName หรืออยู่ใน legacy_tags
    NewTag? matchingTag;
    for (final tag in tags) {
      if (tag.name == tagName ||
          (tag.legacyTags?.contains(tagName) ?? false)) {
        matchingTag = tag;
        break;
      }
    }

    if (matchingTag != null && mounted) {
      ref.read(createPostProvider.notifier).selectTag(matchingTag);
    }
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
        state.selectedVideos.isNotEmpty ||
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
      videoPaths: state.selectedVideos.map((f) => f.path).toList(),
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
    // จำกัดแค่ 1 วิดีโอ - ถ้ามีอยู่แล้วจะแทนที่
    final file = await ImagePickerHelper.pickVideoFromGallery();
    if (file != null && mounted) {
      // Clear existing video แล้วเพิ่มใหม่
      ref.read(createPostProvider.notifier).clearVideos();
      ref.read(createPostProvider.notifier).addVideos([file]);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(createPostProvider);
    final text = _textController.text.trim();

    // รายละเอียดไม่บังคับ - ไม่ต้อง check text.isEmpty

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
      // รวมทั้งรูปและวิดีโอเข้า multi_img_url array เดียวกัน
      List<String> allMediaUrls = [
        ...state.uploadedImageUrls,
        ...state.uploadedVideoUrls,
      ];

      // Upload new images
      if (state.selectedImages.isNotEmpty) {
        final uploadedUrls = await PostMediaService.instance.uploadImages(
          state.selectedImages,
        );
        allMediaUrls.addAll(uploadedUrls);
      }

      // Upload new videos (หลายไฟล์)
      if (state.selectedVideos.isNotEmpty) {
        for (final video in state.selectedVideos) {
          final videoUrl = await PostMediaService.instance.uploadVideo(
            video,
            userId: userId,
          );
          if (videoUrl != null) {
            allMediaUrls.add(videoUrl);
          }
        }
      }

      // Build tag topics list
      List<String>? tagTopics;
      if (state.selectedTag != null) {
        tagTopics = [state.selectedTag!.name];
      }
      // เพิ่ม tag ตาม sendToFamily
      // - ถ้ามาจาก task: ใช้ "ส่งให้ญาติ" (ส่งตรงไปญาติเลย)
      // - ถ้าไม่ได้มาจาก task: ใช้ "ส่งให้หัวหน้าเวร" (ให้หัวหน้าเวรตรวจก่อน)
      if (state.sendToFamily) {
        final familyTag = widget.isFromTask ? 'ส่งให้ญาติ' : 'ส่งให้หัวหน้าเวร';
        tagTopics = [...?tagTopics, familyTag];
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
        imageUrls: allMediaUrls.isEmpty ? null : allMediaUrls,
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
        // ถ้ามี taskLogId ให้ complete task ด้วย
        if (widget.taskLogId != null && mounted) {
          // === Optimistic Update - อัพเดต UI ทันทีก่อนรอ server ===
          // หา task จาก provider เพื่อสร้าง optimistic version
          final tasksAsync = ref.read(tasksProvider);
          void Function()? rollback;

          if (tasksAsync.hasValue) {
            final tasks = tasksAsync.value!;
            final taskToUpdate = tasks
                .where((t) => t.logId == widget.taskLogId)
                .firstOrNull;

            if (taskToUpdate != null) {
              // ดึง nickname ของ user ปัจจุบัน
              final nickname =
                  await ref.read(currentUserNicknameProvider.future);

              // สร้าง optimistic task ที่แสดงว่า completed แล้ว
              final optimisticTask = taskToUpdate.copyWith(
                status: 'completed',
                completedAt: DateTime.now(),
                completedByUid: userId,
                completedByNickname: nickname,
                confirmImage: widget.taskConfirmImageUrl,
              );

              // อัพเดต UI ทันที (ก่อนรอ API)
              rollback = optimisticUpdateTask(ref, optimisticTask);
            }
          }

          // === แสดง Dialog ให้ประเมินความยากของงาน ===
          if (!mounted) return;
          final difficultyResult = await DifficultyRatingDialog.show(
            context,
            taskTitle: widget.initialTitle,
            allowSkip: true, // ให้ข้ามได้
          );

          // คะแนนความยากที่ user ให้ (null = ปิด dialog หรือข้าม)
          final difficultyScore = difficultyResult?.score;

          try {
            // Complete task พร้อม difficulty score
            await TaskService.instance.markTaskComplete(
              widget.taskLogId!,
              userId,
              imageUrl: widget.taskConfirmImageUrl,
              postId: postId,
              difficultyScore: difficultyScore,
              difficultyRatedBy: difficultyScore != null ? userId : null,
            );

            // Commit optimistic update (ลบ optimistic state)
            commitOptimisticUpdate(ref, widget.taskLogId!);

            // Refresh tasks เพื่อ sync กับ server
            refreshTasks(ref);
          } catch (e) {
            // Rollback ถ้า API error
            rollback?.call();
            rethrow;
          }
        }

        // Refresh posts
        ref.invalidate(postsProvider);

        // Clear draft หลังจาก submit สำเร็จ
        await _clearDraftAfterSubmit();

        if (mounted) {
          // แสดง success popup (ถ้ายังไม่ได้แสดงจาก DifficultyRatingDialog)
          if (!widget.isFromTask) {
            await SuccessPopup.show(
              context,
              emoji: '📝',
              message: 'โพสสำเร็จ',
              autoCloseDuration: const Duration(milliseconds: 1000),
            );
          }

          // เรียก callback (ถ้ามี)
          widget.onPostCreated?.call();

          if (mounted) {
            Navigator.of(context).pop(true);
          }
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
              // ถ้ามาจาก task จะแสดง "หัวข้อ" และ lock ไว้
              // ถ้าไม่ได้มาจาก task จะแสดง "หัวข้อ (ถ้ามี)" และแก้ไขได้
              _buildSectionLabel(
                widget.isFromTask ? 'หัวข้อ' : 'หัวข้อ (ถ้ามี)',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                maxLength: widget.isFromTask ? null : 30, // ไม่แสดง counter เมื่อ lock
                readOnly: widget.isFromTask, // Lock เมื่อมาจาก task
                enabled: !widget.isFromTask, // Disable interaction เมื่อมาจาก task
                decoration: InputDecoration(
                  hintText: widget.isFromTask ? null : 'หัวข้อประกาศ',
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                  filled: true,
                  // สีเทาเข้มขึ้นเมื่อ disabled เพื่อแสดงว่า lock อยู่
                  fillColor: widget.isFromTask
                      ? AppColors.alternate
                      : AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  // เพิ่ม border เมื่อ lock เพื่อให้เห็นชัดว่าเป็น locked field
                  enabledBorder: widget.isFromTask
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.alternate,
                            width: 1,
                          ),
                        )
                      : OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.alternate,
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  counterStyle: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                  // แสดง icon lock เมื่อมาจาก task (wrap Center เพื่อให้อยู่กลางแนวตั้ง)
                  suffixIcon: widget.isFromTask
                      ? Center(
                          widthFactor: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedSquareLock02,
                              size: AppIconSize.md,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        )
                      : null,
                ),
                style: AppTypography.body.copyWith(
                  // สีข้อความเข้มเมื่อ disabled เพื่อให้อ่านได้ชัด
                  color: widget.isFromTask
                      ? AppColors.primaryText
                      : AppColors.primaryText,
                ),
                onChanged: widget.isFromTask
                    ? null // ไม่ทำอะไรเมื่อ lock
                    : (value) {
                        ref.read(createPostProvider.notifier).setTitle(value);
                      },
              ),

              AppSpacing.verticalGapLg,

              // Description field (ไม่บังคับกรอก)
              _buildSectionLabel('รายละเอียด'),
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

              // Quiz form (ซ่อนเมื่อมาจาก task)
              if (!widget.isFromTask) ...[
                // Divider
                Divider(color: AppColors.alternate, height: 1),

                AppSpacing.verticalGapLg,

                // Quiz form
                QuizFormWidget(postText: _textController.text),

                AppSpacing.verticalGapLg,

                // Divider
                Divider(color: AppColors.alternate, height: 1),

                AppSpacing.verticalGapLg,
              ],

              // Resident & Tag pickers
              _buildSectionLabel('ตั้งค่าเพิ่มเติม'),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Resident picker (lock เมื่อมาจาก task)
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
                    disabled: widget.isFromTask, // Lock เมื่อมาจาก task
                  ),
                  const SizedBox(width: 8),
                  // Tag picker (lock เมื่อมาจาก task)
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
                    disabled: widget.isFromTask, // Lock เมื่อมาจาก task
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

    // Mutual exclusion: เลือกได้อย่างเดียว รูป หรือ วิดีโอ
    final hasImages = state.hasImages;
    final hasVideo = state.hasVideo;
    final hasMedia = hasImages || hasVideo;

    // เงื่อนไขการโพส:
    // - ถ้ามาจาก task: ต้องมีรูป หรือ วิดีโออย่างน้อย 1 อัน (รายละเอียดไม่บังคับ)
    // - ถ้าไม่ได้มาจาก task: โพสได้เลย (ไม่บังคับอะไร)
    final canSubmit = !_isSubmitting && (!widget.isFromTask || hasMedia);

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
            // เลือกได้อย่างเดียว: รูป หรือ วิดีโอ (ไม่ใช่ทั้งคู่)
            Wrap(
              spacing: 8,
              children: [
                _buildIconButton(
                  icon: HugeIcons.strokeRoundedCamera01,
                  // Disable ถ้ามี video หรือกำลัง submit
                  onTap: (_isSubmitting || hasVideo) ? null : _pickFromCamera,
                  tooltip: hasVideo ? 'ลบวิดีโอก่อนถึงจะถ่ายรูปได้' : 'ถ่ายรูป',
                ),
                _buildIconButton(
                  icon: HugeIcons.strokeRoundedImageComposition,
                  // Disable ถ้ามี video หรือกำลัง submit
                  onTap: (_isSubmitting || hasVideo) ? null : _pickFromGallery,
                  tooltip: hasVideo ? 'ลบวิดีโอก่อนถึงจะเลือกรูปได้' : 'เลือกจากแกลเลอรี่',
                ),
                _buildIconButton(
                  icon: HugeIcons.strokeRoundedVideo01,
                  // Disable ถ้ามี images หรือกำลัง submit
                  onTap: (_isSubmitting || hasImages) ? null : _pickVideo,
                  tooltip: hasImages ? 'ลบรูปก่อนถึงจะเลือกวิดีโอได้' : 'เลือกวีดีโอ',
                ),
              ],
            ),
            const Spacer(),
            // Submit button - ใช้ PrimaryButton จาก theme
            PrimaryButton(
              text: 'โพส',
              icon: HugeIcons.strokeRoundedFloppyDisk,
              onPressed: canSubmit ? _submit : null,
              isLoading: _isSubmitting,
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

    return CheckboxTile(
      value: isHandover,
      onChanged: canToggle
          ? (value) => ref.read(createPostProvider.notifier).setHandover(value)
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

  Widget _buildSendToFamilyToggle(CreatePostState state) {
    final sendToFamily = state.sendToFamily;
    // ถ้ามาจาก task จะบังคับให้ติ๊กและ disable checkbox + แสดงข้อความ "ส่งให้ญาติ"
    final isFromTask = widget.isFromTask;

    return CheckboxTile(
      value: sendToFamily,
      // ถ้า isFromTask = true จะ disable (onChanged = null)
      onChanged: isFromTask
          ? null
          : (value) => ref.read(createPostProvider.notifier).setSendToFamily(value),
      icon: HugeIcons.strokeRoundedUserGroup,
      // ถ้ามาจาก task แสดง "ส่งให้ญาติ" โดยตรง
      title: isFromTask ? 'ส่งให้ญาติ' : 'ส่งให้หัวหน้าเวร',
      subtitle: isFromTask
          ? 'งานนี้จะถูกส่งให้ญาติโดยอัตโนมัติ'
          : 'ส่งให้หัวหน้าเวรตรวจสอบและส่งให้ญาติ',
      isRequired: isFromTask,
    );
  }

  /// สร้าง video preview รองรับหลายไฟล์
  Widget _buildVideoPreview(CreatePostState state) {
    // รวม local videos และ uploaded video URLs
    final allVideos = [
      ...state.selectedVideos.map((f) => _VideoItem(file: f)),
      ...state.uploadedVideoUrls.map((url) => _VideoItem(url: url)),
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: allVideos.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final video = allVideos[index];
          final isLocal = video.file != null;
          final fileName = isLocal
              ? video.file!.path.split('/').last
              : video.url!.split('/').last.split('?').first;

          return Container(
            width: 100,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Video icon
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedVideo01,
                        size: AppIconSize.xl,
                        color: AppColors.secondaryText,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          fileName,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                // Remove button
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () {
                      if (isLocal) {
                        // หา index ใน selectedVideos
                        final localIndex = state.selectedVideos.indexOf(video.file!);
                        if (localIndex >= 0) {
                          ref.read(createPostProvider.notifier).removeVideo(localIndex);
                        }
                      } else {
                        // หา index ใน uploadedVideoUrls
                        final uploadedIndex = state.uploadedVideoUrls.indexOf(video.url!);
                        if (uploadedIndex >= 0) {
                          ref.read(createPostProvider.notifier).removeUploadedVideo(uploadedIndex);
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        size: 16,
                        color: Colors.white,
                      ),
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

/// Helper class สำหรับ video item (local file หรือ uploaded URL)
class _VideoItem {
  final File? file;
  final String? url;

  _VideoItem({this.file, this.url});
}
