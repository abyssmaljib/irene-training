import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/create_post_provider.dart';
import '../providers/post_provider.dart';
import '../services/post_action_service.dart';
import '../services/post_media_service.dart';
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

  @override
  void initState() {
    super.initState();
    // Load existing text from provider (e.g., from simple modal)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(createPostProvider);
      // ถ้ามี text จาก simple modal ให้โหลดมาใส่ใน controller
      if (state.text.isNotEmpty) {
        _textController.text = state.text;
      }
      // ถ้ามี title ให้โหลดมาด้วย
      if (state.title != null && state.title!.isNotEmpty) {
        _titleController.text = state.title!;
      }
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
      // เพิ่ม "ส่งให้ญาติ" ถ้าเลือก
      if (state.sendToFamily) {
        tagTopics = [...?tagTopics, 'ส่งให้ญาติ'];
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'สร้างประกาศใหม่',
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
            'ส่งให้ญาติ',
            style: AppTypography.body.copyWith(
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
      subtitle: Text(
        sendToFamily
            ? 'จะแจ้งเตือนไปยังญาติของผู้พักอาศัย'
            : 'เลือกถ้าต้องการแจ้งญาติ',
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
