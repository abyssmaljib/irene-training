import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/filter_drawer_shell.dart';
import '../../../core/widgets/input_fields.dart';
import '../../medicine/widgets/day_picker.dart';
import '../providers/task_provider.dart';

/// Drawer สำหรับเลือก view mode และ filters
class TaskFilterDrawer extends ConsumerWidget {
  const TaskFilterDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentViewMode = ref.watch(taskViewModeProvider);
    final taskCounts = ref.watch(taskCountsProvider);
    final userShiftAsync = ref.watch(userShiftProvider);

    return FilterDrawerShell(
      title: 'ตัวกรอง',
      filterCount: 0, // TaskFilterDrawer ไม่มี filter count แบบ ResidentsFilterDrawer
      footer: _buildRefreshButton(context, ref),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Selector Section
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'เลือกวันที่',
                style: AppTypography.title.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Consumer(
                builder: (context, ref, _) {
                  final selectedDate = ref.watch(selectedDateProvider);
                  return DayPicker(
                    selectedDate: selectedDate,
                    onDateChanged: (date) {
                      ref.read(selectedDateProvider.notifier).state = date;
                      refreshTasks(ref);
                    },
                  );
                },
              ),
            ),

            const Divider(height: 32),

            // View Mode Section
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'มุมมอง',
                style: AppTypography.title.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            ...TaskViewMode.values.map((mode) => _ViewModeOption(
                  mode: mode,
                  isSelected: currentViewMode == mode,
                  count: taskCounts[mode] ?? 0,
                  onTap: () {
                    ref.read(taskViewModeProvider.notifier).state = mode;
                    Navigator.of(context).pop();
                  },
                )),

            const Divider(height: 32),

            // Role Filter Section (กรองตามตำแหน่ง - ใช้บ่อย)
            _RoleFilterSection(),

            const Divider(height: 32),

            // Task Type Filter Section
            _TaskTypeFilterSection(),

            const Divider(height: 32),

            // Shift Info Section
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'การขึ้นเวรวันนี้',
                style: AppTypography.title.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            userShiftAsync.when(
              data: (shift) {
                if (shift == null) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Container(
                      padding: EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.tagPendingBg,
                        borderRadius: AppRadius.mediumRadius,
                      ),
                      child: Row(
                        children: [
                          Icon(Iconsax.info_circle,
                              color: AppColors.tagPendingText, size: 20),
                          AppSpacing.horizontalGapSm,
                          Expanded(
                            child: Text(
                              'ยังไม่ได้ขึ้นเวร',
                              style: AppTypography.body.copyWith(
                                color: AppColors.tagPendingText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shift type
                      if (shift.shiftType != null) ...[
                        _InfoRow(
                          icon: Iconsax.clock,
                          label: 'เวร',
                          value: shift.shiftType!,
                        ),
                        AppSpacing.verticalGapSm,
                      ],
                      // Zones
                      if (shift.hasZoneFilter) ...[
                        _InfoRow(
                          icon: Iconsax.location,
                          label: 'โซน',
                          value: '${shift.zones.length} โซน',
                        ),
                        AppSpacing.verticalGapSm,
                      ],
                      // Residents
                      if (shift.hasResidentFilter) ...[
                        _InfoRow(
                          icon: Iconsax.user,
                          label: 'ผู้พักอาศัย',
                          value: '${shift.selectedResidentIds.length} คน',
                        ),
                      ],
                      // No filter info
                      if (!shift.hasAnyFilter)
                        Container(
                          padding: EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.accent1,
                            borderRadius: AppRadius.mediumRadius,
                          ),
                          child: Row(
                            children: [
                              Icon(Iconsax.global,
                                  color: AppColors.primary, size: 20),
                              AppSpacing.horizontalGapSm,
                              Expanded(
                                child: Text(
                                  'ดูงานทั้งหมด (ไม่มีการกรอง)',
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'ไม่สามารถโหลดข้อมูลได้',
                  style: AppTypography.body.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ),

            // Bottom padding for scroll content
            AppSpacing.verticalGapLg,
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          refreshTasks(ref);
          Navigator.of(context).pop();
        },
        icon: const Icon(Iconsax.refresh),
        label: const Text('รีเฟรชข้อมูล'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary),
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
      ),
    );
  }
}

class _ViewModeOption extends StatelessWidget {
  final TaskViewMode mode;
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  const _ViewModeOption({
    required this.mode,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        _getIcon(),
        color: isSelected ? AppColors.primary : AppColors.secondaryText,
      ),
      title: Text(
        mode.label,
        style: AppTypography.body.copyWith(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        mode.description,
        style: AppTypography.caption.copyWith(
          color: AppColors.secondaryText,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.accent1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$count',
          style: AppTypography.caption.copyWith(
            color: isSelected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.08), // อ่อนลงเพื่อให้อ่านง่าย
    );
  }

  IconData _getIcon() {
    switch (mode) {
      case TaskViewMode.upcoming:
        return Iconsax.timer_1;
      case TaskViewMode.all:
        return Iconsax.task_square;
      case TaskViewMode.problem:
        return Iconsax.warning_2;
      case TaskViewMode.myDone:
        return Iconsax.tick_circle;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondaryText),
        AppSpacing.horizontalGapSm,
        Text(
          '$label:',
          style: AppTypography.body.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        AppSpacing.horizontalGapSm,
        Text(
          value,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Section สำหรับเลือก filter ตามตำแหน่ง
class _RoleFilterSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRolesAsync = ref.watch(allSystemRolesProvider);
    final selectedRoleId = ref.watch(selectedRoleFilterProvider);
    final userRoleAsync = ref.watch(currentUserSystemRoleProvider);
    final pendingPerRole = ref.watch(pendingTasksPerRoleProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Text(
            'กรองตามตำแหน่ง',
            style: AppTypography.title.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
        allRolesAsync.when(
          data: (allRoles) {
            final userRole = userRoleAsync.valueOrNull;
            if (userRole == null) {
              return Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/not_found.webp',
                      width: 80,
                      height: 80,
                    ),
                    AppSpacing.verticalGapSm,
                    Text(
                      'ไม่พบข้อมูลตำแหน่ง',
                      style: AppTypography.body.copyWith(color: AppColors.secondaryText),
                    ),
                  ],
                ),
              );
            }

            // สร้างรายการ role ที่ user มีสิทธิ์ดู
            // 1. role ของตัวเอง
            // 2. role ใน relatedRoleIds
            final visibleRoleIds = <int>{userRole.id, ...userRole.relatedRoleIds};
            final visibleRoles = allRoles
                .where((r) => visibleRoleIds.contains(r.id))
                .toList();

            // เรียงลำดับให้ role ของตัวเองอยู่บนสุด
            visibleRoles.sort((a, b) {
              if (a.id == userRole.id) return -1;
              if (b.id == userRole.id) return 1;
              return a.name.compareTo(b.name);
            });

            // คำนวณจำนวนงานที่ไม่ระบุ role (ทุกคนทำได้)
            final unassignedCount = pendingPerRole[-999] ?? 0;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  // แสดงแต่ละ role ที่มีสิทธิ์ดู
                  for (int i = 0; i < visibleRoles.length; i++) ...[
                    if (i > 0) AppSpacing.verticalGapSm,
                    Builder(builder: (context) {
                      final role = visibleRoles[i];
                      final isMyRole = role.id == userRole.id;
                      final isSelected = selectedRoleId == role.id ||
                          (selectedRoleId == null && isMyRole);
                      // จำนวนงาน = งานของ role นั้น + งานที่ไม่ระบุ role (ทุกคนทำได้)
                      final roleCount = (pendingPerRole[role.id] ?? 0) + unassignedCount;

                      return _RoleOption(
                        label: isMyRole
                            ? '${role.abb ?? role.name} (ฉัน)'
                            : role.abb ?? role.name,
                        subtitle: role.name,
                        isSelected: isSelected,
                        pendingCount: roleCount,
                        onTap: () {
                          ref.read(selectedRoleFilterProvider.notifier).state = role.id;
                        },
                      );
                    }),
                  ],
                ],
              ),
            );
          },
          loading: () => Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, _) => Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text(
              'ไม่สามารถโหลดข้อมูลได้',
              style: AppTypography.body.copyWith(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}

/// Section สำหรับเลือก filter ตามประเภทงาน
class _TaskTypeFilterSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TaskTypeFilterSection> createState() => _TaskTypeFilterSectionState();
}

class _TaskTypeFilterSectionState extends ConsumerState<_TaskTypeFilterSection> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleTaskType(String taskType) {
    final current = ref.read(selectedTaskTypesFilterProvider);
    final newSet = Set<String>.from(current);
    if (newSet.contains(taskType)) {
      newSet.remove(taskType);
    } else {
      newSet.add(taskType);
    }
    ref.read(selectedTaskTypesFilterProvider.notifier).state = newSet;
  }

  void _clearTaskTypeFilter() {
    ref.read(selectedTaskTypesFilterProvider.notifier).state = {};
    ref.read(taskTypeSearchQueryProvider.notifier).state = '';
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTypes = ref.watch(filteredTaskTypesProvider);
    final selectedTypes = ref.watch(selectedTaskTypesFilterProvider);
    final allTypes = ref.watch(availableTaskTypesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Text(
                'ประเภทงาน',
                style: AppTypography.title.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              if (selectedTypes.isNotEmpty) ...[
                AppSpacing.horizontalGapSm,
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${selectedTypes.length}',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _clearTaskTypeFilter,
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

        // Search bar
        if (allTypes.length > 5)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SearchField(
              controller: _searchController,
              hintText: 'ค้นหาประเภทงาน...',
              isDense: true,
              onChanged: (value) {
                ref.read(taskTypeSearchQueryProvider.notifier).state = value;
              },
              onClear: () {
                ref.read(taskTypeSearchQueryProvider.notifier).state = '';
              },
            ),
          ),

        if (allTypes.length > 5) AppSpacing.verticalGapSm,

        // Task type chips
        if (filteredTypes.isEmpty)
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/not_found.webp',
                  width: 80,
                  height: 80,
                ),
                AppSpacing.verticalGapSm,
                Text(
                  allTypes.isEmpty ? 'ไม่พบประเภทงาน' : 'ไม่พบผลการค้นหา',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filteredTypes.map((taskType) {
                final isSelected = selectedTypes.contains(taskType);
                return GestureDetector(
                  onTap: () => _toggleTaskType(taskType),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent1 : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.inputBorder,
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
                          SizedBox(width: 6),
                        ],
                        Text(
                          taskType,
                          style: AppTypography.body.copyWith(
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

/// Widget สำหรับแต่ละ role option
class _RoleOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final int pendingCount;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    this.pendingCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mediumRadius,
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent1 : Colors.transparent,
              borderRadius: AppRadius.mediumRadius,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.inputBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppColors.primary : AppColors.secondaryText,
                  size: 20,
                ),
                AppSpacing.horizontalGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.body.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Warning badge for pending tasks (แดงพาสเทล)
        if (pendingCount > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.tagFailedBg, // แดงพาสเทล
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                pendingCount > 99 ? '99+' : '$pendingCount',
                style: AppTypography.caption.copyWith(
                  color: AppColors.tagFailedText, // ตัวอักษรแดงเข้ม
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
