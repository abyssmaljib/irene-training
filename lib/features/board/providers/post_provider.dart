import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/user_service.dart';
import '../models/post.dart';
import '../models/post_tab.dart';
import '../models/post_filter.dart';
import '../services/post_service.dart';
import '../services/post_action_service.dart';
import 'post_filter_provider.dart';

// =============================================================================
// Posts Pagination State & Notifier
// =============================================================================

/// จำนวน posts ที่โหลดต่อครั้ง
const int kPostsPageSize = 10;

/// State สำหรับ posts list พร้อม pagination
/// เก็บข้อมูลทั้งหมดที่จำเป็นสำหรับ infinite loading
class PostsState {
  final List<Post> posts;
  final bool isLoading; // กำลังโหลดครั้งแรก
  final bool isLoadingMore; // กำลังโหลดเพิ่ม
  final bool hasMore; // ยังมีข้อมูลเพิ่มเติม
  final int currentOffset; // ตำแหน่งปัจจุบัน
  final String? error;

  const PostsState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentOffset = 0,
    this.error,
  });

  /// สร้าง state เริ่มต้น (กำลังโหลด)
  factory PostsState.loading() => const PostsState(isLoading: true);

  /// Copy with pattern สำหรับ immutable state update
  PostsState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentOffset,
    String? error,
  }) {
    return PostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentOffset: currentOffset ?? this.currentOffset,
      error: error,
    );
  }
}

/// Notifier สำหรับจัดการ posts pagination
/// รองรับ loadInitial, loadMore, refresh
class PostsNotifier extends StateNotifier<PostsState> {
  final Ref ref;
  PostFilter? _lastFilter;

  PostsNotifier(this.ref) : super(PostsState.loading()) {
    // โหลดข้อมูลครั้งแรกเมื่อสร้าง notifier
    loadInitial();
  }

  /// โหลด posts ครั้งแรก (reset offset = 0)
  Future<void> loadInitial() async {
    // ตั้ง state เป็น loading
    state = PostsState.loading();

    try {
      final nursinghomeId = await ref.read(nursinghomeIdProvider.future);
      if (nursinghomeId == null) {
        state = const PostsState(posts: [], isLoading: false, hasMore: false);
        return;
      }

      final filter = ref.read(postFilterProvider);
      final currentUserId = ref.read(currentUserIdProvider);
      final service = ref.read(postServiceProvider);

      // เก็บ filter ล่าสุดไว้เช็คตอน loadMore
      _lastFilter = filter;

      // ใช้ getPostsWithPagination เพื่อให้ได้ hasMore ที่ถูกต้อง
      // (คำนวณจากจำนวนที่ server ส่งมา ไม่ใช่หลัง client-side filter)
      final (posts, hasMore) = await service.getPostsWithPagination(
        nursinghomeId: nursinghomeId,
        filter: filter,
        currentUserId: currentUserId,
        limit: kPostsPageSize,
        offset: 0,
      );

      state = PostsState(
        posts: posts,
        isLoading: false,
        hasMore: hasMore,
        currentOffset: kPostsPageSize, // ใช้ pageSize เพราะ server ส่งมาเท่านี้
      );
    } catch (e) {
      debugPrint('PostsNotifier.loadInitial error: $e');
      state = PostsState(
        isLoading: false,
        hasMore: false,
        error: e.toString(),
      );
    }
  }

  /// โหลด posts เพิ่มเติม (infinite scroll)
  Future<void> loadMore() async {
    // ป้องกันโหลดซ้ำ หรือโหลดเมื่อไม่มีข้อมูลเพิ่ม
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nursinghomeId = await ref.read(nursinghomeIdProvider.future);
      if (nursinghomeId == null) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      final filter = ref.read(postFilterProvider);
      final currentUserId = ref.read(currentUserIdProvider);
      final service = ref.read(postServiceProvider);

      // ถ้า filter เปลี่ยน ให้ loadInitial แทน
      if (_lastFilter != filter) {
        await loadInitial();
        return;
      }

      // ใช้ getPostsWithPagination เพื่อให้ได้ hasMore ที่ถูกต้อง
      final (newPosts, hasMore) = await service.getPostsWithPagination(
        nursinghomeId: nursinghomeId,
        filter: filter,
        currentUserId: currentUserId,
        limit: kPostsPageSize,
        offset: state.currentOffset,
      );

      state = state.copyWith(
        posts: [...state.posts, ...newPosts],
        isLoadingMore: false,
        hasMore: hasMore,
        currentOffset: state.currentOffset + kPostsPageSize, // เพิ่มตาม pageSize
      );
    } catch (e) {
      debugPrint('PostsNotifier.loadMore error: $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh posts (pull to refresh)
  Future<void> refresh() async {
    PostService.instance.invalidateCache();
    await loadInitial();
  }
}

/// Provider สำหรับ PostsNotifier
/// autoDispose เพื่อ reset เมื่อออกจากหน้า
final postsNotifierProvider =
    StateNotifierProvider.autoDispose<PostsNotifier, PostsState>((ref) {
  // Watch filter changes เพื่อ reload เมื่อ filter เปลี่ยน
  ref.watch(postFilterProvider);
  ref.watch(postRefreshCounterProvider);

  return PostsNotifier(ref);
});

/// Provider สำหรับ PostService
final postServiceProvider = Provider<PostService>((ref) {
  return PostService.instance;
});

/// Provider สำหรับ PostActionService
final postActionServiceProvider = Provider<PostActionService>((ref) {
  return PostActionService.instance;
});

/// Provider สำหรับ current user ID (uses effectiveUserId for dev mode)
final currentUserIdProvider = Provider<String?>((ref) {
  return UserService().effectiveUserId;
});

/// Provider สำหรับ nursinghome ID
final nursinghomeIdProvider = FutureProvider<int?>((ref) async {
  final userService = UserService();
  return userService.getNursinghomeId();
});

/// Provider สำหรับ user's role level (สำหรับตรวจสอบสิทธิ์)
/// Returns role level (0-50) where:
/// - 30+ = shift leader (หัวหน้าเวร) - can edit tag/resident of any post
/// - 40+ = manager (ผู้จัดการ)
/// - 50 = owner (เจ้าของ)
final userRoleLevelProvider = FutureProvider<int>((ref) async {
  final userService = UserService();
  final systemRole = await userService.getSystemRole();
  return systemRole?.level ?? 0;
});

/// Provider ตรวจสอบว่า user เป็นหัวหน้าเวรขึ้นไปหรือไม่
final isAtLeastShiftLeaderProvider = FutureProvider<bool>((ref) async {
  final level = await ref.watch(userRoleLevelProvider.future);
  // Shift leader level = 30
  return level >= 30;
});

/// Counter เพื่อ trigger refresh
final postRefreshCounterProvider = StateProvider<int>((ref) => 0);

/// Main posts provider - ดึง posts ตาม current filter
final postsProvider = FutureProvider<List<Post>>((ref) async {
  // Watch refresh counter to trigger rebuild
  ref.watch(postRefreshCounterProvider);

  final nursinghomeId = await ref.watch(nursinghomeIdProvider.future);
  if (nursinghomeId == null) return [];

  final filter = ref.watch(postFilterProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  final service = ref.watch(postServiceProvider);

  return service.getPosts(
    nursinghomeId: nursinghomeId,
    filter: filter,
    currentUserId: currentUserId,
  );
});

/// Provider สำหรับ pinned Critical post
final pinnedPostProvider = FutureProvider<Post?>((ref) async {
  ref.watch(postRefreshCounterProvider);

  final nursinghomeId = await ref.watch(nursinghomeIdProvider.future);
  if (nursinghomeId == null) return null;

  final service = ref.watch(postServiceProvider);
  return service.getPinnedCriticalPost(nursinghomeId);
});

/// Provider สำหรับ unread counts ต่อ tab
final unreadCountsProvider = FutureProvider<Map<PostMainTab, int>>((ref) async {
  ref.watch(postRefreshCounterProvider);

  final nursinghomeId = await ref.watch(nursinghomeIdProvider.future);
  final userId = ref.watch(currentUserIdProvider);

  if (nursinghomeId == null || userId == null) {
    return {
      PostMainTab.announcement: 0,
      PostMainTab.resident: 0,
    };
  }

  final service = ref.watch(postServiceProvider);
  return service.getUnreadCounts(nursinghomeId, userId);
});

/// Provider สำหรับ total unread post count (สำหรับแสดง badge ที่ navigation)
final totalUnreadPostCountProvider = FutureProvider<int>((ref) async {
  final counts = await ref.watch(unreadCountsProvider.future);
  return counts.values.fold<int>(0, (sum, count) => sum + count);
});

/// Provider สำหรับ post detail (by ID)
final postDetailProvider =
    FutureProvider.family<Post?, int>((ref, postId) async {
  final service = ref.watch(postServiceProvider);
  return service.getPostById(postId);
});

/// Provider สำหรับ search results
final postSearchResultsProvider = FutureProvider<List<Post>>((ref) async {
  final searchQuery = ref.watch(postSearchQueryProvider);
  if (searchQuery.isEmpty) return [];

  final nursinghomeId = await ref.watch(nursinghomeIdProvider.future);
  if (nursinghomeId == null) return [];

  final mainTab = ref.watch(postMainTabProvider);
  final service = ref.watch(postServiceProvider);

  return service.searchPosts(
    nursinghomeId: nursinghomeId,
    query: searchQuery,
    tab: mainTab,
  );
});

/// Helper function to refresh all post data
/// รองรับทั้ง postsNotifierProvider (infinite scroll) และ legacy providers
void refreshPosts(WidgetRef ref) {
  PostService.instance.invalidateCache();
  ref.read(postRefreshCounterProvider.notifier).state++;

  // Refresh postsNotifier ถ้ามีอยู่
  // ใช้ try-catch เพราะอาจยังไม่ได้ mount
  try {
    ref.read(postsNotifierProvider.notifier).refresh();
  } catch (_) {
    // Notifier ยังไม่ได้สร้าง - ไม่ต้องทำอะไร
  }
}

/// Helper function to invalidate and refresh
void invalidateAndRefreshPosts(WidgetRef ref) {
  PostService.instance.invalidateCache();
  ref.invalidate(postsProvider);
  ref.invalidate(postsNotifierProvider);
  ref.invalidate(pinnedPostProvider);
  ref.invalidate(unreadCountsProvider);
}

/// Provider for toggling like with optimistic update
final toggleLikeProvider =
    FutureProvider.family<bool, int>((ref, postId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;

  final actionService = ref.watch(postActionServiceProvider);
  final result = await actionService.toggleLike(postId, userId);

  // Invalidate cache after like/unlike
  PostService.instance.invalidateCache();
  ref.invalidate(postsProvider);
  ref.invalidate(unreadCountsProvider);

  return result;
});
