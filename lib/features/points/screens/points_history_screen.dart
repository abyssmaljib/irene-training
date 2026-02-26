import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../models/models.dart';
import '../providers/points_provider.dart';

// PointsHistoryScreen - หน้าแสดงประวัติการได้รับ points
// Group by date

class PointsHistoryScreen extends ConsumerWidget {
  const PointsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(
      pointsHistoryProvider(const HistoryParams(limit: 100)),
    );
    final summaryAsync = ref.watch(userPointsSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: const IreneSecondaryAppBar(
        title: 'ประวัติคะแนน',
      ),
      body: Column(
        children: [
          // Total points header
          summaryAsync.when(
            data: (summary) => summary != null
                ? _buildHeader(summary)
                : const SizedBox.shrink(),
            // แสดง error แทน SizedBox.shrink() เพื่อให้ user รู้ว่าเกิดข้อผิดพลาด
            loading: () => const SizedBox.shrink(),
            error: (error, _) => ErrorStateWidget(
              message: 'โหลดข้อมูลคะแนนไม่สำเร็จ',
              compact: true,
              onRetry: () => ref.invalidate(userPointsSummaryProvider),
            ),
          ),

          // Transaction list
          Expanded(
            child: historyAsync.when(
              data: (transactions) => _buildTransactionList(transactions),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(UserPointsSummary summary) {
    Color tierColor = AppColors.primary;
    if (summary.tierColor != null) {
      try {
        tierColor = Color(
          int.parse(summary.tierColor!.replaceFirst('#', '0xFF')),
        );
      } catch (_) {}
    }

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
      ),
      child: Row(
        children: [
          // Tier icon
          Text(
            summary.tierIcon ?? '🏆',
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(width: AppSpacing.md),

          // Points info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'คะแนนรวม',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${summary.totalPoints}',
                  style: AppTypography.heading2.copyWith(
                    color: tierColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // This week / month
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'สัปดาห์นี้',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '+${summary.weekPoints}',
                style: AppTypography.title.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<PointTransaction> transactions) {
    if (transactions.isEmpty) {
      return _buildEmpty();
    }

    // Group by date
    final grouped = <DateTime, List<PointTransaction>>{};
    for (final tx in transactions) {
      final date = tx.transactionDate;
      grouped.putIfAbsent(date, () => []).add(tx);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // newest first

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final txList = grouped[date]!;
        return _DateGroup(date: date, transactions: txList);
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📋', style: TextStyle(fontSize: 64)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'ยังไม่มีประวัติ',
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

/// Group ของ transactions ตาม date
class _DateGroup extends StatelessWidget {
  final DateTime date;
  final List<PointTransaction> transactions;

  const _DateGroup({
    required this.date,
    required this.transactions,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'วันนี้';
    } else if (date == yesterday) {
      return 'เมื่อวาน';
    } else {
      return DateFormat('d MMM yyyy', 'th').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(
            _formatDate(date),
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Transactions
        ...transactions.map((tx) => _TransactionItem(transaction: tx)),

        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// แต่ละ transaction row
class _TransactionItem extends StatelessWidget {
  final PointTransaction transaction;

  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isPositive = transaction.isPositive;
    final color = isPositive ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smallRadius,
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
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

          // Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.transactionType.displayName,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (transaction.description != null)
                  Text(
                    transaction.description!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Points
          Text(
            transaction.displayPoints,
            style: AppTypography.title.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
