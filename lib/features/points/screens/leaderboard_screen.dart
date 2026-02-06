import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../widgets/my_points_tab.dart';
import '../widgets/rankings_tab.dart';
import '../widgets/my_rewards_tab.dart';

// LeaderboardScreen - หน้าคะแนนและอันดับ
// แบ่งเป็น 3 Tab: คะแนนของฉัน / อันดับ / รางวัล
// เข้าได้จาก Settings > "คะแนนของฉัน" หรือ Home > PointsSummaryCard

class LeaderboardScreen extends ConsumerStatefulWidget {
  final int? nursinghomeId;

  const LeaderboardScreen({
    super.key,
    this.nursinghomeId,
  });

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  // TabController สำหรับ 3 tab
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: IreneSecondaryAppBar(
        title: 'คะแนนและอันดับ',
        // TabBar ด้านล่าง AppBar
        bottom: TabBar(
          controller: _tabController,
          // สี indicator ตาม brand
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          // สี label (tab ที่เลือก)
          labelColor: AppColors.primary,
          labelStyle: AppTypography.label.copyWith(
            fontWeight: FontWeight.w600,
          ),
          // สี label (tab ที่ไม่ได้เลือก)
          unselectedLabelColor: AppColors.textSecondary,
          unselectedLabelStyle: AppTypography.label,
          // ขยายเต็มความกว้าง
          tabAlignment: TabAlignment.fill,
          // 3 tabs
          tabs: const [
            Tab(text: 'คะแนน'),
            Tab(text: 'อันดับ'),
            Tab(text: 'รางวัล'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: คะแนนของฉัน (ย้ายจาก screen เดิม + enhance)
          const MyPointsTab(),

          // Tab 2: อันดับ (leaderboard จริง — เห็นคนอื่น + podium top 3)
          RankingsTab(nursinghomeId: widget.nursinghomeId),

          // Tab 3: รางวัล (จาก period reward distributions)
          const MyRewardsTab(),
        ],
      ),
    );
  }
}
