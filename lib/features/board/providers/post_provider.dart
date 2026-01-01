import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../models/post.dart';
import '../models/post_tab.dart';
import '../services/post_service.dart';
import '../services/post_action_service.dart';
import 'post_filter_provider.dart';

/// Provider สำหรับ PostService
final postServiceProvider = Provider<PostService>((ref) {
  return PostService.instance;
});

/// Provider สำหรับ PostActionService
final postActionServiceProvider = Provider<PostActionService>((ref) {
  return PostActionService.instance;
});

/// Provider สำหรับ current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

/// Provider สำหรับ nursinghome ID
final nursinghomeIdProvider = FutureProvider<int?>((ref) async {
  final userService = UserService();
  return userService.getNursinghomeId();
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
      PostMainTab.handover: 0,
    };
  }

  final service = ref.watch(postServiceProvider);
  return service.getUnreadCounts(nursinghomeId, userId);
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
void refreshPosts(WidgetRef ref) {
  PostService.instance.invalidateCache();
  ref.read(postRefreshCounterProvider.notifier).state++;
}

/// Helper function to invalidate and refresh
void invalidateAndRefreshPosts(WidgetRef ref) {
  PostService.instance.invalidateCache();
  ref.invalidate(postsProvider);
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
