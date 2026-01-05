import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/post.dart';

/// Card แสดง Post
class PostCard extends StatelessWidget {
  final Post post;
  final bool isLiked;
  final String? currentUserId;
  final String? userRole;
  final VoidCallback? onTap;
  final VoidCallback? onLikeTap;
  final Future<void> Function(int queueId)? onCancelPrn;
  final Future<void> Function(int queueId)? onCancelLogLine;

  const PostCard({
    super.key,
    required this.post,
    this.isLiked = false,
    this.currentUserId,
    this.userRole,
    this.onTap,
    this.onLikeTap,
    this.onCancelPrn,
    this.onCancelLogLine,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mediumRadius,
          boxShadow: [AppShadows.subtle],
          border: post.isCritical
              ? Border.all(
                  color: AppColors.error.withValues(alpha: 0.3), width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            AppSpacing.verticalGapMd,
            _buildTitle(),
            if (post.displayText.isNotEmpty) ...[
              AppSpacing.verticalGapSm,
              _buildContent(),
            ],
            if (post.residentName != null) ...[
              AppSpacing.verticalGapSm,
              _buildResidentTag(),
            ],
            // LINE notification status rows
            if (post.hasPrnStatus) ...[
              AppSpacing.verticalGapSm,
              _buildLineStatusRow(
                context: context,
                status: post.prnStatus!,
                queueId: post.prnQueueId,
                canCancel: post.canCancelPrn(currentUserId, userRole),
                onCancel: onCancelPrn,
              ),
            ],
            if (post.hasLogLineStatus) ...[
              AppSpacing.verticalGapSm,
              _buildLineStatusRow(
                context: context,
                status: post.logLineStatus!,
                queueId: post.logLineQueueId,
                canCancel: post.canCancelLogLine(currentUserId, userRole),
                onCancel: onCancelLogLine,
              ),
            ],
            AppSpacing.verticalGapMd,
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildTypeTag(),
        Spacer(),
        Text(
          _formatTimeAgo(post.createdAt),
          style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
        ),
      ],
    );
  }

  Widget _buildTypeTag() {
    final (color, bgColor, text, icon) = _getTypeStyle();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          AppSpacing.horizontalGapXs,
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, String, IconData) _getTypeStyle() {
    if (post.isCritical) {
      return (AppColors.error, AppColors.tagFailedBg, 'สำคัญ', Iconsax.warning_2);
    }
    if (post.isPolicy) {
      return (AppColors.tagPendingText, AppColors.tagPendingBg, 'นโยบาย',
          Iconsax.notification);
    }
    if (post.isInfo) {
      return (AppColors.tagNeutralText, AppColors.tagNeutralBg, 'ข้อมูล',
          Iconsax.info_circle);
    }
    if (post.isCalendar) {
      return (AppColors.secondary, AppColors.accent2, 'นัดหมาย',
          Iconsax.calendar_1);
    }
    // FYI / General
    return (AppColors.tagNeutralText, AppColors.tagNeutralBg, 'ทั่วไป',
        Iconsax.document_text);
  }

  Widget _buildTitle() {
    return Text(
      post.displayTitle.isNotEmpty ? post.displayTitle : post.displayText,
      style: AppTypography.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildContent() {
    if (post.displayTitle.isEmpty) return SizedBox.shrink();
    return Text(
      post.displayText,
      style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildResidentTag() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tagReadBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'คุณ${post.residentName!}',
        style: AppTypography.caption.copyWith(color: AppColors.tagReadText),
      ),
    );
  }

  /// Build LINE notification status row
  Widget _buildLineStatusRow({
    required BuildContext context,
    required String status,
    int? queueId,
    required bool canCancel,
    Future<void> Function(int queueId)? onCancel,
  }) {
    return Row(
      children: [
        Icon(
          Iconsax.send_2,
          color: AppColors.secondaryText,
          size: 14,
        ),
        SizedBox(width: 4),
        Text(
          'LINE: ',
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
            fontSize: 10,
          ),
        ),
        Expanded(
          child: Text(
            status,
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ),
        if (canCancel && queueId != null && onCancel != null)
          _CancelLineButton(
            onPressed: () => onCancel(queueId),
          ),
      ],
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
                AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Indicators
        if (post.hasQuiz) _buildQuizBadge(),
        if (post.hasImages) ...[
          AppSpacing.horizontalGapSm,
          Icon(Iconsax.image, size: 16, color: AppColors.secondaryText),
        ],
        AppSpacing.horizontalGapMd,
        // Like button
        _buildLikeButton(),
      ],
    );
  }

  Widget _buildQuizBadge() {
    return Container(
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
    );
  }

  Widget _buildLikeButton() {
    final likeCount = post.likeUserIds.length;

    return GestureDetector(
      onTap: onLikeTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isLiked
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.tagNeutralBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.tick_circle,
              size: 16,
              color: isLiked ? AppColors.primary : AppColors.secondaryText,
            ),
            if (likeCount > 0) ...[
              AppSpacing.horizontalGapXs,
              Text(
                likeCount.toString(),
                style: AppTypography.caption.copyWith(
                  color: isLiked ? AppColors.primary : AppColors.secondaryText,
                ),
              ),
            ],
          ],
        ),
      ),
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

    // Format as date
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

/// Cancel LINE notification button
class _CancelLineButton extends StatefulWidget {
  final Future<void> Function() onPressed;

  const _CancelLineButton({required this.onPressed});

  @override
  State<_CancelLineButton> createState() => _CancelLineButtonState();
}

class _CancelLineButtonState extends State<_CancelLineButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _handleCancel,
      child: Container(
        height: 28,
        padding: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.error,
                ),
              )
            else
              Icon(Iconsax.danger, size: 14, color: AppColors.error),
            SizedBox(width: 4),
            Text(
              'ยกเลิกการส่ง',
              style: AppTypography.caption.copyWith(
                color: AppColors.error,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCancel() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการยกเลิก'),
        content: Text('ต้องการยกเลิกการส่ง LINE หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ไม่'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('ยกเลิก'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
