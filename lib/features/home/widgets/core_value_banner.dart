import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Banner แสดง Core Value quote ก่อนขึ้นเวร
class CoreValueBanner extends StatelessWidget {
  const CoreValueBanner({super.key});

  // Core values list
  static const _coreValues = [
    'กล้าพูด กล้าสื่อสาร',
    'มี Service Mind ให้บริการด้วยความใส่ใจ',
    'ใช้ระบบแทนความจำ เพื่อใช้ศักยภาพทำเรื่องสำคัญ',
    'ซื่อสัตย์และรับผิดชอบต่อชีวิตคนที่เราดูแล',
    'เรียนรู้และพัฒนาอย่างต่อเนื่อง',
    'ทำงานร่วมกันอย่างเคารพและจริงใจ',
  ];

  String _getTodayQuote() {
    // Use date as seed for consistent quote per day
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);
    return _coreValues[random.nextInt(_coreValues.length)];
  }

  @override
  Widget build(BuildContext context) {
    final quote = _getTodayQuote();

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: AppRadius.mediumRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quote icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: AppRadius.smallRadius,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedQuoteUp,
              color: Colors.white,
              size: 20,
            ),
          ),

          AppSpacing.horizontalGapMd,

          // Quote text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'คติประจำวัน',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                AppSpacing.verticalGapXs,
                Text(
                  quote,
                  style: AppTypography.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
