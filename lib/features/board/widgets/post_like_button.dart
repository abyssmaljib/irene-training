import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Like/Acknowledge button สำหรับ Post
class PostLikeButton extends StatelessWidget {
  final bool isLiked;
  final int likeCount;
  final String? lastLikerName;
  final VoidCallback onTap;
  final bool showCount;
  final bool compact;

  const PostLikeButton({
    super.key,
    required this.isLiked,
    this.likeCount = 0,
    this.lastLikerName,
    required this.onTap,
    this.showCount = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactButton();
    }
    return _buildFullButton();
  }

  Widget _buildCompactButton() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isLiked
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedFavourite,
              size: AppIconSize.sm,
              color: isLiked ? AppColors.primary : AppColors.secondaryText,
            ),
            if (showCount && likeCount > 0) ...[
              SizedBox(width: 4),
              Text(
                '$likeCount',
                style: AppTypography.caption.copyWith(
                  color: isLiked ? AppColors.primary : AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFullButton() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isLiked
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLiked ? AppColors.primary : AppColors.inputBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedFavourite,
              size: AppIconSize.md,
              color: isLiked ? AppColors.primary : AppColors.secondaryText,
            ),
            SizedBox(width: 6),
            Text(
              isLiked ? 'รับทราบแล้ว' : 'รับทราบ',
              style: AppTypography.body.copyWith(
                color: isLiked ? AppColors.primary : AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showCount && likeCount > 0) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLiked
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$likeCount',
                  style: AppTypography.caption.copyWith(
                    color: isLiked ? AppColors.primary : AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Like info row แสดงรายชื่อคนที่ Like
class PostLikeInfo extends StatelessWidget {
  final int likeCount;
  final String? lastLikerName;
  final String? lastLikerPhotoUrl;
  final VoidCallback? onTap;

  const PostLikeInfo({
    super.key,
    required this.likeCount,
    this.lastLikerName,
    this.lastLikerPhotoUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (likeCount == 0) return SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          // Avatar
          if (lastLikerPhotoUrl != null)
            CircleAvatar(
              radius: 10,
              backgroundImage: NetworkImage(lastLikerPhotoUrl!),
            )
          else
            CircleAvatar(
              radius: 10,
              backgroundColor: AppColors.accent1,
              child: HugeIcon(icon: HugeIcons.strokeRoundedUser, size: AppIconSize.xs, color: AppColors.primary),
            ),
          SizedBox(width: 6),
          // Text
          Expanded(
            child: Text(
              _buildLikeText(),
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _buildLikeText() {
    if (likeCount == 1) {
      return lastLikerName ?? 'มีผู้รับทราบ 1 คน';
    }
    if (lastLikerName != null) {
      return '$lastLikerName และอีก ${likeCount - 1} คนรับทราบ';
    }
    return 'มีผู้รับทราบ $likeCount คน';
  }
}
