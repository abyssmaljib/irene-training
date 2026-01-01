import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/post.dart';

/// Card สำหรับ Pinned Critical Post (แสดงด้านบนสุด)
class PinnedPostCard extends StatelessWidget {
  final Post post;
  final bool isLiked;
  final VoidCallback? onTap;
  final VoidCallback? onLikeTap;

  const PinnedPostCard({
    super.key,
    required this.post,
    this.isLiked = false,
    this.onTap,
    this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // ขอบนอก (สีอ่อน) - ชั้นที่ 2
      child: Container(
        margin: EdgeInsets.only(top: AppSpacing.xs),
        padding: EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        // ขอบใน (สีเข้ม) - ชั้นที่ 1
        child: Container(
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFF9C4).withValues(alpha: 0.5), // พาสเทลเหลืองจางๆ
                AppColors.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error, width: 2),
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            AppSpacing.verticalGapSm,
            _buildTitle(),
            if (post.displayText.isNotEmpty &&
                post.displayTitle.isNotEmpty) ...[
              AppSpacing.verticalGapXs,
              _buildContent(),
            ],
            AppSpacing.verticalGapMd,
            _buildFooter(),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Pin icon
        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Iconsax.flag,
            size: 12,
            color: Colors.white,
          ),
        ),
        AppSpacing.horizontalGapSm,
        Text(
          'ประกาศสำคัญ',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        Spacer(),
        Text(
          _formatTimeAgo(post.createdAt),
          style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      post.displayTitle.isNotEmpty ? post.displayTitle : post.displayText,
      style: AppTypography.title.copyWith(
        color: AppColors.error,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildContent() {
    return Text(
      post.displayText,
      style: AppTypography.body.copyWith(
        color: AppColors.primaryText,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        // Author
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.accent1,
          backgroundImage:
              post.photoUrl != null ? NetworkImage(post.photoUrl!) : null,
          child: post.photoUrl == null
              ? Icon(Iconsax.user, size: 12, color: AppColors.primary)
              : null,
        ),
        AppSpacing.horizontalGapSm,
        Expanded(
          child: Text(
            post.postUserNickname ?? 'ไม่ทราบชื่อ',
            style:
                AppTypography.bodySmall.copyWith(color: AppColors.primaryText),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays == 1) return 'เมื่อวาน';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
