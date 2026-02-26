import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../models/app_notification.dart';

class NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final VoidCallback? onMarkAsRead;

  const NotificationItem({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
    this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('notification_${notification.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right = mark as read/unread
          onMarkAsRead?.call();
          return false; // Don't dismiss, just toggle read status
        }
        // Swipe left = delete with confirmation
        final confirmed = await ConfirmDialog.show(
          context,
          type: ConfirmDialogType.delete,
          title: 'ลบการแจ้งเตือน',
          message: 'คุณต้องการลบการแจ้งเตือนนี้หรือไม่?',
        );
        return confirmed;
      },
      onDismissed: (_) => onDismiss?.call(),
      // Swipe left background (delete)
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: AppSpacing.md),
        color: AppColors.error,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedDelete02,
          color: Colors.white,
          size: AppIconSize.lg,
        ),
      ),
      // Swipe right background (mark as read/unread)
      background: Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: AppSpacing.md),
        color: notification.isRead ? AppColors.pastelOrange : AppColors.primary,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: notification.isRead 
                  ? HugeIcons.strokeRoundedMailOpen01 
                  : HugeIcons.strokeRoundedCheckmarkCircle02,
              color: Colors.white,
              size: AppIconSize.lg,
            ),
            SizedBox(width: 8),
            Text(
              notification.isRead ? 'ยังไม่อ่าน' : 'อ่านแล้ว',
              style: AppTypography.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: Material(
        color: notification.isRead 
            ? AppColors.secondaryBackground 
            : AppColors.accent1.withValues(alpha: 0.3),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.alternate,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon based on type
                _buildTypeIcon(),
                AppSpacing.horizontalGapMd,
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        notification.title,
                        style: AppTypography.body.copyWith(
                          fontWeight: notification.isRead 
                              ? FontWeight.w400 
                              : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppSpacing.verticalGapXs,
                      // Body
                      Text(
                        notification.body,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppSpacing.verticalGapXs,
                      // Time and type badge
                      Row(
                        children: [
                          Text(
                            notification.relativeTime,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          ),
                          AppSpacing.horizontalGapSm,
                          _buildTypeBadge(),
                        ],
                      ),
                    ],
                  ),
                ),
                // Unread indicator
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    final iconData = _getIconForType(notification.type);
    final iconColor = _getColorForType(notification.type);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: HugeIcon(
          icon: iconData,
          color: iconColor,
          size: AppIconSize.md,
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    final color = _getColorForType(notification.type);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        notification.type.displayName,
        style: AppTypography.caption.copyWith(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  dynamic _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.post:
        return HugeIcons.strokeRoundedNews01;
      case NotificationType.task:
        return HugeIcons.strokeRoundedTask01;
      case NotificationType.calendar:
        return HugeIcons.strokeRoundedCalendar01;
      case NotificationType.badge:
        return HugeIcons.strokeRoundedAward01;
      case NotificationType.comment:
        return HugeIcons.strokeRoundedComment01;
      case NotificationType.system:
        return HugeIcons.strokeRoundedNotification01;
      case NotificationType.review:
        return HugeIcons.strokeRoundedBook02;
      case NotificationType.assignment:
        return HugeIcons.strokeRoundedUserAdd01;
      case NotificationType.incident:
        return HugeIcons.strokeRoundedAlert02;
      case NotificationType.points:
        return HugeIcons.strokeRoundedCoins01;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.post:
        return AppColors.pastelDarkGreen1; // Teal for posts
      case NotificationType.task:
        return AppColors.pastelOrange;
      case NotificationType.calendar:
        return AppColors.pastelPurple;
      case NotificationType.badge:
        return AppColors.pastelYellow;
      case NotificationType.comment:
        return AppColors.pastelLightGreen1; // Light green for comments
      case NotificationType.system:
        return AppColors.primary;
      case NotificationType.review:
        return AppColors.pastelRed; // Soft red for review reminders
      case NotificationType.assignment:
        return AppColors.secondary; // Light Blue for assignment
      case NotificationType.incident:
        return AppColors.error; // Red for incidents
      case NotificationType.points:
        return AppColors.pastelYellow; // Yellow for points
    }
  }
}
