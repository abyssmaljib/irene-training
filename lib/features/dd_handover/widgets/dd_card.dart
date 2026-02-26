import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/dd_record.dart';

/// Card สำหรับแสดงรายการ DD แต่ละรายการ
class DDCard extends StatelessWidget {
  final DDRecord record;
  final VoidCallback? onTap;
  final bool showCreatePostHint;
  final bool isUpcoming;
  final bool isOverdue;

  const DDCard({
    super.key,
    required this.record,
    this.onTap,
    this.showCreatePostHint = true,
    this.isUpcoming = false,
    this.isOverdue = false,
  });

  // ใช้สีจาก AppColors.ddXxx แทน hardcode — ง่ายต่อการเปลี่ยน theme
  static const _backgroundColor = AppColors.ddPendingBg;
  static const _borderColor = AppColors.ddPendingBorder;
  static const _upcomingBackgroundColor = AppColors.ddUpcomingBg;
  static const _upcomingBorderColor = AppColors.ddUpcomingAccent;
  static const _overdueBackgroundColor = AppColors.ddOverdueBg;
  static const _overdueBorderColor = AppColors.ddOverdueBorder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            boxShadow: [
              BoxShadow(
                blurRadius: (isUpcoming || isOverdue) ? 8.0 : 4.0,
                color: _getBorderColor(),
                offset: const Offset(0.0, 2.0),
              ),
            ],
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: _getBorderColor(),
              width: (isUpcoming || isOverdue) ? 2.0 : 1.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  color: AppColors.primaryText,
                  size: AppIconSize.md,
                ),
                SizedBox(width: AppSpacing.xs),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // วันเวลานัด + status badge
                      Row(
                        children: [
                          Text(
                            record.formattedDatetime,
                            style: AppTypography.body.copyWith(
                              color: _getDatetimeColor(),
                              fontSize: 14.0,
                              fontWeight: (isUpcoming || isOverdue)
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (isUpcoming || isOverdue) ...[
                            SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? AppColors.error
                                    : _upcomingBorderColor,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                isOverdue ? 'เลยกำหนด' : 'กำลังจะถึง',
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: AppSpacing.xs),
                      // หัวข้อ
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.appointmentTitle ?? '-',
                              style: AppTypography.body,
                            ),
                          ),
                        ],
                      ),
                      // รายละเอียด
                      if (record.appointmentDescription != null &&
                          record.appointmentDescription!.isNotEmpty) ...[
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          _truncate(record.appointmentDescription!, 50),
                          style: AppTypography.body.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                      SizedBox(height: AppSpacing.xs),
                      // Badges row
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          // ชื่อคนไข้
                          if (record.appointmentResidentId != null)
                            _buildBadge(
                              record.appointmentResidentName ?? '-',
                              AppColors.accent1,
                              AppColors.primary,
                            ),
                          // โรงพยาบาล
                          if (record.appointmentHospital != null &&
                              record.appointmentHospital!.isNotEmpty)
                            _buildBadge(
                              record.appointmentHospital!,
                              AppColors.accent3,
                              AppColors.tertiary,
                            ),
                          // NPO badge
                          if (record.appointmentIsNpo == true)
                            _buildBadge(
                              'NPO',
                              AppColors.error.withValues(alpha: 0.15),
                              AppColors.error,
                            ),
                        ],
                      ),
                      // ข้อความให้กดสร้างโพส
                      if (showCreatePostHint && !record.isCompleted) ...[
                        SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedInformationCircle,
                              color: AppColors.primaryText,
                              size: AppIconSize.lg,
                            ),
                            SizedBox(width: AppSpacing.xs),
                            Text(
                              'กดเพื่อสร้างโพสส่งเวร DD',
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // แสดงว่าส่งแล้ว
                      if (record.isCompleted) ...[
                        SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                              color: AppColors.success,
                              size: AppIconSize.lg,
                            ),
                            SizedBox(width: AppSpacing.xs),
                            Text(
                              'ส่งเวรแล้ว',
                              style: AppTypography.body.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        child: Text(
          text,
          style: AppTypography.bodySmall.copyWith(
            color: textColor,
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…';
  }

  Color _getBackgroundColor() {
    if (isOverdue) return _overdueBackgroundColor;
    if (isUpcoming) return _upcomingBackgroundColor;
    return _backgroundColor;
  }

  Color _getBorderColor() {
    if (isOverdue) return _overdueBorderColor;
    if (isUpcoming) return _upcomingBorderColor;
    return _borderColor;
  }

  Color _getDatetimeColor() {
    if (isOverdue) return AppColors.error;
    if (isUpcoming) return _upcomingBorderColor;
    return AppColors.secondaryText;
  }
}
