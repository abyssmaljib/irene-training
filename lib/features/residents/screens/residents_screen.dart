import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../home/models/zone.dart';
import '../../home/services/zone_service.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/med_completion_status.dart';
import '../models/report_completion_status.dart';
import '../services/med_completion_service.dart';
import '../services/report_completion_service.dart';
import '../widgets/residents_filter_drawer.dart';
import 'resident_detail_screen.dart';
import '../../../core/widgets/tags_badges.dart';

/// หน้าคนไข้ - Residents
/// แสดงรายชื่อคนไข้ พร้อม action จัดยา/รายงาน
class ResidentsScreen extends StatefulWidget {
  const ResidentsScreen({super.key});

  @override
  State<ResidentsScreen> createState() => _ResidentsScreenState();
}

/// Selection mode types
enum SelectionMode {
  none,
  medicine, // จัดยา
  report, // เขียนรายงาน
}

class _ResidentsScreenState extends State<ResidentsScreen> {
  final _zoneService = ZoneService();
  final _medCompletionService = MedCompletionService();
  final _reportCompletionService = ReportCompletionService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Zone data
  List<Zone> _zones = [];
  Set<int> _selectedZoneIds = {};
  Set<SpatialStatus> _selectedSpatialStatuses = {};

  // Resident data
  List<_ResidentItem> _residents = [];
  bool _isLoadingResidents = true;

  // Med completion status map (residentId -> status)
  Map<int, MedCompletionStatus> _medStatusMap = {};

  // Report completion status map (residentId -> status)
  Map<int, ReportCompletionStatus> _reportStatusMap = {};

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Selection mode state
  SelectionMode _selectionMode = SelectionMode.none;
  final Set<int> _selectedResidentIds = {};

  // Scroll state for hiding action buttons
  final ScrollController _scrollController = ScrollController();
  bool _showActionButtons = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    if (currentOffset > _lastScrollOffset && currentOffset > 50) {
      // Scrolling down - hide
      if (_showActionButtons) {
        setState(() => _showActionButtons = false);
      }
    } else if (currentOffset < _lastScrollOffset) {
      // Scrolling up - show
      if (!_showActionButtons) {
        setState(() => _showActionButtons = true);
      }
    }
    _lastScrollOffset = currentOffset;
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadZones(),
      _loadResidents(),
      _loadMedCompletionStatus(),
      _loadReportCompletionStatus(),
    ]);
  }

  Future<void> _loadReportCompletionStatus() async {
    try {
      final statusMap = await _reportCompletionService
          .getReportCompletionStatusMap();
      if (mounted) {
        setState(() {
          _reportStatusMap = statusMap;
        });
      }
    } catch (e) {
      debugPrint('Load report completion status error: $e');
    }
  }

  Future<void> _loadMedCompletionStatus() async {
    try {
      // ดึงสถานะจัดยาตาม logic:
      // - ก่อน 21:00 → ดูวันนี้ (ยาที่จัดเมื่อคืน สำหรับเสิร์ฟวันนี้)
      // - หลัง 21:00 → ดูวันพรุ่งนี้ (ยาที่กำลังจัดสำหรับเสิร์ฟพรุ่งนี้)
      final targetDate = _medCompletionService.getTargetDate();
      final statusMap = await _medCompletionService.getMedCompletionStatusMap(
        checkDate: targetDate,
      );
      if (mounted) {
        setState(() {
          _medStatusMap = statusMap;
        });
      }
    } catch (e) {
      debugPrint('Load med completion status error: $e');
    }
  }

  Future<void> _loadZones() async {
    final zones = await _zoneService.getZones();
    if (mounted) {
      setState(() {
        _zones = zones;
      });
    }
  }

  Future<void> _loadResidents() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoadingResidents = false);
        return;
      }

      // ดึง nursinghome_id ของ user
      final userInfo = await Supabase.instance.client
          .from('user_info')
          .select('nursinghome_id')
          .eq('id', user.id)
          .maybeSingle();

      final nursinghomeId = userInfo?['nursinghome_id'] as int?;
      if (nursinghomeId == null) {
        setState(() => _isLoadingResidents = false);
        return;
      }

      // ดึง residents จาก database
      final response = await Supabase.instance.client
          .from('residents')
          .select('''
            id,
            i_Name_Surname,
            i_gender,
            i_DOB,
            s_zone,
            s_status,
            i_picture_url,
            s_special_status,
            nursinghome_zone(id, zone)
          ''')
          .eq('nursinghome_id', nursinghomeId)
          .eq('s_status', 'Stay')
          .order('i_Name_Surname');

      if (mounted) {
        setState(() {
          _residents = (response as List).map((json) {
            final zoneData = json['nursinghome_zone'] as Map<String, dynamic>?;

            // คำนวณอายุจาก i_DOB
            int? age;
            final dobStr = json['i_DOB'] as String?;
            if (dobStr != null) {
              try {
                final dob = DateTime.parse(dobStr);
                final now = DateTime.now();
                age = now.year - dob.year;
                if (now.month < dob.month ||
                    (now.month == dob.month && now.day < dob.day)) {
                  age--;
                }
              } catch (_) {}
            }

            final residentId = json['id'] as int;
            return _ResidentItem(
              id: residentId,
              name: json['i_Name_Surname'] as String? ?? '-',
              gender: json['i_gender'] as String?,
              age: age,
              zoneId: zoneData?['id'] as int? ?? json['s_zone'] as int? ?? 0,
              zoneName: zoneData?['zone'] as String? ?? '-',
              imageUrl: json['i_picture_url'] as String?,
              spatialStatus: json['s_special_status'] as String?,
            );
          }).toList();
          _isLoadingResidents = false;
        });
      }
    } catch (e) {
      debugPrint('Load residents error: $e');
      if (mounted) {
        setState(() => _isLoadingResidents = false);
      }
    }
  }

  List<_ResidentItem> get _filteredResidents {
    var list = _residents;

    if (_searchQuery.isNotEmpty) {
      list = list
          .where(
            (r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    if (_selectedZoneIds.isNotEmpty) {
      list = list.where((r) => _selectedZoneIds.contains(r.zoneId)).toList();
    }

    if (_selectedSpatialStatuses.isNotEmpty) {
      list = list.where((r) {
        final status = SpatialStatusExtension.fromString(r.spatialStatus);
        return _selectedSpatialStatuses.contains(status);
      }).toList();
    }

    return list;
  }

  Map<String, List<_ResidentItem>> get _groupedResidents {
    final map = <String, List<_ResidentItem>>{};
    for (final resident in _filteredResidents) {
      map.putIfAbsent(resident.zoneName, () => []);
      map[resident.zoneName]!.add(resident);
    }
    // เรียง keys (zone names) ตามตัวอักษร
    final sortedKeys = map.keys.toList()..sort();
    return {for (final key in sortedKeys) key: map[key]!};
  }

  int get _totalCount => _filteredResidents.length;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _selectedZoneIds.isNotEmpty ||
      _selectedSpatialStatuses.isNotEmpty ||
      _searchQuery.isNotEmpty;

  int get _activeFilterCount {
    int count = _selectedZoneIds.length;
    count += _selectedSpatialStatuses.length;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  void _openFilterDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: ResidentsFilterDrawer(
        zones: _zones,
        selectedZoneIds: _selectedZoneIds,
        searchQuery: _searchQuery,
        selectedSpatialStatuses: _selectedSpatialStatuses,
        onZoneSelectionChanged: (zones) {
          setState(() {
            _selectedZoneIds = zones;
          });
        },
        onSearchChanged: (query) {
          setState(() {
            _searchQuery = query;
            _searchController.text = query;
          });
        },
        onSpatialStatusChanged: (statuses) {
          setState(() {
            _selectedSpatialStatuses = statuses;
          });
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // IreneAppBar
            IreneAppBar(
              title: 'รายชื่อผู้พัก',
              titleBadge: '$_totalCount',
              showFilterButton: true,
              isFilterActive: _hasActiveFilters,
              filterCount: _activeFilterCount,
              onFilterTap: _openFilterDrawer,
              onProfileTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),

            // Action buttons with animation
            SliverToBoxAdapter(
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                height: _showActionButtons ? null : 0,
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: 200),
                  opacity: _showActionButtons ? 1.0 : 0.0,
                  child: Container(
                    color: AppColors.surface,
                    child: Column(
                      children: [
                        // Action buttons
                        _buildActionButtons(),

                        // Active filter chips (show when filters are active)
                        if (_hasActiveFilters) _buildActiveFilterChips(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Resident list
            SliverFillRemaining(child: _buildResidentList()),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            // Zone chips
            ..._selectedZoneIds.map((zoneId) {
              final zone = _zones.firstWhere(
                (z) => z.id == zoneId,
                orElse: () => Zone(
                  id: zoneId,
                  nursinghomeId: 0,
                  name: '-',
                  residentCount: 0,
                ),
              );
              return Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: _buildFilterChip('🏠 ${zone.name}', () {
                  setState(() {
                    _selectedZoneIds.remove(zoneId);
                  });
                }),
              );
            }),
            // Search chip
            if (_searchQuery.isNotEmpty)
              _buildFilterChip('🔍 "$_searchQuery"', () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          AppSpacing.horizontalGapXs,
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // When in selection mode, show selection header
    if (_selectionMode != SelectionMode.none) {
      return _buildSelectionHeader();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: _buildSeparateActionButtons(),
    );
  }

  void _enterSelectionMode(SelectionMode mode) {
    setState(() {
      _selectionMode = mode;
      _selectedResidentIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = SelectionMode.none;
      _selectedResidentIds.clear();
    });
  }

  void _toggleResidentSelection(int id) {
    setState(() {
      if (_selectedResidentIds.contains(id)) {
        _selectedResidentIds.remove(id);
      } else {
        _selectedResidentIds.add(id);
      }
    });
  }

  void _selectAllResidents() {
    setState(() {
      if (_selectedResidentIds.length == _filteredResidents.length) {
        _selectedResidentIds.clear();
      } else {
        _selectedResidentIds.addAll(_filteredResidents.map((r) => r.id));
      }
    });
  }

  void _createTask() {
    final count = _selectedResidentIds.length;
    final taskType = _selectionMode == SelectionMode.medicine
        ? 'จัดยา'
        : 'เขียนรายงาน';

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('สร้าง Task $taskType สำหรับ $count คน'),
        backgroundColor: AppColors.primary,
      ),
    );

    _exitSelectionMode();
  }

  Widget _buildSelectionHeader() {
    final isAllSelected =
        _selectedResidentIds.length == _filteredResidents.length &&
        _filteredResidents.isNotEmpty;
    final taskLabel = _selectionMode == SelectionMode.medicine
        ? 'จัดยา'
        : 'เขียนรายงาน';

    // Different colors based on selection mode
    final isMedicine = _selectionMode == SelectionMode.medicine;
    final barColor = isMedicine
        ? AppColors.tagPassedText
        : AppColors.tagPendingText;
    final barBgColor = isMedicine
        ? AppColors.tagPassedBg
        : AppColors.tagPendingBg;

    return Container(
      color: barBgColor,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Close button
          GestureDetector(
            onTap: _exitSelectionMode,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Iconsax.close_circle, color: barColor, size: 22),
            ),
          ),
          AppSpacing.horizontalGapMd,

          // Selection info
          Expanded(
            child: Text(
              'เลือก$taskLabel: ${_selectedResidentIds.length} คน',
              style: AppTypography.body.copyWith(
                color: barColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Select all button
          GestureDetector(
            onTap: _selectAllResidents,
            child: Container(
              height: 36,
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isAllSelected
                    ? barColor
                    : barColor.withValues(alpha: 0.15),
                borderRadius: AppRadius.smallRadius,
              ),
              alignment: Alignment.center,
              child: Text(
                isAllSelected ? 'ยกเลิก' : 'เลือกทั้งหมด',
                style: AppTypography.bodySmall.copyWith(
                  color: isAllSelected ? AppColors.surface : barColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Create task button (only show when has selection)
          if (_selectedResidentIds.isNotEmpty) ...[
            AppSpacing.horizontalGapSm,
            GestureDetector(
              onTap: _createTask,
              child: Container(
                height: 36,
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: AppRadius.smallRadius,
                ),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Icon(
                      isMedicine ? Iconsax.add_square : Iconsax.edit_2,
                      color: AppColors.surface,
                      size: 18,
                    ),
                    AppSpacing.horizontalGapXs,
                    Text(
                      'สร้าง (${_selectedResidentIds.length})',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color selectedBgColor,
    required Color selectedContentColor,
    required VoidCallback onTap,
  }) {
    final bgColor = isSelected ? selectedBgColor : Colors.transparent;
    final contentColor = isSelected
        ? selectedContentColor
        : AppColors.secondaryText;
    final borderColor = isSelected ? selectedContentColor : AppColors.alternate;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: contentColor),
            AppSpacing.horizontalGapXs,
            Text(
              label,
              style: AppTypography.buttonSmall.copyWith(color: contentColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeparateActionButtons() {
    return Row(
      children: [
        // จัดยา button
        _buildActionButton(
          icon: Iconsax.add,
          label: 'จัดยา',
          isSelected: _selectionMode == SelectionMode.medicine,
          selectedBgColor: AppColors.tagPassedBg,
          selectedContentColor: AppColors.tagPassedText,
          onTap: () => _enterSelectionMode(SelectionMode.medicine),
        ),
        AppSpacing.horizontalGapSm,
        // เขียนรายงาน button
        _buildActionButton(
          icon: Iconsax.add,
          label: 'เขียนรายงาน',
          isSelected: _selectionMode == SelectionMode.report,
          selectedBgColor: AppColors.tagPendingBg,
          selectedContentColor: AppColors.tagPendingText,
          onTap: () => _enterSelectionMode(SelectionMode.report),
        ),
      ],
    );
  }

  Widget _buildResidentList() {
    if (_isLoadingResidents) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_residents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.user_remove, size: 48, color: AppColors.secondaryText),
            AppSpacing.verticalGapMd,
            Text(
              'ไม่พบรายชื่อผู้พัก',
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    final grouped = _groupedResidents;

    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.search_normal,
              size: 48,
              color: AppColors.secondaryText,
            ),
            AppSpacing.verticalGapMd,
            Text(
              'ไม่พบผลการค้นหา',
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(top: AppSpacing.sm),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final zoneName = grouped.keys.elementAt(index);
        final residents = grouped[zoneName]!;

        return _buildSection(zoneName, residents);
      },
    );
  }

  void _toggleZoneSelection(List<_ResidentItem> residents) {
    setState(() {
      final residentIds = residents.map((r) => r.id).toSet();
      final allSelected = residentIds.every(
        (id) => _selectedResidentIds.contains(id),
      );

      if (allSelected) {
        // ยกเลิกเลือกทั้ง zone
        _selectedResidentIds.removeAll(residentIds);
      } else {
        // เลือกทั้ง zone
        _selectedResidentIds.addAll(residentIds);
      }
    });
  }

  Widget _buildSection(String title, List<_ResidentItem> residents) {
    final isInSelectionMode = _selectionMode != SelectionMode.none;
    final residentIds = residents.map((r) => r.id).toSet();
    final allSelected =
        residentIds.isNotEmpty &&
        residentIds.every((id) => _selectedResidentIds.contains(id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header - transparent background
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Text(
                title,
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.primary,
                ),
              ),
              Spacer(),
              // ปุ่มเลือกทั้งหมดใน zone (แสดงเฉพาะตอน selection mode)
              if (isInSelectionMode) ...[
                GestureDetector(
                  onTap: () => _toggleZoneSelection(residents),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: allSelected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: allSelected
                            ? AppColors.primary
                            : AppColors.alternate,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          allSelected
                              ? Iconsax.close_square
                              : Iconsax.tick_square,
                          size: 16,
                          color: allSelected
                              ? AppColors.primary
                              : AppColors.secondaryText,
                        ),
                        AppSpacing.horizontalGapXs,
                        Text(
                          allSelected ? 'ยกเลิก' : 'เลือกทั้งหมด',
                          style: AppTypography.caption.copyWith(
                            color: allSelected
                                ? AppColors.primary
                                : AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AppSpacing.horizontalGapSm,
              ],
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${residents.length}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Residents - wrapped in single container with shadow
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: AppShadows.cardShadow,
          ),
          child: Column(
            children: residents.asMap().entries.map((entry) {
              final index = entry.key;
              final resident = entry.value;
              final isLast = index == residents.length - 1;
              return _buildResidentCard(resident, showDivider: !isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildResidentCard(_ResidentItem resident, {bool showDivider = true}) {
    final isInSelectionMode = _selectionMode != SelectionMode.none;
    final isSelected = _selectedResidentIds.contains(resident.id);

    // ถ้าอยู่ใน selection mode ไม่ให้ swipe
    if (isInSelectionMode) {
      return _buildResidentCardContent(
        resident,
        isSelected: isSelected,
        isInSelectionMode: true,
        showDivider: showDivider,
      );
    }

    // ใช้ swipe ได้เมื่อไม่อยู่ใน selection mode
    return ClipRect(
      child: Dismissible(
        key: Key('resident_${resident.id}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Swipe ซ้าย → จัดยา
            _onSwipeMedicine(resident);
          } else if (direction == DismissDirection.startToEnd) {
            // Swipe ขวา → สร้างรายงาน
            _onSwipeReport(resident);
          }
          return false; // ไม่ลบ item
        },
        background: _buildSwipeBackground(
          alignment: Alignment.centerLeft,
          color: AppColors.tagPendingBg,
          icon: Iconsax.edit_2,
          iconColor: AppColors.tagPendingText,
          label: 'สร้างรายงาน',
        ),
        secondaryBackground: _buildSwipeBackground(
          alignment: Alignment.centerRight,
          color: AppColors.tagPassedBg,
          icon: Iconsax.add_square,
          iconColor: AppColors.tagPassedText,
          label: 'จัดยา',
        ),
        child: _buildResidentCardContent(
          resident,
          isSelected: false,
          isInSelectionMode: false,
          showDivider: showDivider,
        ),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      color: color,
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerRight
            ? [
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.horizontalGapSm,
                Icon(icon, color: iconColor, size: 24),
              ]
            : [
                Icon(icon, color: iconColor, size: 24),
                AppSpacing.horizontalGapSm,
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
      ),
    );
  }

  void _onSwipeMedicine(_ResidentItem resident) {
    // เลือก resident แล้วเข้า selection mode จัดยา
    setState(() {
      _selectionMode = SelectionMode.medicine;
      _selectedResidentIds.clear();
      _selectedResidentIds.add(resident.id);
    });
  }

  void _onSwipeReport(_ResidentItem resident) {
    // เลือก resident แล้วเข้า selection mode รายงาน
    setState(() {
      _selectionMode = SelectionMode.report;
      _selectedResidentIds.clear();
      _selectedResidentIds.add(resident.id);
    });
  }

  Widget _buildResidentCardContent(
    _ResidentItem resident, {
    required bool isSelected,
    required bool isInSelectionMode,
    required bool showDivider,
  }) {
    return GestureDetector(
      onTap: () {
        if (isInSelectionMode) {
          _toggleResidentSelection(resident.id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResidentDetailScreen(residentId: resident.id),
            ),
          );
        }
      },
      child: Container(
        color: isSelected ? AppColors.accent1 : AppColors.surface,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  _buildAvatar(resident),
                  AppSpacing.horizontalGapMd,

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Text(
                          resident.name,
                          style: AppTypography.title.copyWith(
                            color: AppColors.primaryText,
                          ),
                        ),

                        // Gender & Age - skip if both are empty
                        if ((resident.gender != null &&
                                resident.gender!.isNotEmpty) ||
                            resident.age != null)
                          Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                if (resident.gender != null &&
                                    resident.gender!.isNotEmpty)
                                  Text(
                                    resident.gender!,
                                    style: AppTypography.body.copyWith(
                                      color: resident.gender == 'หญิง'
                                          ? AppColors.tertiary
                                          : AppColors.secondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (resident.gender != null &&
                                    resident.gender!.isNotEmpty &&
                                    resident.age != null)
                                  Text(
                                    ', ',
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                if (resident.age != null)
                                  Text(
                                    '${resident.age} ปี',
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        // Status badges - ใช้ข้อมูลจริงจาก _medStatusMap และ _reportStatusMap
                        _buildStatusBadgesRow(resident.id),
                      ],
                    ),
                  ),

                  // Checkbox (only in selection mode) - ด้านขวา
                  if (isInSelectionMode)
                    GestureDetector(
                      onTap: () => _toggleResidentSelection(resident.id),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: EdgeInsets.only(left: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.alternate,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: AppColors.surface,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            // Divider - อยู่นอก padding เพื่อให้ padding บน-ล่างสมดุล
            if (showDivider)
              Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.md + 48 + AppSpacing.md,
                ),
                child: Container(height: 1, color: AppColors.background),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(_ResidentItem resident) {
    final avatarWidget = resident.imageUrl != null && resident.imageUrl!.isNotEmpty
        ? Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: resident.gender == 'หญิง'
                    ? AppColors.tertiary
                    : AppColors.secondary,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Image.network(
                resident.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => _buildDefaultAvatar(resident),
              ),
            ),
          )
        : _buildDefaultAvatar(resident);

    // ถ้าไม่มี spatial status ให้แสดง avatar เฉยๆ
    if (resident.spatialStatus == null || resident.spatialStatus!.isEmpty) {
      return avatarWidget;
    }

    // ใส่ badge มุมขวาบน
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarWidget,
        Positioned(
          top: -2,
          right: -2,
          child: SpatialStatusBadge.fromString(resident.spatialStatus),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar(_ResidentItem resident) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.accent1,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          resident.name.isNotEmpty ? resident.name[0] : '?',
          style: AppTypography.title.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }

  /// สร้าง badge สำหรับสถานะจัดยา (พร้อม icon check ถ้าจัดเรียบร้อย)
  Widget _buildMedBadge(
    String text,
    Color bgColor,
    Color textColor,
    bool showCheck,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCheck) ...[
            Icon(
              Icons.check_circle_outline,
              size: 14,
              color: textColor,
            ),
            SizedBox(width: 4),
          ],
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// สร้าง badges ทั้งหมดในบรรทัดเดียว (จัดยา + รายงาน)
  Widget _buildStatusBadgesRow(int residentId) {
    final medStatus = _medStatusMap[residentId];
    final reportStatus = _reportStatusMap[residentId];

    final List<Widget> badges = [];

    // Badge จัดยา
    if (medStatus != null && !medStatus.hasNoMedication) {
      final String text;
      final Color bgColor;
      final Color textColor;
      final bool showCheck;

      if (medStatus.isCompleted) {
        text = 'จัดยาเรียบร้อย ${medStatus.completionFraction}';
        bgColor = AppColors.tagPassedBg;
        textColor = AppColors.tagPassedText;
        showCheck = true;
      } else if (medStatus.isPartial) {
        text = 'จัดยาบางส่วน ${medStatus.completionFraction}';
        bgColor = AppColors.tagPendingBg;
        textColor = AppColors.tagPendingText;
        showCheck = false;
      } else {
        text = 'รอจัดยา ${medStatus.completionFraction}';
        bgColor = AppColors.background;
        textColor = AppColors.secondaryText;
        showCheck = false;
      }

      badges.add(_buildMedBadge(text, bgColor, textColor, showCheck));
    }

    // Badge รายงาน
    if (reportStatus != null) {
      // เวรดึก - สีม่วงพาสเทล
      badges.add(
        _buildShiftBadge(
          emoji: '\ud83c\udf19', // 🌙
          label: 'เวรดึก',
          isCompleted: reportStatus.hasNightReport,
          completedBgColor: const Color(0xFFEDE7F6), // ม่วงพาสเทล bg
          completedTextColor: const Color(0xFF7C4DFF), // ม่วง text
        ),
      );

      // เวรเช้า - สีส้มพาสเทล
      badges.add(
        _buildShiftBadge(
          emoji: '\u2600\ufe0f', // ☀️
          label: 'เวรเช้า',
          isCompleted: reportStatus.hasMorningReport,
          completedBgColor: const Color(0xFFFFF3E0), // ส้มพาสเทล bg
          completedTextColor: const Color(0xFFFF9800), // ส้ม text
        ),
      );
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 4, children: badges),
    );
  }

  /// สร้าง badge สำหรับแต่ละ shift
  Widget _buildShiftBadge({
    required String emoji,
    required String label,
    required bool isCompleted,
    required Color completedBgColor,
    required Color completedTextColor,
  }) {
    final bgColor = isCompleted ? completedBgColor : AppColors.background;
    final textColor = isCompleted ? completedTextColor : AppColors.secondaryText;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCompleted) ...[
            Icon(
              Icons.check_circle_outline,
              size: 14,
              color: textColor,
            ),
            SizedBox(width: 4),
          ],
          Text(
            '$label$emoji',
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResidentItem {
  final int id;
  final String name;
  final String? gender;
  final int? age;
  final int zoneId;
  final String zoneName;
  final String? imageUrl;
  final String? spatialStatus;

  _ResidentItem({
    required this.id,
    required this.name,
    this.gender,
    this.age,
    required this.zoneId,
    required this.zoneName,
    this.imageUrl,
    this.spatialStatus,
  });
}
