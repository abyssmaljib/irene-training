import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/dd_record.dart';
import '../providers/dd_provider.dart';

/// Summary Card สำหรับแสดงบน Home - แสดงจำนวน DD ที่รอทำ
class DDSummaryCard extends ConsumerStatefulWidget {
  final VoidCallback? onTap;

  const DDSummaryCard({
    super.key,
    this.onTap,
  });

  @override
  ConsumerState<DDSummaryCard> createState() => _DDSummaryCardState();
}

class _DDSummaryCardState extends ConsumerState<DDSummaryCard> {
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _userService.userChangedNotifier.addListener(_onUserChanged);
  }

  @override
  void dispose() {
    _userService.userChangedNotifier.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onUserChanged() {
    // Invalidate provider when user changes (impersonation)
    ref.invalidate(ddRecordsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pendingRecordsAsync = ref.watch(pendingDDRecordsProvider);

    return pendingRecordsAsync.when(
      loading: () => _buildLoadingCard(),
      error: (_, _) => const SizedBox.shrink(),
      data: (records) {
        if (records.isEmpty) return const SizedBox.shrink();
        return _buildCard(context, records);
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
        boxShadow: [AppShadows.subtle],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Text('กำลังโหลด...', style: AppTypography.body),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, List<DDRecord> records) {
    final count = records.length;
    final firstRecord = records.first;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.md),
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          // ใช้ style เดียวกับ cards อื่น (พื้นขาว + shadow)
          color: AppColors.surface,
          boxShadow: [AppShadows.subtle],
          borderRadius: AppRadius.mediumRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - style เหมือน IncidentSummaryCard
            Row(
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smallRadius,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendarCheckIn01,
                    color: AppColors.warning,
                    size: AppIconSize.lg,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'คุณมี $count งาน DD รอทำ',
                    style: AppTypography.title.copyWith(fontSize: 16),
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: AppColors.secondaryText,
                  size: AppIconSize.md,
                ),
              ],
            ),
            // แสดงรายละเอียด record แรก
            SizedBox(height: AppSpacing.sm),
            _buildRecordPreview(firstRecord),
            // ถ้ามีมากกว่า 1 รายการ
            if (count > 1) ...[
              SizedBox(height: AppSpacing.xs),
              Text(
                '+ อีก ${count - 1} รายการ',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordPreview(DDRecord record) {
    return Row(
      children: [
        // วันเวลา
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            record.formattedDatetime,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        // ข้อมูล
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'พา ${record.appointmentResidentName ?? '-'}',
                style: AppTypography.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (record.appointmentHospital != null)
                Text(
                  'ไป ${record.appointmentHospital}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
