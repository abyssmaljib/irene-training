import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/new_tag.dart';
import '../providers/create_post_provider.dart';
import '../providers/post_provider.dart';
import '../providers/tag_provider.dart';
import '../../checklist/services/task_service.dart';
import '../../checklist/providers/task_provider.dart' show refreshTasks;
import 'tag_picker_widget.dart';
import 'resident_picker_widget.dart';
import 'image_picker_bar.dart';
import 'image_preview_grid.dart';
import '../services/post_media_service.dart';

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
        ref.read(createPostProvider.notifier).reset();
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

    // [FUTURE] Listen for # and @ shortcuts - disabled for now
    // เก็บไว้สำหรับฟีเจอร์การสั่งงานระหว่างทีมในอนาคต
    // _textController.addListener(_onTextChanged);

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
    // [FUTURE] _textController.removeListener(_onTextChanged);
    _removeTagOverlay();
    _removeResidentOverlay();
    _textController.dispose();
    _focusNode.dispose();
    _tagScrollController.dispose();
    _residentScrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // [FUTURE] # และ @ Shortcut Functions
  // เก็บไว้สำหรับฟีเจอร์การสั่งงานระหว่างทีมในอนาคต
  // เช่น พิมพ์ # เพื่อเลือก tag, พิมพ์ @ เพื่อ mention ผู้พัก
  // ============================================================

  // ignore: unused_element
  void _onTextChanged() {
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

                    // Resident picker + Tag picker (same row)
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
                          disabled: widget.isFromTask, // ล็อกเมื่อมาจาก task
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
                          disabled: widget.isFromTask, // ล็อกเมื่อมาจาก task
                        ),
                      ],
                    ),

                    // Handover toggle (แสดงเมื่อเลือก tag แล้ว)
                    if (state.selectedTag != null) ...[
                      AppSpacing.verticalGapSm,
                      _buildCompactHandoverToggle(state),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
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
              onPressed: widget.onAdvancedTap,
              icon: Icon(Iconsax.edit_2, size: 16),
              label: Text('แบบละเอียด'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: AppTypography.bodySmall,
              ),
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
        maxLines: 4,
        minLines: 2,
        readOnly: isFromTask, // ถ้ามาจาก task ให้แก้ไขไม่ได้
        enabled: !isFromTask,
        decoration: InputDecoration(
          hintText: isFromTask ? null : 'เขียนข้อความที่นี่...',
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
        onChanged: isFromTask
            ? null
            : (value) {
                ref.read(createPostProvider.notifier).setText(value);
              },
      ),
    );
  }

  Widget _buildCompactHandoverToggle(CreatePostState state) {
    final canToggle = state.selectedTag?.isOptionalHandover ?? false;
    final isForce = state.selectedTag?.isForceHandover ?? false;
    final isHandover = state.isHandover;

    return SwitchListTile(
      value: isHandover,
      onChanged: canToggle
          ? (value) => ref.read(createPostProvider.notifier).setHandover(value)
          : null,
      title: Row(
        children: [
          Icon(
            Icons.swap_horiz,
            size: 20,
            color: isHandover ? AppColors.success : AppColors.secondaryText,
          ),
          const SizedBox(width: 8),
          Text(
            'ส่งเวร',
            style: AppTypography.body.copyWith(
              color: isHandover ? AppColors.success : AppColors.primaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isForce) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.tagFailedBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'จำเป็น',
                style: AppTypography.caption.copyWith(
                  color: AppColors.error,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        isForce ? 'จำเป็นต้องส่งเวรสำหรับหัวข้อนี้' : 'เลือกส่งเวรถ้าเรื่องนี้สำคัญ',
        style: AppTypography.caption.copyWith(
          color: AppColors.secondaryText,
        ),
      ),
      activeTrackColor: AppColors.success.withValues(alpha: 0.5),
      activeThumbColor: AppColors.success,
      inactiveThumbColor: AppColors.secondaryText,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildBottomBar(CreatePostState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.alternate),
        ),
      ),
      child: Row(
        children: [
          // Image picker buttons
          ImagePickerBar(
            isLoading: _isUploading,
            disabled: state.isSubmitting || state.hasVideo,
            onCameraTap: _pickFromCamera,
            onGalleryTap: _pickFromGallery,
            onVideoTap: state.hasImages ? null : _pickVideo,
          ),

          const Spacer(),

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
                : Text(
                    'โพส',
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

  bool _canSubmit(CreatePostState state) {
    return _textController.text.trim().isNotEmpty && !state.isSubmitting;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เลือกรูปได้สูงสุด 5 รูป')),
      );
      return;
    }

    final files = await ImagePickerHelper.pickFromGallery(maxImages: remaining);
    if (files.isNotEmpty) {
      ref.read(createPostProvider.notifier).addImages(files);
    }
  }

  Future<void> _pickVideo() async {
    final file = await ImagePickerHelper.pickVideoFromGallery();
    if (file != null) {
      ref.read(createPostProvider.notifier).setVideo(file);
    }
  }

  Widget _buildVideoPreview(CreatePostState state) {
    final videoFile = state.selectedVideo;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Stack(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: 180,
              child: videoFile != null
                  ? _VideoThumbnailWidget(videoPath: videoFile.path)
                  : Container(
                      color: AppColors.background,
                      child: Center(
                        child: Icon(
                          Iconsax.video,
                          size: 48,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
            ),
          ),
          // Play icon overlay
          Positioned.fill(
            child: Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.video_play5,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          // Remove button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                ref.read(createPostProvider.notifier).clearVideo();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.close_circle5,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          // Video label
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
                  Icon(Iconsax.video, size: 14, color: Colors.white),
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
        ],
      ),
    );
  }

  Future<void> _handleSubmit(CreatePostState state) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    ref.read(createPostProvider.notifier).setSubmitting(true);

    try {
      final actionService = ref.read(postActionServiceProvider);
      final userId = ref.read(currentUserIdProvider);
      final nursinghomeId = await ref.read(nursinghomeIdProvider.future);

      if (userId == null || nursinghomeId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      // Upload images and video
      List<String> mediaUrls = [...state.uploadedImageUrls];
      String? thumbnailUrl; // สำหรับเก็บ video thumbnail

      if (state.selectedImages.isNotEmpty || state.selectedVideo != null) {
        setState(() => _isUploading = true);

        // Upload images
        if (state.selectedImages.isNotEmpty) {
          final imageUrls = await PostMediaService.instance.uploadImages(
            state.selectedImages,
            userId: userId,
          );
          mediaUrls.addAll(imageUrls);
        }

        // Upload video พร้อม thumbnail
        if (state.selectedVideo != null) {
          final result = await PostMediaService.instance.uploadVideoWithThumbnail(
            state.selectedVideo!,
            userId: userId,
          );
          if (result.videoUrl != null) {
            mediaUrls.add(result.videoUrl!);
            thumbnailUrl = result.thumbnailUrl;
          }
        }

        setState(() => _isUploading = false);
      }

      // Create post
      final postId = await actionService.createPost(
        userId: userId,
        nursinghomeId: nursinghomeId,
        text: text,
        tagId: state.selectedTag?.id,
        tagName: state.selectedTag?.name,
        isHandover: state.isHandover,
        residentId: state.selectedResidentId,
        imageUrls: mediaUrls.isNotEmpty ? mediaUrls : null,
        imgUrl: thumbnailUrl, // ส่ง thumbnail URL ไปเก็บที่ imgUrl
      );

      if (postId != null) {
        // ถ้ามี taskLogId ให้ complete task ด้วย
        if (widget.taskLogId != null) {
          await TaskService.instance.markTaskComplete(
            widget.taskLogId!,
            userId,
            imageUrl: widget.taskConfirmImageUrl,
            postId: postId,
          );
          // Refresh tasks
          refreshTasks(ref);
        }

        // Refresh posts
        refreshPosts(ref);

        // Reset form
        ref.read(createPostProvider.notifier).reset();
        _textController.clear();

        // Close sheet
        if (mounted) {
          Navigator.pop(context);
          widget.onPostCreated?.call();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.taskLogId != null ? 'โพสและบันทึกงานสำเร็จ' : 'โพสสำเร็จ')),
          );
        }
      } else {
        throw Exception('ไม่สามารถสร้างโพสได้');
      }
    } catch (e) {
      ref.read(createPostProvider.notifier).setError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      ref.read(createPostProvider.notifier).setSubmitting(false);
    }
  }
}

/// Helper function to show the bottom sheet
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
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => CreatePostBottomSheet(
        onPostCreated: onPostCreated,
        onAdvancedTap: onAdvancedTap,
        initialText: initialText,
        initialResidentId: initialResidentId,
        initialResidentName: initialResidentName,
        initialTagName: initialTagName,
        taskLogId: taskLogId,
        taskConfirmImageUrl: taskConfirmImageUrl,
      ),
    ),
  );
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
                              ? Icon(
                                  Iconsax.user,
                                  size: 18,
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
                                resident.name,
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
              Icon(
                Iconsax.video,
                size: 48,
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
