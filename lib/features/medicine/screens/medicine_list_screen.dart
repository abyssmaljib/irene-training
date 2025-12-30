import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/input_fields.dart';
import '../../../core/widgets/toggle_switch.dart';
import '../models/medicine_summary.dart';
import '../services/medicine_service.dart';
import '../widgets/medicine_card.dart';
import 'medicine_photos_screen.dart';

/// ข้อมูลประเภทยาสำหรับ filter chips
class _GroupInfo {
  final String name;
  final int activeCount;
  final int totalCount;

  _GroupInfo({
    required this.name,
    required this.activeCount,
    required this.totalCount,
  });

  bool get hasActiveItems => activeCount > 0;
}

/// หน้ารายการยาทั้งหมดของ Resident
class MedicineListScreen extends StatefulWidget {
  final int residentId;
  final String residentName;

  const MedicineListScreen({
    super.key,
    required this.residentId,
    required this.residentName,
  });

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  final _medicineService = MedicineService.instance;
  final _searchController = TextEditingController();

  List<MedicineSummary> _allMedicines = [];
  List<MedicineSummary> _filteredMedicines = [];
  List<_GroupInfo> _availableGroups = []; // Sorted by active count
  String? _selectedGroup;
  bool _showOnlyActive = true; // 0 = On, 1 = All
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    setState(() => _isLoading = true);

    try {
      final medicines = await _medicineService.getMedicinesByResident(widget.residentId);

      // Extract groups with active/total counts
      final groupStats = <String, Map<String, int>>{};
      for (final med in medicines) {
        final groupName = med.displayGroup;
        if (groupName.isNotEmpty && groupName != 'ไม่ระบุประเภท') {
          groupStats.putIfAbsent(groupName, () => {'active': 0, 'total': 0});
          groupStats[groupName]!['total'] = groupStats[groupName]!['total']! + 1;
          if (med.isActive) {
            groupStats[groupName]!['active'] = groupStats[groupName]!['active']! + 1;
          }
        }
      }

      // Convert to list and sort by active count (descending)
      final groupList = groupStats.entries.map((e) => _GroupInfo(
        name: e.key,
        activeCount: e.value['active']!,
        totalCount: e.value['total']!,
      )).toList();

      // Sort: groups with active items first, then by active count
      groupList.sort((a, b) {
        if (a.hasActiveItems && !b.hasActiveItems) return -1;
        if (!a.hasActiveItems && b.hasActiveItems) return 1;
        return b.activeCount.compareTo(a.activeCount);
      });

      setState(() {
        _allMedicines = medicines;
        _availableGroups = groupList;
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      debugPrint('Error loading medicines: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<MedicineSummary> result = List.from(_allMedicines);

    // Filter by active status
    if (_showOnlyActive) {
      result = result.where((m) => m.isActive).toList();
    }

    // Filter by group (uses displayGroup which prefers ATC Level 2, fallback to group)
    if (_selectedGroup != null) {
      result = result.where((m) => m.displayGroup == _selectedGroup).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((m) {
        final name = m.displayName.toLowerCase();
        final brand = m.displayBrand.toLowerCase();
        final group = m.displayGroup.toLowerCase();
        return name.contains(query) || brand.contains(query) || group.contains(query);
      }).toList();
    }

    setState(() => _filteredMedicines = result);
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _onToggleChanged(int index) {
    setState(() => _showOnlyActive = index == 0);
    _applyFilters();
  }

  void _onGroupSelected(String? group) {
    setState(() => _selectedGroup = group);
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Collapsible header with back button, title, search, and filter chips
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              backgroundColor: AppColors.secondaryBackground,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Iconsax.arrow_left,
                  color: AppColors.primaryText,
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.residentName,
                    style: AppTypography.title,
                  ),
                  Text(
                    'รายการยา',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              actions: [
                // Shortcut to medicine photos
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MedicinePhotosScreen(
                          residentId: widget.residentId,
                          residentName: widget.residentName,
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    Iconsax.image,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'รูปตัวอย่างยา',
                ),
                SizedBox(width: 8),
              ],
              expandedHeight: _availableGroups.isNotEmpty ? 168 : 120,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppColors.secondaryBackground,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        top: kToolbarHeight + 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search field
                          SearchField(
                            controller: _searchController,
                            hintText: 'ค้นหายา...',
                            onChanged: _onSearchChanged,
                          ),
                          SizedBox(height: AppSpacing.sm),

                          // Group filter chips
                          if (_availableGroups.isNotEmpty)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  _buildGroupChip(null, 'ทั้งหมด', true),
                                  ..._availableGroups.map((group) => _buildGroupChip(
                                    group.name,
                                    group.name,
                                    group.hasActiveItems,
                                  )),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Sticky toggle control + count
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyToggleDelegate(
                height: 64,
                child: Container(
                  height: 64,
                  color: AppColors.secondaryBackground,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedControl(
                          options: const ['ใช้อยู่', 'ทั้งหมด'],
                          selectedIndex: _showOnlyActive ? 0 : 1,
                          onChanged: _onToggleChanged,
                        ),
                      ),
                      AppSpacing.horizontalGapMd,
                      // Medicine count
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accent1,
                          borderRadius: AppRadius.smallRadius,
                        ),
                        child: Text(
                          '${_filteredMedicines.length} รายการ',
                          style: AppTypography.buttonSmall.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: RefreshIndicator(
          onRefresh: _loadMedicines,
          color: AppColors.primary,
          child: _buildMedicineList(),
        ),
      ),
    );
  }

  Widget _buildGroupChip(String? group, String label, bool hasActiveItems) {
    final isSelected = _selectedGroup == group;
    // Dim the chip if it has no active items
    final isDimmed = !hasActiveItems && !isSelected;

    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onGroupSelected(isSelected ? null : group),
        selectedColor: AppColors.accent1,
        checkmarkColor: AppColors.primary,
        backgroundColor: isDimmed
            ? AppColors.background.withValues(alpha: 0.5)
            : AppColors.background,
        labelStyle: AppTypography.bodySmall.copyWith(
          color: isSelected
              ? AppColors.primary
              : isDimmed
                  ? AppColors.textSecondary.withValues(alpha: 0.5)
                  : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smallRadius,
          side: BorderSide(
            color: isSelected
                ? AppColors.primary
                : isDimmed
                    ? AppColors.inputBorder.withValues(alpha: 0.5)
                    : AppColors.inputBorder,
          ),
        ),
      ),
    );
  }

  Widget _buildMedicineList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            AppSpacing.verticalGapMd,
            Text(
              'กำลังโหลดรายการยา...',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredMedicines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.health,
              size: 64,
              color: AppColors.textSecondary,
            ),
            AppSpacing.verticalGapMd,
            Text(
              _searchQuery.isNotEmpty || _selectedGroup != null
                  ? 'ไม่พบยาที่ค้นหา'
                  : 'ไม่มีรายการยา',
              style: AppTypography.title.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (_searchQuery.isNotEmpty || _selectedGroup != null) ...[
              AppSpacing.verticalGapSm,
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedGroup = null;
                  });
                  _applyFilters();
                },
                child: Text('ล้างตัวกรอง'),
              ),
            ],
          ],
        ),
      );
    }

    // Group medicines by ATC Level 2
    final groupedMedicines = <String, List<MedicineSummary>>{};
    for (final med in _filteredMedicines) {
      final groupName = med.displayGroup;
      groupedMedicines.putIfAbsent(groupName, () => []).add(med);
    }

    final groupNames = groupedMedicines.keys.toList()..sort();

    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.md),
      itemCount: groupNames.length,
      itemBuilder: (context, index) {
        final groupName = groupNames[index];
        final medicines = groupedMedicines[groupName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group header
            if (_selectedGroup == null) ...[
              Padding(
                padding: EdgeInsets.only(
                  top: index > 0 ? AppSpacing.lg : 0,
                  bottom: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    AppSpacing.horizontalGapSm,
                    Expanded(
                      child: Text(
                        groupName,
                        style: AppTypography.title.copyWith(
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppSpacing.horizontalGapSm,
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent1,
                        borderRadius: AppRadius.fullRadius,
                      ),
                      child: Text(
                        '${medicines.length}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Medicine cards
            ...medicines.map((med) => Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: MedicineCard(medicine: med),
            )),
          ],
        );
      },
    );
  }
}

/// Delegate สำหรับ sticky toggle control
class _StickyToggleDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyToggleDelegate({
    required this.child,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _StickyToggleDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}
