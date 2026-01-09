import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../board/providers/create_post_provider.dart';
import '../../board/screens/advanced_create_post_screen.dart';
import '../../shift_summary/screens/shift_summary_screen.dart';
import '../models/dd_record.dart';
import '../providers/dd_provider.dart';
import '../widgets/dd_card.dart';

/// หน้ารายการ DD - มี 2 tabs: ยังไม่ได้ทำ / ทำแล้ว
class DDListScreen extends ConsumerStatefulWidget {
  const DDListScreen({super.key});

  @override
  ConsumerState<DDListScreen> createState() => _DDListScreenState();
}

class _DDListScreenState extends ConsumerState<DDListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    refreshDDRecords(ref);
    await ref.read(ddRecordsProvider.future);
  }

  void _onCardTap(DDRecord record) {
    // Init create post provider with DD data
    ref.read(createPostProvider.notifier).initFromDD(
          ddId: record.ddId,
          templateText: record.templateText,
          residentId: record.appointmentResidentId,
          residentName: record.appointmentResidentName,
          title: record.templateTitle,
        );

    // Navigate to advanced create post
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdvancedCreatePostScreen(),
      ),
    ).then((_) {
      // Refresh when returning
      refreshDDRecords(ref);
    });
  }

  void _onCompletedCardTap(DDRecord record) {
    // Navigate to shift summary with highlight
    final dt = record.appointmentDatetime;
    if (dt == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShiftSummaryScreen(
          highlightDDRecordId: record.ddId,
          autoOpenMonth: dt.month,
          autoOpenYear: dt.year,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: IreneSecondaryAppBar(
        title: 'งาน DD',
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primary,
          labelStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTypography.body,
          tabs: const [
            Tab(text: 'ยังไม่ได้ทำ'),
            Tab(text: 'ทำแล้ว'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildCompletedTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    final recordsAsync = ref.watch(pendingDDRecordsProvider);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: recordsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => _buildErrorState(error.toString()),
        data: (records) {
          if (records.isEmpty) {
            return _buildEmptyState('ไม่มีงาน DD ที่รอทำ');
          }
          return _buildRecordList(records, showCreateHint: true);
        },
      ),
    );
  }

  Widget _buildCompletedTab() {
    final recordsAsync = ref.watch(completedDDRecordsProvider);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: recordsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => _buildErrorState(error.toString()),
        data: (records) {
          if (records.isEmpty) {
            return _buildEmptyState('ยังไม่มีงาน DD ที่ทำเสร็จ');
          }
          return _buildRecordList(records, showCreateHint: false);
        },
      ),
    );
  }

  Widget _buildRecordList(List<DDRecord> records, {required bool showCreateHint}) {
    // หา upcoming record (รายการที่ใกล้เวลานัดที่สุดในอนาคต)
    final now = DateTime.now();
    int? upcomingIndex;

    if (showCreateHint && records.isNotEmpty) {
      // หารายการที่ใกล้จะถึงที่สุด (เรียงจาก latest แล้ว หารายการแรกที่ยังไม่ผ่าน)
      for (int i = records.length - 1; i >= 0; i--) {
        final dt = records[i].appointmentDatetime;
        if (dt != null && dt.isAfter(now)) {
          upcomingIndex = i;
          break;
        }
      }
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.md),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final dt = record.appointmentDatetime;
        // isOverdue: เลยเวลาแล้วและยังไม่ได้ทำ (เฉพาะ tab "ยังไม่ได้ทำ")
        final isOverdue = showCreateHint &&
            dt != null &&
            dt.isBefore(now) &&
            !record.isCompleted;

        return DDCard(
          record: record,
          showCreatePostHint: showCreateHint,
          isUpcoming: index == upcomingIndex,
          isOverdue: isOverdue,
          onTap: record.isCompleted
              ? () => _onCompletedCardTap(record)
              : () => _onCardTap(record),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return EmptyStateWidget(message: message);
  }

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
          SizedBox(height: AppSpacing.md),
          Text(
            'เกิดข้อผิดพลาด',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _onRefresh,
            child: Text(
              'ลองใหม่',
              style: AppTypography.body.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
