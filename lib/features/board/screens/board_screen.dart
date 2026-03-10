import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/network_image.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/post.dart';
import '../models/post_tab.dart';
import '../providers/post_provider.dart';
import '../providers/post_filter_provider.dart';
import '../services/post_service.dart';
import '../widgets/post_card.dart';
import '../widgets/post_tab_bar.dart';
import '../widgets/post_search_bar.dart';
import '../widgets/post_filter_drawer.dart';
import '../widgets/create_post_bottom_sheet.dart';
import '../widgets/edit_post_bottom_sheet.dart' show showEditPostBottomSheet, navigateToAdvancedEditPostScreen;
import '../widgets/create_ticket_bottom_sheet.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/ticket_detail_bottom_sheet.dart';
import '../widgets/video_player_widget.dart';
import '../services/ticket_service.dart';
import '../../checklist/providers/task_provider.dart' show currentUserSystemRoleProvider;
import 'advanced_create_post_screen.dart';
import 'required_posts_screen.dart';

/// Navigate to post detail screen
void navigateToPostDetail(BuildContext context, int postId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PostDetailScreen(postId: postId),
    ),
  );
}

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

  /// ScrollController สำหรับ infinite loading
  /// ตรวจจับเมื่อ scroll ใกล้ท้าย list แล้วโหลดเพิ่ม
  final ScrollController _scrollController = ScrollController();

  bool _isSearching = false;
  List<ResidentOption> _residents = [];

  @override
  void initState() {
    super.initState();
    _loadResidents();

    // เพิ่ม listener สำหรับ infinite loading
    // เมื่อ scroll ใกล้ท้าย list (200px) จะโหลดข้อมูลเพิ่ม
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// ตรวจจับ scroll position สำหรับ infinite loading
  void _onScroll() {
    // ถ้า scroll ใกล้ท้าย (200px จากท้าย) ให้โหลดเพิ่ม
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // เรียก loadMore ผ่าน notifier
      ref.read(postsNotifierProvider.notifier).loadMore();
    }
  }

  Future<void> _loadResidents() async {
    final service = ref.read(postServiceProvider);
    final nursinghomeId = await ref.read(postNursinghomeIdProvider.future);
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
          // ใช้ ScrollController สำหรับ infinite loading
          controller: _scrollController,
          // เพิ่ม AlwaysScrollableScrollPhysics เพื่อให้ pull to refresh ทำงานได้
          // แม้ content จะไม่เต็มหน้าจอ
          physics: const AlwaysScrollableScrollPhysics(),
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
              trailing: _buildTrailingButtons(filterType, unreadCountsAsync),
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
          HugeIcon(icon: HugeIcons.strokeRoundedUser, size: AppIconSize.sm, color: AppColors.primary),
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
            child: HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, size: AppIconSize.sm, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  /// ปุ่มด้านขวาของ AppBar: ปุ่มเคลียร์โพส + ปุ่มเปลี่ยนมุมมอง
  Widget _buildTrailingButtons(
    PostFilterType filterType,
    AsyncValue<Map<PostMainTab, int>> unreadCountsAsync,
  ) {
    // รวม unread count ทุก tab
    final totalUnread = unreadCountsAsync.whenOrNull(
      data: (counts) => counts.values.fold(0, (sum, count) => sum + count),
    ) ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ปุ่มเคลียร์โพสที่ยังไม่อ่าน (แสดงเฉพาะเมื่อมีโพสที่ยังไม่อ่าน)
        if (totalUnread > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildClearUnreadButton(totalUnread),
          ),
        // ปุ่มเปลี่ยนมุมมอง
        _buildViewModeToggle(filterType),
      ],
    );
  }

  /// ปุ่มเคลียร์โพสที่ยังไม่อ่าน พร้อม badge แสดงจำนวน
  Widget _buildClearUnreadButton(int unreadCount) {
    return Material(
      color: AppColors.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _navigateToRequiredPosts,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckList,
                color: AppColors.error,
                size: AppIconSize.md,
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigate ไปหน้าเคลียร์โพสที่ยังไม่อ่าน
  Future<void> _navigateToRequiredPosts() async {
    // Invalidate cache ก่อนดึงข้อมูลใหม่
    PostService.instance.invalidateCache();

    // ดึง nursinghome และ user ID
    final nursinghomeId = await ref.read(postNursinghomeIdProvider.future);
    final userId = ref.read(postCurrentUserIdProvider);

    if (nursinghomeId == null || userId == null) {
      if (mounted) {
        // แจ้ง error เมื่อดึงข้อมูล nursinghome/user ไม่ได้
        AppToast.error(context, 'ไม่สามารถดึงข้อมูลได้');
      }
      return;
    }

    // ดึงรายการโพสที่ยังไม่อ่าน (ใช้ PostService เดียวกับ badge)
    final postIds = await PostService.instance.getUnreadPostIds(nursinghomeId, userId);

    if (postIds.isEmpty) {
      // Refresh badge ด้วย
      refreshPosts(ref);
      if (mounted) {
        // แจ้งว่าอ่านโพสครบทุกโพสแล้ว
        AppToast.success(context, 'ไม่มีโพสที่ต้องอ่านแล้ว');
      }
      return;
    }

    if (mounted) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RequiredPostsScreen(
            postIds: postIds,
            onAllPostsRead: () {
              // Refresh posts หลังอ่านครบ
              refreshPosts(ref);
            },
          ),
        ),
      );

      // Refresh ทุกครั้งที่กลับมา (ไม่ว่าจะอ่านครบหรือไม่)
      refreshPosts(ref);
    }
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
          child: HugeIcon(
            icon: _getViewModeIcon(currentMode),
            color: AppColors.primary,
            size: AppIconSize.lg,
          ),
        ),
      ),
    );
  }

  dynamic _getViewModeIcon(PostFilterType mode) {
    switch (mode) {
      case PostFilterType.all:
        return HugeIcons.strokeRoundedFileEdit;
      case PostFilterType.unacknowledged:
        return HugeIcons.strokeRoundedNotification02;
      case PostFilterType.myPosts:
        return HugeIcons.strokeRoundedUserEdit01;
    }
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
        // Search results ไม่มี infinite loading
        return _buildSimplePostsListView(posts);
      },
      loading: () => SliverFillRemaining(
        child: ShimmerWrapper(
          isLoading: true,
          child: Column(
            children: List.generate(3, (_) => const SkeletonCard()),
          ),
        ),
      ),
      error: (e, _) => SliverFillRemaining(
        child: _buildErrorState(e.toString()),
      ),
    );
  }

  /// สร้าง posts list view แบบง่าย (ไม่มี infinite loading)
  /// ใช้สำหรับ search results
  Widget _buildSimplePostsListView(List<Post> posts) {
    final currentUserId = ref.watch(postCurrentUserIdProvider);
    final mainTab = ref.watch(postMainTabProvider);
    const userRole = 'user';
    final isCenterTab = mainTab == PostMainTab.announcement;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = posts[index];
            final isLiked = post.hasUserLiked(currentUserId);
            final isRequiredUnread = !isLiked;

            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: PostCard(
                post: post,
                isLiked: isLiked,
                currentUserId: currentUserId,
                userRole: userRole,
                isCenterTab: isCenterTab,
                isRequiredUnread: isRequiredUnread,
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

  /// สร้าง posts list พร้อม infinite loading
  /// ใช้ postsNotifierProvider แทน postsProvider เดิม
  Widget _buildPostsList() {
    final postsState = ref.watch(postsNotifierProvider);

    // กำลังโหลดครั้งแรก
    if (postsState.isLoading) {
      return SliverFillRemaining(
        child: ShimmerWrapper(
          isLoading: true,
          child: Column(
            children: List.generate(3, (_) => const SkeletonCard()),
          ),
        ),
      );
    }

    // เกิด error
    if (postsState.error != null && postsState.posts.isEmpty) {
      return SliverFillRemaining(
        child: _buildErrorState(postsState.error!),
      );
    }

    // ไม่มีข้อมูล
    if (postsState.posts.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState('ไม่มีโพส'),
      );
    }

    // แสดง posts list พร้อม infinite loading
    return _buildPostsListView(postsState);
  }

  /// สร้าง posts list view พร้อม loading indicator ที่ท้าย
  Widget _buildPostsListView(PostsState postsState) {
    final posts = postsState.posts;
    final currentUserId = ref.watch(postCurrentUserIdProvider);
    final mainTab = ref.watch(postMainTabProvider);
    // TODO: Get userRole from provider when available
    const userRole = 'user';
    // ถ้าอยู่ใน tab ศูนย์ (announcement) = isCenterTab
    final isCenterTab = mainTab == PostMainTab.announcement;

    // จำนวน items = posts + 1 (สำหรับ loading indicator หรือ end message)
    final itemCount = posts.length + 1;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // ถ้าเป็น item สุดท้าย = แสดง loading หรือ end message
            if (index == posts.length) {
              return _buildLoadMoreIndicator(postsState);
            }

            final post = posts[index];
            final isLiked = post.hasUserLiked(currentUserId);

            // ทุก post ที่แสดงในหน้านี้ถือว่า required อยู่แล้ว
            // (Tab ศูนย์ = resident_id IS NULL, Tab ผู้พัก = is_handover = true)
            // ดังนั้นแค่เช็คว่ายังไม่ได้ like ก็พอ
            final isRequiredUnread = !isLiked;

            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: PostCard(
                post: post,
                isLiked: isLiked,
                currentUserId: currentUserId,
                userRole: userRole,
                isCenterTab: isCenterTab,
                isRequiredUnread: isRequiredUnread,
                onTap: () => _navigateToDetail(post),
                onLikeTap: () => _handleLike(post.id),
                onCancelPrn: (queueId) => _handleCancelPrn(queueId),
                onCancelLogLine: (queueId) => _handleCancelLogLine(queueId),
              ),
            );
          },
          childCount: itemCount,
        ),
      ),
    );
  }

  /// สร้าง loading indicator หรือ end message ที่ท้าย list
  Widget _buildLoadMoreIndicator(PostsState postsState) {
    // กำลังโหลดเพิ่ม
    if (postsState.isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // ไม่มีข้อมูลเพิ่มแล้ว
    if (!postsState.hasMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            'ไม่มีข้อมูลเพิ่มเติม',
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
      );
    }

    // ยังมีข้อมูลเพิ่ม แต่ยังไม่โหลด (spacer)
    return SizedBox(height: AppSpacing.lg);
  }

  Widget _buildEmptyState(String message) {
    return EmptyStateWidget(message: message);
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: AppIconSize.display,
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
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
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
      child: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.white),
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
          advancedScreen: const AdvancedCreatePostScreen(),
        );
      },
    );
  }

  void _navigateToDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: post.id),
      ),
    );
  }

  Future<void> _handleLike(int postId) async {
    try {
      final actionService = ref.read(postActionServiceProvider);
      final userId = ref.read(postCurrentUserIdProvider);
      if (userId == null) return;

      await actionService.toggleLike(postId, userId);
      refreshPosts(ref);
    } catch (e) {
      if (mounted) {
        // แจ้ง error เมื่อกดถูกใจไม่สำเร็จ
        AppToast.error(context, 'เกิดข้อผิดพลาด: $e');
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
          // แจ้งยกเลิกการส่ง LINE PRN สำเร็จ
          AppToast.success(context, 'ยกเลิกการส่ง LINE สำเร็จ');
        }
      }
    } catch (e) {
      if (mounted) {
        // แจ้ง error เมื่อยกเลิก PRN ไม่สำเร็จ
        AppToast.error(context, 'เกิดข้อผิดพลาด: $e');
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
          // แจ้งยกเลิกการส่ง LINE Log สำเร็จ
          AppToast.success(context, 'ยกเลิกการส่ง LINE สำเร็จ');
        }
      }
    } catch (e) {
      if (mounted) {
        // แจ้ง error เมื่อยกเลิก Log LINE ไม่สำเร็จ
        AppToast.error(context, 'เกิดข้อผิดพลาด: $e');
      }
    }
  }
}

/// Provider ดึงตั๋วที่สร้างจากโพสนี้ (ถ้ามี)
/// ใช้ .family เพื่อ cache ต่อ postId
final postTicketProvider =
    FutureProvider.family<TicketSummary?, int>((ref, postId) async {
  return TicketService.instance.getTicketForPost(postId);
});

/// หน้ารายละเอียดโพส
class PostDetailScreen extends ConsumerStatefulWidget {
  final int postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  String? _selectedChoice;

  void _openEditPost(BuildContext context, WidgetRef ref, Post post) {
    void onUpdated() {
      ref.invalidate(postDetailProvider(widget.postId));
      refreshPosts(ref);
    }

    // Route based on post content
    if (post.hasAdvancedContent) {
      // Has title or quiz -> go directly to advanced screen
      navigateToAdvancedEditPostScreen(
        context,
        post,
        onPostUpdated: onUpdated,
      );
    } else {
      // Basic post -> show bottom sheet with option to go advanced
      showEditPostBottomSheet(
        context,
        post,
        onPostUpdated: onUpdated,
        onAdvancedTap: () {}, // Enables the advanced button
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final currentUserId = ref.watch(postCurrentUserIdProvider);
    final systemRoleAsync = ref.watch(currentUserSystemRoleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: IreneSecondaryAppBar(
        title: 'รายละเอียดโพส',
        actions: [
          // ปุ่มตั๋ว - แสดงเฉพาะหัวหน้าเวรขึ้นไป (level >= 30)
          // ถ้ามีตั๋วแล้ว = เปลี่ยนสีเป็นสีตามสถานะ + กดเพื่อดูรายละเอียด
          // ถ้ายังไม่มี = สี primary + กดเพื่อสร้างตั๋วใหม่
          postAsync.maybeWhen(
            data: (post) {
              if (post == null) return const SizedBox.shrink();

              final userRoleLevel = systemRoleAsync.valueOrNull?.level;
              // ซ่อนปุ่มถ้า role level < 30
              if (userRoleLevel == null || userRoleLevel < 30) {
                return const SizedBox.shrink();
              }

              // ดึงสถานะตั๋วของโพสนี้
              final ticketAsync =
                  ref.watch(postTicketProvider(widget.postId));
              final existingTicket = ticketAsync.valueOrNull;

              // กำหนดสีตามว่ามีตั๋วหรือยัง
              final Color iconColor;
              if (existingTicket != null) {
                // มีตั๋วแล้ว → สีตามสถานะ
                switch (existingTicket.status) {
                  case 'open':
                    iconColor = AppColors.tagPendingText;
                  case 'in_progress':
                    iconColor = AppColors.secondary;
                  case 'completed':
                  case 'closed':
                    iconColor = AppColors.tagPassedText;
                  case 'cancelled':
                    iconColor = AppColors.tagNeutralText;
                  default:
                    iconColor = AppColors.primary;
                }
              } else {
                // ยังไม่มีตั๋ว → สี primary
                iconColor = AppColors.primary;
              }

              return IconButton(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedTicket02,
                  color: iconColor,
                ),
                onPressed: () {
                  if (existingTicket != null) {
                    // มีตั๋วแล้ว → เปิดดูรายละเอียด
                    showTicketDetailBottomSheet(
                      context,
                      ticket: existingTicket,
                    );
                  } else {
                    // ยังไม่มี → สร้างตั๋วใหม่
                    showCreateTicketBottomSheet(
                      context,
                      post: post,
                      onTicketCreated: () {
                        // Invalidate provider เพื่อ refresh สถานะปุ่ม
                        ref.invalidate(
                            postTicketProvider(widget.postId));
                      },
                    );
                  }
                },
                tooltip: existingTicket != null
                    ? 'ดูตั๋ว #${existingTicket.id}'
                    : 'สร้างตั๋ว',
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          // Edit button - show only if user can edit
          postAsync.maybeWhen(
            data: (post) {
              if (post == null) return const SizedBox.shrink();

              final userRoleLevel = systemRoleAsync.valueOrNull?.level;
              final canEdit = Post.canEdit(
                post: post,
                currentUserId: currentUserId,
                userRoleLevel: userRoleLevel,
              );

              if (!canEdit) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: IconButton(
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedEdit01, color: AppColors.primary),
                  onPressed: () => _openEditPost(context, ref, post),
                  tooltip: 'แก้ไขโพส',
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
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

          // post ใน tab ศูนย์ = ไม่มี resident_id
          final isCenterTabPost = post.residentId == null;

          return SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // tab ศูนย์ = แสดง post tags จริง, tab ผู้พัก = แสดง type tag
                if (isCenterTabPost)
                  _buildDetailPostTags(post)
                else
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

                // Tags (แสดงเฉพาะ tab ผู้พัก เพราะ tab ศูนย์แสดงไว้ด้านบนแล้ว)
                if (!isCenterTabPost && post.postTags.isNotEmpty) ...[
                  _buildTagsSection(post),
                  AppSpacing.verticalGapLg,
                ],

                // Resident info (if linked)
                if (post.residentId != null && post.residentId! > 0) ...[
                  _buildResidentCard(post),
                  AppSpacing.verticalGapLg,
                ],

                // ความเคลื่อนไหวยา (ถ้ามี med_history เชื่อมกับ post นี้)
                _buildMedicineActivitySection(),

                // Images
                if (post.hasImages) ...[
                  _buildImageGallery(post.allImageUrls),
                  AppSpacing.verticalGapLg,
                ],

                // Video player
                if (post.hasUploadedVideo) ...[
                  _buildVideoSection(post),
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
        loading: () => ShimmerWrapper(
          isLoading: true,
          child: Column(
            children: List.generate(3, (_) => const SkeletonCard()),
          ),
        ),
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
      tagText = 'ศูนย์';
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

  /// แสดง post tags จริงที่ user ใส่ (สำหรับ post ใน tab ศูนย์)
  Widget _buildDetailPostTags(Post post) {
    if (post.postTags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: post.postTags.map((tag) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '#$tag',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAuthorInfo(Post post) {
    return Row(
      children: [
        // Avatar ผู้เขียน - ใช้ IreneNetworkAvatar พร้อม timeout/retry/memory optimization
        IreneNetworkAvatar(
          imageUrl: post.photoUrl,
          radius: 20,
          backgroundColor: AppColors.accent1,
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

  /// แสดง section "ความเคลื่อนไหวยา" — ดึงจาก med_history WHERE post_id
  /// แสดงเฉพาะเมื่อมี records เชื่อมกับ post นี้
  Widget _buildMedicineActivitySection() {
    final medHistoryAsync =
        ref.watch(postMedHistoryProvider(widget.postId));

    return medHistoryAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedMedicine02,
                  size: AppIconSize.md,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'ความเคลื่อนไหวยา',
                  style: AppTypography.title.copyWith(fontSize: 16),
                ),
              ],
            ),
            AppSpacing.verticalGapSm,
            // Items container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: items
                    .map((item) => _buildMedActivityItem(item))
                    .toList(),
              ),
            ),
            AppSpacing.verticalGapLg,
          ],
        );
      },
      // ไม่แสดงอะไรระหว่าง loading/error — ไม่ block UI
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  /// แสดงแต่ละ med_history item — icon + label + ชื่อยา + วิธีรับประทาน + จำนวน
  Widget _buildMedActivityItem(Map<String, dynamic> item) {
    final changeType = item['change_type'] as String? ?? 'restock';
    final reconcile = (item['reconcile'] as num?)?.toDouble();
    final newSetting = item['new_setting'] as String?;
    final medList = item['medicine_List'] as Map<String, dynamic>?;
    final medDb = medList?['med_DB'] as Map<String, dynamic>?;
    final name = medDb?['generic_name'] ?? 'ไม่ทราบชื่อ';
    final strength = medDb?['str'] as String?;
    final unit = medDb?['unit'] as String? ?? 'เม็ด';
    final displayName = strength != null && strength.isNotEmpty
        ? '$name $strength'
        : name.toString();

    // Icon + label ตาม change_type
    final isAdd = changeType == 'add';
    final icon = isAdd
        ? HugeIcons.strokeRoundedAdd01
        : HugeIcons.strokeRoundedPackageReceive;
    final label = isAdd ? 'เพิ่มยาใหม่' : 'อัพเดตสต็อก';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          HugeIcon(
            icon: icon,
            size: AppIconSize.sm,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(displayName, style: AppTypography.bodySmall),
                // วิธีรับประทาน (new_setting) — แสดงเฉพาะยาใหม่ที่มี setting
                if (newSetting != null && newSetting.isNotEmpty)
                  Text(
                    newSetting,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                // จำนวนสต็อก
                if (reconcile != null && reconcile > 0)
                  Text(
                    'สต็อก: ${reconcile % 1 == 0 ? reconcile.toInt() : reconcile} $unit',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
              // Avatar ผู้พักอาศัย - ใช้ IreneNetworkAvatar พร้อม timeout/retry/memory optimization
              IreneNetworkAvatar(
                imageUrl: post.residentPictureUrl,
                radius: 22,
                backgroundColor: AppColors.surface,
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
              onTap: () => showFullScreenImage(context, urls: validUrls, initialIndex: index),
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
                    child: Center(
                      child: HugeIcon(icon: HugeIcons.strokeRoundedImage01, color: AppColors.secondaryText, size: AppIconSize.xl),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  /// สร้าง Video Section สำหรับแสดงวิดีโอที่อัพโหลด
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
                  child: VideoThumbnailPlayer(
                    videoUrl: url,
                  ),
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
              HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkBadge01, color: Color(0xFF005460), size: AppIconSize.xl),
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
            fit: BoxFit.cover,
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
                    final userId = ref.read(postCurrentUserIdProvider);
                    if (userId == null) return;

                    await actionService.toggleLike(widget.postId, userId);
                    refreshPosts(ref);
                    ref.invalidate(postDetailProvider(widget.postId));
                  }
                : null,
            icon: HugeIcon(
              icon: isLiked ? HugeIcons.strokeRoundedFavourite : HugeIcons.strokeRoundedFavourite,
              color: isLiked ? AppColors.error : Colors.white,
            ),
            label: Text(
              isLiked ? 'ยกเลิกการรับทราบ' : 'รับทราบ',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: isLiked ? AppColors.error : Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLiked
                  ? AppColors.tagFailedBg
                  : AppColors.primary,
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


