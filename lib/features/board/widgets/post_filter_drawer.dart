import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/filter_drawer_shell.dart';
import '../../../core/widgets/input_fields.dart';
import '../models/post_tab.dart';

/// Filter drawer สำหรับกรอง posts (ตามชื่อคนไข้)
class PostFilterDrawer extends StatefulWidget {
  final int? selectedResidentId;
  final String? selectedResidentName;
  final List<ResidentOption> residents;
  final bool isSearchEnabled;
  final PostFilterType filterType;
  final void Function(int? residentId, String? residentName) onResidentChanged;
  final void Function(bool enabled) onSearchToggle;
  final void Function(PostFilterType filterType) onFilterTypeChanged;
  final VoidCallback onClearFilters;

  const PostFilterDrawer({
    super.key,
    this.selectedResidentId,
    this.selectedResidentName,
    this.residents = const [],
    this.isSearchEnabled = false,
    this.filterType = PostFilterType.all,
    required this.onResidentChanged,
    required this.onSearchToggle,
    required this.onFilterTypeChanged,
    required this.onClearFilters,
  });

  @override
  State<PostFilterDrawer> createState() => _PostFilterDrawerState();
}

class _PostFilterDrawerState extends State<PostFilterDrawer> {
  String _searchQuery = '';

  List<ResidentOption> get _filteredResidents {
    if (_searchQuery.isEmpty) return widget.residents;
    return widget.residents
        .where((r) =>
            r.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  bool get _hasFilters =>
      widget.selectedResidentId != null ||
      widget.filterType != PostFilterType.all;

  int get _filterCount {
    int count = 0;
    if (widget.selectedResidentId != null) count++;
    if (widget.filterType != PostFilterType.all) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return FilterDrawerShell(
      title: 'ตัวกรอง',
      filterCount: _filterCount,
      onClear: _hasFilters ? widget.onClearFilters : null,
      content: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Search toggle section
          _buildSearchToggleSection(),

          Divider(height: 1, color: AppColors.alternate),

          // View mode section (ทั้งหมด, รอรับทราบ, โพสต์ของฉัน)
          _buildViewModeSection(),

          Divider(height: 1, color: AppColors.alternate),

          // Resident filter section
          _buildResidentSection(),

          // Extra space at bottom
          SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildViewModeSection() {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedView, size: AppIconSize.md, color: AppColors.secondaryText),
              AppSpacing.horizontalGapSm,
              Text(
                'มุมมอง',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,

          // View mode options
          ...PostFilterType.values.map((type) => _buildViewModeOption(type)),
        ],
      ),
    );
  }

  Widget _buildViewModeOption(PostFilterType type) {
    final isSelected = widget.filterType == type;

    dynamic icon;
    switch (type) {
      case PostFilterType.all:
        icon = HugeIcons.strokeRoundedFileEdit;
        break;
      case PostFilterType.unacknowledged:
        icon = HugeIcons.strokeRoundedNotification02;
        break;
      case PostFilterType.myPosts:
        icon = HugeIcons.strokeRoundedUserEdit01;
        break;
    }

    return InkWell(
      onTap: () {
        widget.onFilterTypeChanged(type);
        Navigator.pop(context);
      },
      borderRadius: AppRadius.mediumRadius,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent1 : Colors.transparent,
          borderRadius: AppRadius.mediumRadius,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.alternate,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              size: AppIconSize.lg,
              color: isSelected ? AppColors.primary : AppColors.secondaryText,
            ),
            AppSpacing.horizontalGapMd,
            Expanded(
              child: Text(
                type.label,
                style: AppTypography.body.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                size: AppIconSize.lg,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchToggleSection() {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.all(AppSpacing.lg),
      child: GestureDetector(
        onTap: () => widget.onSearchToggle(true),
        child: Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.smallRadius,
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                size: AppIconSize.lg,
                color: AppColors.secondaryText,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ค้นหาโพส...',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResidentSection() {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedUser, size: AppIconSize.md, color: AppColors.secondaryText),
              AppSpacing.horizontalGapSm,
              Text(
                'ผู้พักอาศัย',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,

          // Search field (show if many residents)
          if (widget.residents.length > 5) ...[
            SearchField(
              hintText: 'ค้นหาชื่อ...',
              isDense: true,
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            AppSpacing.verticalGapMd,
          ],

          // Selected resident chip (if any)
          if (widget.selectedResidentId != null) ...[
            GestureDetector(
              onTap: () => widget.onResidentChanged(null, null),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent1,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                      size: AppIconSize.sm,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.selectedResidentName ?? 'Unknown',
                        style: AppTypography.label.copyWith(
                          color: AppColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 6),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCancelCircle,
                      size: AppIconSize.sm,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.verticalGapMd,
            Divider(height: 1, color: AppColors.alternate),
            AppSpacing.verticalGapMd,
          ],

          // Resident list
          if (_filteredResidents.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/not_found.webp',
                      width: 120,
                      height: 120,
                    ),
                    AppSpacing.verticalGapSm,
                    Text(
                      _searchQuery.isEmpty
                          ? 'ไม่มีรายชื่อผู้พักอาศัย'
                          : 'ไม่พบผลการค้นหา',
                      style: AppTypography.body.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // แสดงเป็น list tiles แบบเดิมเพราะมี avatar
            ...(_filteredResidents.map((resident) {
              final isSelected = resident.id == widget.selectedResidentId;
              return InkWell(
                onTap: () {
                  widget.onResidentChanged(resident.id, resident.name);
                  Navigator.pop(context);
                },
                borderRadius: AppRadius.mediumRadius,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent1 : Colors.transparent,
                    borderRadius: AppRadius.mediumRadius,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.alternate,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.accent1,
                        backgroundImage: resident.pictureUrl != null
                            ? NetworkImage(resident.pictureUrl!)
                            : null,
                        child: resident.pictureUrl == null
                            ? HugeIcon(icon: HugeIcons.strokeRoundedUser,
                                color: AppColors.primary, size: AppIconSize.md)
                            : null,
                      ),
                      AppSpacing.horizontalGapMd,
                      // Name & Zone
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'คุณ${resident.name}',
                              style: AppTypography.body.copyWith(
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (resident.zone != null)
                              Text(
                                resident.zone!,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.secondaryText,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Check icon
                      if (isSelected)
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                          size: AppIconSize.lg,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              );
            }).toList()),
        ],
      ),
    );
  }
}

/// Simple resident option model
class ResidentOption {
  final int id;
  final String name;
  final String? zone;
  final String? pictureUrl;

  const ResidentOption({
    required this.id,
    required this.name,
    this.zone,
    this.pictureUrl,
  });
}
