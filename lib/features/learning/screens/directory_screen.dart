import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/topic_with_progress.dart';
import '../widgets/topic_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/input_fields.dart';
import 'topic_detail_screen.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<TopicWithProgress> _allTopics = [];
  Map<String, List<TopicWithProgress>> _topicsByType = {};
  bool _isLoading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    try {
      // ดึง current user
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'กรุณาเข้าสู่ระบบก่อน';
          _isLoading = false;
        });
        return;
      }

      // ดึง topics ทั้งหมดจาก training_topics
      final topicsResponse = await Supabase.instance.client
          .from('training_topics')
          .select()
          .eq('is_active', true)
          .order('display_order');

      // ดึง progress ของ user จาก view
      final progressResponse = await Supabase.instance.client
          .from('training_v_topics_with_progress')
          .select()
          .eq('user_id', user.id);

      // สร้าง map ของ progress โดยใช้ topic_id เป็น key
      final progressMap = <String, Map<String, dynamic>>{};
      for (final progress in progressResponse as List) {
        progressMap[progress['topic_id']] = progress;
      }

      // Merge topics กับ progress
      final topics = (topicsResponse as List).map((topicJson) {
        final topicId = topicJson['id'] as String;
        final progress = progressMap[topicId];

        // ถ้ามี progress ใช้ข้อมูลจาก view, ถ้าไม่มีสร้างจาก topic เปล่าๆ
        if (progress != null) {
          return TopicWithProgress.fromJson(progress);
        } else {
          return TopicWithProgress(
            topicId: topicId,
            topicName: topicJson['name'] as String,
            topicType: topicJson['Type'] as String?,
            notionUrl: topicJson['notion_url'] as String?,
            coverImageUrl: topicJson['cover_image_url'] as String?,
            displayOrder: topicJson['display_order'] as int?,
          );
        }
      }).toList();

      if (!mounted) return;
      setState(() {
        _allTopics = topics;
        _groupTopics(topics);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _groupTopics(List<TopicWithProgress> topics) {
    final Map<String, List<TopicWithProgress>> grouped = {};
    for (final topic in topics) {
      final type = topic.topicType ?? 'อื่นๆ';
      grouped.putIfAbsent(type, () => []);
      grouped[type]!.add(topic);
    }
    _topicsByType = grouped;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();

      if (_searchQuery.isEmpty) {
        _groupTopics(_allTopics);
      } else {
        final filtered = _allTopics.where((topic) {
          final name = topic.topicName.toLowerCase();
          return name.contains(_searchQuery);
        }).toList();

        _groupTopics(filtered);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IreneSecondaryAppBar(title: 'เรียนรู้'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('เกิดข้อผิดพลาด'),
            AppSpacing.verticalGapSm,
            Text(
              _error!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
            AppSpacing.verticalGapMd,
            SizedBox(
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                onPressed: _loadTopics,
                style: ElevatedButton.styleFrom(
                  padding: AppSpacing.paddingHorizontalLg,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.smallRadius,
                  ),
                ),
                child: const Text('ลองใหม่'),
              ),
            ),
          ],
        ),
      );
    }

    final List<Widget> slivers = [];

    // Search Bar
    slivers.add(
      SliverPersistentHeader(
        pinned: true,
        delegate: _SearchBarDelegate(
          controller: _searchController,
          onChanged: _onSearchChanged,
          hasText: _searchQuery.isNotEmpty,
        ),
      ),
    );
    if (_topicsByType.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/not_found.webp',
                  width: 240,
                  height: 240,
                ),
                AppSpacing.verticalGapMd,
                Text(
                  'ไม่พบหัวข้อที่ค้นหา',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return RefreshIndicator(
        onRefresh: _loadTopics,
        color: AppColors.primary,
        child: CustomScrollView(slivers: slivers),
      );
    }

    for (final type in _topicsByType.keys) {
      final topics = _topicsByType[type]!;

      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(title: type),
        ),
      );

      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final topic = topics[index];
            return TopicCard(
              topic: topic,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TopicDetailScreen(topic: topic),
                  ),
                );
                // Refresh data when coming back
                _loadTopics();
              },
            );
          }, childCount: topics.length),
        ),
      );

      // เพิ่ม spacing หลังแต่ละกลุ่ม
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)));
    }

    return RefreshIndicator(
      onRefresh: _loadTopics,
      color: AppColors.primary,
      child: CustomScrollView(slivers: slivers),
    );
  }
}

// Delegate สำหรับ Search Bar
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool hasText;

  _SearchBarDelegate({
    required this.controller,
    required this.onChanged,
    required this.hasText,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 52,
      color: AppColors.secondaryBackground,
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
      child: SearchField(
        controller: controller,
        hintText: 'ค้นหาหัวข้อ...',
        isDense: true,
        onChanged: onChanged,
        onClear: () => onChanged(''),
      ),
    );
  }

  @override
  double get maxExtent => 52;

  @override
  double get minExtent => 52;

  @override
  bool shouldRebuild(covariant _SearchBarDelegate oldDelegate) => true;
}

// Delegate สำหรับ Sticky Header
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;

  _StickyHeaderDelegate({required this.title});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      width: double.infinity,
      color: AppColors.secondaryBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Padding(
              padding: AppSpacing.paddingHorizontalMd,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.alternate),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 45;

  @override
  double get minExtent => 45;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return title != oldDelegate.title;
  }
}
