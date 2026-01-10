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
import 'notification_detail_screen.dart';

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
      // ใช้ IreneSecondaryAppBar ที่มีปุ่มย้อนกลับ พร้อม TabBar ใน bottom
      appBar: IreneSecondaryAppBar(
        title: 'การแจ้งเตือน',
        actions: [
          // Mark all as read button
          _buildMarkAllReadButton(notificationState),
        ],
        bottom: TabBar(
          controller: _tabController,
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
                  // แสดง badge จำนวน unread
                  _buildUnreadBadge(notificationState),
                ],
              ),
            ),
            Tab(text: 'ทั้งหมด'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Unread only tab
          _buildNotificationList(notificationState, showAll: false),
          // All notifications tab
          _buildNotificationList(notificationState, showAll: true),
        ],
      ),
    );
  }

  /// สร้าง badge แสดงจำนวน unread notifications
  Widget _buildUnreadBadge(AsyncValue<List<AppNotification>> state) {
    final unreadCount = state.whenOrNull(
      data: (notifications) => notifications.where((n) => !n.isRead).length,
    ) ?? 0;

    if (unreadCount == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    // Mark as read ก่อน
    if (!notification.isRead) {
      ref.read(notificationStateProvider.notifier).markAsRead(notification.id);
    }

    // Navigate ไปหน้า detail เพื่อดูรายละเอียดเต็มๆ
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(notification: notification),
      ),
    );
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
