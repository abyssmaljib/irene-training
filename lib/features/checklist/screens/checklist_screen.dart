import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../home/models/zone.dart';
import '../../home/models/clock_in_out.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/batch_task_group.dart';
import '../models/resident_simple.dart';
import '../models/task_log.dart';
import '../providers/task_provider.dart';
import '../widgets/batch_task_card.dart';
import '../widgets/task_card.dart';
import '../widgets/task_time_section.dart';
import '../widgets/task_filter_drawer.dart';
import '../services/task_realtime_service.dart';
import 'batch_task_screen.dart';
import 'task_detail_screen.dart';

/// หน้าเช็คลิสต์ - รายการงาน
/// แสดง Tasks ตาม view mode (งานถัดไป, ทั้งหมด, ติดปัญหา, ที่เราติ๊ก)
class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key});

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// ติดตามว่า timeBlock ไหนกำลังเปิดอยู่ (accordion behavior)
  String? _expandedTimeBlock;

  /// ProviderContainer สำหรับ realtime callback (ไม่ใช้ ref หลัง dispose)
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    // Subscribe to realtime updates will be done in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get container once and subscribe
    if (_container == null) {
      _container = ProviderScope.containerOf(context);
      _subscribeToRealtimeUpdates();
    }
  }

  @override
  void dispose() {
    // Unsubscribe from all channels when leaving the screen
    TaskRealtimeService.instance.unsubscribeAll();
    _container = null;
    super.dispose();
  }

  void _subscribeToRealtimeUpdates() {
    final container = _container;
    if (container == null) return;

    TaskRealtimeService.instance.subscribe(
      onTaskUpdated: () {
        // Refresh tasks when other NA updates a task
        // ใช้ container แทน ref เพื่อหลีกเลี่ยง disposed ref error
        if (mounted && _container != null) {
          refreshTasksWithContainer(_container!);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Auto-initialize "คนไข้ของฉัน" filter เมื่อ user clock in อยู่
    ref.watch(initMyPatientsFilterProvider);

    // watch เฉพาะ viewMode ที่จำเป็นสำหรับ body switching
    // ส่วน filter bars และ header แยกเป็น ConsumerWidget ย่อย
    // เพื่อลด rebuild scope — เมื่อ filter เปลี่ยน จะ rebuild เฉพาะส่วนที่เกี่ยว
    final viewMode = ref.watch(taskViewModeProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const TaskFilterDrawer(),
      body: NestedScrollView(
        // ให้ header float กลับมาทันทีเมื่อ scroll ขึ้น
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // AppBar — แยกเป็น ConsumerWidget เพื่อ watch provider ของตัวเอง
          _ChecklistAppBar(
            scaffoldKey: _scaffoldKey,
            onSettingsTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          // Zone filter chips - floating header (ConsumerWidget แยก)
          SliverPersistentHeader(
            floating: true,
            delegate: _FilterBarDelegate(
              child: const _ChecklistZoneFilterBar(),
              height: 52,
            ),
          ),
          // Resident filter chips (ConsumerWidget แยก)
          const SliverToBoxAdapter(
            child: _ChecklistResidentFilterBar(),
          ),
          // Current view mode header (ConsumerWidget แยก)
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(
              child: const _ChecklistViewModeHeader(),
              height: 72,
            ),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: () async {
            refreshTasks(ref);
            // Wait for reload
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: viewMode == TaskViewMode.all
              ? _buildGroupedTaskList()
              : _buildFilteredTaskList(viewMode),
        ),
      ),
    );
  }

  Widget _buildFilteredTaskList(TaskViewMode viewMode) {
    final tasksAsync = ref.watch(filteredTasksProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    // ดึง batch mixed list (null ถ้า batch mode ปิด)
    final batchMixedAsync = ref.watch(filteredBatchMixedProvider);

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return _buildEmptyState(viewMode);
        }

        // ถ้า batch mode เปิด + มี batchItems → render mixed list
        final batchItems = batchMixedAsync?.valueOrNull;
        if (batchItems != null && batchItems.isNotEmpty) {
          return ListView.builder(
            padding: EdgeInsets.all(AppSpacing.md),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: batchItems.length,
            cacheExtent: 200,
            itemBuilder: (context, index) {
              final item = batchItems[index];
              return Padding(
                key: ValueKey(item.isBatch
                    ? 'batch_${item.batchGroup!.groupKey}'
                    : 'task_${item.singleTask!.logId}'),
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: item.isBatch
                    // BatchTaskCard สำหรับ task ที่มี 2+ คนไข้
                    ? BatchTaskCard(
                        group: item.batchGroup!,
                        onTap: () => _onBatchGroupTap(item.batchGroup!),
                      )
                    // TaskCard เดี่ยวสำหรับ task ที่มีคนไข้เดียว
                    : TaskCard(
                        task: item.singleTask!,
                        currentUserId: currentUserId,
                        onTap: () => _onTaskTap(item.singleTask!),
                      ),
              );
            },
          );
        }

        // batch mode ปิด → render flat TaskCard เหมือนเดิม
        return ListView.builder(
          padding: EdgeInsets.all(AppSpacing.md),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: tasks.length,
          cacheExtent: 200,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Padding(
              key: ValueKey(task.logId),
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: TaskCard(
                task: task,
                currentUserId: currentUserId,
                onTap: () => _onTaskTap(task),
              ),
            );
          },
        );
      },
      loading: () => ShimmerWrapper(
        isLoading: true,
        child: Column(
          children: List.generate(5, (_) => const SkeletonListItem()),
        ),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedAlert02,
                size: 48, color: AppColors.error.withValues(alpha: 0.5)),
            AppSpacing.verticalGapMd,
            Text(
              'ไม่สามารถโหลดข้อมูลได้',
              style: AppTypography.body.copyWith(color: AppColors.error),
            ),
            AppSpacing.verticalGapSm,
            TextButton.icon(
              onPressed: () => refreshTasks(ref),
              icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedTaskList() {
    final groupedTasksAsync = ref.watch(groupedTasksProvider);
    final isBatchMode = ref.watch(batchModeEnabledProvider);
    final batchGroupedAsync = isBatchMode
        ? ref.watch(batchGroupedTasksProvider)
        : null;
    final currentUserId = ref.watch(currentUserIdProvider);

    // ถ้ามี batch data → ดึง batch items สำหรับแต่ละ timeBlock
    final batchData = batchGroupedAsync?.valueOrNull;

    return groupedTasksAsync.when(
      data: (groupedTasks) {
        if (groupedTasks.isEmpty) {
          return _buildEmptyState(TaskViewMode.all);
        }

        // Sort time blocks
        final sortedTimeBlocks = groupedTasks.keys.toList()
          ..sort((a, b) => _timeBlockOrder(a).compareTo(_timeBlockOrder(b)));

        return ListView.builder(
          padding: EdgeInsets.all(AppSpacing.md),
          // เพิ่ม AlwaysScrollableScrollPhysics เพื่อให้ pull to refresh ทำงานได้
          // แม้ content จะไม่เต็มหน้าจอ
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: sortedTimeBlocks.length,
          // Optimize: cache nearby items เพื่อลดการ rebuild เมื่อ scroll
          cacheExtent: 100,
          // ปิด addAutomaticKeepAlives เพื่อประหยัด memory บนมือถือ spec ต่ำ
          // (default = true จะเก็บทุก item ไว้ใน memory แม้ offscreen)
          addAutomaticKeepAlives: false,
          itemBuilder: (context, index) {
            final timeBlock = sortedTimeBlocks[index];
            final tasks = groupedTasks[timeBlock]!;

            return RepaintBoundary(
              // Key ช่วยให้ Flutter reuse TimeSection ตาม timeBlock
              key: ValueKey(timeBlock),
              child: TaskTimeSection(
                timeBlock: timeBlock,
                tasks: tasks,
                isExpanded: _expandedTimeBlock == timeBlock,
                currentUserId: currentUserId,
                // Batch mode: ส่ง batchItems ให้ TaskTimeSection render mixed list
                batchItems: batchData?[timeBlock],
                onBatchGroupTap: _onBatchGroupTap,
                onExpandChanged: () {
                  setState(() {
                    // Accordion behavior: ถ้ากดที่เปิดอยู่ = ปิด, ถ้ากดอันอื่น = เปิดอันใหม่
                    if (_expandedTimeBlock == timeBlock) {
                      _expandedTimeBlock = null;
                    } else {
                      _expandedTimeBlock = timeBlock;
                    }
                  });
                },
                onTaskTap: _onTaskTap,
              ),
            );
          },
        );
      },
      loading: () => ShimmerWrapper(
        isLoading: true,
        child: Column(
          children: List.generate(5, (_) => const SkeletonListItem()),
        ),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedAlert02,
                size: 48, color: AppColors.error.withValues(alpha: 0.5)),
            AppSpacing.verticalGapMd,
            Text(
              'ไม่สามารถโหลดข้อมูลได้',
              style: AppTypography.body.copyWith(color: AppColors.error),
            ),
            AppSpacing.verticalGapSm,
            TextButton.icon(
              onPressed: () => refreshTasks(ref),
              icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  int _timeBlockOrder(String timeBlock) {
    // Parse time from timeBlock like "07:00 - 09:00"
    // วันเริ่มที่ 07:00 (เวรเช้า) ไม่ใช่ 00:00
    // ลำดับ: 07:00 -> 09:00 -> 11:00 -> ... -> 23:00 -> 01:00 -> 03:00 -> 05:00
    final match = RegExp(r'(\d{2}):(\d{2})').firstMatch(timeBlock);
    if (match != null) {
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);

      // Shift hours: 07:00 = 0, 09:00 = 2, ..., 05:00 = 22
      // ถ้า hour >= 7 ให้ลบ 7, ถ้า hour < 7 ให้บวก 17 (24-7)
      final adjustedHour = hour >= 7 ? hour - 7 : hour + 17;
      return adjustedHour * 60 + minute;
    }
    return 9999; // Unknown time blocks at the end
  }

  Widget _buildEmptyState(TaskViewMode viewMode) {
    String message;

    switch (viewMode) {
      case TaskViewMode.upcoming:
        message = 'ไม่พบงานที่คุณกรองในอีก 2 ชั่วโมงข้างหน้า';
        break;
      case TaskViewMode.all:
        message = 'ไม่มีงานในวันนี้';
        break;
      case TaskViewMode.problem:
        message = 'ไม่มีงานที่ติดปัญหา';
        break;
      case TaskViewMode.myDone:
        message = 'คุณยังไม่ได้ทำงานใดๆ';
        break;
    }

    return EmptyStateWidget(
      message: message,
      imageSize: 240,
      action: viewMode == TaskViewMode.upcoming
          ? TextButton(
              onPressed: () {
                ref.read(taskViewModeProvider.notifier).state = TaskViewMode.all;
              },
              child: const Text('ดูงานทั้งหมด'),
            )
          : null,
    );
  }

  void _onTaskTap(TaskLog task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(task: task),
      ),
    );
  }

  /// เปิดหน้า BatchTaskScreen เมื่อกด BatchTaskCard
  void _onBatchGroupTap(BatchTaskGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BatchTaskScreen(group: group),
      ),
    );
  }
}

// ============================================================
// แยก ConsumerWidget ย่อย เพื่อลด rebuild scope
// แต่ละ widget watch เฉพาะ provider ที่ตัวเองต้องการ
// ============================================================

/// Helper: คืน icon ตาม ViewMode
dynamic _getViewModeIcon(TaskViewMode mode) {
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

/// AppBar — watch เฉพาะ viewMode, pendingCount
/// rebuild เฉพาะเมื่อ viewMode หรือ badge count เปลี่ยน
class _ChecklistAppBar extends ConsumerWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback onSettingsTap;

  const _ChecklistAppBar({
    required this.scaffoldKey,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(taskViewModeProvider);
    final pendingCount = ref.watch(myRolePendingTasksCountProvider);

    return IreneAppBar(
      title: 'เช็คลิสต์',
      showFilterButton: true,
      isFilterActive: viewMode != TaskViewMode.upcoming,
      filterCount: pendingCount,
      onFilterTap: () {
        scaffoldKey.currentState?.openDrawer();
      },
      onProfileTap: onSettingsTap,
      trailing: _ViewModeToggle(currentMode: viewMode),
    );
  }
}

/// Toggle button สำหรับเปลี่ยน ViewMode
/// แยกออกมาเพราะไม่ต้อง rebuild ทั้ง AppBar เมื่อ viewMode เปลี่ยน
class _ViewModeToggle extends ConsumerWidget {
  final TaskViewMode currentMode;

  const _ViewModeToggle({required this.currentMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.accent1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          // วนไปมุมมองถัดไป
          final modes = TaskViewMode.values;
          final currentIndex = modes.indexOf(currentMode);
          final nextIndex = (currentIndex + 1) % modes.length;
          ref.read(taskViewModeProvider.notifier).state = modes[nextIndex];
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: HugeIcon(
            icon: _getViewModeIcon(currentMode),
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Zone filter bar — watch เฉพาะ zones, selectedZones, shift, myPatients
/// rebuild เฉพาะเมื่อ zone selection หรือ shift เปลี่ยน
class _ChecklistZoneFilterBar extends ConsumerWidget {
  const _ChecklistZoneFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(nursinghomeZonesProvider);
    final selectedZones = ref.watch(selectedZonesFilterProvider);
    final currentShiftAsync = ref.watch(currentShiftProvider);
    final isMyPatientsActive = ref.watch(myPatientsFilterActiveProvider);
    final allResidentsAsync = ref.watch(nursinghomeResidentsProvider);

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: AppColors.surface,
      child: zonesAsync.when(
        data: (zones) {
          if (zones.isEmpty) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('ทั้งหมด'),
                    selected: true,
                    onSelected: (_) {},
                    selectedColor: AppColors.accent1,
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            );
          }

          final sortedZones = List<Zone>.from(zones)
            ..sort((a, b) => a.name.compareTo(b.name));

          final currentShift = currentShiftAsync.valueOrNull;
          final isClockedIn = currentShift?.isClockedIn ?? false;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "คนไข้ของฉัน" chip - แสดงเฉพาะเมื่อ clock in แล้ว
                if (isClockedIn) ...[
                  Padding(
                    padding: EdgeInsets.only(right: AppSpacing.sm),
                    child: SizedBox(
                      height: 35,
                      child: FilterChip(
                        label: const Text('คนไข้ของฉัน'),
                        selected: isMyPatientsActive,
                        onSelected: (_) {
                          final allResidents = allResidentsAsync.valueOrNull ?? [];
                          _toggleMyPatientsFilter(ref, currentShift!, allResidents);
                        },
                        selectedColor: AppColors.accent1,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isMyPatientsActive
                              ? AppColors.primary
                              : AppColors.secondaryText,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
                // "ทั้งหมด" chip
                Padding(
                  padding: EdgeInsets.only(right: AppSpacing.sm),
                  child: SizedBox(
                    height: 35,
                    child: FilterChip(
                      label: const Text('ทั้งหมด'),
                      selected: selectedZones.isEmpty && !isMyPatientsActive,
                      onSelected: (_) {
                        ref.read(selectedZonesFilterProvider.notifier).state = {};
                        ref.read(selectedResidentsFilterProvider.notifier).state = {};
                        ref.read(myPatientsFilterActiveProvider.notifier).state = false;
                      },
                      selectedColor: AppColors.accent1,
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: (selectedZones.isEmpty && !isMyPatientsActive)
                            ? AppColors.primary
                            : AppColors.secondaryText,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                // Zone chips
                ...sortedZones.map((zone) => Padding(
                      padding: EdgeInsets.only(right: AppSpacing.sm),
                      child: SizedBox(
                        height: 35,
                        child: FilterChip(
                          label: Text(zone.name),
                          selected: selectedZones.contains(zone.id),
                          onSelected: (selected) {
                            ref.read(myPatientsFilterActiveProvider.notifier).state = false;
                            final currentZones = ref.read(selectedZonesFilterProvider);
                            if (selected) {
                              ref.read(selectedZonesFilterProvider.notifier).state =
                                  {...currentZones, zone.id};
                            } else {
                              ref.read(selectedZonesFilterProvider.notifier).state =
                                  currentZones.where((z) => z != zone.id).toSet();
                              ref.read(selectedResidentsFilterProvider.notifier).state = {};
                            }
                          },
                          selectedColor: AppColors.accent1,
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: selectedZones.contains(zone.id)
                                ? AppColors.primary
                                : AppColors.secondaryText,
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    )),
              ],
            ),
          );
        },
        loading: () => const SizedBox(
          height: 32,
          child: Center(
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }

  /// Toggle "คนไข้ของฉัน" filter
  void _toggleMyPatientsFilter(WidgetRef ref, ClockInOut currentShift, List<ResidentSimple> allResidents) {
    final isActive = ref.read(myPatientsFilterActiveProvider);

    if (isActive) {
      ref.read(myPatientsFilterActiveProvider.notifier).state = false;
      ref.read(selectedZonesFilterProvider.notifier).state = {};
      ref.read(selectedResidentsFilterProvider.notifier).state = {};
    } else {
      ref.read(myPatientsFilterActiveProvider.notifier).state = true;

      final selectedResidentIds = currentShift.selectedResidentIdList.toSet();
      final zonesFromResidents = getZonesFromResidentIds(allResidents, selectedResidentIds);

      final zonesToUse = zonesFromResidents.isNotEmpty
          ? zonesFromResidents
          : currentShift.zones.toSet();

      ref.read(selectedZonesFilterProvider.notifier).state = zonesToUse;
      ref.read(selectedResidentsFilterProvider.notifier).state = selectedResidentIds;
    }
  }
}

/// Resident filter bar — watch เฉพาะ filteredResidents, selectedResidents
/// rebuild เฉพาะเมื่อ resident selection หรือ zone เปลี่ยน
class _ChecklistResidentFilterBar extends ConsumerWidget {
  const _ChecklistResidentFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final residentsAsync = ref.watch(filteredResidentsProvider);
    final selectedResidents = ref.watch(selectedResidentsFilterProvider);

    return residentsAsync.when(
      data: (residents) {
        if (residents.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: EdgeInsets.only(
            left: AppSpacing.md, right: AppSpacing.md, bottom: AppSpacing.xs,
          ),
          color: AppColors.surface,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              SizedBox(
                height: 28,
                child: FilterChip(
                  label: const Text('ทั้งหมด'),
                  selected: selectedResidents.isEmpty,
                  onSelected: (_) {
                    ref.read(selectedResidentsFilterProvider.notifier).state = {};
                  },
                  selectedColor: AppColors.pastelLightGreen1,
                  checkmarkColor: AppColors.tagPassedText,
                  labelStyle: TextStyle(
                    color: selectedResidents.isEmpty
                        ? AppColors.tagPassedText
                        : AppColors.secondaryText,
                    fontSize: 12,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              ...residents.map((resident) => SizedBox(
                    height: 28,
                    child: FilterChip(
                      label: Text('คุณ${resident.name}'),
                      selected: selectedResidents.contains(resident.id),
                      showCheckmark: false,
                      onSelected: (selected) {
                        final current = ref.read(selectedResidentsFilterProvider);
                        if (selected) {
                          ref.read(selectedResidentsFilterProvider.notifier).state =
                              {...current, resident.id};
                        } else {
                          ref.read(selectedResidentsFilterProvider.notifier).state =
                              current.where((r) => r != resident.id).toSet();
                        }
                      },
                      selectedColor: AppColors.pastelLightGreen1,
                      labelStyle: TextStyle(
                        color: selectedResidents.contains(resident.id)
                            ? AppColors.tagPassedText
                            : AppColors.secondaryText,
                        fontSize: 12,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  )),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// View mode header — watch เฉพาะ viewMode, taskCounts
/// rebuild เฉพาะเมื่อ viewMode หรือ task counts เปลี่ยน
class _ChecklistViewModeHeader extends ConsumerWidget {
  const _ChecklistViewModeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(taskViewModeProvider);
    final taskCounts = ref.watch(taskCountsProvider);

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [AppShadows.subtle],
      ),
      child: Row(
        children: [
          HugeIcon(icon: _getViewModeIcon(viewMode), color: AppColors.primary, size: AppIconSize.lg),
          AppSpacing.horizontalGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(viewMode.label, style: AppTypography.title),
                Text(
                  viewMode.description,
                  style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent1,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${taskCounts[viewMode] ?? 0}',
              style: AppTypography.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Delegate สำหรับ SliverPersistentHeader ของ filter bars
class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _FilterBarDelegate({
    required this.child,
    required this.height,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
