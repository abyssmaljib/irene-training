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
import '../../checklist/providers/task_provider.dart'
    show currentShiftProvider, nursinghomeZonesProvider;

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
  final nursinghomeId = await ref.watch(postNursinghomeIdProvider.future);
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

  /// true = แสดงทุกโซน, false = แสดงเฉพาะโซนที่ user clock-in อยู่
  bool _showAllZones = false;

  /// รายชื่อ zone names ที่ user clock-in อยู่ (โหลดจาก provider)
  List<String> _userZoneNames = [];

  @override
  void initState() {
    super.initState();
    // โหลด zone names ของ user จาก currentShift + nursinghomeZones
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserZones());
  }

  /// ดึง zone names ที่ user clock-in อยู่
  Future<void> _loadUserZones() async {
    try {
      final shift = await ref.read(currentShiftProvider.future);
      if (shift == null || !shift.isClockedIn || shift.zones.isEmpty) {
        // ไม่ได้ clock-in หรือไม่มีโซน → แสดงทั้งหมด
        if (mounted) setState(() => _showAllZones = true);
        return;
      }

      final allZones = await ref.read(nursinghomeZonesProvider.future);
      // Map zone IDs → zone names
      final zoneNames = allZones
          .where((z) => shift.zones.contains(z.id))
          .map((z) => z.name)
          .toList();

      if (mounted) {
        setState(() {
          _userZoneNames = zoneNames;
          // ถ้าไม่มี zone names ที่ match → แสดงทั้งหมด
          if (zoneNames.isEmpty) _showAllZones = true;
        });
      }
    } catch (_) {
      // Error → fallback แสดงทั้งหมด
      if (mounted) setState(() => _showAllZones = true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final residentsAsync = ref.watch(residentsProvider);

    // ใช้ sizeOf แทน of เพื่อไม่ rebuild ตาม viewInsets (keyboard)
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
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

          // Search field + ปุ่มแสดงทั้งหมด/เฉพาะโซน
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // ช่อง search
                Expanded(
                  child: SearchField(
                    controller: _searchController,
                    hintText: 'ค้นหาชื่อ...',
                    isDense: true,
                    onClear: () => _searchController.clear(),
                  ),
                ),
                // ปุ่ม toggle โซน (แสดงเมื่อมี zone data)
                if (_userZoneNames.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _showAllZones = !_showAllZones),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _showAllZones
                            ? AppColors.background
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _showAllZones
                              ? AppColors.alternate
                              : AppColors.primary,
                          width: _showAllZones ? 1 : 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            // icon บอกสถานะปัจจุบัน
                            icon: _showAllZones
                                ? HugeIcons.strokeRoundedLocation01
                                : HugeIcons.strokeRoundedBuilding06,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            // label บอกว่ากดแล้วจะไปไหน (hint)
                            _showAllZones ? 'เฉพาะโซนฉัน' : 'แสดงทั้งหมด',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
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
                                  : !_showAllZones && _userZoneNames.isNotEmpty
                                      ? 'ไม่มีผู้พักอาศัยในโซนนี้'
                                      : 'ไม่มีข้อมูลผู้พักอาศัย',
                              style: AppTypography.body
                                  .copyWith(color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      );
                    }

                    // === Group by zone ===
                    // จัดกลุ่มตามโซน แสดง header แยกแต่ละกลุ่ม
                    final groupedItems =
                        _buildGroupedItems(filtered);

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: groupedItems.length,
                      itemBuilder: (context, index) {
                        final item = groupedItems[index];
                        // Zone header (String) หรือ Resident tile (ResidentOption)
                        if (item is String) {
                          return _buildZoneHeader(item);
                        }
                        return _buildResidentTile(item as ResidentOption);
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

  /// Filter residents ตาม search query + zone filter
  List<ResidentOption> _filterResidents(
    List<ResidentOption> residents,
    String searchQuery,
  ) {
    var filtered = residents;

    // Zone filter: ถ้าไม่ได้แสดงทั้งหมด → เฉพาะโซนที่ user clock-in
    if (!_showAllZones && _userZoneNames.isNotEmpty) {
      filtered = filtered
          .where((r) => r.zone != null && _userZoneNames.contains(r.zone))
          .toList();
    }

    // Search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.name.toLowerCase().contains(query) ||
            (r.zone?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  /// จัดกลุ่ม residents ตามโซน → return flat list ที่มีทั้ง zone header (String)
  /// และ resident (ResidentOption) สลับกัน เพื่อใช้กับ ListView.builder
  List<dynamic> _buildGroupedItems(List<ResidentOption> residents) {
    // Group by zone name
    final grouped = <String, List<ResidentOption>>{};
    for (final r in residents) {
      final zone = r.zone ?? 'ไม่ระบุโซน';
      grouped.putIfAbsent(zone, () => []).add(r);
    }

    // Sort zones: ชื่อโซนจริงก่อน, 'ไม่ระบุโซน' อยู่ท้ายสุด
    final sortedZones = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'ไม่ระบุโซน') return 1;
        if (b == 'ไม่ระบุโซน') return -1;
        return a.compareTo(b);
      });

    // Flatten: [zone header, resident, resident, zone header, resident, ...]
    final items = <dynamic>[];
    for (final zone in sortedZones) {
      items.add(zone); // zone header (String)
      items.addAll(grouped[zone]!); // residents ในโซนนั้น
    }
    return items;
  }

  /// Header แยกกลุ่มโซน
  Widget _buildZoneHeader(String zoneName) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedLocation01,
            size: AppIconSize.sm,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            zoneName,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          // เส้นแบ่ง
          Expanded(
            child: Divider(
              color: AppColors.alternate,
              height: 1,
            ),
          ),
        ],
      ),
    );
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
