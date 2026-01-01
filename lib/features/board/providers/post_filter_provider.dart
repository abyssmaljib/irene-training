import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post_tab.dart';
import '../models/post_filter.dart';

/// Provider สำหรับ main tab selection
final postMainTabProvider = StateProvider<PostMainTab>((ref) {
  return PostMainTab.announcement;
});

/// Provider สำหรับ filter type (All, Unacknowledged, MyPosts)
final postFilterTypeProvider = StateProvider<PostFilterType>((ref) {
  return PostFilterType.all;
});

/// Provider สำหรับ selected resident ID
final selectedResidentIdProvider = StateProvider<int?>((ref) {
  return null;
});

/// Provider สำหรับ selected resident name (for display)
final selectedResidentNameProvider = StateProvider<String?>((ref) {
  return null;
});

/// Provider สำหรับ search query
final postSearchQueryProvider = StateProvider<String>((ref) {
  return '';
});

/// Combined filter state provider - V3: ลบ announcementSubTab
final postFilterProvider = Provider<PostFilter>((ref) {
  return PostFilter(
    mainTab: ref.watch(postMainTabProvider),
    filterType: ref.watch(postFilterTypeProvider),
    selectedResidentId: ref.watch(selectedResidentIdProvider),
    selectedResidentName: ref.watch(selectedResidentNameProvider),
    searchQuery: ref.watch(postSearchQueryProvider),
  );
});

/// Provider สำหรับนับจำนวน active filters (for badge)
final activeFilterCountProvider = Provider<int>((ref) {
  int count = 0;
  if (ref.watch(postFilterTypeProvider) != PostFilterType.all) count++;
  if (ref.watch(selectedResidentIdProvider) != null) count++;
  if (ref.watch(postSearchQueryProvider).isNotEmpty) count++;
  return count;
});

/// Helper class for filter actions - V3: ลบ announcementSubTab methods
class PostFilterNotifier {
  final WidgetRef ref;

  PostFilterNotifier(this.ref);

  /// Set main tab
  void setMainTab(PostMainTab tab) {
    ref.read(postMainTabProvider.notifier).state = tab;
  }

  /// Set filter type
  void setFilterType(PostFilterType type) {
    ref.read(postFilterTypeProvider.notifier).state = type;
  }

  /// Set selected resident
  void setSelectedResident(int? residentId, String? residentName) {
    ref.read(selectedResidentIdProvider.notifier).state = residentId;
    ref.read(selectedResidentNameProvider.notifier).state = residentName;
  }

  /// Clear selected resident
  void clearSelectedResident() {
    ref.read(selectedResidentIdProvider.notifier).state = null;
    ref.read(selectedResidentNameProvider.notifier).state = null;
  }

  /// Set search query
  void setSearchQuery(String query) {
    ref.read(postSearchQueryProvider.notifier).state = query;
  }

  /// Clear search query
  void clearSearchQuery() {
    ref.read(postSearchQueryProvider.notifier).state = '';
  }

  /// Reset all filters to default
  void resetAllFilters() {
    ref.read(postMainTabProvider.notifier).state = PostMainTab.announcement;
    ref.read(postFilterTypeProvider.notifier).state = PostFilterType.all;
    ref.read(selectedResidentIdProvider.notifier).state = null;
    ref.read(selectedResidentNameProvider.notifier).state = null;
    ref.read(postSearchQueryProvider.notifier).state = '';
  }

  /// Reset secondary filters only (keep tabs)
  void resetSecondaryFilters() {
    ref.read(postFilterTypeProvider.notifier).state = PostFilterType.all;
    ref.read(selectedResidentIdProvider.notifier).state = null;
    ref.read(selectedResidentNameProvider.notifier).state = null;
    ref.read(postSearchQueryProvider.notifier).state = '';
  }
}
