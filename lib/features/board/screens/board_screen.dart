import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../settings/screens/settings_screen.dart';

/// หน้ากระดานข่าว - Posts
/// แสดงข่าว ประกาศ และปฏิทิน
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          IreneAppBar(
            title: 'กระดานข่าว',
            showFilterButton: true,
            onFilterTap: () {
              // TODO: Open filter
            },
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
                  Tab(text: 'ทั้งหมด'),
                  Tab(text: 'ประกาศ'),
                  Tab(text: 'ปฏิทิน'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAllTab(),
            _buildAnnouncementTab(),
            _buildCalendarTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        child: Icon(Iconsax.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAllTab() {
    return ListView(
      padding: EdgeInsets.all(AppSpacing.md),
      children: [
        _buildPostCard(
          type: PostType.critical,
          title: 'แจ้งเตือน: การใช้ยา Warfarin',
          author: 'พี่แนน',
          time: '2 ชั่วโมงที่แล้ว',
          hasQuiz: true,
        ),
        AppSpacing.verticalGapMd,
        _buildPostCard(
          type: PostType.announcement,
          title: 'ตารางเวรเดือนมกราคม 2568',
          author: 'หัวหน้าเวร',
          time: '5 ชั่วโมงที่แล้ว',
          needAcknowledge: true,
        ),
        AppSpacing.verticalGapMd,
        _buildPostCard(
          type: PostType.general,
          title: 'คุณสมศรี - อัพเดตอาการวันนี้',
          author: 'น้องมิ้นท์',
          time: '10 นาทีที่แล้ว',
          hasImage: true,
          residentName: 'คุณสมศรี',
        ),
        AppSpacing.verticalGapMd,
        _buildPostCard(
          type: PostType.calendar,
          title: 'นัดพบแพทย์ - คุณประยุทธ์',
          author: 'พี่แนน',
          time: 'พรุ่งนี้ 10:00 น.',
          residentName: 'คุณประยุทธ์',
        ),
      ],
    );
  }

  Widget _buildAnnouncementTab() {
    return ListView(
      padding: EdgeInsets.all(AppSpacing.md),
      children: [
        _buildPostCard(
          type: PostType.critical,
          title: 'แจ้งเตือน: การใช้ยา Warfarin',
          author: 'พี่แนน',
          time: '2 ชั่วโมงที่แล้ว',
          hasQuiz: true,
        ),
        AppSpacing.verticalGapMd,
        _buildPostCard(
          type: PostType.announcement,
          title: 'ตารางเวรเดือนมกราคม 2568',
          author: 'หัวหน้าเวร',
          time: '5 ชั่วโมงที่แล้ว',
          needAcknowledge: true,
        ),
      ],
    );
  }

  Widget _buildCalendarTab() {
    return ListView(
      padding: EdgeInsets.all(AppSpacing.md),
      children: [
        _buildPostCard(
          type: PostType.calendar,
          title: 'นัดพบแพทย์ - คุณประยุทธ์',
          author: 'พี่แนน',
          time: 'พรุ่งนี้ 10:00 น.',
          residentName: 'คุณประยุทธ์',
        ),
        AppSpacing.verticalGapMd,
        _buildPostCard(
          type: PostType.calendar,
          title: 'นัดพบแพทย์ - คุณสมชาย',
          author: 'หัวหน้าเวร',
          time: '28 ธ.ค. 10:00 น.',
          residentName: 'คุณสมชาย',
        ),
      ],
    );
  }

  Widget _buildPostCard({
    required PostType type,
    required String title,
    required String author,
    required String time,
    bool hasQuiz = false,
    bool needAcknowledge = false,
    bool hasImage = false,
    String? residentName,
  }) {
    Color tagColor;
    Color tagBgColor;
    String tagText;
    IconData tagIcon;

    switch (type) {
      case PostType.critical:
        tagColor = AppColors.error;
        tagBgColor = AppColors.tagFailedBg;
        tagText = 'สำคัญ';
        tagIcon = Iconsax.warning_2;
        break;
      case PostType.announcement:
        tagColor = AppColors.tagPendingText;
        tagBgColor = AppColors.tagPendingBg;
        tagText = 'ประกาศ';
        tagIcon = Iconsax.notification;
        break;
      case PostType.calendar:
        tagColor = AppColors.secondary;
        tagBgColor = AppColors.accent2;
        tagText = 'นัดหมาย';
        tagIcon = Iconsax.calendar_1;
        break;
      case PostType.general:
        tagColor = AppColors.tagNeutralText;
        tagBgColor = AppColors.tagNeutralBg;
        tagText = 'ทั่วไป';
        tagIcon = Iconsax.document_text;
        break;
    }

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: [AppShadows.subtle],
        border: type == PostType.critical
            ? Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagBgColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tagIcon, size: 12, color: tagColor),
                    AppSpacing.horizontalGapXs,
                    Text(
                      tagText,
                      style: AppTypography.caption.copyWith(
                        color: tagColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
              Text(
                time,
                style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
          Text(title, style: AppTypography.title),
          AppSpacing.verticalGapSm,
          if (residentName != null) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.tagReadBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                residentName,
                style: AppTypography.caption.copyWith(color: AppColors.tagReadText),
              ),
            ),
            AppSpacing.verticalGapSm,
          ],
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.accent1,
                child: Icon(Iconsax.user, size: 12, color: AppColors.primary),
              ),
              AppSpacing.horizontalGapSm,
              Text(
                author,
                style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
              ),
              Spacer(),
              if (hasQuiz)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.document_text, size: 12, color: AppColors.error),
                      AppSpacing.horizontalGapXs,
                      Text(
                        'มี Quiz',
                        style: AppTypography.caption.copyWith(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              if (needAcknowledge)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.tagPendingBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'รอรับทราบ',
                    style: AppTypography.caption.copyWith(color: AppColors.tagPendingText),
                  ),
                ),
              if (hasImage)
                Icon(Iconsax.image, size: 16, color: AppColors.secondaryText),
            ],
          ),
        ],
      ),
    );
  }
}

enum PostType {
  critical,
  announcement,
  calendar,
  general,
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
