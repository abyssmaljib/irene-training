import 'post_tab.dart';

/// Filter state for post list - V3: ลบ announcementSubTab
class PostFilter {
  final PostMainTab mainTab;
  final PostFilterType filterType;
  final int? selectedResidentId;
  final String? selectedResidentName;
  final String searchQuery;

  const PostFilter({
    this.mainTab = PostMainTab.announcement,
    this.filterType = PostFilterType.all,
    this.selectedResidentId,
    this.selectedResidentName,
    this.searchQuery = '',
  });

  /// Check if any filter is active (besides default tab)
  bool get hasActiveFilters {
    return filterType != PostFilterType.all ||
        selectedResidentId != null ||
        searchQuery.isNotEmpty;
  }

  /// Count of active filters (for badge)
  int get activeFilterCount {
    int count = 0;
    if (filterType != PostFilterType.all) count++;
    if (selectedResidentId != null) count++;
    if (searchQuery.isNotEmpty) count++;
    return count;
  }

  /// Get database tab values to filter by
  List<String> get dbTabValues {
    return mainTab.dbTabValues;
  }

  /// Check if this is the resident tab (posts ที่มี resident_id)
  bool get isResidentTab => mainTab == PostMainTab.resident;

  /// Copy with method
  PostFilter copyWith({
    PostMainTab? mainTab,
    PostFilterType? filterType,
    int? selectedResidentId,
    bool clearSelectedResident = false,
    String? selectedResidentName,
    String? searchQuery,
  }) {
    return PostFilter(
      mainTab: mainTab ?? this.mainTab,
      filterType: filterType ?? this.filterType,
      selectedResidentId: clearSelectedResident
          ? null
          : (selectedResidentId ?? this.selectedResidentId),
      selectedResidentName: clearSelectedResident
          ? null
          : (selectedResidentName ?? this.selectedResidentName),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Reset all filters to default
  PostFilter reset() {
    return const PostFilter();
  }

  /// Reset only secondary filters (keep main tab)
  PostFilter resetSecondaryFilters() {
    return PostFilter(mainTab: mainTab);
  }

  @override
  String toString() {
    return 'PostFilter(mainTab: $mainTab, '
        'filterType: $filterType, residentId: $selectedResidentId, '
        'search: $searchQuery)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostFilter &&
        other.mainTab == mainTab &&
        other.filterType == filterType &&
        other.selectedResidentId == selectedResidentId &&
        other.searchQuery == searchQuery;
  }

  @override
  int get hashCode {
    return Object.hash(
      mainTab,
      filterType,
      selectedResidentId,
      searchQuery,
    );
  }
}
