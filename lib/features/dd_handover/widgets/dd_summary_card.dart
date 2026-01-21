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

  // สีพิเศษสำหรับ DD Card
  static const _backgroundColor = Color(0xFFFFFFD9);
  static const _borderColor = Color(0xFFF1EF99);

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
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: _borderColor),
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
        margin: EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: _backgroundColor,
          boxShadow: const [
            BoxShadow(
              blurRadius: 4.0,
              color: _borderColor,
              offset: Offset(0.0, 2.0),
            ),
          ],
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: _borderColor),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendarCheckIn01,
                    color: AppColors.warning,
                    size: AppIconSize.xl,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'คุณมี $count งาน DD รอทำ',
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: AppColors.secondaryText,
                    size: AppIconSize.lg,
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
