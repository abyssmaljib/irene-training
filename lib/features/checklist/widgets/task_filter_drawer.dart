import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/task_provider.dart';

/// Drawer สำหรับเลือก view mode และ filters
class TaskFilterDrawer extends ConsumerWidget {
  const TaskFilterDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentViewMode = ref.watch(taskViewModeProvider);
    final taskCounts = ref.watch(taskCountsProvider);
    final userShiftAsync = ref.watch(userShiftProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (fixed)
            Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Icon(Iconsax.filter, color: AppColors.primary),
                  AppSpacing.horizontalGapMd,
                  Text(
                    'ตัวกรอง',
                    style: AppTypography.heading2,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    // Role Filter Section
                    _RoleFilterSection(),

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
            ),

            // Refresh button (fixed at bottom)
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
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
              ),
            ),
          ],
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
      selectedTileColor: AppColors.accent1.withValues(alpha: 0.5),
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
    final pendingForMyRole = ref.watch(pendingTasksForMyRoleProvider);
    final pendingForAllRoles = ref.watch(pendingTasksForAllRolesProvider);

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
          data: (roles) {
            final userRole = userRoleAsync.valueOrNull;
            // Determine which option is selected
            // null or user's role id = "ตำแหน่งของฉัน"
            // -1 = "ดูทุกตำแหน่ง"
            final isMyRoleSelected = selectedRoleId == null ||
                (userRole != null && selectedRoleId == userRole.id);
            final isAllSelected = selectedRoleId == -1;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  // ตำแหน่งของฉัน option
                  _RoleOption(
                    label: 'ตำแหน่งของฉัน',
                    subtitle: userRole?.name ?? 'ไม่ระบุ',
                    isSelected: isMyRoleSelected,
                    pendingCount: pendingForMyRole,
                    onTap: () {
                      ref.read(selectedRoleFilterProvider.notifier).state = null;
                    },
                  ),
                  AppSpacing.verticalGapSm,
                  // ดูทุกตำแหน่ง option
                  _RoleOption(
                    label: 'ดูทุกตำแหน่ง',
                    subtitle: 'แสดงงานของทุกตำแหน่ง',
                    isSelected: isAllSelected,
                    pendingCount: pendingForAllRoles,
                    onTap: () {
                      ref.read(selectedRoleFilterProvider.notifier).state = -1;
                    },
                  ),
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
