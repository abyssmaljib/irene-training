import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/filter_drawer_shell.dart';
import '../../../core/widgets/input_fields.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../board/models/post.dart';
import '../../board/screens/board_screen.dart';
import '../providers/activity_log_provider.dart';
import '../../../core/widgets/shimmer_loading.dart';

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
      appBar: IreneSecondaryAppBar(
        backgroundColor: AppColors.surface,
        // ใช้ titleWidget สำหรับ search field หรือ 2 บรรทัด
        titleWidget: _showSearch
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
            icon: HugeIcon(
              icon: _showSearch ? HugeIcons.strokeRoundedCancelCircle : HugeIcons.strokeRoundedSearch01,
              color: _showSearch ? AppColors.error : AppColors.textPrimary,
            ),
            onPressed: _toggleSearch,
          ),
          // Filter button
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Stack(
              children: [
                IconButton(
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedFilterHorizontal, color: AppColors.textPrimary),
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
        loading: () => ShimmerWrapper(
          isLoading: true,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              children: List.generate(5, (_) => const SkeletonListItem()),
            ),
          ),
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
            HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: AppIconSize.xxxl, color: AppColors.error),
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
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedFileEdit,
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
              icon: HugeIcon(icon: HugeIcons.strokeRoundedDelete01, size: AppIconSize.md),
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
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
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
    // ถ้าเป็น post ส่งเวร (isHandover) จะใช้กรอบสีแดง
    final isHandover = post.isHandover;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.sm),
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          boxShadow: [AppShadows.subtle],
          // ถ้าเป็น handover ใช้กรอบสีแดง, ถ้าไม่ใช่ไม่มีกรอบ
          border: isHandover
              ? Border.all(color: AppColors.error, width: 1.5)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tag icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getTagColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: HugeIcon(
                  icon: _getTagIcon(),
                  size: AppIconSize.md,
                  color: _getTagColor(),
                ),
              ),
            ),
            AppSpacing.horizontalGapMd,
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tag label row (รวม handover tag ถ้ามี)
                  Row(
                    children: [
                      Text(
                        _getTagLabel(),
                        style: AppTypography.bodySmall.copyWith(
                          color: _getTagColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // แสดง tag "ส่งเวรแล้ว" ถ้าเป็น handover
                      if (isHandover) ...[
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ส่งเวรแล้ว',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
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
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedUser,
                        size: AppIconSize.sm,
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
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedClock01,
                        size: AppIconSize.sm,
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
                        child: HugeIcon(icon: HugeIcons.strokeRoundedImage01,
                            size: AppIconSize.sm, color: AppColors.secondaryText),
                      ),
                    if (post.hasVideo)
                      Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: HugeIcon(icon: HugeIcons.strokeRoundedVideo01,
                            size: AppIconSize.sm, color: AppColors.secondaryText),
                      ),
                  ],
                ),
                SizedBox(height: 20),
                HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                    size: AppIconSize.md, color: AppColors.secondaryText),
              ],
            ),
          ],
        ),
      ),
    );
  }

  dynamic _getTagIcon() {
    final label = post.postTags.firstOrNull?.toLowerCase() ?? '';
    if (label.contains('แผล') || label.contains('ทำแผล')) return HugeIcons.strokeRoundedMedicine01;
    if (label.contains('กายภาพ')) return HugeIcons.strokeRoundedActivity01;
    if (label.contains('ยา')) return HugeIcons.strokeRoundedShoppingBag01;
    if (label.contains('อาหาร')) return HugeIcons.strokeRoundedRestaurant01;
    if (label.contains('กิจกรรม')) return HugeIcons.strokeRoundedMusicNote01;
    if (label.contains('ญาติ')) return HugeIcons.strokeRoundedUserGroup;
    if (label.contains('อัพเดต')) return HugeIcons.strokeRoundedFileEdit;
    if (label.contains('อาการ')) return HugeIcons.strokeRoundedMedicine01;
    return HugeIcons.strokeRoundedFileEdit;
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
