import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/new_tag.dart';
import '../models/post_draft.dart';
import '../providers/create_post_provider.dart';
import '../providers/post_provider.dart';
import '../providers/tag_provider.dart';
import '../services/post_draft_service.dart';
import '../../checklist/services/task_service.dart';
import '../../checklist/providers/task_provider.dart' show refreshTasks;
import 'resident_tag_picker_row.dart';
import 'resident_picker_widget.dart' show ResidentOption, residentsProvider;
import 'image_picker_bar.dart';
import 'image_preview_grid.dart';
import '../services/post_media_service.dart';
import '../../../core/widgets/success_popup.dart';
import '../../../core/widgets/checkbox_tile.dart';
import 'handover_toggle_widget.dart';

/// Bottom Sheet สำหรับสร้างโพสแบบรวดเร็ว
class CreatePostBottomSheet extends ConsumerStatefulWidget {
  final VoidCallback? onPostCreated;
  final VoidCallback? onAdvancedTap;

  /// Initial values for pre-filling the form (สำหรับ task completion by post)
  final String? initialText;
  final int? initialResidentId;
  final String? initialResidentName;
  final String? initialTagName; // ชื่อ tag ที่จะ auto-select

  /// Task completion fields (สำหรับ complete task เมื่อโพสสำเร็จ)
  final int? taskLogId; // ถ้ามี จะ complete task เมื่อโพสสำเร็จ
  final String? taskConfirmImageUrl; // รูปยืนยันจาก task (ถ้ามี)

  /// ตรวจสอบว่ามาจาก task หรือไม่ (ถ้ามา text จะแก้ไขไม่ได้)
  bool get isFromTask => taskLogId != null;

  const CreatePostBottomSheet({
    super.key,
    this.onPostCreated,
    this.onAdvancedTap,
    this.initialText,
    this.initialResidentId,
    this.initialResidentName,
    this.initialTagName,
    this.taskLogId,
    this.taskConfirmImageUrl,
  });

  @override
  ConsumerState<CreatePostBottomSheet> createState() =>
      _CreatePostBottomSheetState();
}

class _CreatePostBottomSheetState extends ConsumerState<CreatePostBottomSheet> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isUploading = false;

  // Upload progress state - แสดงสถานะการอัพโหลดให้ user ทราบ
  String? _uploadStatusMessage;

  // Draft auto-save state
  // ใช้สำหรับบันทึก draft อัตโนมัติเมื่อ user พิมพ์
  Timer? _autoSaveTimer;
  static const _autoSaveDelay = Duration(seconds: 2);
  PostDraftService? _draftService;
  bool _isRestoringDraft = false; // ป้องกันการ save ระหว่าง restore

  // # shortcut state (tags)
  bool _showTagSuggestions = false;
  String _tagSearchQuery = '';
  OverlayEntry? _tagOverlay;
  final LayerLink _layerLink = LayerLink();
  int _selectedTagIndex = 0;
  List<NewTag> _filteredTags = [];
  final ScrollController _tagScrollController = ScrollController();

  // @ shortcut state (residents)
  bool _showResidentSuggestions = false;
  String _residentSearchQuery = '';
  OverlayEntry? _residentOverlay;
  int _selectedResidentIndex = 0;
  List<ResidentOption> _filteredResidents = [];
  final ScrollController _residentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Set initial text if provided
    if (widget.initialText != null) {
      _textController.text = widget.initialText!;
    }

    // Reset state when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize draft service
      final prefs = ref.read(sharedPreferencesProvider);
      _draftService = PostDraftService(prefs);

      // Initialize state with initial values if provided
      if (widget.initialText != null ||
          widget.initialResidentId != null ||
          widget.initialTagName != null) {
        ref.read(createPostProvider.notifier).initFromTask(
              text: widget.initialText ?? '',
              residentId: widget.initialResidentId,
              residentName: widget.initialResidentName,
            );

        // Auto-select tag if initialTagName is provided
        if (widget.initialTagName != null) {
          _autoSelectTagByName(widget.initialTagName!);
        }
      } else {
        // ถ้าไม่ได้มาจาก task ให้ตรวจสอบ draft
        _checkAndRestoreDraft();
      }

      // [FUTURE] Listen to provider changes and update overlays when data arrives
      // เก็บไว้สำหรับฟีเจอร์ # และ @ shortcut ในอนาคต (เช่น การสั่งงานระหว่างทีม)
      // ref.listenManual(tagsProvider, (previous, next) {
      //   if (_showTagSuggestions && next.hasValue) {
      //     _updateFilteredTags();
      //     _tagOverlay?.markNeedsBuild();
      //   }
      // });

      // ref.listenManual(residentsProvider, (previous, next) {
      //   if (_showResidentSuggestions && next.hasValue) {
      //     _updateFilteredResidents();
      //     _residentOverlay?.markNeedsBuild();
      //   }
      // });
    });

    // Listen for text changes เพื่อ auto-save draft
    _textController.addListener(_onContentChanged);

    // [FUTURE] Listen for keyboard navigation - disabled for now
    // _focusNode.onKeyEvent = _handleKeyEvent;
  }

  /// Auto-select tag by name (match by taskType name)
  Future<void> _autoSelectTagByName(String tagName) async {
    // รอให้ tags โหลดเสร็จก่อน
    final tags = await ref.read(tagsProvider.future);

    // หา tag ที่ชื่อตรงกับ tagName หรืออยู่ใน legacy_tags
    final matchingTag = tags.cast<NewTag?>().firstWhere(
          (tag) =>
              tag!.name == tagName ||
              (tag.legacyTags?.contains(tagName) ?? false),
          orElse: () => null,
        );

    if (matchingTag != null && mounted) {
      ref.read(createPostProvider.notifier).selectTag(matchingTag);
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _textController.removeListener(_onContentChanged);
    _removeTagOverlay();
    _removeResidentOverlay();
    _textController.dispose();
    _focusNode.dispose();
    _tagScrollController.dispose();
    _residentScrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // Draft Management Functions
  // ============================================================

  /// Callback เมื่อ content เปลี่ยน - debounce แล้ว auto-save draft
  void _onContentChanged() {
    // ถ้ากำลัง restore draft อยู่ ไม่ต้อง save
    if (_isRestoringDraft) return;
    // ถ้ามาจาก task ไม่ต้อง save draft
    if (widget.isFromTask) return;

    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, _saveDraft);
  }

  /// ตรวจสอบว่ามีข้อมูลที่ยังไม่ได้บันทึกหรือไม่
  bool _hasUnsavedData() {
    final state = ref.read(createPostProvider);
    return _textController.text.trim().isNotEmpty ||
        state.selectedTag != null ||
        state.selectedResidentId != null ||
        state.selectedImages.isNotEmpty ||
        state.selectedVideos.isNotEmpty;
  }

  /// บันทึก draft ลง SharedPreferences
  Future<void> _saveDraft() async {
    if (_draftService == null) return;
    if (widget.isFromTask) return;

    final userId = ref.read(postCurrentUserIdProvider);
    if (userId == null) return;

    final state = ref.read(createPostProvider);
    final draft = PostDraft(
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
      isAdvanced: false,
    );

    await _draftService!.saveDraft(userId.toString(), draft);
  }

  /// ตรวจสอบและ restore draft ถ้ามี
  Future<void> _checkAndRestoreDraft() async {
    if (_draftService == null) return;

    final userId = ref.read(postCurrentUserIdProvider);
    if (userId == null) {
      ref.read(createPostProvider.notifier).reset();
      return;
    }

    final userIdStr = userId.toString();
    if (!_draftService!.hasDraft(userIdStr)) {
      ref.read(createPostProvider.notifier).reset();
      return;
    }

    // โหลด draft
    final draft = _draftService!.loadDraft(userIdStr);
    if (draft == null || !draft.hasContent) {
      ref.read(createPostProvider.notifier).reset();
      return;
    }

    // ถ้า draft เป็น advanced mode ให้ข้ามไป (ไม่ restore ใน simple mode)
    if (draft.isAdvanced) {
      ref.read(createPostProvider.notifier).reset();
      return;
    }

    // แสดง dialog ถามว่าจะใช้ draft หรือไม่
    if (!mounted) return;
    final shouldRestore = await _showRestoreDraftDialog();

    if (shouldRestore == true) {
      _restoreDraft(draft);
    } else {
      // ลบ draft และ reset
      await _draftService!.clearDraft(userIdStr);
      if (mounted) {
        ref.read(createPostProvider.notifier).reset();
      }
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

    // Restore text
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

    // Note: Images และ Video ไม่ restore เพราะ file อาจถูกลบไปแล้ว
    // ถ้าต้องการ restore ต้องตรวจสอบว่า file ยังอยู่หรือไม่

    _isRestoringDraft = false;
  }

  /// จัดการเมื่อ user พยายามปิด modal
  /// ใช้ ExitCreateDialog จาก reusable widget (3 ปุ่ม)
  /// Returns true ถ้าควรปิด, false ถ้าไม่ควรปิด
  Future<bool> _handleCloseAttempt() async {
    // ถ้าไม่มีข้อมูล ปิดได้เลย
    if (!_hasUnsavedData()) return true;

    // ใช้ ExitCreateDialog.show() สำหรับ 3 ปุ่ม
    final result = await ExitCreateDialog.show(context);

    switch (result) {
      case ExitCreateResult.continueEditing:
        // กลับไปแก้ไข - ไม่ปิด modal
        return false;
      case ExitCreateResult.saveDraft:
        // บันทึกร่าง แล้วปิด
        await _saveDraft();
        return true;
      case ExitCreateResult.discard:
        // ยกเลิก - ลบ draft แล้วปิด
        final userId = ref.read(postCurrentUserIdProvider);
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
    final userId = ref.read(postCurrentUserIdProvider);
    if (userId != null && _draftService != null) {
      await _draftService!.clearDraft(userId.toString());
    }
  }

  // ============================================================
  // [FUTURE] # และ @ Shortcut Functions
  // เก็บไว้สำหรับฟีเจอร์การสั่งงานระหว่างทีมในอนาคต
  // เช่น พิมพ์ # เพื่อเลือก tag, พิมพ์ @ เพื่อ mention ผู้พัก
  // ============================================================

  // ignore: unused_element
  void _onTextChangedForShortcuts() {
    final text = _textController.text;
    final selection = _textController.selection;

    if (selection.baseOffset != selection.extentOffset) {
      // มี selection อยู่ ไม่แสดง suggestions
      _hideTagSuggestions();
      _hideResidentSuggestions();
      return;
    }

    final cursorPos = selection.baseOffset;
    if (cursorPos <= 0) {
      _hideTagSuggestions();
      _hideResidentSuggestions();
      return;
    }

    final textBeforeCursor = text.substring(0, cursorPos);

    // หา # และ @ ที่อยู่ก่อน cursor
    final lastHashIndex = textBeforeCursor.lastIndexOf('#');
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    // ตรวจสอบว่าอันไหนอยู่ใกล้ cursor มากกว่า
    if (lastAtIndex > lastHashIndex) {
      // @ อยู่ใกล้กว่า - ตรวจสอบ resident suggestions
      _hideTagSuggestions();
      _checkResidentSuggestion(textBeforeCursor, lastAtIndex);
    } else if (lastHashIndex > lastAtIndex) {
      // # อยู่ใกล้กว่า - ตรวจสอบ tag suggestions
      _hideResidentSuggestions();
      _checkTagSuggestion(textBeforeCursor, lastHashIndex);
    } else {
      // ไม่มีทั้ง # และ @
      _hideTagSuggestions();
      _hideResidentSuggestions();
    }
  }

  void _checkTagSuggestion(String textBeforeCursor, int lastHashIndex) {
    if (lastHashIndex == -1) {
      _hideTagSuggestions();
      return;
    }

    // ตรวจสอบว่า # อยู่หลัง space หรือขึ้นต้นบรรทัด
    final charBeforeHash = lastHashIndex > 0 ? textBeforeCursor[lastHashIndex - 1] : ' ';
    if (charBeforeHash != ' ' && charBeforeHash != '\n' && lastHashIndex != 0) {
      _hideTagSuggestions();
      return;
    }

    // ดึงคำที่พิมพ์หลัง #
    final queryAfterHash = textBeforeCursor.substring(lastHashIndex + 1);

    // ถ้ามี space หลัง # แปลว่าจบการพิมพ์ tag แล้ว
    if (queryAfterHash.contains(' ') || queryAfterHash.contains('\n')) {
      _hideTagSuggestions();
      return;
    }

    // แสดง tag suggestions
    setState(() {
      _showTagSuggestions = true;
      _tagSearchQuery = queryAfterHash;
      _selectedTagIndex = 0;
    });
    _updateFilteredTags();
    _showTagOverlay();
  }

  void _checkResidentSuggestion(String textBeforeCursor, int lastAtIndex) {
    if (lastAtIndex == -1) {
      _hideResidentSuggestions();
      return;
    }

    // ตรวจสอบว่า @ อยู่หลัง space หรือขึ้นต้นบรรทัด
    final charBeforeAt = lastAtIndex > 0 ? textBeforeCursor[lastAtIndex - 1] : ' ';
    if (charBeforeAt != ' ' && charBeforeAt != '\n' && lastAtIndex != 0) {
      _hideResidentSuggestions();
      return;
    }

    // ดึงคำที่พิมพ์หลัง @
    final queryAfterAt = textBeforeCursor.substring(lastAtIndex + 1);

    // ถ้ามี space หลัง @ แปลว่าจบการพิมพ์ชื่อแล้ว
    if (queryAfterAt.contains(' ') || queryAfterAt.contains('\n')) {
      _hideResidentSuggestions();
      return;
    }

    // แสดง resident suggestions
    setState(() {
      _showResidentSuggestions = true;
      _residentSearchQuery = queryAfterAt;
      _selectedResidentIndex = 0;
    });
    _updateFilteredResidents();
    _showResidentOverlay();
  }

  void _updateFilteredTags() {
    final tagsAsync = ref.read(tagsProvider);

    tagsAsync.when(
      data: (tags) {
        if (_tagSearchQuery.isEmpty) {
          _filteredTags = tags;
        } else {
          final query = _tagSearchQuery.toLowerCase();
          _filteredTags = tags.where((t) {
            return t.name.toLowerCase().contains(query) ||
                (t.emoji?.contains(query) ?? false);
          }).toList();
        }
      },
      loading: () {
        _filteredTags = [];
      },
      error: (_, _) {
        _filteredTags = [];
      },
    );
  }

  // ignore: unused_element
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Handle tag suggestions
    if (_showTagSuggestions && _filteredTags.isNotEmpty) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            _selectedTagIndex = (_selectedTagIndex + 1) % _filteredTags.length;
          });
          _tagOverlay?.markNeedsBuild();
          _scrollToSelectedTag();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            _selectedTagIndex = (_selectedTagIndex - 1 + _filteredTags.length) % _filteredTags.length;
          });
          _tagOverlay?.markNeedsBuild();
          _scrollToSelectedTag();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.tab) {
          _onTagSelectedFromPopup(_filteredTags[_selectedTagIndex]);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          _hideTagSuggestions();
          return KeyEventResult.handled;
        }
      }
    }

    // Handle resident suggestions
    if (_showResidentSuggestions && _filteredResidents.isNotEmpty) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            _selectedResidentIndex = (_selectedResidentIndex + 1) % _filteredResidents.length;
          });
          _residentOverlay?.markNeedsBuild();
          _scrollToSelectedResident();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            _selectedResidentIndex = (_selectedResidentIndex - 1 + _filteredResidents.length) % _filteredResidents.length;
          });
          _residentOverlay?.markNeedsBuild();
          _scrollToSelectedResident();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.tab) {
          _onResidentSelectedFromPopup(_filteredResidents[_selectedResidentIndex]);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          _hideResidentSuggestions();
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  void _scrollToSelectedResident() {
    if (!_residentScrollController.hasClients) return;

    const itemHeight = 56.0;
    final targetOffset = _selectedResidentIndex * itemHeight;
    final maxScroll = _residentScrollController.position.maxScrollExtent;
    final viewportHeight = _residentScrollController.position.viewportDimension;

    double scrollTo = targetOffset - (viewportHeight / 2) + (itemHeight / 2);
    scrollTo = scrollTo.clamp(0.0, maxScroll);

    _residentScrollController.animateTo(
      scrollTo,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  void _scrollToSelectedTag() {
    if (!_tagScrollController.hasClients) return;

    const itemHeight = 40.0; // ความสูงของแต่ละ item
    final targetOffset = _selectedTagIndex * itemHeight;
    final maxScroll = _tagScrollController.position.maxScrollExtent;
    final viewportHeight = _tagScrollController.position.viewportDimension;

    // คำนวณว่าต้อง scroll ไปที่ไหน
    double scrollTo = targetOffset - (viewportHeight / 2) + (itemHeight / 2);
    scrollTo = scrollTo.clamp(0.0, maxScroll);

    _tagScrollController.animateTo(
      scrollTo,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  void _hideTagSuggestions() {
    if (_showTagSuggestions) {
      setState(() {
        _showTagSuggestions = false;
        _tagSearchQuery = '';
      });
      _removeTagOverlay();
    }
  }

  void _showTagOverlay() {
    _removeTagOverlay();

    _tagOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 8),
          followerAnchor: Alignment.topLeft,
          targetAnchor: Alignment.bottomLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: _TagSuggestionsPopup(
              searchQuery: _tagSearchQuery,
              filteredTags: _filteredTags,
              selectedIndex: _selectedTagIndex,
              scrollController: _tagScrollController,
              onTagSelected: _onTagSelectedFromPopup,
              onDismiss: _hideTagSuggestions,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_tagOverlay!);
  }

  void _removeTagOverlay() {
    _tagOverlay?.remove();
    _tagOverlay = null;
  }

  void _onTagSelectedFromPopup(NewTag tag) {
    // แทนที่ #query ด้วย tag name
    final text = _textController.text;
    final cursorPos = _textController.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);
    final lastHashIndex = textBeforeCursor.lastIndexOf('#');

    if (lastHashIndex != -1) {
      final newText =
          '${text.substring(0, lastHashIndex)}#${tag.name} ${text.substring(cursorPos)}';

      _textController.text = newText;
      // ย้าย cursor ไปหลัง tag
      final newCursorPos = lastHashIndex + tag.name.length + 2;
      _textController.selection = TextSelection.collapsed(offset: newCursorPos);

      // เลือก tag ใน state
      ref.read(createPostProvider.notifier).selectTag(tag);
    }

    _hideTagSuggestions();
  }

  // ==================== @ Resident Suggestions ====================

  void _updateFilteredResidents() {
    final residentsAsync = ref.read(residentsProvider);

    residentsAsync.when(
      data: (residents) {
        if (_residentSearchQuery.isEmpty) {
          _filteredResidents = residents;
        } else {
          final query = _residentSearchQuery.toLowerCase();
          _filteredResidents = residents.where((r) {
            return r.name.toLowerCase().contains(query) ||
                (r.zone?.toLowerCase().contains(query) ?? false);
          }).toList();
        }
      },
      loading: () {
        _filteredResidents = [];
      },
      error: (_, _) {
        _filteredResidents = [];
      },
    );
  }

  void _hideResidentSuggestions() {
    if (_showResidentSuggestions) {
      setState(() {
        _showResidentSuggestions = false;
        _residentSearchQuery = '';
      });
      _removeResidentOverlay();
    }
  }

  void _showResidentOverlay() {
    _removeResidentOverlay();

    _residentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 8),
          followerAnchor: Alignment.topLeft,
          targetAnchor: Alignment.bottomLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: _ResidentSuggestionsPopup(
              searchQuery: _residentSearchQuery,
              filteredResidents: _filteredResidents,
              selectedIndex: _selectedResidentIndex,
              scrollController: _residentScrollController,
              onResidentSelected: _onResidentSelectedFromPopup,
              onDismiss: _hideResidentSuggestions,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_residentOverlay!);
  }

  void _removeResidentOverlay() {
    _residentOverlay?.remove();
    _residentOverlay = null;
  }

  void _onResidentSelectedFromPopup(ResidentOption resident) {
    // แทนที่ @query ด้วยชื่อผู้พัก
    final text = _textController.text;
    final cursorPos = _textController.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex != -1) {
      final newText =
          '${text.substring(0, lastAtIndex)}@${resident.name} ${text.substring(cursorPos)}';

      _textController.text = newText;
      // ย้าย cursor ไปหลังชื่อ
      final newCursorPos = lastAtIndex + resident.name.length + 2;
      _textController.selection = TextSelection.collapsed(offset: newCursorPos);

      // เลือก resident ใน state
      ref.read(createPostProvider.notifier).selectResident(resident.id, resident.name);
    }

    _hideResidentSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createPostProvider);
    final canCreateAdvanced = ref.watch(canCreateAdvancedPostProvider);

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
            _buildHeader(canCreateAdvanced),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text input
                    _buildTextInput(),
                    AppSpacing.verticalGapMd,

                    // Resident picker + Tag picker (ใช้ reusable widget)
                    ResidentTagPickerRow(
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
                      disabled: widget.isFromTask, // ล็อกเมื่อมาจาก task
                      isTagRequired: true, // บังคับเลือก tag
                    ),

                    // Handover toggle (แสดงเมื่อเลือก tag แล้ว)
                    if (state.selectedTag != null) ...[
                      AppSpacing.verticalGapSm,
                      HandoverToggleWidget(
                        selectedTag: state.selectedTag,
                        isHandover: state.isHandover,
                        selectedResidentId: state.selectedResidentId,
                        onHandoverChanged: (value) {
                          ref.read(createPostProvider.notifier).setHandover(value);
                        },
                        descriptionFocusNode: _focusNode,
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
                    AppSpacing.verticalGapMd,

                    // Image preview
                    if (state.hasImages)
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

                    // Video preview
                    if (state.hasVideo)
                      _buildVideoPreview(state),

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

  Widget _buildHeader(bool canCreateAdvanced) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          Text(
            'แจ้งข่าว',
            style: AppTypography.title,
          ),
          const Spacer(),

          // Advanced button (หัวหน้าเวร+)
          if (canCreateAdvanced && widget.onAdvancedTap != null)
            TextButton.icon(
              onPressed: () {
                // Sync text ไปที่ provider ก่อน navigate
                ref.read(createPostProvider.notifier).setText(_textController.text);
                widget.onAdvancedTap?.call();
              },
              icon: HugeIcon(icon: HugeIcons.strokeRoundedEdit02, size: AppIconSize.sm),
              label: Text('แบบละเอียด'),
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

  Widget _buildTextInput() {
    final isFromTask = widget.isFromTask;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        maxLines: null,
        minLines: 3,
        readOnly: isFromTask, // ถ้ามาจาก task ให้แก้ไขไม่ได้
        enabled: !isFromTask,
        decoration: InputDecoration(
          // ถ้ามาจาก task ให้ใช้ hint text พิเศษเพื่อแนะนำ user
          hintText: isFromTask
              ? 'หากมีอาการผิดปกติ ผิดแปลกไปจากเดิม ให้บรรยายไว้ที่นี่'
              : 'เขียนข้อความที่นี่...',
          hintStyle: AppTypography.body.copyWith(
            color: AppColors.secondaryText,
          ),
          filled: true,
          fillColor: isFromTask
              ? AppColors.alternate.withValues(alpha: 0.5)
              : AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
        style: AppTypography.body.copyWith(
          color: isFromTask ? AppColors.primaryText : null,
        ),
        // ไม่ต้อง sync text ทุก keystroke เพราะทำให้ rebuild บ่อย
        // จะ sync ตอน submit หรือ navigate to advanced แทน
      ),
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

  Widget _buildBottomBar(CreatePostState state) {
    // รับค่า keyboard padding
    // ใช้ viewInsetsOf แทน .of().viewInsets เพื่อ subscribe เฉพาะ viewInsets
    // ไม่ rebuild เมื่อ MediaQuery อื่นเปลี่ยน (เช่น orientation, textScaleFactor)
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.alternate),
        ),
      ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Image picker buttons (Wrap เพื่อรองรับหลายปุ่ม)
              Wrap(
                spacing: 8,
                children: [
                  _buildIconButton(
                    icon: HugeIcons.strokeRoundedCamera01,
                    onTap: _isUploading || state.isSubmitting || state.hasVideo
                        ? null
                        : _pickFromCamera,
                    tooltip: 'ถ่ายรูป',
                  ),
                  _buildIconButton(
                    icon: HugeIcons.strokeRoundedImageComposition,
                    onTap: _isUploading || state.isSubmitting || state.hasVideo
                        ? null
                        : _pickFromGallery,
                    tooltip: 'เลือกจากแกลเลอรี่',
                  ),
                  _buildIconButton(
                    icon: HugeIcons.strokeRoundedVideo01,
                    onTap: _isUploading || state.isSubmitting || state.hasImages
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
        ),  // Row
        ],
      ),  // Column
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

  bool _canSubmit(CreatePostState state) {
    // ต้องมีข้อความ + ต้องเลือก tag + ไม่กำลัง submit อยู่
    return _textController.text.trim().isNotEmpty &&
        state.selectedTag != null &&
        !state.isSubmitting;
  }

  Future<void> _pickFromCamera() async {
    final file = await ImagePickerHelper.pickFromCamera();
    if (file != null) {
      ref.read(createPostProvider.notifier).addImages([file]);
    }
  }

  Future<void> _pickFromGallery() async {
    final state = ref.read(createPostProvider);
    final remaining = 5 - state.selectedImages.length - state.uploadedImageUrls.length;

    if (remaining <= 0) {
      // แจ้งเตือนเลือกรูปเกินจำนวนที่กำหนด
      AppSnackbar.warning(context, 'เลือกรูปได้สูงสุด 5 รูป');
      return;
    }

    final files = await ImagePickerHelper.pickFromGallery(maxImages: remaining);
    if (files.isNotEmpty) {
      ref.read(createPostProvider.notifier).addImages(files);
    }
  }

  Future<void> _pickVideo() async {
    // Simple mode ยังคงเลือกได้ 1 video (ล้างของเดิมก่อนเพิ่มใหม่)
    final file = await ImagePickerHelper.pickVideoFromGallery();
    if (file != null) {
      // เริ่ม optimistic background upload ทันที
      // แสดง progress UI ก่อน แล้วค่อยแสดง preview เมื่อ upload สำเร็จ
      _startBackgroundVideoUpload(file);
    }
  }

  /// เริ่ม background upload video พร้อม progress tracking
  Future<void> _startBackgroundVideoUpload(File videoFile) async {
    final notifier = ref.read(createPostProvider.notifier);
    final userId = ref.read(postCurrentUserIdProvider);

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

  Widget _buildVideoPreview(CreatePostState state) {
    // ตรวจสอบ state ของ video upload
    final isUploading = state.isUploadingVideo;
    final hasError = state.videoUploadError != null;
    final hasUploadedVideo = state.uploadedVideoUrls.isNotEmpty;
    final videoFile = state.selectedVideos.isNotEmpty ? state.selectedVideos.first : null;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          height: 180,
          child: Stack(
            children: [
              // Background - แสดงตาม state
              if (isUploading)
                // State 1: กำลังอัพโหลด - แสดง progress
                _buildUploadingState(state)
              else if (hasError)
                // State 2: เกิด error - แสดง error + retry
                _buildErrorState(state)
              else if (hasUploadedVideo)
                // State 3: อัพโหลดสำเร็จ - แสดง preview จาก URL
                _buildSuccessState(state)
              else if (videoFile != null)
                // Fallback: แสดง local file (กรณียังไม่ได้เริ่ม upload)
                _VideoThumbnailWidget(videoPath: videoFile.path)
              else
                // Default: placeholder
                Container(
                  color: AppColors.background,
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedVideo01,
                      size: AppIconSize.xxxl,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),

              // Cancel/Remove button (แสดงทุก state ยกเว้นตอน uploading)
              if (!isUploading)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(createPostProvider.notifier).cancelVideoUpload();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: Colors.white,
                        size: AppIconSize.lg,
                      ),
                    ),
                  ),
                ),

              // Video label (แสดงเฉพาะเมื่อ upload สำเร็จ)
              if (hasUploadedVideo && !isUploading && !hasError)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedVideo01,
                          size: AppIconSize.sm,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'วีดีโอ',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Play icon overlay (แสดงเฉพาะเมื่อ upload สำเร็จ)
              if (hasUploadedVideo && !isUploading && !hasError)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedPlay,
                        color: Colors.white,
                        size: AppIconSize.xxl,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// State 1: กำลังอัพโหลดวีดีโอ - แสดง progress bar และ percentage
  Widget _buildUploadingState(CreatePostState state) {
    final progress = state.videoUploadProgress;
    final percentage = (progress * 100).toInt();

    return Container(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Upload icon with animation
              HugeIcon(
                icon: HugeIcons.strokeRoundedCloudUpload,
                size: AppIconSize.xxl,
                color: AppColors.primary,
              ),
              SizedBox(height: AppSpacing.md),
              // Progress bar
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.inputBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              // Percentage text
              Text(
                'กำลังอัพโหลดวีดีโอ... $percentage%',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// State 2: เกิด error - แสดงข้อความ error และปุ่ม retry
  Widget _buildErrorState(CreatePostState state) {
    return Container(
      color: AppColors.error.withValues(alpha: 0.1),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: AppIconSize.xxl,
                color: AppColors.error,
              ),
              SizedBox(height: AppSpacing.md),
              // Error message
              Text(
                state.videoUploadError ?? 'เกิดข้อผิดพลาด',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.md),
              // Retry button
              ElevatedButton.icon(
                onPressed: _retryVideoUpload,
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  size: AppIconSize.md,
                  color: Colors.white,
                ),
                label: Text('ลองใหม่'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// State 3: อัพโหลดสำเร็จ - แสดง thumbnail จาก URL หรือ video URL
  Widget _buildSuccessState(CreatePostState state) {
    // ใช้ thumbnail URL ถ้ามี
    final thumbnailUrl = state.videoThumbnailUrl;

    if (thumbnailUrl != null) {
      // แสดง thumbnail image
      return CachedNetworkImage(
        imageUrl: thumbnailUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: AppColors.background,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildVideoPlaceholder(),
      );
    } else {
      // ไม่มี thumbnail - แสดง placeholder พร้อมบอกว่า video พร้อมแล้ว
      return _buildVideoPlaceholder(showReady: true);
    }
  }

  /// Placeholder สำหรับ video (ใช้เมื่อไม่มี thumbnail)
  Widget _buildVideoPlaceholder({bool showReady = false}) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedVideo01,
              size: AppIconSize.xxxl,
              color: showReady ? AppColors.primary : AppColors.secondaryText,
            ),
            if (showReady) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                'วีดีโอพร้อมแล้ว',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit(CreatePostState state) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // ถ้าติ๊ก "ส่งเวร" บังคับต้องกรอกรายละเอียด
    // เพื่อให้พี่เลี้ยงเขียนข้อมูลสำคัญที่ต้องส่งต่อให้เวรถัดไป
    if (state.isHandover && text.isEmpty) {
      // แจ้งเตือน validation: ต้องกรอกรายละเอียดเมื่อติ๊กส่งเวร
      AppSnackbar.warning(context, 'กรุณากรอกรายละเอียดเมื่อติ๊กส่งเวร');
      return;
    }

    // ป้องกัน submit ขณะ video กำลัง upload
    if (state.isUploadingVideo) {
      // แจ้งเตือนให้รอ video upload เสร็จก่อน
      AppSnackbar.info(context, 'กรุณารอให้วีดีโออัพโหลดเสร็จก่อน');
      return;
    }

    // ป้องกัน submit ถ้า video upload error (ต้อง retry หรือลบก่อน)
    if (state.videoUploadError != null) {
      // แจ้งเตือนให้แก้ไข video upload error ก่อน submit
      AppSnackbar.warning(context, 'กรุณาลองอัพโหลดวีดีโอใหม่ หรือลบวีดีโอออก');
      return;
    }

    ref.read(createPostProvider.notifier).setSubmitting(true);

    try {
      final actionService = ref.read(postActionServiceProvider);
      final userId = ref.read(postCurrentUserIdProvider);
      final nursinghomeId = await ref.read(postNursinghomeIdProvider.future);

      if (userId == null || nursinghomeId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      // รวม media URLs: images + videos ที่ upload ไว้แล้ว
      List<String> mediaUrls = [...state.uploadedImageUrls];
      String? videoThumbnailUrl = state.videoThumbnailUrl; // จาก background upload

      // เพิ่ม video URLs ที่ upload ไว้แล้ว (จาก background upload)
      mediaUrls.addAll(state.uploadedVideoUrls);

      // Upload images ที่ยังไม่ได้ upload (เฉพาะ local files)
      if (state.selectedImages.isNotEmpty) {
        setState(() {
          _isUploading = true;
          _uploadStatusMessage = 'กำลังอัพโหลดรูปภาพ...';
        });

        final imageUrls = await PostMediaService.instance.uploadImages(
          state.selectedImages,
          userId: userId,
        );
        mediaUrls.addAll(imageUrls);

        setState(() {
          _isUploading = false;
          _uploadStatusMessage = null;
        });
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

      // Create post
      final postId = await actionService.createPost(
        userId: userId,
        nursinghomeId: nursinghomeId,
        text: text,
        tagId: state.selectedTag?.id,
        tagTopics: tagTopics,
        isHandover: state.isHandover,
        residentId: state.selectedResidentId,
        imageUrls: mediaUrls.isNotEmpty ? mediaUrls : null,
        imgUrl: videoThumbnailUrl, // เก็บ video thumbnail ใน imgUrl
      );

      if (postId != null) {
        // ถ้ามี taskLogId ให้ complete task ด้วย
        // ไม่ส่ง imageUrl เพราะรูปอยู่ใน Post แล้ว (ผ่าน post_id)
        // ป้องกันการบันทึกซ้ำซ้อนและเข้าคิวส่งซ้ำ
        if (widget.taskLogId != null) {
          await TaskService.instance.markTaskComplete(
            widget.taskLogId!,
            userId,
            // imageUrl: widget.taskConfirmImageUrl, // ไม่บันทึก confirmImage เพราะดึงจาก post_id แทน
            postId: postId,
          );
          // Refresh tasks
          refreshTasks(ref);
        }

        // Refresh posts
        refreshPosts(ref);

        // Clear draft หลังจาก submit สำเร็จ
        await _clearDraftAfterSubmit();

        // Reset form
        ref.read(createPostProvider.notifier).reset();
        _textController.clear();

        // Close sheet และแสดง success popup
        if (mounted) {
          Navigator.pop(context);

          // แสดง success popup พร้อม animated checkmark
          await SuccessPopup.show(
            context,
            emoji: '📝',
            message: widget.taskLogId != null ? 'โพสและบันทึกงานสำเร็จ' : 'โพสสำเร็จ',
            autoCloseDuration: const Duration(milliseconds: 1000),
          );

          widget.onPostCreated?.call();
        }
      } else {
        throw Exception('ไม่สามารถสร้างโพสได้');
      }
    } catch (e) {
      ref.read(createPostProvider.notifier).setError(e.toString());
      if (mounted) {
        // แจ้ง error เมื่อสร้างโพสไม่สำเร็จ
        AppSnackbar.error(context, 'เกิดข้อผิดพลาด: $e');
      }
    } finally {
      ref.read(createPostProvider.notifier).setSubmitting(false);
      // Clear upload status เสมอ ไม่ว่าจะสำเร็จหรือ error
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusMessage = null;
        });
      }
    }
  }
}

/// Helper function to show the bottom sheet
/// ใช้ _CreatePostBottomSheetWrapper เพื่อจัดการ back gesture และ draft
void showCreatePostBottomSheet(
  BuildContext context, {
  VoidCallback? onPostCreated,
  VoidCallback? onAdvancedTap,
  String? initialText,
  int? initialResidentId,
  String? initialResidentName,
  String? initialTagName,
  int? taskLogId,
  String? taskConfirmImageUrl,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // ปิด drag - ใช้ปุ่มกากบาทแทน
    enableDrag: false,
    // isDismissible: false เพื่อป้องกัน tap outside ปิด modal
    isDismissible: false,
    builder: (context) => _CreatePostBottomSheetWrapper(
      onPostCreated: onPostCreated,
      onAdvancedTap: onAdvancedTap,
      initialText: initialText,
      initialResidentId: initialResidentId,
      initialResidentName: initialResidentName,
      initialTagName: initialTagName,
      taskLogId: taskLogId,
      taskConfirmImageUrl: taskConfirmImageUrl,
    ),
  );
}

/// Wrapper widget ที่จัดการ PopScope สำหรับ back gesture
class _CreatePostBottomSheetWrapper extends ConsumerStatefulWidget {
  final VoidCallback? onPostCreated;
  final VoidCallback? onAdvancedTap;
  final String? initialText;
  final int? initialResidentId;
  final String? initialResidentName;
  final String? initialTagName;
  final int? taskLogId;
  final String? taskConfirmImageUrl;

  const _CreatePostBottomSheetWrapper({
    this.onPostCreated,
    this.onAdvancedTap,
    this.initialText,
    this.initialResidentId,
    this.initialResidentName,
    this.initialTagName,
    this.taskLogId,
    this.taskConfirmImageUrl,
  });

  @override
  ConsumerState<_CreatePostBottomSheetWrapper> createState() =>
      _CreatePostBottomSheetWrapperState();
}

class _CreatePostBottomSheetWrapperState
    extends ConsumerState<_CreatePostBottomSheetWrapper> {
  final GlobalKey<_CreatePostBottomSheetState> _sheetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // คำนวณความสูงของ modal (85% ของหน้าจอ)
    // ใช้ sizeOf แทน .of().size เพื่อ subscribe เฉพาะ size change
    // ไม่ rebuild ทุกเฟรมตอน keyboard animation (viewInsets เปลี่ยน)
    final screenHeight = MediaQuery.sizeOf(context).height;
    final modalHeight = screenHeight * 0.85;

    return PopScope(
      // ไม่ให้ pop อัตโนมัติ - เราจะจัดการเอง
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // เรียก _handleCloseAttempt จาก CreatePostBottomSheet
        final sheetState = _sheetKey.currentState;
        if (sheetState != null) {
          final shouldClose = await sheetState._handleCloseAttempt();
          if (shouldClose && context.mounted) {
            Navigator.of(context).pop();
          }
        } else {
          // ถ้าไม่มี state ให้ปิดเลย
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: SizedBox(
        height: modalHeight,
        child: CreatePostBottomSheet(
          key: _sheetKey,
          onPostCreated: widget.onPostCreated,
          onAdvancedTap: widget.onAdvancedTap,
          initialText: widget.initialText,
          initialResidentId: widget.initialResidentId,
          initialResidentName: widget.initialResidentName,
          initialTagName: widget.initialTagName,
          taskLogId: widget.taskLogId,
          taskConfirmImageUrl: widget.taskConfirmImageUrl,
        ),
      ),
    );
  }
}

/// Helper function สำหรับ navigate ไป advanced screen
/// ใช้ pushReplacement เพื่อให้ page ใหม่ขึ้นมาแทนที่ modal โดยตรง
/// - Modal หายไป (ไม่มี animation ลง)
/// - Page ใหม่ขึ้นมาจากล่าง (slide up)
void navigateToAdvancedPostScreen(
  BuildContext context, {
  required Widget advancedScreen,
}) {
  // ใช้ pushReplacement - ปิด bottom sheet และเปิด page ใหม่พร้อมกัน
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => advancedScreen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        // Slide จากล่างขึ้นบน - เหมือน modal ขยายตัวเป็น full page
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(curvedAnimation);

        // Fade in เร็ว
        final fadeAnimation = Tween<double>(
          begin: 0.8,
          end: 1.0,
        ).animate(curvedAnimation);

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    ),
  );
}

/// Popup แสดง tag suggestions เมื่อพิมพ์ #
/// รองรับ keyboard navigation (arrow up/down, enter, escape)
class _TagSuggestionsPopup extends StatefulWidget {
  final String searchQuery;
  final List<NewTag> filteredTags;
  final int selectedIndex;
  final ScrollController scrollController;
  final void Function(NewTag) onTagSelected;
  final VoidCallback onDismiss;

  const _TagSuggestionsPopup({
    required this.searchQuery,
    required this.filteredTags,
    required this.selectedIndex,
    required this.scrollController,
    required this.onTagSelected,
    required this.onDismiss,
  });

  @override
  State<_TagSuggestionsPopup> createState() => _TagSuggestionsPopupState();
}

class _TagSuggestionsPopupState extends State<_TagSuggestionsPopup> {
  static const _itemHeight = 40.0;

  @override
  void initState() {
    super.initState();
    _scrollToSelected();
  }

  @override
  void didUpdateWidget(covariant _TagSuggestionsPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    if (widget.filteredTags.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;

      final targetOffset = widget.selectedIndex * _itemHeight;
      final maxScroll = widget.scrollController.position.maxScrollExtent;
      final viewportHeight = widget.scrollController.position.viewportDimension;

      // คำนวณว่าต้อง scroll ไปที่ไหน - ให้ item อยู่ตรงกลาง
      double scrollTo = targetOffset - (viewportHeight / 2) + (_itemHeight / 2);
      scrollTo = scrollTo.clamp(0.0, maxScroll);

      widget.scrollController.animateTo(
        scrollTo,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alternate),
      ),
      child: widget.filteredTags.isEmpty
          ? Center(
              child: widget.searchQuery.isNotEmpty
                  ? Text(
                      'ไม่พบหัวข้อ "${widget.searchQuery}"',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    )
                  : const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            )
          : ListView.builder(
              controller: widget.scrollController,
              itemExtent: _itemHeight,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: widget.filteredTags.length,
              itemBuilder: (context, index) {
                final tag = widget.filteredTags[index];
                final isHighlighted = index == widget.selectedIndex;

                return InkWell(
                  onTap: () => widget.onTagSelected(tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    color: isHighlighted
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : null,
                    child: Row(
                      children: [
                        if (tag.emoji != null) ...[
                          Text(tag.emoji!,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            tag.name,
                            style: AppTypography.body.copyWith(
                              color: isHighlighted
                                  ? AppColors.primary
                                  : AppColors.primaryText,
                              fontWeight: isHighlighted
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(
                          '#',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Popup แสดง resident suggestions เมื่อพิมพ์ @
class _ResidentSuggestionsPopup extends StatefulWidget {
  final String searchQuery;
  final List<ResidentOption> filteredResidents;
  final int selectedIndex;
  final ScrollController scrollController;
  final void Function(ResidentOption) onResidentSelected;
  final VoidCallback onDismiss;

  const _ResidentSuggestionsPopup({
    required this.searchQuery,
    required this.filteredResidents,
    required this.selectedIndex,
    required this.scrollController,
    required this.onResidentSelected,
    required this.onDismiss,
  });

  @override
  State<_ResidentSuggestionsPopup> createState() =>
      _ResidentSuggestionsPopupState();
}

class _ResidentSuggestionsPopupState extends State<_ResidentSuggestionsPopup> {
  static const _itemHeight = 56.0; // สูงกว่า tag เพราะมีรูป

  @override
  void initState() {
    super.initState();
    _scrollToSelected();
  }

  @override
  void didUpdateWidget(covariant _ResidentSuggestionsPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    if (widget.filteredResidents.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;

      final targetOffset = widget.selectedIndex * _itemHeight;
      final maxScroll = widget.scrollController.position.maxScrollExtent;
      final viewportHeight = widget.scrollController.position.viewportDimension;

      double scrollTo = targetOffset - (viewportHeight / 2) + (_itemHeight / 2);
      scrollTo = scrollTo.clamp(0.0, maxScroll);

      widget.scrollController.animateTo(
        scrollTo,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alternate),
      ),
      child: widget.filteredResidents.isEmpty
          ? Center(
              child: widget.searchQuery.isNotEmpty
                  ? Text(
                      'ไม่พบผู้พักอาศัย "${widget.searchQuery}"',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    )
                  : const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            )
          : ListView.builder(
              controller: widget.scrollController,
              itemExtent: _itemHeight,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: widget.filteredResidents.length,
              itemBuilder: (context, index) {
                final resident = widget.filteredResidents[index];
                final isHighlighted = index == widget.selectedIndex;

                return InkWell(
                  onTap: () => widget.onResidentSelected(resident),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: isHighlighted
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : null,
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.alternate,
                          backgroundImage: resident.pictureUrl != null
                              ? CachedNetworkImageProvider(resident.pictureUrl!)
                              : null,
                          child: resident.pictureUrl == null
                              ? HugeIcon(
                                  icon: HugeIcons.strokeRoundedUser,
                                  size: AppIconSize.md,
                                  color: AppColors.secondaryText,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        // Name & zone
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'คุณ${resident.name}',
                                style: AppTypography.body.copyWith(
                                  color: isHighlighted
                                      ? AppColors.primary
                                      : AppColors.primaryText,
                                  fontWeight: isHighlighted
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (resident.zone != null)
                                Text(
                                  resident.zone!,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // @ indicator
                        Text(
                          '@',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Widget สำหรับแสดง thumbnail ของวีดีโอ
class _VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;

  const _VideoThumbnailWidget({required this.videoPath});

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget> {
  Uint8List? _thumbnailData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  @override
  void didUpdateWidget(covariant _VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final data = await VideoThumbnail.thumbnailData(
        video: widget.videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 75,
      );

      if (mounted) {
        setState(() {
          _thumbnailData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_hasError || _thumbnailData == null) {
      // Fallback to placeholder
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedVideo01,
                size: AppIconSize.xxxl,
                color: AppColors.secondaryText,
              ),
              SizedBox(height: 8),
              Text(
                'วิดีโอ',
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Image.memory(
      _thumbnailData!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
