import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/post.dart';
import '../providers/post_provider.dart';
import '../widgets/video_player_widget.dart';

/// หน้าแสดง posts ที่ต้องอ่านก่อนลงเวร
/// แสดงทีละ post และเลื่อนไปต่อเมื่อกด "รับทราบ"
class RequiredPostsScreen extends ConsumerStatefulWidget {
  final List<int> postIds;
  final VoidCallback? onAllPostsRead;

  const RequiredPostsScreen({
    super.key,
    required this.postIds,
    this.onAllPostsRead,
  });

  @override
  ConsumerState<RequiredPostsScreen> createState() => _RequiredPostsScreenState();
}

class _RequiredPostsScreenState extends ConsumerState<RequiredPostsScreen> {
  int _currentIndex = 0;
  String? _selectedChoice;
  final _scrollController = ScrollController();

  int get _currentPostId => widget.postIds[_currentIndex];
  bool get _isLastPost => _currentIndex >= widget.postIds.length - 1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goToNextPost() {
    if (_isLastPost) {
      // อ่านครบแล้ว - กลับไปหน้าก่อน
      widget.onAllPostsRead?.call();
      Navigator.pop(context, true);
    } else {
      // ไป post ถัดไป
      setState(() {
        _currentIndex++;
        _selectedChoice = null;
      });
      // Scroll to top
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      // Invalidate provider to fetch new post
      ref.invalidate(postDetailProvider(_currentPostId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(_currentPostId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondaryBackground,
        title: Text(
          'โพสที่ต้องอ่าน',
          style: AppTypography.title,
        ),
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: postAsync.when(
        data: (post) {
          if (post == null) {
            return Center(
              child: Text('ไม่พบโพสนี้', style: AppTypography.body),
            );
          }

          final isLiked = post.hasUserLiked(currentUserId);
          final hasQuiz = post.hasQuiz && post.qaId != null && post.qaId! > 0;
          final quizAnswered = hasQuiz && _selectedChoice == post.qaAnswer;

          return Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type tag
                      _buildTypeTag(post),
                      AppSpacing.verticalGapMd,

                      // Title
                      if (post.title != null && post.title!.isNotEmpty)
                        Text(post.title!, style: AppTypography.heading2),
                      AppSpacing.verticalGapMd,

                      // Author info
                      _buildAuthorInfo(post),
                      AppSpacing.verticalGapLg,

                      // Content
                      Text(
                        'รายละเอียด',
                        style: AppTypography.title.copyWith(fontSize: 16),
                      ),
                      AppSpacing.verticalGapSm,
                      SelectableText(post.text ?? '', style: AppTypography.body),
                      AppSpacing.verticalGapLg,

                      // Tags
                      if (post.postTags.isNotEmpty) ...[
                        _buildTagsSection(post),
                        AppSpacing.verticalGapLg,
                      ],

                      // Resident info
                      if (post.residentId != null && post.residentId! > 0) ...[
                        _buildResidentCard(post),
                        AppSpacing.verticalGapLg,
                      ],

                      // Images
                      if (post.hasImages) ...[
                        _buildImageGallery(post.allImageUrls),
                        AppSpacing.verticalGapLg,
                      ],

                      // Video
                      if (post.hasUploadedVideo) ...[
                        _buildVideoSection(post),
                        AppSpacing.verticalGapLg,
                      ],

                      Divider(color: AppColors.alternate),
                      AppSpacing.verticalGapMd,

                      // Quiz section
                      if (hasQuiz) ...[
                        _buildQuizSection(post),
                        Divider(color: AppColors.alternate),
                        AppSpacing.verticalGapMd,
                      ],

                      // Like section
                      _buildLikeSection(post, isLiked, hasQuiz, quizAnswered),

                      AppSpacing.verticalGapXl,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('เกิดข้อผิดพลาด: $e', style: AppTypography.body),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / widget.postIds.length,
                backgroundColor: AppColors.alternate,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ),
          SizedBox(width: 12),
          Text(
            '${_currentIndex + 1}/${widget.postIds.length}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTag(Post post) {
    Color tagColor;
    Color tagBgColor;
    String tagText;

    if (post.isCritical) {
      tagColor = AppColors.error;
      tagBgColor = AppColors.tagFailedBg;
      tagText = 'สำคัญ';
    } else if (post.isPolicy) {
      tagColor = AppColors.tagPendingText;
      tagBgColor = AppColors.tagPendingBg;
      tagText = 'นโยบาย';
    } else if (post.isAnnouncement) {
      tagColor = AppColors.tagNeutralText;
      tagBgColor = AppColors.tagNeutralBg;
      tagText = 'ข้อมูล';
    } else {
      tagColor = AppColors.tagNeutralText;
      tagBgColor = AppColors.tagNeutralBg;
      tagText = 'ทั่วไป';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tagBgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tagText,
        style: AppTypography.bodySmall.copyWith(
          color: tagColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAuthorInfo(Post post) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.accent1,
          backgroundImage:
              post.photoUrl != null ? NetworkImage(post.photoUrl!) : null,
          child: post.photoUrl == null
              ? Icon(Iconsax.user, color: AppColors.primary, size: 20)
              : null,
        ),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.postUserNickname ?? 'ไม่ระบุ',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                if (post.userGroup != null) ...[
                  Text(
                    post.userGroup!,
                    style:
                        AppTypography.caption.copyWith(color: AppColors.primary),
                  ),
                  Text(
                    ' • ',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.secondaryText),
                  ),
                ],
                Text(
                  _formatDate(post.createdAt),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.secondaryText),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTagsSection(Post post) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: post.postTags.map((tag) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '#$tag',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResidentCard(Post post) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '👴 ผู้พักอาศัย',
            style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
          ),
          AppSpacing.verticalGapSm,
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.surface,
                backgroundImage: post.residentPictureUrl != null
                    ? NetworkImage(post.residentPictureUrl!)
                    : null,
                child: post.residentPictureUrl == null
                    ? Icon(Iconsax.user, color: AppColors.primary, size: 22)
                    : null,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'คุณ ${post.residentName ?? '-'}',
                      style: AppTypography.title.copyWith(fontSize: 18),
                    ),
                    if (post.residentZone != null)
                      Text(
                        post.residentZone!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
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

  Widget _buildImageGallery(List<String> urls) {
    final validUrls = urls
        .map((url) => url.trim())
        .where((url) =>
            url.isNotEmpty &&
            url.length > 10 &&
            (url.startsWith('http://') || url.startsWith('https://')))
        .toList();

    if (validUrls.isEmpty) return SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: validUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: validUrls[index],
                height: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  width: 200,
                  color: AppColors.background,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  width: 200,
                  color: AppColors.background,
                  child: Icon(Iconsax.image, color: AppColors.secondaryText),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoSection(Post post) {
    final videoUrls = post.videoUrls;
    if (videoUrls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'วิดีโอ',
          style: AppTypography.title.copyWith(fontSize: 16),
        ),
        AppSpacing.verticalGapSm,
        ...videoUrls.map((url) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: VideoThumbnailPlayer(videoUrl: url),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildQuizSection(Post post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ทดสอบความเข้าใจ',
          style: AppTypography.title.copyWith(fontSize: 16),
        ),
        AppSpacing.verticalGapSm,
        Text(
          post.qaQuestion ?? '',
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
        AppSpacing.verticalGapMd,
        if (post.qaChoiceA != null)
          _buildChoiceItem('A', post.qaChoiceA!, post.qaAnswer),
        if (post.qaChoiceB != null)
          _buildChoiceItem('B', post.qaChoiceB!, post.qaAnswer),
        if (post.qaChoiceC != null)
          _buildChoiceItem('C', post.qaChoiceC!, post.qaAnswer),
        AppSpacing.verticalGapMd,
      ],
    );
  }

  Widget _buildChoiceItem(String choice, String text, String? correctAnswer) {
    final isSelected = _selectedChoice == choice;
    final isCorrect = isSelected && correctAnswer == choice;
    final isWrong = isSelected && correctAnswer != choice;

    Color bgColor = AppColors.surface;
    Color borderColor = AppColors.alternate;

    if (isCorrect) {
      bgColor = const Color(0xFFB5FFDA);
      borderColor = const Color(0xFF005460);
    } else if (isWrong) {
      bgColor = AppColors.tagFailedBg;
      borderColor = AppColors.error;
    } else if (isSelected) {
      borderColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedChoice = choice;
        });
        if (correctAnswer == choice) {
          _showCorrectAnswerDialog();
        } else {
          _showWrongAnswerDialog();
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: isCorrect ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('$choice : $text', style: AppTypography.body),
            ),
            if (isCorrect)
              Icon(Iconsax.verify, color: const Color(0xFF005460), size: 24),
          ],
        ),
      ),
    );
  }

  void _showCorrectAnswerDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted && navigator.canPop()) {
            navigator.pop();
          }
        });
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Lottie.asset(
            'assets/animations/Trophy.json',
            width: 300,
            height: 300,
            fit: BoxFit.contain,
            repeat: false,
          ),
        );
      },
    );
  }

  void _showWrongAnswerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        Future.delayed(const Duration(milliseconds: 3500), () {
          if (mounted && navigator.canPop()) {
            navigator.pop();
          }
        });
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/shock.webp',
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                AppSpacing.verticalGapMd,
                Text(
                  'ตอบผิด..',
                  style: AppTypography.heading2.copyWith(color: AppColors.error),
                ),
                AppSpacing.verticalGapSm,
                Text(
                  'อ่านดีๆแล้วลองเลือกคำตอบใหม่อีกครั้งนะ',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLikeSection(
      Post post, bool isLiked, bool hasQuiz, bool quizAnswered) {
    final canAcknowledge = !hasQuiz || quizAnswered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รับทราบ ${post.likeCount} คน',
          style: AppTypography.title.copyWith(fontSize: 16),
        ),
        if (post.likeUserNicknames.isNotEmpty) ...[
          AppSpacing.verticalGapSm,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: post.likeUserNicknames.take(10).map((nickname) {
              return Text(
                nickname,
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                ),
              );
            }).toList(),
          ),
        ],
        AppSpacing.verticalGapLg,

        // Like button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: canAcknowledge
                ? () async {
                    // ถ้ายังไม่ได้ like ให้ like ก่อน
                    if (!isLiked) {
                      final actionService = ref.read(postActionServiceProvider);
                      final userId = ref.read(currentUserIdProvider);
                      if (userId == null) return;

                      await actionService.toggleLike(_currentPostId, userId);
                      refreshPosts(ref);
                    }

                    // ไป post ถัดไป หรือจบ
                    _goToNextPost();
                  }
                : null,
            icon: Icon(
              _isLastPost ? Iconsax.tick_circle : Iconsax.arrow_right,
              color: Colors.white,
            ),
            label: Text(
              _isLastPost ? 'รับทราบและเสร็จสิ้น' : 'รับทราบและไปต่อ',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.alternate,
              disabledForegroundColor: AppColors.secondaryText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        if (hasQuiz && !quizAnswered) ...[
          AppSpacing.verticalGapSm,
          Text(
            'กรุณาตอบคำถามให้ถูกต้องก่อนกดรับทราบ',
            style: AppTypography.caption.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';

    return '${date.day}/${date.month}/${date.year}';
  }
}