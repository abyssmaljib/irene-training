import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../models/app_notification.dart';

/// หน้าแสดงรายละเอียด notification เต็มๆ
/// แสดง title, body, เวลา, ประเภท และรูปภาพ (ถ้ามี)
class NotificationDetailScreen extends StatelessWidget {
  final AppNotification notification;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      // ใช้ IreneSecondaryAppBar ที่มีปุ่มย้อนกลับ
      appBar: IreneSecondaryAppBar(
        title: 'รายละเอียด',
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalGapMd,
            // Header section: icon + type badge + time
            _buildHeader(),
            AppSpacing.verticalGapLg,
            // Title
            Text(
              notification.title,
              style: AppTypography.heading3.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.verticalGapMd,
            // Image (ถ้ามี)
            if (notification.imageUrl != null &&
                notification.imageUrl!.isNotEmpty)
              _buildImage(),
            // Body content
            _buildBody(),
            AppSpacing.verticalGapXl,
            // Metadata section
            _buildMetadata(),
            AppSpacing.verticalGapXl,
          ],
        ),
      ),
    );
  }

  /// สร้าง header แสดง icon, type badge และเวลา
  Widget _buildHeader() {
    final iconData = _getIconForType(notification.type);
    final color = _getColorForType(notification.type);

    return Row(
      children: [
        // Icon ประเภท notification
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: HugeIcon(
              icon: iconData,
              color: color,
              size: AppIconSize.xl,
            ),
          ),
        ),
        AppSpacing.horizontalGapMd,
        // Type badge และเวลา
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  notification.type.displayName,
                  style: AppTypography.label.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppSpacing.verticalGapXs,
              // เวลาที่สร้าง
              Text(
                notification.relativeTime,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        // Read status indicator
        if (!notification.isRead)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'ใหม่',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// สร้างส่วนแสดงรูปภาพ (ถ้ามี)
  Widget _buildImage() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: AppRadius.mediumRadius,
          child: Image.network(
            notification.imageUrl!,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // ถ้าโหลดรูปไม่ได้ ไม่แสดงอะไร
              return SizedBox.shrink();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              // แสดง loading indicator ขณะโหลดรูป
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.alternate,
                  borderRadius: AppRadius.mediumRadius,
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    color: AppColors.primary,
                  ),
                ),
              );
            },
          ),
        ),
        AppSpacing.verticalGapMd,
      ],
    );
  }

  /// สร้างส่วนแสดง body content
  Widget _buildBody() {
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: AppColors.alternate),
      ),
      child: Text(
        notification.body,
        style: AppTypography.body.copyWith(
          height: 1.6, // เพิ่ม line height ให้อ่านง่าย
        ),
      ),
    );
  }

  /// สร้างส่วนแสดง metadata (เวลาเต็ม, reference info)
  Widget _buildMetadata() {
    // Format เวลาแบบเต็ม (ใช้ format ที่ไม่ต้องพึ่ง locale)
    final formattedDate = _formatThaiDate(notification.createdAt);

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: AppColors.alternate.withValues(alpha: 0.3),
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // เวลาสร้าง
          _buildMetadataRow(
            icon: HugeIcons.strokeRoundedClock01,
            label: 'เวลาแจ้งเตือน',
            value: formattedDate,
          ),
          // Reference table (ถ้ามี)
          if (notification.referenceTable != null) ...[
            AppSpacing.verticalGapSm,
            _buildMetadataRow(
              icon: HugeIcons.strokeRoundedLink01,
              label: 'อ้างอิงจาก',
              value: _getReadableTableName(notification.referenceTable!),
            ),
          ],
          // Reference ID (ถ้ามี)
          if (notification.referenceId != null) ...[
            AppSpacing.verticalGapSm,
            _buildMetadataRow(
              icon: HugeIcons.strokeRoundedTag01,
              label: 'รหัสอ้างอิง',
              value: '#${notification.referenceId}',
            ),
          ],
        ],
      ),
    );
  }

  /// สร้าง row แสดง metadata แต่ละรายการ
  Widget _buildMetadataRow({
    required dynamic icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HugeIcon(
          icon: icon,
          color: AppColors.secondaryText,
          size: AppIconSize.sm,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              Text(
                value,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// แปลงชื่อ table เป็นชื่อที่อ่านง่าย
  String _getReadableTableName(String tableName) {
    switch (tableName) {
      case 'posts':
        return 'โพสต์';
      case 'tasks':
        return 'งาน';
      case 'task_logs':
        return 'บันทึกงาน';
      case 'comments':
        return 'ความคิดเห็น';
      case 'badges':
        return 'เหรียญรางวัล';
      case 'calendar_events':
        return 'นัดหมาย';
      case 'residents':
        return 'ผู้รับบริการ';
      case 'user_info':
        return 'ผู้ใช้';
      default:
        return tableName;
    }
  }

  /// ดึง icon ตามประเภท notification
  /// ต้อง sync กับ notification_item.dart
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
    }
  }

  /// ดึงสีตามประเภท notification
  /// ต้อง sync กับ notification_item.dart
  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.post:
        return AppColors.pastelDarkGreen1;
      case NotificationType.task:
        return AppColors.pastelOrange;
      case NotificationType.calendar:
        return AppColors.pastelPurple;
      case NotificationType.badge:
        return AppColors.pastelYellow;
      case NotificationType.comment:
        return AppColors.pastelLightGreen1;
      case NotificationType.system:
        return AppColors.primary;
      case NotificationType.review:
        return AppColors.pastelRed;
      case NotificationType.assignment:
        return AppColors.secondary;
    }
  }

  /// Format วันที่เป็นภาษาไทยแบบ manual (ไม่ต้องใช้ intl locale)
  String _formatThaiDate(DateTime date) {
    const thaiDays = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    const thaiMonths = [
      'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
      'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
    ];

    final dayName = thaiDays[date.weekday % 7];
    final monthName = thaiMonths[date.month - 1];
    final buddhistYear = date.year + 543;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return 'วัน$dayName ที่ ${date.day} $monthName $buddhistYear เวลา $hour:$minute น.';
  }
}
