import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tags_badges.dart';
import '../../home/models/zone.dart';

/// Filter Drawer สำหรับหน้า Residents
/// UI ที่ปรับปรุงแล้ว - Clean, Minimal, Real-time filtering
class ResidentsFilterDrawer extends StatefulWidget {
  final List<Zone> zones;
  final Set<int> selectedZoneIds;
  final String searchQuery;
  final Set<SpatialStatus> selectedSpatialStatuses;
  final ValueChanged<Set<int>> onZoneSelectionChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Set<SpatialStatus>> onSpatialStatusChanged;

  const ResidentsFilterDrawer({
    super.key,
    required this.zones,
    required this.selectedZoneIds,
    required this.searchQuery,
    required this.selectedSpatialStatuses,
    required this.onZoneSelectionChanged,
    required this.onSearchChanged,
    required this.onSpatialStatusChanged,
  });

  @override
  State<ResidentsFilterDrawer> createState() => _ResidentsFilterDrawerState();
}

class _ResidentsFilterDrawerState extends State<ResidentsFilterDrawer> {
  late Set<int> _tempSelectedZoneIds;
  late Set<SpatialStatus> _tempSelectedSpatialStatuses;
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _tempSelectedZoneIds = Set.from(widget.selectedZoneIds);
    _tempSelectedSpatialStatuses = Set.from(widget.selectedSpatialStatuses);
    _searchController = TextEditingController(text: widget.searchQuery);
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleZone(int zoneId) {
    setState(() {
      if (_tempSelectedZoneIds.contains(zoneId)) {
        _tempSelectedZoneIds.remove(zoneId);
      } else {
        _tempSelectedZoneIds.add(zoneId);
      }
    });
    // Apply immediately
    widget.onZoneSelectionChanged(Set.from(_tempSelectedZoneIds));
  }

  void _selectAllZones() {
    setState(() {
      if (_tempSelectedZoneIds.length == widget.zones.length) {
        _tempSelectedZoneIds.clear();
      } else {
        _tempSelectedZoneIds = widget.zones.map((z) => z.id).toSet();
      }
    });
    // Apply immediately
    widget.onZoneSelectionChanged(Set.from(_tempSelectedZoneIds));
  }

  void _onSearchChanged(String value) {
    setState(() {});
    widget.onSearchChanged(value);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
    });
    widget.onSearchChanged('');
  }

  void _toggleSpatialStatus(SpatialStatus status) {
    setState(() {
      if (_tempSelectedSpatialStatuses.contains(status)) {
        _tempSelectedSpatialStatuses.remove(status);
      } else {
        _tempSelectedSpatialStatuses.add(status);
      }
    });
    widget.onSpatialStatusChanged(Set.from(_tempSelectedSpatialStatuses));
  }

  void _clearAll() {
    setState(() {
      _tempSelectedZoneIds.clear();
      _tempSelectedSpatialStatuses.clear();
      _searchController.clear();
    });
    widget.onZoneSelectionChanged({});
    widget.onSpatialStatusChanged({});
    widget.onSearchChanged('');
  }

  bool get _hasFilters =>
      _tempSelectedZoneIds.isNotEmpty ||
      _tempSelectedSpatialStatuses.isNotEmpty ||
      _searchController.text.isNotEmpty;

  int get _filterCount {
    int count = _tempSelectedZoneIds.length;
    count += _tempSelectedSpatialStatuses.length;
    if (_searchController.text.isNotEmpty) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final sortedZones = List<Zone>.from(widget.zones)
      ..sort((a, b) => a.name.compareTo(b.name));

    // Golden ratio width (~61.8%) with minimum 52px margin from left edge
    final screenWidth = MediaQuery.of(context).size.width;
    final goldenRatioWidth = screenWidth * 0.618;
    final maxWidth = screenWidth - 52;
    final drawerWidth = goldenRatioWidth.clamp(0.0, maxWidth);

    return Drawer(
      backgroundColor: AppColors.surface,
      width: drawerWidth,
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Content
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Search Section
                _buildSearchSection(),

                // Divider
                Divider(height: 1, color: AppColors.alternate),

                // Zone Section
                _buildZoneSection(sortedZones),

                // Divider
                Divider(height: 1, color: AppColors.alternate),

                // Spatial Status Section
                _buildSpatialStatusSection(),

                // Extra space at bottom
                SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),

          // Footer - Clear button only (shows when has filters)
          if (_hasFilters) _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.of(context).padding.top + AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          // Filter icon with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Iconsax.filter, color: AppColors.primary, size: 22),
              ),
              if (_hasFilters)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_filterCount',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.horizontalGapMd,
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ตัวกรอง',
                  style: AppTypography.heading3.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_hasFilters)
                  Text(
                    'เลือก $_filterCount รายการ',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(Iconsax.search_normal, size: 18, color: AppColors.secondaryText),
              AppSpacing.horizontalGapSm,
              Text(
                'ค้นหา',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
          // Search field
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _searchController.text.isNotEmpty
                    ? AppColors.primary
                    : AppColors.alternate,
                width: _searchController.text.isNotEmpty ? 1.5 : 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'พิมพ์ชื่อผู้พัก...',
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                ),
                prefixIcon: Icon(
                  Iconsax.search_normal,
                  color: _searchController.text.isNotEmpty
                      ? AppColors.primary
                      : AppColors.secondaryText,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: _clearSearch,
                        child: Icon(
                          Iconsax.close_circle5,
                          color: AppColors.secondaryText,
                          size: 20,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 14,
                ),
              ),
              style: AppTypography.body,
              onChanged: _onSearchChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneSection(List<Zone> sortedZones) {
    final allSelected = _tempSelectedZoneIds.length == sortedZones.length &&
        sortedZones.isNotEmpty;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(Iconsax.location, size: 18, color: AppColors.secondaryText),
              AppSpacing.horizontalGapSm,
              Text(
                'Zone',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
              Spacer(),
              // Select all button
              GestureDetector(
                onTap: _selectAllZones,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  height: 32,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: allSelected ? AppColors.accent1 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: allSelected ? AppColors.primary : AppColors.alternate,
                      width: allSelected ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    allSelected ? 'ยกเลิกทั้งหมด' : 'เลือกทั้งหมด',
                    style: AppTypography.label.copyWith(
                      color: allSelected ? AppColors.primary : AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
          // Zone chips - ใช้ design เดียวกับหน้าหลัก
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedZones.map((zone) {
              final isSelected = _tempSelectedZoneIds.contains(zone.id);
              return GestureDetector(
                onTap: () => _toggleZone(zone.id),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  height: 36,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent1 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.alternate,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        Icon(
                          Iconsax.tick_circle5,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                      ],
                      Text(
                        zone.name,
                        style: AppTypography.label.copyWith(
                          color: isSelected ? AppColors.primary : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpatialStatusSection() {
    // รายการ status ที่แสดง (ไม่รวม none)
    const statuses = [
      SpatialStatus.newResident,
      SpatialStatus.refer,
      SpatialStatus.home,
    ];

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(Iconsax.status, size: 18, color: AppColors.secondaryText),
              AppSpacing.horizontalGapSm,
              Text(
                'สถานะพิเศษ',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
          // Status chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statuses.map((status) {
              final isSelected = _tempSelectedSpatialStatuses.contains(status);
              return GestureDetector(
                onTap: () => _toggleSpatialStatus(status),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  height: 36,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent1 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.alternate,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        Icon(
                          Iconsax.tick_circle5,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                      ],
                      // Status icon
                      SpatialStatusBadge(status: status, size: 18, iconSize: 10),
                      SizedBox(width: 6),
                      Text(
                        status.label,
                        style: AppTypography.label.copyWith(
                          color: isSelected ? AppColors.primary : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      child: GestureDetector(
        onTap: _clearAll,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Iconsax.trash,
                size: 16,
                color: AppColors.error,
              ),
              SizedBox(width: 6),
              Text(
                'ล้างตัวกรอง',
                style: AppTypography.body.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
