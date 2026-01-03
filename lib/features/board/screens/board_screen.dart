import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/input_fields.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/post.dart';
import '../models/post_tab.dart';
import '../providers/post_provider.dart';
import '../providers/post_filter_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/post_tab_bar.dart';
import '../widgets/post_search_bar.dart';
import '../widgets/pinned_post_card.dart';
import '../widgets/post_filter_drawer.dart';
import '../widgets/create_post_bottom_sheet.dart';

/// หน้ากระดานข่าว - Posts
/// แสดงข่าว ประกาศ และปฏิทิน
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  List<ResidentOption> _residents = [];

  @override
  void initState() {
    super.initState();
    _loadResidents();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadResidents() async {
    final service = ref.read(postServiceProvider);
    final nursinghomeId = await ref.read(nursinghomeIdProvider.future);
    if (nursinghomeId != null) {
      final residents = await service.getResidents(nursinghomeId);
      if (mounted) {
        setState(() {
          _residents = residents
              .map((r) => ResidentOption(
                    id: r['id'] as int,
                    name: r['Name'] as String? ?? 'Unknown',
                    zone: r['zone_name'] as String?,
                    pictureUrl: r['i_Picture_url'] as String?,
                  ))
              .toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainTab = ref.watch(postMainTabProvider);
    final filterType = ref.watch(postFilterTypeProvider);
    final selectedResidentId = ref.watch(selectedResidentIdProvider);
    final selectedResidentName = ref.watch(selectedResidentNameProvider);
    final searchQuery = ref.watch(postSearchQueryProvider);
    final activeFilterCount = ref.watch(activeFilterCountProvider);
    final unreadCountsAsync = ref.watch(unreadCountsProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: PostFilterDrawer(
        selectedResidentId: selectedResidentId,
        selectedResidentName: selectedResidentName,
        residents: _residents,
        isSearchEnabled: _isSearching,
        filterType: filterType,
        onResidentChanged: (residentId, residentName) {
          ref.read(selectedResidentIdProvider.notifier).state = residentId;
          ref.read(selectedResidentNameProvider.notifier).state = residentName;
        },
        onSearchToggle: (enabled) {
          setState(() => _isSearching = enabled);
          if (!enabled) {
            ref.read(postSearchQueryProvider.notifier).state = '';
          }
          Navigator.pop(context);
          if (enabled) {
            // Request focus after drawer closes and widget rebuilds
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _searchFocusNode.requestFocus();
            });
          }
        },
        onFilterTypeChanged: (type) {
          PostFilterNotifier(ref).setFilterType(type);
        },
        onClearFilters: () {
          PostFilterNotifier(ref).resetSecondaryFilters();
          Navigator.pop(context);
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshPosts(ref);
        },
        child: CustomScrollView(
          slivers: [
            // App Bar
            IreneAppBar(
              title: 'กระดานข่าว',
              showFilterButton: true,
              isFilterActive: filterType != PostFilterType.all,
              filterCount: activeFilterCount,
              onFilterTap: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              onProfileTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              trailing: _buildViewModeToggle(filterType),
            ),

            // Search bar (collapsible) - full width
            SliverToBoxAdapter(
              child: _isSearching
                  ? PostSearchBar(
                      initialQuery: searchQuery,
                      focusNode: _searchFocusNode,
                      onSearch: (query) {
                        ref.read(postSearchQueryProvider.notifier).state =
                            query;
                      },
                      onClear: () {
                        ref.read(postSearchQueryProvider.notifier).state = '';
                        setState(() => _isSearching = false);
                      },
                    )
                  : SizedBox.shrink(),
            ),

            // Main tab bar - full width
            SliverToBoxAdapter(
              child: PostTabBar(
                selectedTab: mainTab,
                unreadCounts: unreadCountsAsync.valueOrNull ?? {},
                onTabChanged: (tab) {
                  PostFilterNotifier(ref).setMainTab(tab);
                },
              ),
            ),

            // Resident filter chip (if selected)
            if (selectedResidentName != null)
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surface,
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      _buildResidentChip(selectedResidentName),
                    ],
                  ),
                ),
              ),

            // Pinned Critical post
            if (mainTab == PostMainTab.announcement) _buildPinnedPost(),

            // Search results or posts list
            if (searchQuery.isNotEmpty)
              _buildSearchResults()
            else
              _buildPostsList(),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildResidentChip(String name) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.user, size: 14, color: AppColors.primary),
          SizedBox(width: 4),
          Text(
            name,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              PostFilterNotifier(ref).clearSelectedResident();
            },
            child: Icon(Iconsax.close_circle, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  /// Toggle button สำหรับเปลี่ยนมุมมอง (View Mode) ที่มุมขวาของ AppBar
  /// กดแล้ววนไปมุมมองถัดไป: all -> unacknowledged -> myPosts -> all ...
  Widget _buildViewModeToggle(PostFilterType currentMode) {
    return Material(
      color: AppColors.accent1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          // วนไปมุมมองถัดไป
          final modes = PostFilterType.values;
          final currentIndex = modes.indexOf(currentMode);
          final nextIndex = (currentIndex + 1) % modes.length;
          ref.read(postFilterTypeProvider.notifier).state = modes[nextIndex];
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            _getViewModeIcon(currentMode),
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ),
    );
  }

  IconData _getViewModeIcon(PostFilterType mode) {
    switch (mode) {
      case PostFilterType.all:
        return Iconsax.document_text;
      case PostFilterType.unacknowledged:
        return Iconsax.notification_bing;
      case PostFilterType.myPosts:
        return Iconsax.user_edit;
    }
  }

  Widget _buildPinnedPost() {
    final pinnedPostAsync = ref.watch(pinnedPostProvider);

    return pinnedPostAsync.when(
      data: (post) {
        if (post == null) return SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: PinnedPostCard(
              post: post,
              onTap: () => _navigateToDetail(post),
              onLikeTap: () => _handleLike(post.id),
            ),
          ),
        );
      },
      loading: () => SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (e, s) => SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildSearchResults() {
    final searchResultsAsync = ref.watch(postSearchResultsProvider);

    return searchResultsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return SliverFillRemaining(
            child: _buildEmptyState('ไม่พบผลลัพธ์'),
          );
        }
        return _buildPostsListView(posts);
      },
      loading: () => SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SliverFillRemaining(
        child: _buildErrorState(e.toString()),
      ),
    );
  }

  Widget _buildPostsList() {
    final postsAsync = ref.watch(postsProvider);

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return SliverFillRemaining(
            child: _buildEmptyState('ไม่มีโพส'),
          );
        }
        return _buildPostsListView(posts);
      },
      loading: () => SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SliverFillRemaining(
        child: _buildErrorState(e.toString()),
      ),
    );
  }

  Widget _buildPostsListView(List<Post> posts) {
    final currentUserId = ref.watch(currentUserIdProvider);
    // TODO: Get userRole from provider when available
    const userRole = 'user';

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = posts[index];
            final isLiked = post.hasUserLiked(currentUserId);

            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: PostCard(
                post: post,
                isLiked: isLiked,
                currentUserId: currentUserId,
                userRole: userRole,
                onTap: () => _navigateToDetail(post),
                onLikeTap: () => _handleLike(post.id),
                onCancelPrn: (queueId) => _handleCancelPrn(queueId),
                onCancelLogLine: (queueId) => _handleCancelLogLine(queueId),
              ),
            );
          },
          childCount: posts.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Iconsax.document,
            size: 64,
            color: AppColors.secondaryText.withValues(alpha: 0.5),
          ),
          AppSpacing.verticalGapMd,
          Text(
            message,
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Iconsax.warning_2,
            size: 64,
            color: AppColors.error.withValues(alpha: 0.5),
          ),
          AppSpacing.verticalGapMd,
          Text(
            'เกิดข้อผิดพลาด',
            style: AppTypography.body.copyWith(
              color: AppColors.error,
            ),
          ),
          AppSpacing.verticalGapSm,
          Text(
            message,
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalGapLg,
          ElevatedButton.icon(
            onPressed: () => refreshPosts(ref),
            icon: Icon(Iconsax.refresh),
            label: Text('ลองอีกครั้ง'),
          ),
        ],
      ),
    );
  }

  Widget? _buildFab() {
    // TODO: Check if user is admin
    return FloatingActionButton(
      onPressed: () {
        _showCreatePostScreen();
      },
      backgroundColor: AppColors.primary,
      child: Icon(Iconsax.add, color: Colors.white),
    );
  }

  void _showCreatePostScreen() {
    showCreatePostBottomSheet(
      context,
      onPostCreated: () {
        refreshPosts(ref);
      },
      onAdvancedTap: () {
        // ใช้ expand animation จาก bottom sheet ไป full page
        navigateToAdvancedPostScreen(
          context,
          advancedScreen: const _CreatePostScreen(),
        );
      },
    );
  }

  void _navigateToDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PostDetailScreen(postId: post.id),
      ),
    );
  }

  Future<void> _handleLike(int postId) async {
    try {
      final actionService = ref.read(postActionServiceProvider);
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      await actionService.toggleLike(postId, userId);
      refreshPosts(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  Future<void> _handleCancelPrn(int queueId) async {
    try {
      final actionService = ref.read(postActionServiceProvider);
      final success = await actionService.cancelPrnNotification(queueId);
      if (success) {
        refreshPosts(ref);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ยกเลิกการส่ง LINE สำเร็จ')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  Future<void> _handleCancelLogLine(int queueId) async {
    try {
      final actionService = ref.read(postActionServiceProvider);
      final success = await actionService.cancelLogLineNotification(queueId);
      if (success) {
        refreshPosts(ref);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ยกเลิกการส่ง LINE สำเร็จ')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }
}

/// หน้ารายละเอียดโพส
class _PostDetailScreen extends ConsumerStatefulWidget {
  final int postId;

  const _PostDetailScreen({required this.postId});

  @override
  ConsumerState<_PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<_PostDetailScreen> {
  String? _selectedChoice;

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondaryBackground,
        title: Text('รายละเอียดโพส', style: AppTypography.title),
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
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

          return SingleChildScrollView(
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

                // Resident info (if linked)
                if (post.residentId != null && post.residentId! > 0) ...[
                  _buildResidentCard(post),
                  AppSpacing.verticalGapLg,
                ],

                // Images
                if (post.hasImages) ...[
                  _buildImageGallery(post.allImageUrls),
                  AppSpacing.verticalGapLg,
                ],

                Divider(color: AppColors.alternate),
                AppSpacing.verticalGapMd,

                // Quiz section (if has quiz)
                if (hasQuiz) ...[
                  _buildQuizSection(post),
                  Divider(color: AppColors.alternate),
                  AppSpacing.verticalGapMd,
                ],

                // Like section
                _buildLikeSection(post, isLiked, hasQuiz, quizAnswered),
              ],
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('เกิดข้อผิดพลาด: $e', style: AppTypography.body),
        ),
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
    } else if (post.isCalendar) {
      tagColor = AppColors.secondary;
      tagBgColor = AppColors.accent2;
      tagText = 'ปฏิทิน';
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
                    style: AppTypography.caption
                        .copyWith(color: AppColors.primary),
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
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.primary,
            ),
          ),
          AppSpacing.verticalGapSm,
          Row(
            children: [
              // Avatar
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
    // กรอง URL ที่ valid เท่านั้น
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
            child: GestureDetector(
              onTap: () => _showFullScreenImage(context, validUrls, index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: validUrls[index],
                  height: 200,
                  fit: BoxFit.cover,
                  progressIndicatorBuilder: (context, url, progress) =>
                      Container(
                    height: 200,
                    width: 200,
                    color: AppColors.background,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress.progress,
                            color: AppColors.primary,
                            strokeWidth: 3,
                            backgroundColor: AppColors.alternate,
                          ),
                          if (progress.progress != null)
                            Text(
                              '${(progress.progress! * 100).toInt()}%',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    width: 200,
                    color: AppColors.background,
                    child: Icon(Iconsax.image, color: AppColors.secondaryText),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// แสดงรูปเต็มจอพร้อม zoom และ swipe ดูรูปอื่น
  void _showFullScreenImage(
      BuildContext context, List<String> urls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
          imageUrls: urls,
          initialIndex: initialIndex,
        ),
      ),
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
        // Choice A
        if (post.qaChoiceA != null)
          _buildChoiceItem('A', post.qaChoiceA!, post.qaAnswer),
        // Choice B
        if (post.qaChoiceB != null)
          _buildChoiceItem('B', post.qaChoiceB!, post.qaAnswer),
        // Choice C
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
      bgColor = Color(0xFFB5FFDA);
      borderColor = Color(0xFF005460);
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
        // Show feedback
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
              child: Text(
                '$choice : $text',
                style: AppTypography.body,
              ),
            ),
            if (isCorrect)
              Icon(Iconsax.verify, color: Color(0xFF005460), size: 24),
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
        Future.delayed(Duration(milliseconds: 2500), () {
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
            animate: true,
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
        Future.delayed(Duration(milliseconds: 3500), () {
          if (mounted && navigator.canPop()) {
            navigator.pop();
          }
        });
        return _WrongAnswerDialogContent();
      },
    );
  }

  Widget _buildLikeSection(
      Post post, bool isLiked, bool hasQuiz, bool quizAnswered) {
    // ถ้ามี quiz แต่ยังตอบไม่ถูก ให้ disable ปุ่มรับทราบ
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
                    final actionService = ref.read(postActionServiceProvider);
                    final userId = ref.read(currentUserIdProvider);
                    if (userId == null) return;

                    await actionService.toggleLike(widget.postId, userId);
                    refreshPosts(ref);
                    ref.invalidate(postDetailProvider(widget.postId));
                  }
                : null,
            icon: Icon(
              isLiked ? Iconsax.heart5 : Iconsax.heart,
              color: isLiked ? Colors.white : AppColors.primary,
            ),
            label: Text(
              isLiked ? '🤔 ยกเลิกการรับทราบ' : '🫡 รับทราบ',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: canAcknowledge
                    ? (isLiked ? Colors.white : AppColors.primary)
                    : AppColors.secondaryText,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLiked
                  ? (canAcknowledge ? AppColors.error : AppColors.alternate)
                  : (canAcknowledge ? AppColors.primary : AppColors.alternate),
              foregroundColor: isLiked ? Colors.white : AppColors.primary,
              disabledBackgroundColor: AppColors.alternate,
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
            style: AppTypography.caption.copyWith(
              color: AppColors.error,
            ),
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

/// Dialog สำหรับตอบผิด - มี animation เลื่อนขึ้นช้าๆ
class _WrongAnswerDialogContent extends StatefulWidget {
  const _WrongAnswerDialogContent();

  @override
  State<_WrongAnswerDialogContent> createState() =>
      _WrongAnswerDialogContentState();
}

class _WrongAnswerDialogContentState extends State<_WrongAnswerDialogContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 2500),
      vsync: this,
    );

    // เลื่อนขึ้นมาช้าๆ จากด้านล่าง
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // รูป shock
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
                  style: AppTypography.heading2.copyWith(
                    color: AppColors.error,
                  ),
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
        ),
      ),
    );
  }
}

/// หน้าสร้างโพส (Placeholder - จะแยกไฟล์ทีหลัง)
class _CreatePostScreen extends ConsumerStatefulWidget {
  const _CreatePostScreen();

  @override
  ConsumerState<_CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<_CreatePostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondaryBackground,
        title: Text('สร้างโพสใหม่', style: AppTypography.title),
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handlePost,
            child: Text(
              'โพส',
              style: AppTypography.body.copyWith(
                color: _isLoading ? AppColors.secondaryText : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title field
            AppTextField(
              label: 'หัวข้อ',
              controller: _titleController,
              hintText: 'ใส่หัวข้อ...',
            ),
            AppSpacing.verticalGapLg,

            // Content field
            AppTextField(
              label: 'เนื้อหา',
              controller: _contentController,
              hintText: 'เขียนเนื้อหา...',
              maxLines: 8,
            ),
            AppSpacing.verticalGapLg,

            // Note
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tagPendingBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.info_circle, color: AppColors.tagPendingText),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'โพสจะถูกตั้งเป็นโพสทั่วไป (FYI)\nหากต้องการสร้างประกาศ กรุณาติดต่อผู้ดูแลระบบ',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.tagPendingText),
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

  Future<void> _handlePost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณาใส่เนื้อหา')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final actionService = ref.read(postActionServiceProvider);
      final userId = ref.read(currentUserIdProvider);
      final nursinghomeId = await ref.read(nursinghomeIdProvider.future);

      if (userId == null || nursinghomeId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      final postId = await actionService.createPost(
        userId: userId,
        nursinghomeId: nursinghomeId,
        text: content,
        title: title.isEmpty ? null : title,
      );

      if (postId != null) {
        refreshPosts(ref);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('โพสสำเร็จ')),
          );
        }
      } else {
        throw Exception('ไม่สามารถสร้างโพสได้');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Full screen image viewer with zoom and swipe
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: widget.imageUrls.length > 1
            ? Text(
                '${_currentIndex + 1} / ${widget.imageUrls.length}',
                style: AppTypography.body.copyWith(color: Colors.white),
              )
            : null,
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.imageUrls[index],
                fit: BoxFit.contain,
                progressIndicatorBuilder: (context, url, progress) => Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress.progress,
                        color: AppColors.primary,
                        strokeWidth: 3,
                        backgroundColor: Colors.white24,
                      ),
                      if (progress.progress != null)
                        Text(
                          '${(progress.progress! * 100).toInt()}%',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                errorWidget: (context, url, error) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.image, size: 48, color: Colors.white54),
                    SizedBox(height: 8),
                    Text(
                      'ไม่สามารถโหลดรูปได้',
                      style: AppTypography.body.copyWith(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
