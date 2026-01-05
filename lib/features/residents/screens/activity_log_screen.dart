import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/filter_drawer_shell.dart';
import '../../../core/widgets/input_fields.dart';
import '../../board/models/post.dart';
import '../../board/screens/board_screen.dart';
import '../providers/activity_log_provider.dart';

/// หน้าแสดงบันทึกกิจกรรมทั้งหมดของ resident
class ActivityLogScreen extends ConsumerStatefulWidget {
  final int residentId;
  final String residentName;

  const ActivityLogScreen({
    super.key,
    required this.residentId,
    required this.residentName,
  });

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    final currentSearch =
        ref.read(activityLogSearchProvider(widget.residentId));
    _searchController.text = currentSearch;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        ref
            .read(activityLogSearchProvider(widget.residentId).notifier)
            .state = '';
      }
    });
  }

  int get _filterCount {
    final tags = ref.watch(activityLogSelectedTagsProvider(widget.residentId));
    return tags.isNotEmpty ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync =
        ref.watch(residentActivityPostsFullProvider(widget.residentId));
    final filteredPosts =
        ref.watch(filteredActivityPostsProvider(widget.residentId));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: _ActivityLogFilterDrawer(residentId: widget.residentId),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _showSearch
            ? SearchField(
                controller: _searchController,
                hintText: 'ค้นหาบันทึก...',
                isDense: true,
                autofocus: true,
                onChanged: (value) {
                  ref
                      .read(activityLogSearchProvider(widget.residentId)
                          .notifier)
                      .state = value;
                },
                onClear: () {
                  _searchController.clear();
                  ref
                      .read(activityLogSearchProvider(widget.residentId)
                          .notifier)
                      .state = '';
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.residentName,
                    style: AppTypography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'บันทึกกิจกรรม',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
        actions: [
          // Search toggle
          IconButton(
            icon: Icon(
              _showSearch ? Iconsax.close_circle : Iconsax.search_normal,
              color: _showSearch ? AppColors.error : AppColors.textPrimary,
            ),
            onPressed: _toggleSearch,
          ),
          // Filter button
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                IconButton(
                  icon: Icon(Iconsax.filter, color: AppColors.textPrimary),
                  onPressed: () {
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                ),
                if (_filterCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$_filterCount',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: postsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _buildError(e.toString()),
        data: (allPosts) {
          if (allPosts.isEmpty) {
            return _buildEmpty();
          }

          if (filteredPosts.isEmpty) {
            return _buildNoResults();
          }

          return _buildPostsList(filteredPosts);
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.warning_2, size: 48, color: AppColors.error),
            AppSpacing.verticalGapMd,
            Text(
              'เกิดข้อผิดพลาด',
              style: AppTypography.title.copyWith(color: AppColors.error),
            ),
            AppSpacing.verticalGapSm,
            Text(
              message,
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent1,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.document_text,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            AppSpacing.verticalGapLg,
            Text(
              'ยังไม่มีบันทึก',
              style: AppTypography.title,
            ),
            AppSpacing.verticalGapSm,
            Text(
              'กิจกรรมต่างๆ จะแสดงที่นี่',
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/not_found.webp',
              width: 120,
              height: 120,
            ),
            AppSpacing.verticalGapLg,
            Text(
              'ไม่พบผลการค้นหา',
              style: AppTypography.title,
            ),
            AppSpacing.verticalGapSm,
            Text(
              'ลองเปลี่ยนคำค้นหาหรือตัวกรอง',
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            AppSpacing.verticalGapLg,
            TextButton.icon(
              onPressed: () {
                clearActivityLogFilters(ref, widget.residentId);
                _searchController.clear();
              },
              icon: Icon(Iconsax.trash, size: 18),
              label: Text('ล้างตัวกรอง'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList(List<Post> posts) {
    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.md),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _ActivityLogCard(
          post: post,
          onTap: () => navigateToPostDetail(context, post.id),
        );
      },
    );
  }
}

/// Filter drawer สำหรับหน้า Activity Log
class _ActivityLogFilterDrawer extends ConsumerWidget {
  final int residentId;

  const _ActivityLogFilterDrawer({required this.residentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableTagsAsync =
        ref.watch(activityLogAvailableTagsProvider(residentId));
    final selectedTags =
        ref.watch(activityLogSelectedTagsProvider(residentId));

    final filterCount = selectedTags.isNotEmpty ? 1 : 0;

    return FilterDrawerShell(
      title: 'ตัวกรอง',
      filterCount: filterCount,
      onClear: filterCount > 0
          ? () => clearActivityLogFilters(ref, residentId)
          : null,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tags Section
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Text(
                    'ประเภท',
                    style: AppTypography.title.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  if (selectedTags.isNotEmpty) ...[
                    AppSpacing.horizontalGapSm,
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${selectedTags.length}',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(activityLogSelectedTagsProvider(residentId)
                                .notifier)
                            .state = {};
                      },
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
            availableTagsAsync.when(
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
              data: (tags) {
                if (tags.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'ไม่พบประเภท',
                      style: AppTypography.body.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () =>
                            toggleActivityLogTag(ref, residentId, tag),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accent1
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.inputBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getTagColor(tag),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6),
                              if (isSelected) ...[
                                Icon(
                                  Iconsax.tick_circle,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 4),
                              ],
                              Text(
                                tag,
                                style: AppTypography.body.copyWith(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            // Bottom padding
            AppSpacing.verticalGapLg,
          ],
        ),
      ),
    );
  }

  Color _getTagColor(String tag) {
    final label = tag.toLowerCase();
    if (label.contains('แผล') || label.contains('ทำแผล')) return AppColors.error;
    if (label.contains('กายภาพ')) return AppColors.secondary;
    if (label.contains('ยา')) return AppColors.tagPendingText;
    if (label.contains('อาหาร')) return AppColors.tagPassedText;
    if (label.contains('กิจกรรม')) return AppColors.primary;
    if (label.contains('ญาติ')) return AppColors.tagReadText;
    return AppColors.secondaryText;
  }
}

/// Card สำหรับแสดง activity log item
class _ActivityLogCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const _ActivityLogCard({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.sm),
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          boxShadow: [AppShadows.subtle],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tag icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getTagColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getTagIcon(),
                size: 22,
                color: _getTagColor(),
              ),
            ),
            AppSpacing.horizontalGapMd,
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tag label
                  Text(
                    _getTagLabel(),
                    style: AppTypography.bodySmall.copyWith(
                      color: _getTagColor(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.verticalGapXs,
                  // Content text
                  if (post.displayText.isNotEmpty)
                    Text(
                      post.displayText,
                      style: AppTypography.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  AppSpacing.verticalGapSm,
                  // Author & time
                  Row(
                    children: [
                      Icon(
                        Iconsax.user,
                        size: 14,
                        color: AppColors.secondaryText,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.postUserNickname ?? '',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Iconsax.clock,
                        size: 14,
                        color: AppColors.secondaryText,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _formatDateTime(post.createdAt),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Indicators & arrow
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (post.hasImages)
                      Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Iconsax.image,
                            size: 16, color: AppColors.secondaryText),
                      ),
                    if (post.hasVideo)
                      Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Iconsax.video,
                            size: 16, color: AppColors.secondaryText),
                      ),
                  ],
                ),
                SizedBox(height: 20),
                Icon(Iconsax.arrow_right_3,
                    size: 18, color: AppColors.secondaryText),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTagIcon() {
    final label = post.postTags.firstOrNull?.toLowerCase() ?? '';
    if (label.contains('แผล') || label.contains('ทำแผล')) return Iconsax.health;
    if (label.contains('กายภาพ')) return Iconsax.activity;
    if (label.contains('ยา')) return Iconsax.bag_2;
    if (label.contains('อาหาร')) return Iconsax.cake;
    if (label.contains('กิจกรรม')) return Iconsax.music;
    if (label.contains('ญาติ')) return Iconsax.people;
    if (label.contains('อัพเดต')) return Iconsax.document_text;
    if (label.contains('อาการ')) return Iconsax.health;
    return Iconsax.document_text;
  }

  Color _getTagColor() {
    final label = post.postTags.firstOrNull?.toLowerCase() ?? '';
    if (label.contains('แผล') || label.contains('ทำแผล')) return AppColors.error;
    if (label.contains('กายภาพ')) return AppColors.secondary;
    if (label.contains('ยา')) return AppColors.tagPendingText;
    if (label.contains('อาหาร')) return AppColors.tagPassedText;
    if (label.contains('กิจกรรม')) return AppColors.primary;
    if (label.contains('ญาติ')) return AppColors.tagReadText;
    return AppColors.secondaryText;
  }

  String _getTagLabel() {
    return post.postTags.firstOrNull ?? 'ทั่วไป';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
    if (diff.inDays == 1) return 'เมื่อวาน';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

/// Navigate to Activity Log Screen
void navigateToActivityLog(
  BuildContext context, {
  required int residentId,
  required String residentName,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ActivityLogScreen(
        residentId: residentId,
        residentName: residentName,
      ),
    ),
  );
}
