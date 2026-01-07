import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/input_fields.dart';
import '../../home/models/zone.dart';
import '../../home/services/zone_service.dart';
import '../../medicine/screens/medicine_photos_screen.dart';
import '../../medicine/services/medicine_service.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/report_completion_status.dart';
import '../services/report_completion_service.dart';
import '../widgets/residents_filter_drawer.dart';
import 'resident_detail_screen.dart';
import 'create_vital_sign_screen.dart';
import '../../../core/widgets/tags_badges.dart';

/// หน้าคนไข้ - Residents
/// แสดงรายชื่อคนไข้ พร้อม swipe action จัดยา/รายงาน
class ResidentsScreen extends StatefulWidget {
  const ResidentsScreen({super.key});

  @override
  State<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends State<ResidentsScreen> {
  final _zoneService = ZoneService();
  final _medicineService = MedicineService.instance;
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
  Map<int, ResidentMedSummary> _medStatusMap = {};

  // Report completion status map (residentId -> status)
  Map<int, ReportCompletionStatus> _reportStatusMap = {};

  // Loading state for med status refresh (ใช้เมื่อกลับมาจากหน้าจัดยา)
  bool _isRefreshingMedStatus = false;

  String _searchQuery = '';
  bool _isSearchEnabled = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Scroll controller
  final ScrollController _scrollController = ScrollController();

  // Cache สำหรับ filtered/grouped results (ลด rebuild overhead)
  List<_ResidentItem>? _cachedFiltered;
  List<String>? _cachedZoneKeys;
  Map<String, List<_ResidentItem>>? _cachedGrouped;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Invalidate cache เมื่อ filter หรือ data เปลี่ยน
  void _invalidateCache() {
    _cachedFiltered = null;
    _cachedZoneKeys = null;
    _cachedGrouped = null;
  }

  Future<void> _loadData() async {
    // โหลด zones และ residents พร้อมกัน
    await Future.wait([
      _loadZones(),
      _loadResidents(),
    ]);

    // โหลด med status และ report status หลังจากมี residents แล้ว
    await Future.wait([
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
    // รอให้โหลด residents เสร็จก่อน
    if (_residents.isEmpty) return;

    if (mounted) {
      setState(() => _isRefreshingMedStatus = true);
    }

    try {
      // ใช้ logic เดียวกับ MedCompletionService สำหรับหา target date
      // หลัง 21:00 = ดูวันพรุ่งนี้ (กำลังจัดยาสำหรับพรุ่งนี้)
      final now = DateTime.now();
      final DateTime targetDate;
      if (now.hour >= 21) {
        targetDate = DateTime(now.year, now.month, now.day + 1);
      } else {
        targetDate = DateTime(now.year, now.month, now.day);
      }

      // ดึงสถานะการจัดยาของ residents ทั้งหมด
      final residentIds = _residents.map((r) => r.id).toList();
      final statusMap = await _medicineService.getMedCompletionStatusForResidents(
        residentIds,
        targetDate,
      );

      if (mounted) {
        setState(() {
          _medStatusMap = statusMap;
          _isRefreshingMedStatus = false;
        });
      }
    } catch (e) {
      debugPrint('Load med completion status error: $e');
      if (mounted) {
        setState(() => _isRefreshingMedStatus = false);
      }
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
      final userId = UserService().effectiveUserId;
      if (userId == null) {
        setState(() => _isLoadingResidents = false);
        return;
      }

      final userInfo = await Supabase.instance.client
          .from('user_info')
          .select('nursinghome_id')
          .eq('id', userId)
          .maybeSingle();

      final nursinghomeId = userInfo?['nursinghome_id'] as int?;
      if (nursinghomeId == null) {
        setState(() => _isLoadingResidents = false);
        return;
      }

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
          _invalidateCache();
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
    if (_cachedFiltered != null) return _cachedFiltered!;
    _cachedFiltered = _computeFilteredResidents();
    return _cachedFiltered!;
  }

  List<_ResidentItem> _computeFilteredResidents() {
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
    if (_cachedGrouped != null) return _cachedGrouped!;
    _cachedGrouped = _computeGroupedResidents();
    _cachedZoneKeys = _cachedGrouped!.keys.toList();
    return _cachedGrouped!;
  }

  Map<String, List<_ResidentItem>> _computeGroupedResidents() {
    final map = <String, List<_ResidentItem>>{};
    for (final resident in _filteredResidents) {
      map.putIfAbsent(resident.zoneName, () => []);
      map[resident.zoneName]!.add(resident);
    }
    final sortedKeys = map.keys.toList()..sort();
    return {for (final key in sortedKeys) key: map[key]!};
  }

  int get _totalCount => _filteredResidents.length;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Filter chips แสดงเฉพาะ zone และ spatial status (search มี search bar แยก)
  bool get _hasActiveFilters =>
      _selectedZoneIds.isNotEmpty ||
      _selectedSpatialStatuses.isNotEmpty;

  int get _activeFilterCount {
    return _selectedZoneIds.length + _selectedSpatialStatuses.length;
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
        selectedSpatialStatuses: _selectedSpatialStatuses,
        isSearchEnabled: _isSearchEnabled,
        onZoneSelectionChanged: (zones) {
          setState(() {
            _selectedZoneIds = zones;
            _invalidateCache();
          });
        },
        onSpatialStatusChanged: (statuses) {
          setState(() {
            _selectedSpatialStatuses = statuses;
            _invalidateCache();
          });
        },
        onSearchToggle: (enabled) {
          setState(() {
            _isSearchEnabled = enabled;
            if (!enabled) {
              _searchQuery = '';
              _searchController.clear();
              _invalidateCache();
            }
          });
          if (enabled) {
            // Request focus after drawer closes and widget rebuilds
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _searchFocusNode.requestFocus();
            });
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          controller: _scrollController,
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

            // Search bar (show when enabled)
            if (_isSearchEnabled)
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surface,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: _buildSearchBar(),
                ),
              ),

            // Active filter chips (show when filters are active)
            if (_hasActiveFilters)
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surface,
                  child: _buildActiveFilterChips(),
                ),
              ),

            // Resident list
            ..._buildResidentSlivers(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SearchField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hintText: 'ค้นหาชื่อผู้พัก...',
      isDense: true,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
          _invalidateCache();
        });
      },
      onClear: () {
        setState(() {
          _searchQuery = '';
          _invalidateCache();
        });
      },
    );
  }

  Widget _buildActiveFilterChips() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                child: _buildFilterChip(zone.name, () {
                  setState(() {
                    _selectedZoneIds.remove(zoneId);
                    _invalidateCache();
                  });
                }),
              );
            }),
            // Spatial status chips
            ..._selectedSpatialStatuses.map((status) {
              return Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: _buildFilterChip(status.label, () {
                  setState(() {
                    _selectedSpatialStatuses.remove(status);
                    _invalidateCache();
                  });
                }),
              );
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
            child: HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, size: AppIconSize.sm, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  /// สร้าง Sliver widgets สำหรับแสดงรายชื่อผู้พัก
  List<Widget> _buildResidentSlivers() {
    if (_isLoadingResidents) {
      return [
        SliverFillRemaining(
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ];
    }

    if (_residents.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/not_found.webp',
                  width: 240,
                  height: 240,
                ),
                AppSpacing.verticalGapMd,
                Text(
                  'ไม่พบรายชื่อผู้พัก',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final grouped = _groupedResidents;

    if (grouped.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/not_found.webp',
                  width: 240,
                  height: 240,
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
          ),
        ),
      ];
    }

    final zoneKeys = _cachedZoneKeys ?? grouped.keys.toList();

    return [
      SliverPadding(
        padding: EdgeInsets.only(top: AppSpacing.sm),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final zoneName = zoneKeys[index];
              final residents = grouped[zoneName]!;
              return _buildSection(zoneName, residents);
            },
            childCount: grouped.length,
          ),
        ),
      ),
      SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xl)),
    ];
  }

  Widget _buildSection(String title, List<_ResidentItem> residents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
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

        // Residents
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
    return ClipRect(
      child: Dismissible(
        key: Key('resident_${resident.id}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            _onSwipeMedicine(resident);
          } else if (direction == DismissDirection.startToEnd) {
            _onSwipeReport(resident);
          }
          return false;
        },
        background: _buildSwipeBackground(
          alignment: Alignment.centerLeft,
          color: AppColors.tagPendingBg,
          icon: HugeIcons.strokeRoundedEdit02,
          iconColor: AppColors.tagPendingText,
          label: 'สร้างรายงาน',
        ),
        secondaryBackground: _buildSwipeBackground(
          alignment: Alignment.centerRight,
          color: AppColors.tagPassedBg,
          icon: HugeIcons.strokeRoundedMedicine01,
          iconColor: AppColors.tagPassedText,
          label: 'จัดยา',
        ),
        child: _buildResidentCardContent(resident, showDivider: showDivider),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required dynamic icon,
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
                HugeIcon(icon: icon, color: iconColor, size: AppIconSize.xl),
              ]
            : [
                HugeIcon(icon: icon, color: iconColor, size: AppIconSize.xl),
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

  void _onSwipeMedicine(_ResidentItem resident) async {
    // ไปหน้ารูปตัวอย่างยาของ resident โดยตรง
    final hasDataChanged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicinePhotosScreen(
          residentId: resident.id,
          residentName: resident.name,
        ),
      ),
    );

    // ถ้ามีการเปลี่ยนแปลงข้อมูลยา ให้ refresh med status
    if (hasDataChanged == true && mounted) {
      _loadMedCompletionStatus();
    }
  }

  void _onSwipeReport(_ResidentItem resident) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateVitalSignScreen(
          residentId: resident.id,
          residentName: resident.name,
        ),
      ),
    );
  }

  Widget _buildResidentCardContent(
    _ResidentItem resident, {
    required bool showDivider,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResidentDetailScreen(residentId: resident.id),
          ),
        );
      },
      child: Container(
        color: AppColors.surface,
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
                          'คุณ${resident.name}',
                          style: AppTypography.title.copyWith(
                            color: AppColors.primaryText,
                          ),
                        ),

                        // Gender & Age
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

                        // Status badges
                        _buildStatusBadgesRow(resident.id),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Divider
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
              child: CachedNetworkImage(
                imageUrl: resident.imageUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 96,
                memCacheHeight: 96,
                placeholder: (_, _) => _buildDefaultAvatar(resident),
                errorWidget: (_, _, _) => _buildDefaultAvatar(resident),
              ),
            ),
          )
        : _buildDefaultAvatar(resident);

    if (resident.spatialStatus == null || resident.spatialStatus!.isEmpty) {
      return avatarWidget;
    }

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

  Widget _buildMedLoadingBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.secondaryText,
            ),
          ),
          SizedBox(width: 6),
          Text(
            'กำลังโหลด...',
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

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
            HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              size: AppIconSize.sm,
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

  Widget _buildStatusBadgesRow(int residentId) {
    final medStatus = _medStatusMap[residentId];
    final reportStatus = _reportStatusMap[residentId];

    final List<Widget> badges = [];

    // แสดง loading indicator ขณะ refresh med status
    if (_isRefreshingMedStatus) {
      badges.add(_buildMedLoadingBadge());
    } else if (medStatus != null && !medStatus.hasNoMedication) {
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

    if (reportStatus != null) {
      badges.add(
        _buildShiftBadge(
          emoji: '\ud83c\udf19',
          label: 'เวรดึก',
          isCompleted: reportStatus.hasNightReport,
          completedBgColor: const Color(0xFFEDE7F6),
          completedTextColor: const Color(0xFF7C4DFF),
        ),
      );

      badges.add(
        _buildShiftBadge(
          emoji: '\u2600\ufe0f',
          label: 'เวรเช้า',
          isCompleted: reportStatus.hasMorningReport,
          completedBgColor: const Color(0xFFFFF3E0),
          completedTextColor: const Color(0xFFFF9800),
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
            HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              size: AppIconSize.sm,
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
