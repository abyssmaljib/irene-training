import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../settings/screens/settings_screen.dart';

/// หน้าเช็คลิสต์ - รายการงาน
/// แสดง Routine และงานมอบหมาย แยกตามช่วงเวลา
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          IreneAppBar(
            title: 'เช็คลิสต์',
            onProfileTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          // TabBar as pinned header
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.secondaryText,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: 'งาน Routine'),
                  Tab(text: 'งานมอบหมาย'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRoutineTab(),
            _buildAssignedTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          AppSpacing.verticalGapMd,
          _buildTimeSection(
            icon: Iconsax.sun_1,
            title: 'เช้า (06:00-12:00)',
            color: AppColors.pastelYellow1,
            tasks: [
              _TaskItem(title: 'อาบน้ำ - คุณสมศรี', isNew: true),
              _TaskItem(title: 'ให้ยาเช้า - คุณสมศรี', isMedicine: true),
              _TaskItem(title: 'วัด Vital Signs - Zone A', isCompleted: true),
            ],
          ),
          AppSpacing.verticalGapMd,
          _buildTimeSection(
            icon: Iconsax.sun,
            title: 'เที่ยง (12:00-18:00)',
            color: AppColors.pastelOrange1,
            tasks: [
              _TaskItem(title: 'ให้ยาเที่ยง - คุณสมศรี', isMedicine: true),
              _TaskItem(title: 'ให้ยาเที่ยง - คุณประยุทธ์', isMedicine: true),
            ],
          ),
          AppSpacing.verticalGapMd,
          _buildTimeSection(
            icon: Iconsax.moon,
            title: 'เย็น (18:00-22:00)',
            color: AppColors.pastelLightGreen1,
            tasks: [
              _TaskItem(title: 'ให้ยาเย็น - คุณสมศรี', isMedicine: true),
            ],
          ),
          AppSpacing.verticalGapMd,
          _buildTimeSection(
            icon: Iconsax.cloud,
            title: 'ดึก (22:00-06:00)',
            color: AppColors.pastelDarkGreen1,
            tasks: [],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          AppSpacing.verticalGapMd,
          _buildTaskCard(_TaskItem(title: 'พาคุณสมศรีไปหาหมอ (14:00)', isNew: true)),
          AppSpacing.verticalGapSm,
          _buildTaskCard(_TaskItem(title: 'จัดยา - คุณประยุทธ์', isMedicine: true)),
          AppSpacing.verticalGapSm,
          _buildTaskCard(_TaskItem(title: 'รายงานอาการ - คุณสมชาย')),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Zone A', isSelected: true),
          AppSpacing.horizontalGapSm,
          _buildFilterChip('ทั้งหมด'),
          AppSpacing.horizontalGapSm,
          _buildFilterChip('เช้า'),
          AppSpacing.horizontalGapSm,
          _buildFilterChip('เที่ยง'),
          AppSpacing.horizontalGapSm,
          _buildFilterChip('เย็น'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false}) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {},
      selectedColor: AppColors.accent1,
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.secondaryText,
      ),
    );
  }

  Widget _buildTimeSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<_TaskItem> tasks,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: AppRadius.smallRadius,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textPrimary),
              AppSpacing.horizontalGapSm,
              Text(title, style: AppTypography.title.copyWith(fontSize: 14)),
            ],
          ),
        ),
        AppSpacing.verticalGapSm,
        if (tasks.isEmpty)
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: Text(
                'ไม่มีงานในช่วงนี้',
                style: AppTypography.body.copyWith(color: AppColors.secondaryText),
              ),
            ),
          )
        else
          ...tasks.map((task) => Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: _buildTaskCard(task),
          )),
      ],
    );
  }

  Widget _buildTaskCard(_TaskItem task) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: [AppShadows.subtle],
        border: task.isCompleted
            ? Border.all(color: AppColors.tagPassedBg, width: 2)
            : null,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: task.isCompleted ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: task.isCompleted ? AppColors.primary : AppColors.alternate,
                  width: 2,
                ),
              ),
              child: task.isCompleted
                  ? Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
          AppSpacing.horizontalGapMd,
          Expanded(
            child: Text(
              task.title,
              style: AppTypography.body.copyWith(
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? AppColors.secondaryText : AppColors.textPrimary,
              ),
            ),
          ),
          if (task.isNew)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.tagUpdateBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ใหม่',
                style: AppTypography.caption.copyWith(
                  color: AppColors.tagUpdateText,
                  fontSize: 10,
                ),
              ),
            ),
          if (task.isMedicine) ...[
            AppSpacing.horizontalGapSm,
            Icon(Iconsax.health, color: AppColors.tertiary, size: 18),
          ],
        ],
      ),
    );
  }
}

class _TaskItem {
  final String title;
  final bool isNew;
  final bool isMedicine;
  final bool isCompleted;

  _TaskItem({
    required this.title,
    this.isNew = false,
    this.isMedicine = false,
    this.isCompleted = false,
  });
}

/// Delegate for pinned TabBar in SliverPersistentHeader
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surface,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
