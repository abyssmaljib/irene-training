import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/filter_drawer_shell.dart';
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _medicineService = MedicineService.instance;
  final _searchController = TextEditingController();

  List<MedicineSummary> _allMedicines = [];
  List<MedicineSummary> _filteredMedicines = [];
  List<_GroupInfo> _availableGroups = [];
  String? _selectedGroup;
  bool _showOnlyActive = true;
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showSearch = false;

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
      final medicines =
          await _medicineService.getMedicinesByResident(widget.residentId);

      // Extract groups with active/total counts
      final groupStats = <String, Map<String, int>>{};
      for (final med in medicines) {
        final groupName = med.displayGroup;
        if (groupName.isNotEmpty && groupName != 'ไม่ระบุประเภท') {
          groupStats.putIfAbsent(groupName, () => {'active': 0, 'total': 0});
          groupStats[groupName]!['total'] =
              groupStats[groupName]!['total']! + 1;
          if (med.isActive) {
            groupStats[groupName]!['active'] =
                groupStats[groupName]!['active']! + 1;
          }
        }
      }

      // Convert to list and sort by active count (descending)
      final groupList = groupStats.entries
          .map((e) => _GroupInfo(
                name: e.key,
                activeCount: e.value['active']!,
                totalCount: e.value['total']!,
              ))
          .toList();

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

    // Filter by group
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
        return name.contains(query) ||
            brand.contains(query) ||
            group.contains(query);
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

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        _searchQuery = '';
        _applyFilters();
      }
    });
  }

  int get _filterCount {
    int count = 0;
    if (_selectedGroup != null) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _selectedGroup = null;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: _MedicineFilterDrawer(
        availableGroups: _availableGroups,
        selectedGroup: _selectedGroup,
        showOnlyActive: _showOnlyActive,
        onGroupSelected: _onGroupSelected,
        onClearFilters: _clearFilters,
        filterCount: _filterCount,
      ),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _showSearch
            ? SearchField(
                controller: _searchController,
                hintText: 'ค้นหายา...',
                isDense: true,
                autofocus: true,
                onChanged: _onSearchChanged,
                onClear: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.residentName,
                    style: AppTypography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'รายการยา',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
        actions: [
          // Search toggle
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close : Iconsax.search_normal,
              color: _showSearch ? AppColors.error : AppColors.textPrimary,
            ),
            onPressed: _toggleSearch,
          ),
          // Filter button
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                IconButton(
                  icon: Icon(Iconsax.filter, color: AppColors.textPrimary),
                  onPressed: () {
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                ),
                if (_filterCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$_filterCount',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Toggle to medicine photos
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Material(
              color: AppColors.accent1,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MedicinePhotosScreen(
                        residentId: widget.residentId,
                        residentName: widget.residentName,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: Icon(
                    Iconsax.image,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Toggle & count row
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
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

          // Medicine list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadMedicines,
              color: AppColors.primary,
              child: _buildMedicineList(),
            ),
          ),
        ],
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
            Image.asset(
              'assets/images/not_found.webp',
              width: 200,
              height: 200,
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
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedGroup = null;
                  });
                  _applyFilters();
                },
                icon: Icon(Iconsax.trash, size: 18),
                label: const Text('ล้างตัวกรอง'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
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

/// Filter drawer สำหรับหน้ารายการยา
class _MedicineFilterDrawer extends StatelessWidget {
  final List<_GroupInfo> availableGroups;
  final String? selectedGroup;
  final bool showOnlyActive;
  final ValueChanged<String?> onGroupSelected;
  final VoidCallback onClearFilters;
  final int filterCount;

  const _MedicineFilterDrawer({
    required this.availableGroups,
    required this.selectedGroup,
    required this.showOnlyActive,
    required this.onGroupSelected,
    required this.onClearFilters,
    required this.filterCount,
  });

  @override
  Widget build(BuildContext context) {
    return FilterDrawerShell(
      title: 'ตัวกรอง',
      filterCount: filterCount,
      onClear: filterCount > 0 ? onClearFilters : null,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Section
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Text(
                    'ประเภทยา',
                    style: AppTypography.title.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  if (selectedGroup != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => onGroupSelected(null),
                      child: Text(
                        'ล้าง',
                        style: AppTypography.body.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (availableGroups.isEmpty)
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'ไม่พบประเภทยา',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableGroups.map((group) {
                    final isSelected = selectedGroup == group.name;
                    final isDimmed = !group.hasActiveItems && showOnlyActive;
                    return GestureDetector(
                      onTap: () =>
                          onGroupSelected(isSelected ? null : group.name),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent1
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : isDimmed
                                    ? AppColors.inputBorder
                                        .withValues(alpha: 0.5)
                                    : AppColors.inputBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              Icon(
                                Iconsax.tick_circle,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4),
                            ],
                            Text(
                              group.name,
                              style: AppTypography.body.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : isDimmed
                                        ? AppColors.textPrimary
                                            .withValues(alpha: 0.5)
                                        : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Bottom padding
            AppSpacing.verticalGapLg,
          ],
        ),
      ),
    );
  }
}
