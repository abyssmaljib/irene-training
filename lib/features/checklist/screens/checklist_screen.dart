import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../home/models/zone.dart';
import '../../home/models/clock_in_out.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/resident_simple.dart';
import '../models/task_log.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';
import '../widgets/task_time_section.dart';
import '../widgets/task_filter_drawer.dart';
import '../services/task_realtime_service.dart';
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

    final viewMode = ref.watch(taskViewModeProvider);
    final filteredTasksAsync = ref.watch(filteredTasksProvider);
    final groupedTasksAsync = ref.watch(groupedTasksProvider);
    final taskCounts = ref.watch(taskCountsProvider);
    final zonesAsync = ref.watch(nursinghomeZonesProvider);
    final selectedZones = ref.watch(selectedZonesFilterProvider);
    final filteredResidentsAsync = ref.watch(filteredResidentsProvider);
    final selectedResidents = ref.watch(selectedResidentsFilterProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const TaskFilterDrawer(),
      body: NestedScrollView(
        // ให้ header float กลับมาทันทีเมื่อ scroll ขึ้น
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          IreneAppBar(
            title: 'เช็คลิสต์',
            showFilterButton: true,
            isFilterActive: viewMode != TaskViewMode.upcoming,
            filterCount: ref.watch(myRolePendingTasksCountProvider),
            onFilterTap: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            onProfileTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            trailing: _buildViewModeToggle(viewMode),
          ),
          // Zone filter chips - floating header
          SliverPersistentHeader(
            floating: true,
            delegate: _FilterBarDelegate(
              child: _buildZoneFilterBar(zonesAsync, selectedZones),
              height: 52,
            ),
          ),
          // Resident filter chips (แสดงเมื่อเลือก zone) - dynamic height
          SliverToBoxAdapter(
            child: _buildResidentFilterBar(filteredResidentsAsync, selectedResidents),
          ),
          // Current view mode header - pinned at top
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(
              child: _buildViewModeHeader(viewMode, taskCounts),
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
              ? _buildGroupedTaskList(groupedTasksAsync)
              : _buildFilteredTaskList(filteredTasksAsync, viewMode),
        ),
      ),
    );
  }

  Widget _buildZoneFilterBar(
      AsyncValue<List<Zone>> zonesAsync, Set<int> selectedZones) {
    final currentShiftAsync = ref.watch(currentShiftProvider);
    final isMyPatientsActive = ref.watch(myPatientsFilterActiveProvider);
    // ดึง residents ทั้งหมดเพื่อหา zones จาก residents ที่ user รับผิดชอบ
    final allResidentsAsync = ref.watch(nursinghomeResidentsProvider);

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: AppColors.surface,
      child: zonesAsync.when(
        data: (zones) {
          if (zones.isEmpty) {
            // ไม่มี zone - แสดง "ทั้งหมด"
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

          // เรียง zones ตามตัวอักษร
          final sortedZones = List<Zone>.from(zones)
            ..sort((a, b) => a.name.compareTo(b.name));

          // ตรวจสอบว่า user clock in อยู่หรือไม่
          final currentShift = currentShiftAsync.valueOrNull;
          final isClockedIn = currentShift?.isClockedIn ?? false;

          // มี zones - แสดง filter chips
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
                          // ส่ง allResidents เพื่อหา zones จาก residents ที่ user รับผิดชอบ
                          final allResidents = allResidentsAsync.valueOrNull ?? [];
                          _toggleMyPatientsFilter(currentShift!, allResidents);
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
                        // Clear ทั้ง zones, residents และ myPatients filter
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
                // Zone chips - แสดงชื่อ zone จาก nursinghome_zone (เรียงตามตัวอักษร)
                ...sortedZones.map((zone) => Padding(
                      padding: EdgeInsets.only(right: AppSpacing.sm),
                      child: SizedBox(
                        height: 35,
                        child: FilterChip(
                          label: Text(zone.name),
                          selected: selectedZones.contains(zone.id),
                          onSelected: (selected) {
                            // ปิด myPatients filter เมื่อเลือก zone อื่น
                            ref.read(myPatientsFilterActiveProvider.notifier).state = false;

                            final currentZones =
                                ref.read(selectedZonesFilterProvider);
                            if (selected) {
                              ref
                                  .read(selectedZonesFilterProvider.notifier)
                                  .state = {...currentZones, zone.id};
                            } else {
                              ref
                                  .read(selectedZonesFilterProvider.notifier)
                                  .state = currentZones
                                      .where((z) => z != zone.id)
                                      .toSet();
                              // Clear residents selection เมื่อ unselect zone
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
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }

  /// Toggle "คนไข้ของฉัน" filter
  /// รับ residents ทั้งหมดเพื่อหา zones จาก residents ที่ user รับผิดชอบ
  void _toggleMyPatientsFilter(ClockInOut currentShift, List<ResidentSimple> allResidents) {
    final isActive = ref.read(myPatientsFilterActiveProvider);

    if (isActive) {
      // ปิด filter - กลับไป "ทั้งหมด"
      ref.read(myPatientsFilterActiveProvider.notifier).state = false;
      ref.read(selectedZonesFilterProvider.notifier).state = {};
      ref.read(selectedResidentsFilterProvider.notifier).state = {};
    } else {
      // เปิด filter - set zones และ residents จาก current shift
      ref.read(myPatientsFilterActiveProvider.notifier).state = true;

      // *** สำคัญ: หา zones จาก residents ที่ user รับผิดชอบ ***
      // เพราะผู้พักอาจอยู่หลายโซน ไม่ใช่แค่โซนที่เลือกตอน clock in
      final selectedResidentIds = currentShift.selectedResidentIdList.toSet();
      final zonesFromResidents = getZonesFromResidentIds(allResidents, selectedResidentIds);

      // ถ้าหา zones จาก residents ได้ ใช้ค่านั้น ไม่งั้นใช้ zones จาก shift
      final zonesToUse = zonesFromResidents.isNotEmpty
          ? zonesFromResidents
          : currentShift.zones.toSet();

      ref.read(selectedZonesFilterProvider.notifier).state = zonesToUse;
      ref.read(selectedResidentsFilterProvider.notifier).state = selectedResidentIds;
    }
  }

  Widget _buildResidentFilterBar(
      AsyncValue<List<ResidentSimple>> residentsAsync, Set<int> selectedResidents) {
    return residentsAsync.when(
      data: (residents) {
        if (residents.isEmpty) {
          // ไม่มี residents (ยังไม่ได้เลือก zone) - ไม่แสดงอะไร
          return const SizedBox.shrink();
        }

        // แสดง resident filter chips ด้วย Wrap เพื่อให้เห็นทั้งหมด
        return Container(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.xs,
          ),
          color: AppColors.surface,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              // "ทั้งหมด" chip
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
              // Resident chips (เรียงตามชื่อแล้วจาก provider)
              ...residents.map((resident) => SizedBox(
                    height: 28,
                    child: FilterChip(
                      label: Text('คุณ${resident.name}'),
                      selected: selectedResidents.contains(resident.id),
                      showCheckmark: false,
                      onSelected: (selected) {
                        final current =
                            ref.read(selectedResidentsFilterProvider);
                        if (selected) {
                          ref
                              .read(selectedResidentsFilterProvider.notifier)
                              .state = {...current, resident.id};
                        } else {
                          ref
                              .read(selectedResidentsFilterProvider.notifier)
                              .state = current
                                  .where((r) => r != resident.id)
                                  .toSet();
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

  Widget _buildViewModeHeader(
      TaskViewMode viewMode, Map<TaskViewMode, int> taskCounts) {
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
                Text(
                  viewMode.label,
                  style: AppTypography.title,
                ),
                Text(
                  viewMode.description,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          // Task count
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

  /// Toggle button สำหรับเปลี่ยนมุมมอง (View Mode) ที่มุมขวาของ AppBar
  /// กดแล้ววนไปมุมมองถัดไป: upcoming -> all -> problem -> myDone -> upcoming ...
  Widget _buildViewModeToggle(TaskViewMode currentMode) {
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

  Widget _buildFilteredTaskList(
      AsyncValue<List<TaskLog>> tasksAsync, TaskViewMode viewMode) {
    final currentUserId = ref.watch(currentUserIdProvider);

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return _buildEmptyState(viewMode);
        }

        return ListView.builder(
          padding: EdgeInsets.all(AppSpacing.md),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Padding(
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
      loading: () => const Center(child: CircularProgressIndicator()),
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

  Widget _buildGroupedTaskList(
      AsyncValue<Map<String, List<TaskLog>>> groupedTasksAsync) {
    final currentUserId = ref.watch(currentUserIdProvider);

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
          itemCount: sortedTimeBlocks.length,
          // Optimize: cache nearby items เพื่อลดการ rebuild เมื่อ scroll
          cacheExtent: 100,
          // Optimize: ใช้ addAutomaticKeepAlives เพื่อเก็บ state ของ items
          addAutomaticKeepAlives: true,
          itemBuilder: (context, index) {
            final timeBlock = sortedTimeBlocks[index];
            final tasks = groupedTasks[timeBlock]!;

            return RepaintBoundary(
              child: TaskTimeSection(
                timeBlock: timeBlock,
                tasks: tasks,
                isExpanded: _expandedTimeBlock == timeBlock,
                currentUserId: currentUserId,
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
