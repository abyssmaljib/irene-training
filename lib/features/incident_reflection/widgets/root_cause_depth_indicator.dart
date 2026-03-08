// Widget แสดงระดับความลึกของ Root Cause Analysis
// แสดงเป็น 5 ระดับ: อาการ → สาเหตุตรง → ปัจจัยร่วม → เชิงระบบ → รากเหง้า
// ใช้แสดงใต้ PillarProgressIndicator เมื่อกำลังวิเคราะห์สาเหตุ (Pillar 2)

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';

/// ข้อมูลแต่ละระดับของ Root Cause Depth
class _DepthLevel {
  final int level;
  final String labelTh;
  final String labelEn;

  const _DepthLevel({
    required this.level,
    required this.labelTh,
    required this.labelEn,
  });
}

/// 5 ระดับความลึกของ Root Cause
const _depthLevels = [
  _DepthLevel(level: 1, labelTh: 'อาการ', labelEn: 'Symptom'),
  _DepthLevel(level: 2, labelTh: 'สาเหตุตรง', labelEn: 'Direct'),
  _DepthLevel(level: 3, labelTh: 'ปัจจัยร่วม', labelEn: 'Contributing'),
  _DepthLevel(level: 4, labelTh: 'เชิงระบบ', labelEn: 'Systemic'),
  _DepthLevel(level: 5, labelTh: 'รากเหง้า', labelEn: 'Root'),
];

/// Widget แสดงระดับความลึกของ Root Cause Analysis
/// แสดงเป็น progress bar 5 ขั้น พร้อม label ระดับปัจจุบัน
class RootCauseDepthIndicator extends StatelessWidget {
  /// ระดับความลึกปัจจุบัน (1-5) หรือ null ถ้ายังไม่เริ่ม
  final int? currentDepth;

  /// หมวด Fishbone ที่สำรวจแล้ว เช่น ["คน", "กระบวนการ"]
  final List<String> exploredCategories;

  /// คุณภาพการวิเคราะห์ ("shallow", "moderate", "deep")
  final String? analysisQuality;

  const RootCauseDepthIndicator({
    super.key,
    this.currentDepth,
    this.exploredCategories = const [],
    this.analysisQuality,
  });

  @override
  Widget build(BuildContext context) {
    // ไม่แสดงถ้ายังไม่มี depth data
    if (currentDepth == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // สีพื้นหลังตาม quality
        color: _qualityColor.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: AppColors.alternate.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Depth progress bar (5 ขั้น)
          _buildDepthBar(),

          // แสดงหมวด Fishbone ที่สำรวจแล้ว (ถ้ามี)
          if (exploredCategories.isNotEmpty) ...[
            AppSpacing.verticalGapXs,
            _buildCategoryChips(),
          ],
        ],
      ),
    );
  }

  /// สร้าง progress bar 5 ขั้น แสดงระดับความลึก
  Widget _buildDepthBar() {
    final depth = currentDepth ?? 0;

    return Row(
      children: [
        // Label "ความลึก"
        Text(
          'ระดับ',
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            color: AppColors.secondaryText,
          ),
        ),
        AppSpacing.horizontalGapSm,

        // 5 bars แสดงระดับ
        Expanded(
          child: Row(
            children: List.generate(5, (index) {
              final level = index + 1;
              final isReached = level <= depth;
              // สีตามระดับ: 1-2 = shallow (เหลือง), 3 = moderate (ส้ม), 4-5 = deep (เขียว)
              final barColor = isReached ? _colorForLevel(level) : AppColors.alternate.withValues(alpha: 0.3);

              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: index < 4 ? 2 : 0),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ),
        AppSpacing.horizontalGapSm,

        // Label ระดับปัจจุบัน
        Text(
          depth > 0 ? _depthLevels[depth - 1].labelTh : '',
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            color: _colorForLevel(depth),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// สร้าง chips แสดงหมวด Fishbone ที่สำรวจแล้ว
  Widget _buildCategoryChips() {
    return Row(
      children: [
        Text(
          'มิติ:',
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            color: AppColors.secondaryText,
          ),
        ),
        AppSpacing.horizontalGapXs,
        // แสดง category chips
        ...exploredCategories.map((category) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  category,
                  style: AppTypography.caption.copyWith(
                    fontSize: 9,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )),
      ],
    );
  }

  /// สีสำหรับแต่ละระดับความลึก
  /// Level 1-2: เหลือง/ส้มอ่อน (ยังตื้น)
  /// Level 3: ส้ม (กลาง)
  /// Level 4-5: เขียว (ลึก)
  Color _colorForLevel(int level) {
    switch (level) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.deepOrange;
      case 4:
        return AppColors.primary;
      case 5:
        return AppColors.primary;
      default:
        return AppColors.secondaryText;
    }
  }

  /// สีรวมตาม quality
  Color get _qualityColor {
    switch (analysisQuality) {
      case 'deep':
        return AppColors.primary;
      case 'moderate':
        return Colors.deepOrange;
      case 'shallow':
        return Colors.amber;
      default:
        return AppColors.secondaryText;
    }
  }
}
