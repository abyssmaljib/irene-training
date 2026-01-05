import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tags_badges.dart';
import '../models/zone.dart';

/// Widget สำหรับเลือก Zone แบบ multi-select
class ZoneMultiSelect extends StatelessWidget {
  final List<Zone> zones;
  final Set<int> selectedZoneIds;
  final ValueChanged<Set<int>> onChanged;
  final bool isLoading;

  const ZoneMultiSelect({
    super.key,
    required this.zones,
    required this.selectedZoneIds,
    required this.onChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'เลือก Zone',
              style: AppTypography.title,
            ),
            if (selectedZoneIds.isNotEmpty) ...[
              AppSpacing.horizontalGapSm,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedZoneIds.length}',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        AppSpacing.verticalGapSm,
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (zones.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'ไม่พบ Zone',
              style: AppTypography.body.copyWith(color: AppColors.secondaryText),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: zones.map((zone) {
              final isSelected = selectedZoneIds.contains(zone.id);
              return CategoryChip(
                label: '${zone.name} (${zone.residentCount})',
                isSelected: isSelected,
                onTap: () {
                  final newSelection = Set<int>.from(selectedZoneIds);
                  if (isSelected) {
                    newSelection.remove(zone.id);
                  } else {
                    newSelection.add(zone.id);
                  }
                  onChanged(newSelection);
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}
