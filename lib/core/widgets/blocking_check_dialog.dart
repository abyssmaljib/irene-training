import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'buttons.dart';

/// สถานะของ blocking item (เช่น incident, task)
/// ใช้สำหรับกำหนดสีของ badge
enum BlockingItemStatus {
  /// รอดำเนินการ (สีส้ม/amber) - ยังไม่เริ่มทำ
  pending,

  /// กำลังดำเนินการ (สีฟ้า) - เริ่มทำแล้วแต่ยังไม่เสร็จ
  inProgress,

  /// ล้มเหลว/มีปัญหา (สีแดง)
  failed,
}

/// ข้อมูลสำหรับแต่ละ item ใน blocking list
class BlockingItemData {
  final String title;
  final String? subtitle;
  final BlockingItemStatus status;
  final String statusText;
  final dynamic icon;

  const BlockingItemData({
    required this.title,
    this.subtitle,
    required this.status,
    required this.statusText,
    this.icon,
  });
}

/// Reusable content widget สำหรับแสดงรายการที่ยังค้างอยู่
/// ใช้สำหรับ clock out, exit screen ที่ต้องตรวจสอบก่อน
///
/// หมายเหตุ: นี่คือ content widget ไม่ใช่ dialog
/// ใช้ภายใน Dialog wrapper ที่มีอยู่แล้ว
class BlockingCheckContent extends StatelessWidget {
  /// หัวข้อ
  final String title;

  /// รูปแมว (ใช้ asset path)
  final String imageAsset;

  /// ขนาดรูป
  final double imageSize;

  /// Rich text ด้านบน list (ถ้ามี)
  final Widget? richMessage;

  /// ข้อความธรรมดา (ถ้าไม่ใช้ richMessage)
  final String? message;

  /// รายการ items ที่ต้องแก้
  final List<BlockingItemData> items;

  /// จำนวนทั้งหมด (ถ้ามีมากกว่าที่แสดง)
  final int totalCount;

  /// จำนวนที่แสดง (default 5)
  final int displayLimit;

  /// Text สำหรับปุ่ม primary action
  final String primaryButtonText;

  /// Icon สำหรับปุ่ม primary
  final dynamic primaryButtonIcon;

  /// Callback เมื่อกด primary button
  final VoidCallback? onPrimaryPressed;

  /// Text สำหรับปุ่ม cancel (default: 'ยกเลิก')
  final String cancelButtonText;

  /// Callback เมื่อกด cancel
  final VoidCallback? onCancelPressed;

  const BlockingCheckContent({
    super.key,
    required this.title,
    this.imageAsset = 'assets/images/checking_cat.webp',
    this.imageSize = 160,
    this.richMessage,
    this.message,
    required this.items,
    required this.totalCount,
    this.displayLimit = 5,
    required this.primaryButtonText,
    this.primaryButtonIcon,
    this.onPrimaryPressed,
    this.cancelButtonText = 'ยกเลิก',
    this.onCancelPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            title,
            style: AppTypography.heading3,
            textAlign: TextAlign.center,
          ),

          AppSpacing.verticalGapMd,

          // Cat image
          Image.asset(
            imageAsset,
            width: imageSize,
            height: imageSize,
          ),

          AppSpacing.verticalGapMd,

          // Message
          if (richMessage != null)
            richMessage!
          else if (message != null)
            Text(
              message!,
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),

          AppSpacing.verticalGapMd,

          // Items List
          if (items.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount:
                    items.length > displayLimit ? displayLimit : items.length,
                itemBuilder: (context, index) {
                  return _BlockingItemTile(item: items[index]);
                },
              ),
            ),

            // "และอีก X รายการ..." text
            if (totalCount > displayLimit) ...[
              AppSpacing.verticalGapSm,
              Text(
                'และอีก ${totalCount - displayLimit} รายการ...',
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ],

          AppSpacing.verticalGapLg,

          // Primary Action Button
          PrimaryButton(
            text: primaryButtonText,
            onPressed: onPrimaryPressed,
            icon: primaryButtonIcon,
          ),

          AppSpacing.verticalGapSm,

          // Cancel Button
          TextButton(
            onPressed: onCancelPressed,
            child: Text(
              cancelButtonText,
              style: AppTypography.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal widget สำหรับแสดงแต่ละ item
class _BlockingItemTile extends StatelessWidget {
  final BlockingItemData item;

  const _BlockingItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    // กำหนดสีตาม status
    final (bgColor, borderColor, iconColor, textColor) = _getStatusColors();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Icon
          HugeIcon(
            icon: item.icon ?? HugeIcons.strokeRoundedAlert02,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  item.title,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                AppSpacing.verticalGapXs,

                // Subtitle + Status Badge
                Row(
                  children: [
                    // Subtitle (if any)
                    if (item.subtitle != null) ...[
                      Flexible(
                        child: Text(
                          item.subtitle!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text(' • '),
                    ],

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.statusText,
                        style: AppTypography.caption.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// คืนค่า (backgroundColor, borderColor, iconColor, textColor) ตาม status
  (Color, Color, Color, Color) _getStatusColors() {
    switch (item.status) {
      case BlockingItemStatus.pending:
        // สีส้ม/amber สำหรับ "รอดำเนินการ"
        return (
          AppColors.tagPendingBg,
          AppColors.warning,
          AppColors.warning,
          AppColors.tagPendingText,
        );

      case BlockingItemStatus.inProgress:
        // สีฟ้า สำหรับ "กำลังดำเนินการ"
        return (
          const Color(0xFFE3F2FD), // light blue bg
          const Color(0xFF2196F3), // blue border
          const Color(0xFF2196F3), // blue icon
          const Color(0xFF1565C0), // blue text (เข้มขึ้นให้อ่านง่าย)
        );

      case BlockingItemStatus.failed:
        // สีแดง สำหรับ "ล้มเหลว"
        return (
          AppColors.tagFailedBg,
          AppColors.error,
          AppColors.error,
          AppColors.tagFailedText,
        );
    }
  }
}