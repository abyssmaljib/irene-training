import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/network_image.dart';
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

  /// ถ้า true = อยู่ใน tab ศูนย์ (ซ่อน tag, แสดงกรอบสีแดงพาสเทล)
  final bool isCenterTab;

  /// ถ้า true = เป็นโพสที่บังคับอ่านและยังไม่ได้อ่าน (แสดง red dot)
  final bool isRequiredUnread;

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
    this.isCenterTab = false,
    this.isRequiredUnread = false,
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
          // tab ศูนย์ = กรอบสีแดงพาสเทลทุก card
          // tab ผู้พัก = กรอบสีแดงเฉพาะ critical
          border: isCenterTab
              ? Border.all(
                  color: AppColors.error.withValues(alpha: 0.2), width: 1.5)
              : (post.isCritical
                  ? Border.all(
                      color: AppColors.error.withValues(alpha: 0.3), width: 2)
                  : null),
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
        // แสดง post_tags (tag name) ทั้ง tab ศูนย์และ tab ผู้พัก
        _buildPostTags(),
        Spacer(),
        // Red dot สำหรับโพสที่บังคับอ่านและยังไม่ได้อ่าน
        if (isRequiredUnread) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          _formatTimeAgo(post.createdAt),
          style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
        ),
      ],
    );
  }

  /// แสดง post tags จริงที่ user ใส่
  Widget _buildPostTags() {
    if (post.postTags.isEmpty) return const SizedBox.shrink();

    // แสดงแค่ 2 tags แรก เพื่อไม่ให้ยาวเกินไป
    final displayTags = post.postTags.take(2).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: displayTags.map((tag) {
        return Container(
          margin: EdgeInsets.only(right: 4),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '#$tag',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
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

  /// Map raw database status เป็นคำที่ user เข้าใจง่าย
  /// อ้างอิงจาก QUEUE_SYSTEM_DOCS.md
  _LineStatusInfo _mapLineStatus(String rawStatus) {
    // Normalize: lowercase + trim เพื่อเปรียบเทียบ
    final normalized = rawStatus.toLowerCase().trim();

    // รอส่ง (pending/waiting/Trigger fired)
    if (normalized == 'pending' ||
        normalized == 'waiting' ||
        normalized.contains('trigger fired')) {
      return _LineStatusInfo(
        label: 'รอส่ง',
        color: AppColors.warning,
        icon: HugeIcons.strokeRoundedClock01,
      );
    }

    // ส่งสำเร็จ
    if (normalized == 'sent') {
      return _LineStatusInfo(
        label: 'ส่งแล้ว',
        color: AppColors.success,
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
      );
    }

    // ส่งไม่สำเร็จ
    if (normalized == 'fail') {
      return _LineStatusInfo(
        label: 'ส่งไม่สำเร็จ',
        color: AppColors.error,
        icon: HugeIcons.strokeRoundedAlert02,
      );
    }

    // กำลังยกเลิก
    if (normalized == 'canceling...' || normalized.contains('canceling')) {
      return _LineStatusInfo(
        label: 'กำลังยกเลิก',
        color: AppColors.secondaryText,
        icon: HugeIcons.strokeRoundedLoading03,
      );
    }

    // ยกเลิกแล้ว
    if (normalized == 'canceled') {
      return _LineStatusInfo(
        label: 'ยกเลิกแล้ว',
        color: AppColors.secondaryText,
        icon: HugeIcons.strokeRoundedCancel01,
      );
    }

    // ไม่มี LINE group
    if (normalized == 'ยังไม่ลงทะเบียน') {
      return _LineStatusInfo(
        label: 'ยังไม่มี LINE',
        color: AppColors.secondaryText,
        icon: HugeIcons.strokeRoundedUserBlock01,
      );
    }

    // รอหัวหน้าเวรตรวจ (Vitals ผิดปกติ)
    if (normalized == 'ผิดปกติ') {
      return _LineStatusInfo(
        label: 'รอตรวจสอบ',
        color: AppColors.warning,
        icon: HugeIcons.strokeRoundedAlertCircle,
      );
    }

    // Default: แสดง status ดิบ (ป้องกันกรณีมี status ใหม่ที่ยังไม่ได้ map)
    return _LineStatusInfo(
      label: rawStatus,
      color: AppColors.secondaryText,
      icon: HugeIcons.strokeRoundedSent,
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
    // Map status ดิบเป็นคำที่ user เข้าใจง่าย
    final statusInfo = _mapLineStatus(status);

    return Row(
      children: [
        HugeIcon(
          icon: statusInfo.icon,
          color: statusInfo.color,
          size: AppIconSize.sm,
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
            statusInfo.label,
            style: AppTypography.caption.copyWith(
              color: statusInfo.color,
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
        // Author avatar - ใช้ IreneNetworkAvatar ที่มี timeout และ retry mechanism
        IreneNetworkAvatar(
          imageUrl: post.photoUrl,
          radius: 12,
          fallbackIcon: HugeIcon(
            icon: HugeIcons.strokeRoundedUser,
            size: AppIconSize.xs,
            color: AppColors.primary,
          ),
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
          HugeIcon(icon: HugeIcons.strokeRoundedImage01, size: AppIconSize.sm, color: AppColors.secondaryText),
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
          HugeIcon(icon: HugeIcons.strokeRoundedFileEdit, size: AppIconSize.xs, color: AppColors.error),
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
            HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              size: AppIconSize.sm,
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

/// ข้อมูล LINE status ที่แปลงแล้ว (label, color, icon)
class _LineStatusInfo {
  final String label;
  final Color color;
  final dynamic icon;

  const _LineStatusInfo({
    required this.label,
    required this.color,
    required this.icon,
  });
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
              HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: AppIconSize.sm, color: AppColors.error),
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
