import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/input_fields.dart';
import '../services/post_service.dart';
import '../providers/post_provider.dart';

/// Model สำหรับ Resident option
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

/// Provider สำหรับดึงรายชื่อ residents
final residentsProvider = FutureProvider<List<ResidentOption>>((ref) async {
  final nursinghomeId = await ref.watch(nursinghomeIdProvider.future);
  if (nursinghomeId == null) return [];

  final service = PostService.instance;
  final residents = await service.getResidents(nursinghomeId);

  return residents
      .map((r) => ResidentOption(
            id: r['id'] as int,
            name: r['Name'] as String? ?? 'Unknown',
            zone: r['zone_name'] as String?,
            pictureUrl: r['i_Picture_url'] as String?,
          ))
      .toList();
});

/// Widget สำหรับเลือก Resident
class ResidentPickerWidget extends ConsumerWidget {
  final int? selectedResidentId;
  final String? selectedResidentName;
  final void Function(int id, String name) onResidentSelected;
  final VoidCallback? onResidentCleared;
  final bool disabled; // ถ้า true จะไม่สามารถเปลี่ยนได้

  const ResidentPickerWidget({
    super.key,
    this.selectedResidentId,
    this.selectedResidentName,
    required this.onResidentSelected,
    this.onResidentCleared,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ถ้าเลือกแล้ว แสดง chip
    if (selectedResidentId != null) {
      return _buildSelectedChip();
    }

    // ไม่เลือก แสดงปุ่มเลือก (ถ้าไม่ disabled)
    if (disabled) {
      return const SizedBox.shrink();
    }
    return _buildSelectButton(context);
  }

  Widget _buildSelectedChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: disabled ? AppColors.alternate : AppColors.accent1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: disabled ? AppColors.secondaryText : AppColors.primary,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedUser,
            size: AppIconSize.sm,
            color: disabled ? AppColors.secondaryText : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            selectedResidentName ?? 'ผู้พักอาศัย',
            style: AppTypography.bodySmall.copyWith(
              color: disabled ? AppColors.secondaryText : AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          // ไม่แสดงปุ่มลบเมื่อ disabled
          if (onResidentCleared != null && !disabled) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onResidentCleared,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCancelCircle,
                size: AppIconSize.sm,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectButton(BuildContext context) {
    // Chip style เหมือน tag picker
    return GestureDetector(
      onTap: () => _showResidentPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.alternate),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedUser,
              size: AppIconSize.sm,
              color: AppColors.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              'เลือกผู้พักอาศัย',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(width: 4),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowDown01,
              size: AppIconSize.sm,
              color: AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  void _showResidentPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ResidentPickerSheet(
        onSelect: (resident) {
          onResidentSelected(resident.id, resident.name);
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Bottom sheet สำหรับเลือก Resident
class ResidentPickerSheet extends ConsumerStatefulWidget {
  final void Function(ResidentOption) onSelect;

  const ResidentPickerSheet({super.key, required this.onSelect});

  @override
  ConsumerState<ResidentPickerSheet> createState() =>
      _ResidentPickerSheetState();
}

class _ResidentPickerSheetState extends ConsumerState<ResidentPickerSheet> {
  final _searchController = TextEditingController();
  // ลบ _searchQuery ออก - ใช้ _searchController.text แทน
  // ใช้ ValueListenableBuilder wrap ส่วน list เพื่อ rebuild เฉพาะส่วนนั้นเมื่อพิมพ์

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final residentsAsync = ref.watch(residentsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.alternate,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'เลือกผู้พักอาศัย',
              style: AppTypography.title,
            ),
          ),

          // Search field - ลบ onChanged/onClear ออก เพราะใช้ ValueListenableBuilder แทน
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchField(
              controller: _searchController,
              hintText: 'ค้นหาชื่อ...',
              isDense: true,
              // ไม่ต้องใช้ onChanged/onClear เพราะ ValueListenableBuilder
              // จะ listen _searchController โดยตรง
              onClear: () => _searchController.clear(),
            ),
          ),

          AppSpacing.verticalGapMd,

          // Residents list - ใช้ ValueListenableBuilder เพื่อ rebuild เฉพาะ list
          // เมื่อ search text เปลี่ยน แทนที่จะ rebuild ทั้ง sheet
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, textValue, child) {
                final searchQuery = textValue.text;

                return residentsAsync.when(
                  data: (residents) {
                    final filtered = _filterResidents(residents, searchQuery);

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedUserSearch01,
                              size: AppIconSize.xxxl,
                              color: AppColors.alternate,
                            ),
                            AppSpacing.verticalGapMd,
                            Text(
                              searchQuery.isNotEmpty
                                  ? 'ไม่พบผู้พักอาศัย'
                                  : 'ไม่มีข้อมูลผู้พักอาศัย',
                              style: AppTypography.body
                                  .copyWith(color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final resident = filtered[index];
                        return _buildResidentTile(resident);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      'เกิดข้อผิดพลาด',
                      style: AppTypography.body.copyWith(color: AppColors.error),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Filter residents โดยรับ searchQuery เป็น parameter
  /// เพื่อให้ใช้กับ ValueListenableBuilder ได้
  List<ResidentOption> _filterResidents(
    List<ResidentOption> residents,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return residents;

    final query = searchQuery.toLowerCase();
    return residents.where((r) {
      return r.name.toLowerCase().contains(query) ||
          (r.zone?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Widget _buildResidentTile(ResidentOption resident) {
    return InkWell(
      onTap: () => widget.onSelect(resident),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accent1,
              backgroundImage: resident.pictureUrl != null
                  ? CachedNetworkImageProvider(resident.pictureUrl!)
                  : null,
              child: resident.pictureUrl == null
                  ? HugeIcon(icon: HugeIcons.strokeRoundedUser, color: AppColors.primary, size: AppIconSize.lg)
                  : null,
            ),
            const SizedBox(width: 12),

            // Name and zone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'คุณ${resident.name}',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (resident.zone != null)
                    Text(
                      resident.zone!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ),

            // Arrow
            HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                size: AppIconSize.md, color: AppColors.secondaryText),
          ],
        ),
      ),
    );
  }
}
