import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/filter_drawer_shell.dart';
import '../../../core/widgets/input_fields.dart';
import '../../../core/services/user_service.dart';
import '../../medicine/widgets/day_picker.dart';
import '../../home/services/home_service.dart';
import '../../home/services/clock_service.dart';
import '../../shift_summary/services/shift_summary_service.dart';
import '../../dd_handover/services/dd_service.dart';
import '../providers/task_provider.dart';

/// Provider สำหรับ all users (dev mode)
final _allUsersProvider = FutureProvider<List<DevUserInfo>>((ref) async {
  // Watch for changes
  ref.watch(userChangeCounterProvider);
  return UserService().getAllUsers();
});

/// Dev emails ที่สามารถใช้ impersonate ได้
const _devEmails = ['beautyheechul@gmail.com'];

/// Drawer สำหรับเลือก view mode และ filters
class TaskFilterDrawer extends ConsumerWidget {
  const TaskFilterDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentViewMode = ref.watch(taskViewModeProvider);
    final taskCounts = ref.watch(taskCountsProvider);
    final userShiftAsync = ref.watch(userShiftProvider);
    final userService = UserService();
    final isImpersonating = userService.isImpersonating;

    // Check if current user is dev
    final userEmail = Supabase.instance.client.auth.currentUser?.email;
    final isDevMode = _devEmails.contains(userEmail);

    return FilterDrawerShell(
      title: 'ตัวกรอง',
      filterCount: 0, // TaskFilterDrawer ไม่มี filter count แบบ ResidentsFilterDrawer
      footer: _buildRefreshButton(context, ref),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Impersonation Banner (if impersonating)
            if (isImpersonating)
              _ImpersonationBanner(),

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
                          HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle,
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
                          icon: HugeIcons.strokeRoundedClock01,
                          label: 'เวร',
                          value: shift.shiftType!,
                        ),
                        AppSpacing.verticalGapSm,
                      ],
                      // Zones
                      if (shift.hasZoneFilter) ...[
                        _InfoRow(
                          icon: HugeIcons.strokeRoundedLocation01,
                          label: 'โซน',
                          value: '${shift.zones.length} โซน',
                        ),
                        AppSpacing.verticalGapSm,
                      ],
                      // Residents
                      if (shift.hasResidentFilter) ...[
                        _InfoRow(
                          icon: HugeIcons.strokeRoundedUser,
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
                              HugeIcon(icon: HugeIcons.strokeRoundedGlobe,
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

            // Dev Mode Section (only for dev emails)
            if (isDevMode) ...[
              const Divider(height: 32),
              _DevModeUserSelector(),
            ],

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
        icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
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
      leading: HugeIcon(
        icon: _getIcon(),
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

  dynamic _getIcon() {
    switch (mode) {
      case TaskViewMode.upcoming:
        return HugeIcons.strokeRoundedTimer01;
      case TaskViewMode.all:
        return HugeIcons.strokeRoundedTask01;
      case TaskViewMode.problem:
        return HugeIcons.strokeRoundedAlert02;
      case TaskViewMode.myDone:
        return HugeIcons.strokeRoundedCheckmarkCircle02;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final dynamic icon;
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
        HugeIcon(icon: icon, size: AppIconSize.sm, color: AppColors.secondaryText),
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
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                            size: AppIconSize.sm,
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
                HugeIcon(
                  icon: isSelected ? HugeIcons.strokeRoundedCheckmarkCircle02 : HugeIcons.strokeRoundedCircle,
                  color: isSelected ? AppColors.primary : AppColors.secondaryText,
                  size: AppIconSize.lg,
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

// ============================================================
// Impersonation Widgets (Dev Mode)
// ============================================================

/// Banner แสดงว่ากำลัง impersonate อยู่
class _ImpersonationBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allUsersAsync = ref.watch(_allUsersProvider);
    final userService = UserService();
    final effectiveUserId = userService.effectiveUserId;

    final impersonatedUser = allUsersAsync.whenOrNull(
      data: (users) => users.where((u) => u.id == effectiveUserId).firstOrNull,
    );

    return Container(
      margin: EdgeInsets.all(AppSpacing.md),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: Colors.red.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: AppIconSize.lg,
                color: Colors.red.shade700,
              ),
              AppSpacing.horizontalGapSm,
              Expanded(
                child: Text(
                  'สวมรอยเป็น: ${impersonatedUser?.displayName ?? "..."}',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _stopImpersonating(context, ref),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowTurnBackward,
                size: AppIconSize.md,
              ),
              label: Text('กลับมาเป็นตัวฉันเอง'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.smallRadius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _stopImpersonating(BuildContext context, WidgetRef ref) {
    UserService().stopImpersonating();

    // Invalidate all service caches
    HomeService.instance.invalidateCache();
    ClockService.instance.invalidateCache();
    ShiftSummaryService.instance.invalidateCache();
    DDService.instance.invalidateCache();
    UserService().clearCache();

    // Invalidate role-related providers
    ref.invalidate(currentUserSystemRoleProvider);
    ref.invalidate(effectiveRoleFilterProvider);
    ref.invalidate(currentShiftProvider);
    ref.invalidate(userShiftProvider);

    // Increment user change counter to refresh Riverpod providers
    ref.read(userChangeCounterProvider.notifier).state++;

    // Reset role filter to use new user's role
    ref.read(selectedRoleFilterProvider.notifier).state = null;

    // Refresh tasks
    refreshTasks(ref);

    // Close drawer
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('กลับมาเป็นตัวคุณเองแล้ว'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

/// Section สำหรับ Dev Mode - สวมรอยเป็น User อื่น
class _DevModeUserSelector extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DevModeUserSelector> createState() => _DevModeUserSelectorState();
}

class _DevModeUserSelectorState extends ConsumerState<_DevModeUserSelector> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final allUsersAsync = ref.watch(_allUsersProvider);
    final userService = UserService();
    final effectiveUserId = userService.effectiveUserId;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.cyan.shade50,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: Colors.cyan.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedUserEdit01,
                size: AppIconSize.sm,
                color: Colors.cyan.shade700,
              ),
              AppSpacing.horizontalGapSm,
              Expanded(
                child: Text(
                  'Dev Mode - สวมรอยเป็น User อื่น',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.cyan.shade700,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
          // Search field
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อ...',
              hintStyle: AppTypography.bodySmall.copyWith(
                color: Colors.cyan.shade300,
              ),
              prefixIcon: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedSearch01,
                  size: AppIconSize.md,
                  color: Colors.cyan.shade400,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide(color: Colors.cyan.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide(color: Colors.cyan.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.smallRadius,
                borderSide: BorderSide(color: Colors.cyan, width: 2),
              ),
            ),
            style: AppTypography.body.copyWith(
              color: Colors.cyan.shade900,
            ),
          ),
          AppSpacing.verticalGapMd,
          allUsersAsync.when(
            data: (allUsers) {
              // Filter users by search query
              final filteredUsers = _searchQuery.isEmpty
                  ? allUsers
                  : allUsers.where((user) {
                      final query = _searchQuery.toLowerCase();
                      final nickname = user.nickname?.toLowerCase() ?? '';
                      final fullName = user.fullName?.toLowerCase() ?? '';
                      return nickname.contains(query) || fullName.contains(query);
                    }).toList();

              if (filteredUsers.isEmpty) {
                return Center(
                  child: Text(
                    allUsers.isEmpty ? 'ไม่พบรายชื่อพนักงาน' : 'ไม่พบผู้ใช้ที่ค้นหา',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.cyan.shade600,
                    ),
                  ),
                );
              }

              return Container(
                constraints: BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.smallRadius,
                  border: Border.all(color: Colors.cyan.shade200),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredUsers.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.cyan.shade100,
                  ),
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final isSelected = user.id == effectiveUserId;

                    return _UserListTile(
                      user: user,
                      isSelected: isSelected,
                      onTap: () => _impersonateUser(user),
                    );
                  },
                ),
              );
            },
            loading: () => Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.cyan,
                ),
              ),
            ),
            error: (_, _) => Text(
              'ไม่สามารถโหลดรายชื่อได้',
              style: AppTypography.bodySmall.copyWith(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _impersonateUser(DevUserInfo user) async {
    final success = await UserService().impersonateUser(user.id);

    if (!success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการสวมรอย'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Invalidate all service caches
    HomeService.instance.invalidateCache();
    ClockService.instance.invalidateCache();
    ShiftSummaryService.instance.invalidateCache();
    DDService.instance.invalidateCache();
    UserService().clearCache();

    // Invalidate role-related providers
    ref.invalidate(currentUserSystemRoleProvider);
    ref.invalidate(effectiveRoleFilterProvider);
    ref.invalidate(currentShiftProvider);
    ref.invalidate(userShiftProvider);

    // Increment user change counter to refresh Riverpod providers
    ref.read(userChangeCounterProvider.notifier).state++;

    // Reset role filter to use new user's role
    ref.read(selectedRoleFilterProvider.notifier).state = null;

    // Refresh tasks
    refreshTasks(ref);

    // Close drawer
    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('สวมรอยเป็น: ${user.displayName}'),
        backgroundColor: Colors.cyan,
      ),
    );
  }
}

/// Widget สำหรับแสดงแต่ละ user ใน list
class _UserListTile extends StatelessWidget {
  final DevUserInfo user;
  final bool isSelected;
  final VoidCallback onTap;

  const _UserListTile({
    required this.user,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyan.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Row(
          children: [
            // Avatar with clocked-in indicator
            Stack(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.cyan.shade100,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.cyan, width: 2)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? Image.network(
                            user.photoUrl!,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedUser,
                                size: AppIconSize.md,
                                color: Colors.cyan.shade700,
                              ),
                            ),
                          )
                        : Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedUser,
                              size: AppIconSize.md,
                              color: Colors.cyan.shade700,
                            ),
                          ),
                  ),
                ),
                // Clocked-in indicator (green dot)
                if (user.isClockedIn)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.horizontalGapMd,
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.nickname ?? '-',
                          style: AppTypography.body.copyWith(
                            color: Colors.cyan.shade900,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isClockedIn) ...[
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ขึ้นเวร',
                            style: AppTypography.caption.copyWith(
                              fontSize: 9,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (user.fullName != null)
                    Text(
                      user.fullName!,
                      style: AppTypography.caption.copyWith(
                        color: Colors.cyan.shade600,
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
                color: Colors.cyan,
              ),
          ],
        ),
      ),
    );
  }
}
