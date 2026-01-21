// Widget สำหรับแสดง Incident card ในหน้า list
// Card มีสีพื้นหลังและขอบต่างกันตาม reflection status

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/tags_badges.dart';
import '../models/incident.dart';

/// Card สำหรับแสดง Incident ในหน้า list
/// ใช้ pattern เดียวกับ ListItemCard
class IncidentListCard extends StatelessWidget {
  final Incident incident;
  final VoidCallback onTap;

  const IncidentListCard({
    super.key,
    required this.incident,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _getCardBackgroundColor(),
        borderRadius: AppRadius.smallRadius,
        border: Border.all(
          color: _getCardBorderColor(),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smallRadius,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Severity indicator (แถบสีด้านซ้าย)
                Container(
                  width: 4,
                  height: 70,
                  decoration: BoxDecoration(
                    color: _getSeverityColor(incident.severity),
                    borderRadius: AppRadius.smallRadius,
                  ),
                ),
                AppSpacing.horizontalGapMd,

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + Shift badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              incident.title ?? 'ไม่มีชื่อ',
                              style: AppTypography.title.copyWith(fontSize: 15),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AppSpacing.horizontalGapSm,
                          // Shift badge
                          _buildShiftBadge(),
                        ],
                      ),

                      AppSpacing.verticalGapXs,

                      // Resident name + Zone + Date
                      Text(
                        _buildSubtitle(),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      AppSpacing.verticalGapSm,

                      // Status badge + Chat message count
                      Row(
                        children: [
                          _buildStatusBadge(),
                          const Spacer(),
                          // Chat message count (ถ้ามี)
                          if (incident.hasChatHistory) ...[
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedMessage01,
                              size: AppIconSize.sm,
                              color: AppColors.secondaryText,
                            ),
                            AppSpacing.horizontalGapXs,
                            Text(
                              '${incident.chatMessageCount}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                AppSpacing.horizontalGapSm,

                // Arrow
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: AppIconSize.md,
                  color: AppColors.secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// สร้างข้อความ subtitle (resident name, zone, date)
  String _buildSubtitle() {
    final parts = <String>[];

    if (incident.residentName != null) {
      parts.add(incident.residentName!);
    }
    if (incident.zoneName != null) {
      parts.add(incident.zoneName!);
    }
    if (incident.incidentDate != null) {
      parts.add(_formatDate(incident.incidentDate!));
    }

    return parts.join(' | ');
  }

  /// Format date เป็น dd/MM/yyyy
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// สร้าง shift badge (เวรเช้า/เวรดึก)
  Widget _buildShiftBadge() {
    // รองรับทั้ง 'NIGHT' เป็นเวรดึก, อื่นๆ (DAY/MORNING) เป็นเวรเช้า
    final isNight = incident.shift?.toUpperCase() == 'NIGHT';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isNight
            ? AppColors.pastelPurple.withValues(alpha: 0.5)
            : AppColors.pastelOrange.withValues(alpha: 0.5),
        borderRadius: AppRadius.smallRadius,
        border: Border.all(
          color: isNight
              ? AppColors.pastelPurple
              : AppColors.pastelOrange,
          width: 1,
        ),
      ),
      child: Text(
        incident.shiftDisplayText,
        style: AppTypography.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isNight
              ? const Color(0xFF554C6F)
              : const Color(0xFF8B5C3A),
        ),
      ),
    );
  }

  /// สร้าง status badge ตาม reflection status
  Widget _buildStatusBadge() {
    switch (incident.reflectionStatus) {
      case ReflectionStatus.pending:
        return StatusBadge.pending(
          text: 'รอดำเนินการ',
          icon: HugeIcons.strokeRoundedClock01,
        );
      case ReflectionStatus.inProgress:
        return StatusBadge(
          text: 'กำลังดำเนินการ',
          status: BadgeStatus.neutral,
          icon: HugeIcons.strokeRoundedLoading03,
        );
      case ReflectionStatus.completed:
        return StatusBadge.passed(
          text: 'เสร็จแล้ว',
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
    }
  }

  /// ดึงสีตาม severity
  Color _getSeverityColor(IncidentSeverity severity) {
    switch (severity) {
      case IncidentSeverity.low:
        return AppColors.tagPassedText;
      case IncidentSeverity.medium:
        return AppColors.warning;
      case IncidentSeverity.high:
        return AppColors.error;
      case IncidentSeverity.critical:
        return const Color(0xFF7B1F3B); // Dark red
    }
  }

  /// สีพื้นหลัง card ตาม reflection status
  /// - pending: สีเหลืองอ่อน (รอดำเนินการ)
  /// - in_progress: สีฟ้าอ่อน (กำลังดำเนินการ)
  /// - completed: สีขาว (เสร็จสิ้น)
  Color _getCardBackgroundColor() {
    switch (incident.reflectionStatus) {
      case ReflectionStatus.pending:
        return const Color(0xFFFFFBEB); // Warm yellow tint
      case ReflectionStatus.inProgress:
        return const Color(0xFFF0F9FF); // Light blue tint
      case ReflectionStatus.completed:
        return AppColors.secondaryBackground;
    }
  }

  /// สีขอบ card ตาม reflection status
  Color _getCardBorderColor() {
    switch (incident.reflectionStatus) {
      case ReflectionStatus.pending:
        return const Color(0xFFFCD34D); // Yellow border
      case ReflectionStatus.inProgress:
        return const Color(0xFF93C5FD); // Blue border
      case ReflectionStatus.completed:
        return AppColors.inputBorder; // Gray border
    }
  }
}
