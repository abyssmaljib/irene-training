import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/resident_simple.dart';

/// Widget สำหรับแสดงรายการคนไข้พร้อม checkbox
class ResidentCheckboxList extends StatelessWidget {
  final List<ResidentSimple> residents;
  final Set<int> selectedResidentIds;
  final Set<int> disabledResidentIds; // คนไข้ที่เพื่อนเลือกไปแล้ว
  final ValueChanged<Set<int>> onChanged;
  final bool isLoading;

  const ResidentCheckboxList({
    super.key,
    required this.residents,
    required this.selectedResidentIds,
    this.disabledResidentIds = const {},
    required this.onChanged,
    this.isLoading = false,
  });

  // เฉพาะคนไข้ที่ไม่ถูก disable
  List<ResidentSimple> get _selectableResidents =>
      residents.where((r) => !disabledResidentIds.contains(r.id)).toList();

  bool get _isAllSelected =>
      _selectableResidents.isNotEmpty &&
      _selectableResidents.every((r) => selectedResidentIds.contains(r.id));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'เลือกคนไข้',
                  style: AppTypography.title,
                ),
                if (selectedResidentIds.isNotEmpty) ...[
                  AppSpacing.horizontalGapSm,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${selectedResidentIds.length}',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_selectableResidents.isNotEmpty)
              TextButton(
                onPressed: () {
                  if (_isAllSelected) {
                    onChanged({});
                  } else {
                    // เลือกเฉพาะคนไข้ที่ไม่ถูก disable
                    onChanged(_selectableResidents.map((r) => r.id).toSet());
                  }
                },
                child: Text(
                  _isAllSelected ? 'ยกเลิกทั้งหมด' : 'เลือกทั้งหมด',
                  style: AppTypography.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        AppSpacing.verticalGapSm,
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (residents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mediumRadius,
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 48,
                  color: AppColors.secondaryText,
                ),
                AppSpacing.verticalGapSm,
                Text(
                  'กรุณาเลือก Zone ก่อน',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          )
        else
          Builder(
            builder: (context) {
              // เรียงลำดับ: คนที่เลือกได้ก่อน, คนที่ถูก disabled ทีหลัง
              final sortedResidents = List<ResidentSimple>.from(residents)
                ..sort((a, b) {
                  final aDisabled = disabledResidentIds.contains(a.id);
                  final bDisabled = disabledResidentIds.contains(b.id);
                  if (aDisabled && !bDisabled) return 1;
                  if (!aDisabled && bDisabled) return -1;
                  return 0;
                });

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.mediumRadius,
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: sortedResidents.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: AppColors.inputBorder,
                  ),
                  itemBuilder: (context, index) {
                    final resident = sortedResidents[index];
                    final isSelected = selectedResidentIds.contains(resident.id);
                    final isDisabled = disabledResidentIds.contains(resident.id);

                    return _ResidentListItem(
                      resident: resident,
                      isSelected: isSelected,
                      isDisabled: isDisabled,
                      onTap: isDisabled
                          ? null
                          : () {
                              final newSelection = Set<int>.from(selectedResidentIds);
                              if (isSelected) {
                                newSelection.remove(resident.id);
                              } else {
                                newSelection.add(resident.id);
                              }
                              onChanged(newSelection);
                            },
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ResidentListItem extends StatelessWidget {
  final ResidentSimple resident;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _ResidentListItem({
    required this.resident,
    required this.isSelected,
    this.isDisabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isDisabled
            ? AppColors.alternate.withValues(alpha: 0.5)
            : isSelected
                ? AppColors.accent1
                : Colors.transparent,
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDisabled ? AppColors.secondaryText : AppColors.tertiary,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Opacity(
                  opacity: isDisabled ? 0.5 : 1.0,
                  child: resident.photoUrl != null && resident.photoUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: resident.photoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.alternate,
                            child: Icon(
                              Icons.person,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.alternate,
                            child: Icon(
                              Icons.person,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.alternate,
                          child: Icon(
                            Icons.person,
                            color: AppColors.secondaryText,
                          ),
                        ),
                ),
              ),
            ),
            AppSpacing.horizontalGapMd,
            // Name and info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'คุณ${resident.name}',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDisabled ? AppColors.secondaryText : AppColors.textPrimary,
                    ),
                  ),
                  if (isDisabled)
                    Text(
                      'เพื่อนเลือกไปแล้ว',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.warning,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else if (resident.genderAndAge.isNotEmpty)
                    Text(
                      resident.genderAndAge,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                ],
              ),
            ),
            // Checkbox
            Checkbox(
              value: isSelected,
              onChanged: isDisabled ? null : (_) => onTap?.call(),
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
