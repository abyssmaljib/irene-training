// หน้า List แสดงรายการ Incidents พร้อม Tab แบ่งตามสถานะ
// มี 2 tabs: รอดำเนินการ (รวม pending + in_progress), เสร็จสิ้น

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../models/incident.dart';
import '../providers/incident_provider.dart';
import '../widgets/incident_list_card.dart';
import 'incident_chat_screen.dart';

/// หน้ารายการ Incidents พร้อม Tab แบ่งตามสถานะ
class IncidentListScreen extends ConsumerStatefulWidget {
  const IncidentListScreen({super.key});

  @override
  ConsumerState<IncidentListScreen> createState() => _IncidentListScreenState();
}

class _IncidentListScreenState extends ConsumerState<IncidentListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tabs: 2 สถานะ (รวม pending + in_progress เป็น "รอดำเนินการ")
  final _tabs = [
    const _TabData(
      value: 'pending', // รวม pending + in_progress
      label: 'รอดำเนินการ',
      icon: HugeIcons.strokeRoundedClock01,
    ),
    const _TabData(
      value: 'completed',
      label: 'เสร็จสิ้น',
      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // อัปเดต selected tab ใน provider
      ref.read(selectedTabProvider.notifier).state =
          _tabs[_tabController.index].value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentsAsync = ref.watch(myIncidentsProvider);
    final counts = ref.watch(incidentCountsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: IreneSecondaryAppBar(
        title: 'ถอดบทเรียน',
        titleIcon: HugeIcons.strokeRoundedBrain,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTypography.body,
          tabs: _tabs.map((tab) {
            final count = counts[tab.value] ?? 0;
            return Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab.label),
                  if (count > 0) ...[
                    AppSpacing.horizontalGapXs,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _getCountBadgeColor(tab.value),
                        borderRadius: AppRadius.fullRadius,
                      ),
                      child: Text(
                        '$count',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: incidentsAsync.when(
        data: (incidents) {
          return TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) {
              // Filter incidents ตาม tab
              // tab "pending" รวม pending + in_progress
              final filtered = incidents.where((i) {
                if (tab.value == 'pending') {
                  return i.reflectionStatus.value == 'pending' ||
                      i.reflectionStatus.value == 'in_progress';
                }
                return i.reflectionStatus.value == tab.value;
              }).toList();
              return _buildIncidentList(filtered, tab.value);
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(error.toString()),
      ),
    );
  }

  /// สร้าง list ของ incidents
  /// Wrap ทั้ง list และ empty state ด้วย RefreshIndicator เพื่อให้ pull to refresh ได้เสมอ
  Widget _buildIncidentList(List<Incident> incidents, String tabValue) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(refreshIncidentsProvider)();
      },
      child: incidents.isEmpty
          ? _buildEmptyScrollable(tabValue)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              // เพิ่ม AlwaysScrollableScrollPhysics เพื่อให้ pull to refresh ทำงานได้
              // แม้ content จะไม่เต็มหน้าจอ
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: incidents.length,
              itemBuilder: (context, index) {
                final incident = incidents[index];
                return IncidentListCard(
                  incident: incident,
                  onTap: () => _openChatScreen(incident),
                );
              },
            ),
    );
  }

  /// เปิดหน้า chat
  void _openChatScreen(Incident incident) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncidentChatScreen(incident: incident),
      ),
    ).then((_) {
      // Refresh list เมื่อกลับมา
      ref.invalidate(myIncidentsProvider);
    });
  }

  /// Empty state ที่ scrollable ได้ เพื่อให้ RefreshIndicator ทำงาน
  Widget _buildEmptyScrollable(String tabValue) {
    String message;
    dynamic icon;

    switch (tabValue) {
      case 'pending':
        // รวม pending + in_progress แล้ว
        message = 'ไม่มีรายการที่รอดำเนินการ';
        icon = HugeIcons.strokeRoundedCheckmarkCircle02;
        break;
      case 'completed':
        message = 'ยังไม่มีรายการที่เสร็จสิ้น';
        icon = HugeIcons.strokeRoundedTaskDone01;
        break;
      default:
        message = 'ไม่มีรายการ';
        icon = HugeIcons.strokeRoundedInbox;
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                size: AppIconSize.display,
                color: AppColors.alternate,
              ),
              AppSpacing.verticalGapMd,
              Text(
                message,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Error state
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: AppIconSize.display,
            color: AppColors.error,
          ),
          AppSpacing.verticalGapMd,
          Text(
            'เกิดข้อผิดพลาด',
            style: AppTypography.title,
          ),
          AppSpacing.verticalGapSm,
          Padding(
            padding: AppSpacing.paddingHorizontalMd,
            child: Text(
              error,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          AppSpacing.verticalGapLg,
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(myIncidentsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// สีของ badge count ตาม tab
  Color _getCountBadgeColor(String tabValue) {
    switch (tabValue) {
      case 'pending':
        return AppColors.warning; // รวม pending + in_progress
      case 'completed':
        return AppColors.primary;
      default:
        return AppColors.secondaryText;
    }
  }
}

/// Data class สำหรับ Tab
class _TabData {
  final String value;
  final String label;
  final dynamic icon;

  const _TabData({
    required this.value,
    required this.label,
    required this.icon,
  });
}
