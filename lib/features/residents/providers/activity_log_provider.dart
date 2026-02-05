import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../board/models/post.dart';
import '../../board/providers/post_provider.dart';
import '../../checklist/providers/task_provider.dart'; // for nursinghomeIdProvider

/// State สำหรับ activity log filters
class ActivityLogFilter {
  final String searchQuery;
  final Set<String> selectedTags;
  final DateTime? startDate;
  final DateTime? endDate;

  const ActivityLogFilter({
    this.searchQuery = '',
    this.selectedTags = const {},
    this.startDate,
    this.endDate,
  });

  ActivityLogFilter copyWith({
    String? searchQuery,
    Set<String>? selectedTags,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return ActivityLogFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTags: selectedTags ?? this.selectedTags,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (searchQuery.isNotEmpty) count++;
    if (selectedTags.isNotEmpty) count++;
    if (startDate != null || endDate != null) count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;
}

/// Provider สำหรับ filter state
final activityLogFilterProvider =
    StateProvider.family<ActivityLogFilter, int>((ref, residentId) {
  return const ActivityLogFilter();
});

/// Provider สำหรับ search query
final activityLogSearchProvider =
    StateProvider.family<String, int>((ref, residentId) => '');

/// Provider สำหรับ selected tags
final activityLogSelectedTagsProvider =
    StateProvider.family<Set<String>, int>((ref, residentId) => {});

/// Provider สำหรับ available tags จาก posts
final activityLogAvailableTagsProvider =
    FutureProvider.family<List<String>, int>((ref, residentId) async {
  final posts =
      await ref.watch(residentActivityPostsFullProvider(residentId).future);

  final tagSet = <String>{};
  for (final post in posts) {
    tagSet.addAll(post.postTags);
  }

  final tags = tagSet.toList()..sort();
  return tags;
});

/// Provider สำหรับ activity posts ทั้งหมดของ resident (limit สูงขึ้น)
final residentActivityPostsFullProvider =
    FutureProvider.family<List<Post>, int>((ref, residentId) async {
  final nursinghomeId = await ref.watch(nursinghomeIdProvider.future);
  if (nursinghomeId == null) return [];

  final service = ref.watch(postServiceProvider);
  return service.getPostsByResident(
    nursinghomeId: nursinghomeId,
    residentId: residentId,
    limit: 100, // ดึงมากขึ้นสำหรับหน้าดูทั้งหมด
  );
});

/// Provider สำหรับ filtered activity posts
final filteredActivityPostsProvider =
    Provider.family<List<Post>, int>((ref, residentId) {
  final postsAsync = ref.watch(residentActivityPostsFullProvider(residentId));
  final searchQuery = ref.watch(activityLogSearchProvider(residentId));
  final selectedTags = ref.watch(activityLogSelectedTagsProvider(residentId));

  return postsAsync.when(
    loading: () => [],
    error: (_, _) => [],
    data: (posts) {
      var filtered = posts;

      // Filter by search query
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        filtered = filtered.where((post) {
          final text = post.text?.toLowerCase() ?? '';
          final title = post.title?.toLowerCase() ?? '';
          final author = post.postUserNickname?.toLowerCase() ?? '';
          return text.contains(query) ||
              title.contains(query) ||
              author.contains(query);
        }).toList();
      }

      // Filter by tags
      if (selectedTags.isNotEmpty) {
        filtered = filtered.where((post) {
          return post.postTags.any((tag) => selectedTags.contains(tag));
        }).toList();
      }

      return filtered;
    },
  );
});

/// Helper functions
void clearActivityLogFilters(WidgetRef ref, int residentId) {
  ref.read(activityLogSearchProvider(residentId).notifier).state = '';
  ref.read(activityLogSelectedTagsProvider(residentId).notifier).state = {};
}

void toggleActivityLogTag(WidgetRef ref, int residentId, String tag) {
  final current = ref.read(activityLogSelectedTagsProvider(residentId));
  final newSet = Set<String>.from(current);
  if (newSet.contains(tag)) {
    newSet.remove(tag);
  } else {
    newSet.add(tag);
  }
  ref.read(activityLogSelectedTagsProvider(residentId).notifier).state = newSet;
}
