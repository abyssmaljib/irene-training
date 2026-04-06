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
import '../../../core/widgets/app_toast.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../models/new_tag.dart';
import '../models/post_draft.dart';
import '../providers/create_post_provider.dart';
import '../providers/post_provider.dart';
import '../services/post_action_service.dart';
import '../services/post_media_service.dart';
import '../services/post_draft_service.dart';
import '../widgets/resident_tag_picker_row.dart';
import '../widgets/image_picker_bar.dart' show ImagePickerHelper;
import '../widgets/image_preview_grid.dart';
import '../widgets/quiz_form_widget.dart';
import '../widgets/ai_summary_widget.dart';
import '../../../core/widgets/checkbox_tile.dart';
import '../widgets/handover_toggle_widget.dart';
import '../widgets/post_extras_section.dart';
import '../../medicine/services/medicine_service.dart';
import '../services/ticket_service.dart';
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
  final _descriptionFocusNode = FocusNode(); // FocusNode สำหรับ focus ไปที่ description field
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Upload progress state - แสดงสถานะการอัพโหลดให้ user ทราบ
  String? _uploadStatusMessage;

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
    _descriptionFocusNode.dispose();
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
      // แจ้งเตือนเลือกรูปเกินจำนวนที่กำหนด
      AppToast.warning(context, 'สูงสุด 5 รูป');
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
      // เริ่ม optimistic background upload ทันที
      // แสดง progress UI ก่อน แล้วค่อยแสดง preview เมื่อ upload สำเร็จ
      _startBackgroundVideoUpload(file);
    }
  }

  /// เริ่ม background upload video พร้อม progress tracking
  Future<void> _startBackgroundVideoUpload(File videoFile) async {
    final notifier = ref.read(createPostProvider.notifier);
    final userId = UserService().effectiveUserId;

    // ล้าง video เดิม และเริ่ม upload state
    notifier.clearVideos();
    notifier.startVideoUpload(videoFile);

    try {
      // Upload video ด้วย dio streaming (แสดง progress จริง)
      final result = await PostMediaService.instance.uploadVideoWithProgress(
        videoFile,
        userId: userId,
        onProgress: (progress) {
          // อัพเดท progress ใน provider
          notifier.setVideoUploadProgress(progress);
        },
      );

      // ตรวจสอบผลลัพธ์
      if (result.videoUrl != null) {
        // อัพโหลดสำเร็จ - เก็บ URL และ thumbnail
        notifier.setVideoUploadSuccess(result.videoUrl!, result.thumbnailUrl);
      } else {
        // อัพโหลดไม่สำเร็จ
        notifier.setVideoUploadError('อัพโหลดวีดีโอไม่สำเร็จ กรุณาลองใหม่');
      }
    } catch (e) {
      // เกิด error ระหว่าง upload
      notifier.setVideoUploadError('เกิดข้อผิดพลาด: ${e.toString()}');
    }
  }

  /// Retry upload video ที่ล้มเหลว
  void _retryVideoUpload() {
    final state = ref.read(createPostProvider);
    // ถ้ามี local video file อยู่ ให้ลอง upload ใหม่
    if (state.selectedVideos.isNotEmpty) {
      _startBackgroundVideoUpload(state.selectedVideos.first);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(createPostProvider);
    final text = _textController.text.trim();

    // ถ้าติ๊ก "ส่งเวร" บังคับต้องกรอกรายละเอียด
    // เพื่อให้พี่เลี้ยงเขียนข้อมูลสำคัญที่ต้องส่งต่อให้เวรถัดไป
    if (state.isHandover && text.isEmpty) {
      // แจ้งเตือน validation: ต้องกรอกรายละเอียดเมื่อติ๊กส่งเวร
      AppToast.warning(context, 'กรุณากรอกรายละเอียดเมื่อติ๊กส่งเวร');
      return;
    }

    // ป้องกัน submit ขณะ video กำลัง upload
    if (state.isUploadingVideo) {
      // แจ้งเตือนให้รอ video upload เสร็จก่อน
      AppToast.info(context, 'กรุณารอให้วีดีโออัพโหลดเสร็จก่อน');
      return;
    }

    // ป้องกัน submit ถ้า video upload error (ต้อง retry หรือลบก่อน)
    if (state.videoUploadError != null) {
      // แจ้งเตือนให้แก้ไข video upload error ก่อน submit
      AppToast.warning(context, 'กรุณาลองอัพโหลดวีดีโอใหม่ หรือลบวีดีโอออก');
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

      // รวม media URLs: images + videos ที่ upload ไว้แล้ว (จาก background upload)
      List<String> allMediaUrls = [
        ...state.uploadedImageUrls,
        ...state.uploadedVideoUrls, // video URLs จาก background upload
      ];

      // Upload new images พร้อมแสดง progress (images ยังคง upload ตอน submit)
      if (state.selectedImages.isNotEmpty) {
        setState(() => _uploadStatusMessage = 'กำลังอัพโหลดรูปภาพ...');
        final uploadedUrls = await PostMediaService.instance.uploadImages(
          state.selectedImages,
          userId: userId,
        );
        allMediaUrls.addAll(uploadedUrls);
      }

      // Video ไม่ต้อง upload ตรงนี้แล้ว - ใช้ URL จาก background upload
      // (state.uploadedVideoUrls มี URL อยู่แล้วจาก _startBackgroundVideoUpload)

      // Clear upload status หลัง upload เสร็จ
      if (mounted) {
        setState(() => _uploadStatusMessage = null);
      }

      // Build tag topics list
      List<String>? tagTopics;
      if (state.selectedTag != null) {
        tagTopics = [state.selectedTag!.name];
      }
      // เพิ่ม tag "ส่งให้ญาติ" ถ้าเลือก
      if (state.sendToFamily) {
        const familyTag = 'ส่งให้ญาติ';
        tagTopics = [...?tagTopics, familyTag];
      }

      // === สรุป restock ต่อท้ายข้อความ (เมื่อส่งให้ญาติ) ===
      // ญาติจะได้เห็นว่ามียาอะไรถูกเติมบ้าง
      // === สรุป restock ต่อท้ายข้อความเสมอ (ไม่ว่าจะส่งให้ญาติหรือไม่) ===
      // เพื่อให้โพสมีบันทึกว่าเติมยาอะไรไปบ้าง
      String finalText = text;
      final restockSummary = _buildRestockSummaryText(state.restockItems);
      if (restockSummary.isNotEmpty) {
        finalText = text.isEmpty
            ? restockSummary
            : '$text\n\n$restockSummary';
      }

      // Create post
      final postId = await PostActionService.instance.createPost(
        userId: userId,
        nursinghomeId: nursinghomeId,
        text: finalText,
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
        // เชื่อมโพสกับนัดหมายใน C_Calendar_with_Post
        calendarAppointmentId: state.calendarAppointmentId,
      );

      if (postId != null) {
        // === Link pending med_history (จากการสร้างยาใหม่ระหว่าง session) ===
        // UPDATE med_history rows ที่สร้างไว้ก่อนหน้า ให้มี post_id
        if (state.pendingMedHistoryIds.isNotEmpty) {
          await _linkPendingMedHistory(postId, state.pendingMedHistoryIds);
        }

        // === INSERT restock records (ถ้ามี) ===
        // เชื่อม med_history กับ post ผ่าน post_id เพื่อ audit trail
        final enabledRestocks = state.restockItems
            .where((i) => i.enabled && i.reconcile > 0)
            .toList();
        if (enabledRestocks.isNotEmpty) {
          await _insertRestockRecords(postId, userId, enabledRestocks);
          // Invalidate medicine cache เพื่อให้หน้ายาแสดงข้อมูลใหม่
          MedicineService.instance.invalidateCache();
        }

        // === Complete selected tickets (ถ้ามี) ===
        // ปิด tickets ที่ user ติ๊ก "ปิด ticket นี้เมื่อสร้างโพส"
        final ticketIdsToComplete = state.allTicketIdsToComplete;
        if (ticketIdsToComplete.isNotEmpty) {
          await TicketService.instance
              .completeTickets(ticketIdsToComplete.toList());
        }

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
              // ไม่ใส่ confirmImage เพราะรูปจะดึงจาก post_id แทน
              final optimisticTask = taskToUpdate.copyWith(
                status: 'completed',
                completedAt: DateTime.now(),
                completedByUid: userId,
                completedByNickname: nickname,
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
            allowSkip: false, // ต้องให้คะแนนทุกครั้ง
          );

          // คะแนนความยากที่ user ให้ (null = ปิด dialog หรือข้าม)
          final difficultyScore = difficultyResult?.score;

          try {
            // Complete task พร้อม difficulty score
            // ไม่ส่ง imageUrl เพราะรูปอยู่ใน Post แล้ว (ผ่าน post_id)
            // ป้องกันการบันทึกซ้ำซ้อนและเข้าคิวส่งซ้ำ
            await TaskService.instance.markTaskComplete(
              widget.taskLogId!,
              userId,
              // imageUrl: widget.taskConfirmImageUrl, // ไม่บันทึก confirmImage เพราะดึงจาก post_id แทน
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
        // แจ้ง error เมื่อสร้างโพสไม่สำเร็จ
        AppToast.error(context, 'เกิดข้อผิดพลาด: $e');
      }
    } finally {
      // Clear upload status และ submitting state เสมอ
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _uploadStatusMessage = null;
        });
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
                // ไม่ต้อง sync ทุก keystroke เพราะทำให้ rebuild บ่อย
                // จะ read จาก controller ตอน submit แทน
              ),

              AppSpacing.verticalGapLg,

              // Description field (ไม่บังคับกรอก - ยกเว้นติ๊กส่งเวร)
              _buildSectionLabel('รายละเอียด'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _textController,
                focusNode: _descriptionFocusNode, // ใช้สำหรับ focus เมื่อติ๊กส่งเวร
                maxLines: null,
                minLines: 4,
                decoration: InputDecoration(
                  // ถ้ามาจาก task ให้ใช้ hint text พิเศษเพื่อแนะนำ user
                  hintText: widget.isFromTask
                      ? 'หากมีอาการผิดปกติ ผิดแปลกไปจากเดิม ให้บรรยายไว้ที่นี่'
                      : 'เขียนรายละเอียดที่นี่...',
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
              // Resident picker + Tag picker (ใช้ reusable widget)
              ResidentTagPickerRow(
                selectedResidentId: state.selectedResidentId,
                selectedResidentName: state.selectedResidentName,
                onResidentSelected: (id, name) {
                  ref.read(createPostProvider.notifier).selectResident(id, name);
                },
                onResidentCleared: () {
                  ref.read(createPostProvider.notifier).clearResident();
                },
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
                // ล็อก resident + tag เมื่อมาจาก task หรือ DD
                // เพื่อป้องกัน user ลบ resident ที่ discharge ไปแล้ว
                disabled: widget.isFromTask || state.ddId != null,
                isTagRequired: true, // บังคับเลือก tag
              ),

              // Handover toggle
              if (state.selectedTag != null) ...[
                AppSpacing.verticalGapSm,
                HandoverToggleWidget(
                  selectedTag: state.selectedTag,
                  isHandover: state.isHandover,
                  selectedResidentId: state.selectedResidentId,
                  onHandoverChanged: (value) {
                    ref.read(createPostProvider.notifier).setHandover(value);
                  },
                  descriptionFocusNode: _descriptionFocusNode,
                  descriptionText: _textController.text,
                  onAutoEnableHandover: () {
                    ref.read(createPostProvider.notifier).setHandover(true);
                  },
                ),
              ],

              // Send to family toggle (แสดงเมื่อเลือก resident แล้ว)
              if (state.selectedResidentId != null) ...[
                AppSpacing.verticalGapSm,
                _buildSendToFamilyToggle(state),
              ],

              // แนบเพิ่มเติม: อัพเดตสต็อก, ใบนัด, อื่นๆ
              // แสดงเมื่อเลือก resident แล้ว
              if (state.selectedResidentId != null) ...[
                AppSpacing.verticalGapSm,
                PostExtrasSection(
                  residentId: state.selectedResidentId!,
                  residentName: state.selectedResidentName,
                  restockItems: state.restockItems,
                  onRestockItemsLoaded: (items) {
                    ref.read(createPostProvider.notifier).setRestockItems(items);
                  },
                  onRestockItemToggled: (medListId, enabled) {
                    final notifier = ref.read(createPostProvider.notifier);
                    notifier.toggleRestockItem(medListId, enabled);

                    // ถ้ามี restock item enabled อย่างน้อย 1 ตัว → auto-select tag "ยา"
                    // overwrite tag ปัจจุบัน เพื่อให้โพสจัดหมวดหมู่ถูกต้อง
                    if (enabled) {
                      final currentState = ref.read(createPostProvider);
                      final hasAnyEnabled =
                          currentState.restockItems.any((i) => i.enabled);
                      if (hasAnyEnabled) {
                        _autoSelectTagByName('ยา');
                      }
                    }
                  },
                  onRestockQuantityChanged: (medListId, inputDisplay, reconcile) {
                    ref
                        .read(createPostProvider.notifier)
                        .updateRestockQuantity(
                          medListId,
                          inputDisplay: inputDisplay,
                          reconcile: reconcile,
                        );
                  },
                  // เมื่อสร้างยาใหม่สำเร็จ → เก็บ med_history ID ไว้ link กับ post ตอน submit
                  onNewMedicineCreated: (medHistoryId) {
                    ref
                        .read(createPostProvider.notifier)
                        .addPendingMedHistoryId(medHistoryId);
                  },
                ),
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
    // ไม่ต้องใช้ MediaQuery.viewInsets ที่นี่
    // เพราะ Scaffold จัดการ keyboard avoidance ให้ bottomNavigationBar อัตโนมัติ
    // การเพิ่ม viewInsets.bottom ซ้ำจะทำให้ padding เกินจริง + rebuild ทุกเฟรมตอน keyboard ขึ้น

    // Mutual exclusion: เลือกได้อย่างเดียว รูป หรือ วิดีโอ
    final hasImages = state.hasImages;
    final hasVideo = state.hasVideo;
    final hasMedia = hasImages || hasVideo;

    // เงื่อนไขการโพส:
    // - ต้องเลือก tag เสมอ
    // - ถ้ามาจาก task: ต้องมีรูป หรือ วิดีโออย่างน้อย 1 อัน (รายละเอียดไม่บังคับ)
    // - ถ้าไม่ได้มาจาก task: โพสได้เลย (ไม่บังคับอะไร)
    final hasTag = state.selectedTag != null;
    final canSubmit =
        !_isSubmitting && hasTag && (!widget.isFromTask || hasMedia);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.alternate),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Upload progress indicator - แสดงเมื่อกำลังอัพโหลด
            if (_uploadStatusMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _uploadStatusMessage!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Row ของปุ่ม picker และปุ่ม submit
            Row(
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

  Widget _buildSendToFamilyToggle(CreatePostState state) {
    final sendToFamily = state.sendToFamily;
    // ถ้ามาจาก task จะบังคับให้ติ๊กและ disable checkbox
    final isFromTask = widget.isFromTask;

    return CheckboxTile(
      value: sendToFamily,
      // ถ้า isFromTask = true จะ disable (onChanged = null)
      onChanged: isFromTask
          ? null
          : (value) => ref.read(createPostProvider.notifier).setSendToFamily(value),
      icon: HugeIcons.strokeRoundedUserGroup,
      title: 'ส่งให้ญาติ',
      subtitle: isFromTask
          ? 'งานนี้จะถูกส่งให้ญาติโดยอัตโนมัติ'
          : 'ส่งโพสต์นี้ให้ญาติของผู้สูงอายุ',
      isRequired: isFromTask,
    );
  }

  /// สร้างข้อความสรุป restock สำหรับแนบท้ายโพส (ส่งให้ญาติ)
  /// เฉพาะ items ที่ enabled + reconcile > 0
  /// ตัวอย่าง:
  ///   📦 อัพเดตสต็อกยา
  ///   • พาราเซตามอล เพิ่ม 30 เม็ด → คงเหลือ 90 เม็ด
  ///   • อะม็อกซิซิลลิน เพิ่ม 10 แคปซูล → คงเหลือ 25 แคปซูล
  String _buildRestockSummaryText(List<RestockItem> items) {
    final enabled = items.where((i) => i.enabled && i.reconcile > 0).toList();
    if (enabled.isEmpty) return '';

    final lines = <String>['📦 อัพเดตสต็อกยา'];
    for (final item in enabled) {
      // ใช้ generic name ถ้ามี, ไม่งั้นใช้ medicineName
      final name = item.medicineSummary?.genericName ?? item.medicineName;
      final diff = item.reconcile - item.currentReconcile;
      final diffStr = _formatNumber(diff.abs());
      final reconcileStr = _formatNumber(item.reconcile);

      // แสดง "เพิ่ม / ลด / ตั้งเป็น" ตามผลลัพธ์
      final String action;
      if (diff > 0) {
        action = 'เพิ่ม $diffStr ${item.unit}';
      } else if (diff < 0) {
        action = 'ลด $diffStr ${item.unit}';
      } else {
        action = 'คงเดิม';
      }

      lines.add('• $name $action → คงเหลือ $reconcileStr ${item.unit}');
    }
    return lines.join('\n');
  }

  /// Format ตัวเลข: ถ้าเป็นจำนวนเต็มแสดงไม่มีทศนิยม
  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  /// INSERT restock records ลง med_history พร้อม post_id
  /// เรียกหลัง createPost สำเร็จ เพื่อเชื่อม restock กับ post
  /// ถ้า INSERT ล้มเหลว → แสดง warning แต่ไม่ rollback post (post เป็น primary action)
  Future<void> _insertRestockRecords(
    int postId,
    String userId,
    List<RestockItem> items,
  ) async {
    try {
      // สร้าง rows สำหรับ batch insert
      final rows = items
          .map((item) => {
                'med_list_id': item.medicineListId,
                'reconcile': item.reconcile,
                'change_type': 'restock',
                'post_id': postId,
                'user_id': userId,
              })
          .toList();

      await Supabase.instance.client.from('med_history').insert(rows);
      debugPrint('[AdvancedCreatePost] restock ${rows.length} items OK');
    } catch (e) {
      debugPrint('[AdvancedCreatePost] restock insert error: $e');
      if (mounted) {
        AppToast.warning(context, 'สร้างโพสสำเร็จ แต่บันทึก restock ไม่สำเร็จ');
      }
    }
  }

  /// UPDATE med_history rows ที่สร้างระหว่าง session (สร้างยาใหม่) ให้มี post_id
  /// เรียกหลัง createPost สำเร็จ เพื่อเชื่อม med_history กับ post
  Future<void> _linkPendingMedHistory(int postId, List<int> medHistoryIds) async {
    try {
      await Supabase.instance.client
          .from('med_history')
          .update({'post_id': postId})
          .inFilter('id', medHistoryIds);
      debugPrint(
          '[AdvancedCreatePost] linked ${medHistoryIds.length} pending med_history to post $postId');
    } catch (e) {
      debugPrint('[AdvancedCreatePost] link pending med_history error: $e');
      // Warning only — ไม่ rollback post
    }
  }

  /// สร้าง video preview รองรับ upload states
  Widget _buildVideoPreview(CreatePostState state) {
    // ตรวจสอบ state ของ video upload
    final isUploading = state.isUploadingVideo;
    final hasError = state.videoUploadError != null;
    final hasUploadedVideo = state.uploadedVideoUrls.isNotEmpty;

    // ถ้ากำลัง upload - แสดง progress UI
    if (isUploading) {
      return _buildVideoUploadingItem(state);
    }

    // ถ้ามี error - แสดง error + retry
    if (hasError) {
      return _buildVideoErrorItem(state);
    }

    // ถ้า upload สำเร็จ - แสดง uploaded video(s)
    if (hasUploadedVideo) {
      return _buildUploadedVideosPreview(state);
    }

    // Fallback: แสดง local videos ที่ยังไม่ได้ upload (กรณียังไม่ได้เริ่ม upload)
    if (state.selectedVideos.isNotEmpty) {
      return _buildLocalVideosPreview(state);
    }

    // ไม่มี video
    return const SizedBox.shrink();
  }

  /// แสดง uploading state
  Widget _buildVideoUploadingItem(CreatePostState state) {
    final progress = state.videoUploadProgress;
    final percentage = (progress * 100).toInt();

    return Container(
      height: 100,
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Upload icon
          HugeIcon(
            icon: HugeIcons.strokeRoundedCloudUpload,
            size: AppIconSize.xl,
            color: AppColors.primary,
          ),
          SizedBox(width: AppSpacing.md),
          // Progress info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'กำลังอัพโหลดวีดีโอ... $percentage%',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.inputBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// แสดง error state พร้อมปุ่ม retry
  Widget _buildVideoErrorItem(CreatePostState state) {
    return Container(
      height: 100,
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Error icon
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: AppIconSize.xl,
            color: AppColors.error,
          ),
          SizedBox(width: AppSpacing.md),
          // Error message
          Expanded(
            child: Text(
              state.videoUploadError ?? 'อัพโหลดไม่สำเร็จ',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          // Action buttons
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Retry button
              GestureDetector(
                onTap: _retryVideoUpload,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 4),
              // Cancel button
              GestureDetector(
                onTap: () => ref.read(createPostProvider.notifier).cancelVideoUpload(),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// แสดง uploaded videos (สำเร็จแล้ว)
  Widget _buildUploadedVideosPreview(CreatePostState state) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.uploadedVideoUrls.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final url = state.uploadedVideoUrls[index];
          final fileName = url.split('/').last.split('?').first;

          return Container(
            width: 100,
            decoration: BoxDecoration(
              color: AppColors.accent1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Stack(
              children: [
                // Video icon with success indicator
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedVideo01,
                            size: AppIconSize.xl,
                            color: AppColors.primary,
                          ),
                          // Success checkmark
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          fileName,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
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
                      ref.read(createPostProvider.notifier).cancelVideoUpload();
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

  /// แสดง local videos (fallback - กรณียังไม่ได้เริ่ม upload)
  Widget _buildLocalVideosPreview(CreatePostState state) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.selectedVideos.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final file = state.selectedVideos[index];
          final fileName = file.path.split('/').last.split('\\').last;

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
                      ref.read(createPostProvider.notifier).cancelVideoUpload();
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

