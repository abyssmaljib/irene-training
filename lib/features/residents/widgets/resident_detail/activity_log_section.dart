import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../board/models/post.dart';
import '../../../board/providers/post_provider.dart';

/// Provider สำหรับ activity posts ของ resident
final residentActivityPostsProvider =
    FutureProvider.family<List<Post>, int>((ref, residentId) async {
  final nursinghomeId = await ref.watch(nursinghomeIdProvider.future);
  if (nursinghomeId == null) return [];

  final service = ref.watch(postServiceProvider);
  return service.getPostsByResident(
    nursinghomeId: nursinghomeId,
    residentId: residentId,
    limit: 20,
  );
});

/// Activity Log Section - แสดง posts ที่เกี่ยวข้องกับ resident
class ActivityLogSection extends ConsumerWidget {
  final int residentId;

  const ActivityLogSection({
    super.key,
    required this.residentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(residentActivityPostsProvider(residentId));

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('บันทึกกิจกรรม', style: AppTypography.title),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full activity log
                },
                child: Text(
                  'ดูทั้งหมด',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapSm,

          // Content
          postsAsync.when(
            loading: () => _buildLoading(),
            error: (e, s) => _buildError(e.toString()),
            data: (posts) =>
                posts.isEmpty ? _buildEmpty() : _buildPostsList(posts),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: AppShadows.cardShadow,
      ),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
            AppSpacing.verticalGapSm,
            Text(
              'กำลังโหลดบันทึก...',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: AppShadows.cardShadow,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Iconsax.warning_2, size: 32, color: AppColors.error),
            AppSpacing.verticalGapSm,
            Text(
              'เกิดข้อผิดพลาด',
              style: AppTypography.body.copyWith(color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: AppShadows.cardShadow,
        border: Border.all(
          color: AppColors.alternate,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.document_text,
              size: 24,
              color: AppColors.secondaryText,
            ),
          ),
          AppSpacing.verticalGapMd,
          Text(
            'ยังไม่มีบันทึก',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          Text(
            'กิจกรรมต่างๆ จะแสดงที่นี่',
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(List<Post> posts) {
    return Column(
      children: posts.take(5).map((post) => _buildPostItem(post)).toList(),
    );
  }

  Widget _buildPostItem(Post post) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smallRadius,
        boxShadow: [AppShadows.subtle],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getTagColor(post).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getTagIcon(post),
              size: 18,
              color: _getTagColor(post),
            ),
          ),
          AppSpacing.horizontalGapSm,
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag label
                Text(
                  _getTagLabel(post),
                  style: AppTypography.caption.copyWith(
                    color: _getTagColor(post),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Content
                if (post.displayText.isNotEmpty)
                  Text(
                    post.displayText,
                    style: AppTypography.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                AppSpacing.verticalGapXs,
                // Author & time
                Row(
                  children: [
                    Text(
                      post.postUserNickname ?? '',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Text(
                      ' • ',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Text(
                      _formatTimeAgo(post.createdAt),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Image indicator
          if (post.hasImages)
            Icon(Iconsax.image, size: 16, color: AppColors.secondaryText),
        ],
      ),
    );
  }

  IconData _getTagIcon(Post post) {
    final label = post.postTags.firstOrNull?.toLowerCase() ?? '';
    if (label.contains('แผล') || label.contains('ทำแผล')) return Iconsax.health;
    if (label.contains('กายภาพ')) return Iconsax.activity;
    if (label.contains('ยา')) return Iconsax.bag_2;
    if (label.contains('อาหาร')) return Iconsax.cake;
    if (label.contains('กิจกรรม')) return Iconsax.music;
    if (label.contains('ญาติ')) return Iconsax.people;
    return Iconsax.document_text;
  }

  Color _getTagColor(Post post) {
    final label = post.postTags.firstOrNull?.toLowerCase() ?? '';
    if (label.contains('แผล') || label.contains('ทำแผล')) return AppColors.error;
    if (label.contains('กายภาพ')) return AppColors.secondary;
    if (label.contains('ยา')) return AppColors.tagPendingText;
    if (label.contains('อาหาร')) return AppColors.tagPassedText;
    if (label.contains('กิจกรรม')) return AppColors.primary;
    if (label.contains('ญาติ')) return AppColors.tagReadText;
    return AppColors.secondaryText;
  }

  String _getTagLabel(Post post) {
    return post.postTags.firstOrNull ?? 'ทั่วไป';
  }

  String _formatTimeAgo(DateTime dateTime) {
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
