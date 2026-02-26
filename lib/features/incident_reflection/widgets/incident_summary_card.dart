// Widget แสดงสรุปสถานะ Incidents บนหน้า Home
// เป็น shortcut ไปหน้าถอดบทเรียน

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/incident_provider.dart';

/// Card แสดงสรุปสถานะ Incidents เป็น shortcut ไปหน้าถอดบทเรียน
/// ใช้ pattern เดียวกับ DDSummaryCard, MonthlySummaryCard
class IncidentSummaryCard extends ConsumerWidget {
  final VoidCallback onTap;

  const IncidentSummaryCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentsAsync = ref.watch(myIncidentsProvider);

    return incidentsAsync.when(
      data: (incidents) {
        // รวม pending + in_progress เป็น "รอดำเนินการ"
        final pendingCount = incidents
            .where((i) =>
                i.reflectionStatus.value == 'pending' ||
                i.reflectionStatus.value == 'in_progress')
            .length;

        // ซ่อน card ถ้าไม่มี pending (ไม่ต้องรบกวน user)
        if (pendingCount == 0) return const SizedBox.shrink();

        final completedCount = incidents
            .where((i) => i.reflectionStatus.value == 'completed')
            .length;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            // margin: บน=0 (ลด gap จาก DD card), ล่าง=md (ให้ห่างจาก card ด้านล่าง)
            margin: EdgeInsets.only(bottom: AppSpacing.md),
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mediumRadius,
              // ใช้ shadow จาก theme เพื่อความสม่ำเสมอ
              boxShadow: [AppShadows.subtle],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smallRadius,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedBrain,
                        color: AppColors.primary,
                        size: AppIconSize.lg,
                      ),
                    ),
                    AppSpacing.horizontalGapSm,
                    Text(
                      'ถอดบทเรียน',
                      style: AppTypography.title.copyWith(fontSize: 16),
                    ),
                    const Spacer(),

                    // Red dot + badge for pending (รวม pending + in_progress)
                    if (pendingCount > 0) ...[
                      // Red notification dot
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      AppSpacing.horizontalGapXs,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: AppRadius.fullRadius,
                        ),
                        child: Text(
                          '$pendingCount รอดำเนินการ',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    AppSpacing.horizontalGapSm,
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      color: AppColors.secondaryText,
                      size: AppIconSize.md,
                    ),
                  ],
                ),

                AppSpacing.verticalGapMd,

                // Status Row - 2 columns (รวม pending + in_progress)
                Row(
                  children: [
                    _buildStatusItem(
                        'รอดำเนินการ', pendingCount, AppColors.warning),
                    _buildStatusItem(
                        'เสร็จสิ้น', completedCount, AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => _buildLoadingSkeleton(),
      // แสดง error แทน SizedBox.shrink() เพื่อให้ user รู้ว่าเกิดข้อผิดพลาด
      error: (error, _) => ErrorStateWidget(
        message: 'โหลดข้อมูลถอดบทเรียนไม่สำเร็จ',
        compact: true,
        onRetry: () => ref.invalidate(myIncidentsProvider),
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count.toString(),
            style: AppTypography.heading3.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.alternate,
                  borderRadius: AppRadius.smallRadius,
                ),
              ),
              AppSpacing.horizontalGapSm,
              Container(
                width: 80,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.alternate,
                  borderRadius: AppRadius.smallRadius,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
          // Stats skeleton - 2 columns
          Row(
            children: List.generate(
              2,
              (_) => Expanded(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.alternate,
                    borderRadius: AppRadius.smallRadius,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
