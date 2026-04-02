import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/models.dart';
import '../providers/points_provider.dart';

// MyPointsTab - Tab "คะแนนของฉัน"
// แสดง points summary (tier + progress) + ประวัติคะแนน
// ย้ายมาจาก LeaderboardScreen เดิม + เพิ่ม tier progress bar

class MyPointsTab extends ConsumerWidget {
  const MyPointsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ดึง summary ของ user (total points, tier, week/month points)
    final summaryAsync = ref.watch(userPointsSummaryProvider);
    // ดึงประวัติคะแนน
    final historyAsync = ref.watch(
      pointsHistoryProvider(const HistoryParams(limit: 100)),
    );

    return Column(
      children: [
        // Summary Card (tier + points + progress)
        summaryAsync.when(
          data: (summary) =>
              summary != null ? _buildSummaryCard(summary) : const SizedBox.shrink(),
          loading: () => _buildSummarySkeleton(),
          // แสดง error แทน SizedBox.shrink() เพื่อให้ user รู้ว่าเกิดข้อผิดพลาด
          error: (error, _) => ErrorStateWidget(
            message: 'โหลดข้อมูลคะแนนไม่สำเร็จ',
            compact: true,
            onRetry: () => ref.invalidate(userPointsSummaryProvider),
          ),
        ),

        // History List
        Expanded(
          child: historyAsync.when(
            data: (history) => _buildHistoryList(history),
            loading: () => ShimmerWrapper(
              isLoading: true,
              child: Column(
                children: List.generate(2, (_) => const SkeletonCard()),
              ),
            ),
            error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
          ),
        ),
      ],
    );
  }

  // สี tier ที่เข้มขึ้นสำหรับ light background
  // DB colors บางตัวจางมาก (Silver=#C0C0C0, Platinum=#E5E4E2, Diamond=#B9F2FF)
  static const _tierDisplayColors = {
    'Bronze': Color(0xFF92400E),   // amber-800
    'Silver': Color(0xFF4B5563),   // gray-600
    'Gold': Color(0xFFB45309),     // amber-700
    'Platinum': Color(0xFF6D28D9), // violet-700
    'Diamond': Color(0xFF0369A1),  // sky-700
  };

  /// Card แสดง tier, total points, week/month points, และ progress bar
  Widget _buildSummaryCard(UserPointsSummary summary) {
    // ใช้ mapping สีเข้มแทน DB color ที่จางเกินไปบนพื้นขาว
    final tierColor = _tierDisplayColors[summary.tierName] ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tierColor.withValues(alpha: 0.15),
            tierColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(
          color: tierColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Tier icon + tier name + total points
          Row(
            children: [
              // Tier icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    summary.tierIcon ?? '🏆',
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Tier name + total points + percentile info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tier name + percentile badge (ถ้ามี)
                    Row(
                      children: [
                        Text(
                          summary.tierDisplayName,
                          style: AppTypography.label.copyWith(
                            color: tierColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // แสดง "Top X%" badge ถ้าเป็น percentile mode
                        if (summary.percentileDisplay != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              summary.percentileDisplay!,
                              style: AppTypography.caption.copyWith(
                                color: tierColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.totalPoints} คะแนน',
                      style: AppTypography.heading2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    // แสดง "อันดับ X จาก Y คน" ถ้าเป็น percentile mode
                    if (summary.rankDisplay != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary.rankDisplay!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Progress bar ไป next tier
          if (!summary.isMaxTier) ...[
            // Progress bar
            ClipRRect(
              borderRadius: AppRadius.smallRadius,
              child: LinearProgressIndicator(
                value: summary.progressToNextTier,
                backgroundColor: tierColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // อีก X คะแนนถึง next tier
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  // Percentile mode: แสดงจำนวนคะแนนที่ต้องเพิ่ม
                  // Fixed mode: แสดงจำนวนคะแนนที่เหลือ
                  summary.isPercentileMode
                      ? 'อีก ~${summary.pointsToNextTier} คะแนน'
                      : 'อีก ${summary.pointsToNextTier} คะแนน',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  summary.nextTierName ?? '',
                  style: AppTypography.caption.copyWith(
                    color: tierColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            // ถึง tier สูงสุดแล้ว — แสดงข้อความพิเศษ
            if (summary.isPercentileMode) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '🎉 คุณอยู่ระดับสูงสุดแล้ว!',
                style: AppTypography.caption.copyWith(
                  color: tierColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],

          // สถิติคะแนน: Season นี้ / สัปดาห์นี้ / เดือนนี้
          Row(
            children: [
              // Season นี้ (คะแนนตั้งแต่ season เริ่ม รวม carry-over bonus)
              Expanded(
                child: _buildStatBox(
                  label: 'Season นี้',
                  value: summary.seasonPoints,
                  color: tierColor,
                  showSign: false,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // สัปดาห์นี้
              Expanded(
                child: _buildStatBox(
                  label: 'สัปดาห์นี้',
                  value: summary.weekPoints,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // เดือนนี้
              Expanded(
                child: _buildStatBox(
                  label: 'เดือนนี้',
                  value: summary.monthPoints,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Stat box สำหรับแสดงคะแนนแต่ละช่วงเวลา (สัปดาห์นี้, เดือนนี้, 3 เดือน)
  Widget _buildStatBox({
    required String label,
    required int value,
    required Color color,
    bool showSign = true, // ใส่ +/- นำหน้าหรือไม่
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.smallRadius,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            showSign
                ? '${value >= 0 ? '+' : ''}$value'
                : '$value',
            style: AppTypography.title.copyWith(
              color: showSign
                  ? (value >= 0 ? color : AppColors.error)
                  : color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Skeleton สำหรับ summary card ตอน loading
  Widget _buildSummarySkeleton() {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.alternate,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.alternate,
                    borderRadius: AppRadius.smallRadius,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.alternate,
                    borderRadius: AppRadius.smallRadius,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// List แสดงประวัติการได้รับคะแนน
  Widget _buildHistoryList(List<PointTransaction> history) {
    if (history.isEmpty) {
      return _buildEmpty();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final tx = history[index];
        return _HistoryListItem(transaction: tx);
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📝', style: TextStyle(fontSize: 64)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'ยังไม่มีประวัติคะแนน',
            style: AppTypography.title.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'ทำกิจกรรมเพื่อสะสมคะแนน!',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// แต่ละ row ใน history list
class _HistoryListItem extends StatelessWidget {
  final PointTransaction transaction;

  const _HistoryListItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isPositive = transaction.isPositive;
    final pointColor = isPositive ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Row(
        children: [
          // Icon ตาม transaction type
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: pointColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.smallRadius,
            ),
            child: Center(
              child: Text(
                transaction.transactionType.icon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Description + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ??
                      transaction.transactionType.displayName,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(transaction.createdAt),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Points change
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: pointColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.smallRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: isPositive
                      ? HugeIcons.strokeRoundedArrowUp01
                      : HugeIcons.strokeRoundedArrowDown01,
                  color: pointColor,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  transaction.displayPoints,
                  style: AppTypography.label.copyWith(
                    color: pointColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Format วันที่แบบ relative (วันนี้, เมื่อวาน, X วันที่แล้ว)
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'วันนี้ ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays == 1) {
      return 'เมื่อวาน ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} วันที่แล้ว';
    } else {
      return DateFormat('d MMM yyyy', 'th').format(date);
    }
  }
}
