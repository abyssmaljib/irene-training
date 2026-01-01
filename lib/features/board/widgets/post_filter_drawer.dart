import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/filter_drawer_shell.dart';

/// Filter drawer สำหรับกรอง posts (ตามชื่อคนไข้)
class PostFilterDrawer extends StatefulWidget {
  final int? selectedResidentId;
  final String? selectedResidentName;
  final List<ResidentOption> residents;
  final void Function(int? residentId, String? residentName) onResidentChanged;
  final VoidCallback onClearFilters;

  const PostFilterDrawer({
    super.key,
    this.selectedResidentId,
    this.selectedResidentName,
    this.residents = const [],
    required this.onResidentChanged,
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

  @override
  Widget build(BuildContext context) {
    return FilterDrawerShell(
      title: 'กรองโพส',
      filterCount: widget.selectedResidentId != null ? 1 : 0,
      onClear: widget.onClearFilters,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resident filter section
          Text(
            'กรองตามชื่อคนไข้',
            style: AppTypography.title,
          ),
          AppSpacing.verticalGapMd,
          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อคนไข้...',
              hintStyle:
                  AppTypography.body.copyWith(color: AppColors.secondaryText),
              prefixIcon:
                  Icon(Iconsax.search_normal, color: AppColors.secondaryText),
              filled: true,
              fillColor: AppColors.background,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: AppTypography.body,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          AppSpacing.verticalGapMd,
          // Selected resident chip (if any)
          if (widget.selectedResidentId != null) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.user, size: 16, color: AppColors.primary),
                  AppSpacing.horizontalGapSm,
                  Flexible(
                    child: Text(
                      widget.selectedResidentName ?? 'Unknown',
                      style: AppTypography.body
                          .copyWith(color: AppColors.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppSpacing.horizontalGapSm,
                  GestureDetector(
                    onTap: () => widget.onResidentChanged(null, null),
                    child: Icon(Iconsax.close_circle,
                        size: 18, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            AppSpacing.verticalGapMd,
          ],
          // Resident list
          Expanded(
            child: _filteredResidents.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'ไม่มีรายชื่อคนไข้'
                          : 'ไม่พบผลลัพธ์',
                      style: AppTypography.body
                          .copyWith(color: AppColors.secondaryText),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredResidents.length,
                    itemBuilder: (context, index) {
                      final resident = _filteredResidents[index];
                      final isSelected =
                          resident.id == widget.selectedResidentId;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accent1,
                          backgroundImage: resident.pictureUrl != null
                              ? NetworkImage(resident.pictureUrl!)
                              : null,
                          child: resident.pictureUrl == null
                              ? Icon(Iconsax.user,
                                  color: AppColors.primary, size: 20)
                              : null,
                        ),
                        title: Text(
                          resident.name,
                          style: AppTypography.body.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: resident.zone != null
                            ? Text(
                                resident.zone!,
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.secondaryText),
                              )
                            : null,
                        trailing: isSelected
                            ? Icon(Iconsax.tick_circle5,
                                color: AppColors.primary)
                            : null,
                        onTap: () {
                          widget.onResidentChanged(resident.id, resident.name);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
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
