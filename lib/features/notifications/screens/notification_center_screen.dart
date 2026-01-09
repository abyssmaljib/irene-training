import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../models/app_notification.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_item.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationStateProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: CustomScrollView(
        slivers: [
          IreneAppBar(
            title: 'การแจ้งเตือน',
            actions: [
              // Mark all as read button
              _buildMarkAllReadButton(notificationState),
            ],
          ),
          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabController: _tabController,
              notificationState: notificationState,
            ),
          ),
          // Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Unread only tab
                _buildNotificationList(notificationState, showAll: false),
                // All notifications tab
                _buildNotificationList(notificationState, showAll: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(
    AsyncValue<List<AppNotification>> state, {
    required bool showAll,
  }) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(error.toString()),
      data: (notifications) {
        final filteredNotifications = showAll
            ? notifications
            : notifications.where((n) => !n.isRead).toList();

        if (filteredNotifications.isEmpty) {
          return _buildEmptyState(showAll);
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(notificationStateProvider.notifier).refresh(),
          color: AppColors.primary,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: filteredNotifications.length,
            itemBuilder: (context, index) {
              final notification = filteredNotifications[index];
              return NotificationItem(
                notification: notification,
                onTap: () => _onNotificationTap(notification),
                onDismiss: () => _onNotificationDismiss(notification),
                onMarkAsRead: () => _onToggleReadStatus(notification),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool showAll) {
    return EmptyStateWidget(
      message: showAll ? 'ยังไม่มีการแจ้งเตือน' : 'ไม่มีการแจ้งเตือนที่ยังไม่อ่าน',
      subMessage: showAll 
          ? 'การแจ้งเตือนใหม่จะปรากฏที่นี่'
          : 'คุณอ่านการแจ้งเตือนทั้งหมดแล้ว 🎉',
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            color: AppColors.error,
            size: 48,
          ),
          AppSpacing.verticalGapMd,
          Text(
            'เกิดข้อผิดพลาด',
            style: AppTypography.body.copyWith(
              color: AppColors.error,
            ),
          ),
          AppSpacing.verticalGapSm,
          TextButton(
            onPressed: () => ref.read(notificationStateProvider.notifier).refresh(),
            child: Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  void _onNotificationTap(AppNotification notification) {
    // Mark as read
    if (!notification.isRead) {
      ref.read(notificationStateProvider.notifier).markAsRead(notification.id);
    }

    // Navigate based on type
    _navigateToReference(notification);
  }

  void _navigateToReference(AppNotification notification) {
    // TODO: Implement navigation based on notification type and reference
    // For now, just show a snackbar
    switch (notification.type) {
      case NotificationType.post:
        // Navigate to post detail
        // if (notification.referenceId != null) {
        //   Navigator.push(context, MaterialPageRoute(
        //     builder: (_) => PostDetailScreen(postId: notification.referenceId!),
        //   ));
        // }
        break;
      case NotificationType.task:
        // Navigate to task detail
        break;
      case NotificationType.calendar:
        // Navigate to calendar
        break;
      case NotificationType.badge:
        // Navigate to badge collection
        break;
      case NotificationType.comment:
        // Navigate to post with comment
        break;
      case NotificationType.review:
        // Navigate to learning topic
        break;
      case NotificationType.system:
        // System notifications may not have navigation
        break;
    }
  }

  void _onNotificationDismiss(AppNotification notification) {
    ref.read(notificationStateProvider.notifier).deleteNotification(notification.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ลบการแจ้งเตือนแล้ว'),
        backgroundColor: AppColors.primary,
        action: SnackBarAction(
          label: 'เลิกทำ',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Implement undo
            ref.read(notificationStateProvider.notifier).refresh();
          },
        ),
      ),
    );
  }

  void _onToggleReadStatus(AppNotification notification) {
    ref.read(notificationStateProvider.notifier).toggleReadStatus(
      notification.id,
      notification.isRead,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notification.isRead ? 'ทำเครื่องหมายยังไม่อ่าน' : 'ทำเครื่องหมายอ่านแล้ว'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _markAllAsRead() {
    ref.read(notificationStateProvider.notifier).markAllAsRead();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('อ่านทั้งหมดแล้ว'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildMarkAllReadButton(AsyncValue<List<AppNotification>> state) {
    final hasUnread = state.whenOrNull(
      data: (notifications) => notifications.any((n) => !n.isRead),
    ) ?? false;

    if (!hasUnread) {
      return const SizedBox.shrink();
    }

    return IconButton(
      onPressed: () => _markAllAsRead(),
      icon: HugeIcon(
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        color: AppColors.primary,
        size: AppIconSize.lg,
      ),
      tooltip: 'อ่านทั้งหมด',
    );
  }
}

/// Tab bar delegate for sliver persistent header
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final AsyncValue<List<AppNotification>> notificationState;

  _TabBarDelegate({
    required this.tabController,
    required this.notificationState,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final unreadCount = notificationState.whenOrNull(
      data: (notifications) => notifications.where((n) => !n.isRead).length,
    ) ?? 0;

    return Container(
      color: AppColors.secondaryBackground,
      child: TabBar(
        controller: tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.secondaryText,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: AppTypography.label.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTypography.label,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ยังไม่อ่าน'),
                if (unreadCount > 0) ...[
                  SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(text: 'ทั้งหมด'),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return notificationState != oldDelegate.notificationState;
  }
}
