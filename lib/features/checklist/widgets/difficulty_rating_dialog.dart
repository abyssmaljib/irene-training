import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/nps_scale.dart';
import '../../../core/widgets/success_popup.dart';

/// ผลลัพธ์จาก DifficultyRatingDialog
/// - null = user ปิด dialog โดยไม่ทำอะไร (กด back หรือ tap outside)
/// - DifficultyResult = user กดยืนยัน หรือ กดข้าม
class DifficultyResult {
  /// คะแนนที่เลือก (1-10)
  /// null = user กดข้าม (ไม่ให้คะแนน)
  final int? score;

  /// true = user กดข้าม, false = user กดยืนยัน
  final bool skipped;

  const DifficultyResult({
    this.score,
    this.skipped = false,
  });

  /// สร้าง result สำหรับกรณี skip
  const DifficultyResult.skip()
      : score = null,
        skipped = true;

  /// สร้าง result สำหรับกรณีเลือกคะแนน
  DifficultyResult.withScore(int selectedScore)
      : score = selectedScore,
        skipped = false;
}

/// Dialog แสดงหลังทำ task เสร็จ เพื่อให้ user ให้คะแนนความยาก
///
/// UI คล้าย NPS score:
/// - Title: "งานนี้ยากแค่ไหน?"
/// - NpsScale widget (1-10)
/// - Labels อธิบายความหมาย
/// - ปุ่ม "ข้าม" และ "ยืนยัน"
///
/// Returns:
/// - null = user ปิด dialog โดยไม่ทำอะไร
/// - DifficultyResult = user กดยืนยัน หรือ กดข้าม
class DifficultyRatingDialog extends StatefulWidget {
  /// ชื่องาน (แสดงให้ user เห็นว่ากำลังให้คะแนนงานอะไร)
  final String? taskTitle;

  /// ให้ข้ามได้หรือไม่ (default: true)
  final bool allowSkip;

  /// ค่าเฉลี่ยคะแนนความยากย้อนหลัง 30 วัน (null = ไม่มีข้อมูล)
  final double? avgScore;

  /// คะแนนเริ่มต้น (สำหรับแก้ไข) - ถ้าไม่ระบุจะใช้ 5
  final int? initialScore;

  const DifficultyRatingDialog({
    super.key,
    this.taskTitle,
    this.allowSkip = true,
    this.avgScore,
    this.initialScore,
  });

  /// Show dialog และ return ผลลัพธ์
  ///
  /// Returns:
  /// - null = user ปิด dialog โดยไม่ทำอะไร (กด back)
  /// - DifficultyResult = user กดยืนยัน หรือ กดข้าม
  static Future<DifficultyResult?> show(
    BuildContext context, {
    String? taskTitle,
    bool allowSkip = true,
    double? avgScore,
    int? initialScore,
  }) async {
    return showDialog<DifficultyResult>(
      context: context,
      barrierDismissible: true, // กดนอก modal เพื่อปิดได้
      builder: (context) => DifficultyRatingDialog(
        taskTitle: taskTitle,
        allowSkip: allowSkip,
        avgScore: avgScore,
        initialScore: initialScore,
      ),
    );
  }

  @override
  State<DifficultyRatingDialog> createState() => _DifficultyRatingDialogState();
}

class _DifficultyRatingDialogState extends State<DifficultyRatingDialog> {
  /// คะแนนที่ user เลือก
  /// - ถ้ามี initialScore จะใช้ค่านั้น (สำหรับแก้ไข)
  /// - ถ้าไม่มี จะใช้ 5 เป็น default
  late int? _selectedScore;

  /// ป้องกันการ confirm ซ้ำ (เช่น ปล่อยนิ้วหลายครั้ง)
  bool _hasConfirmed = false;

  @override
  void initState() {
    super.initState();
    // ใช้ initialScore ถ้ามี (สำหรับแก้ไข) หรือ 5 เป็น default
    _selectedScore = widget.initialScore ?? 5;
  }

  /// Emoji สำหรับแต่ละคะแนน (1-10)
  static const _scoreEmojis = {
    1: '😎',
    2: '🤗',
    3: '🙂',
    4: '😀',
    5: '😃',
    6: '🤔',
    7: '😥',
    8: '😫',
    9: '😱',
    10: '🤯',
  };

  /// จัดการเมื่อ user ปล่อยนิ้ว = ยืนยันคะแนน
  Future<void> _handleConfirm() async {
    // ป้องกัน confirm ซ้ำ
    if (_hasConfirmed) return;
    _hasConfirmed = true;

    // ต้องมีคะแนนที่เลือกอยู่
    if (_selectedScore == null) {
      _hasConfirmed = false;
      return;
    }

    // === เล่นเสียง "หยดน้ำ" ทันทีที่ปล่อยนิ้ว ===
    SoundService.instance.playTaskComplete();

    // หา emoji และ color สำหรับ popup
    final emoji = _scoreEmojis[_selectedScore];
    Color? color;
    for (final threshold in kDifficultyThresholds) {
      if (_selectedScore! >= threshold.from && _selectedScore! <= threshold.to) {
        color = threshold.color;
        break;
      }
    }

    // แสดง success popup พร้อม emoji
    await SuccessPopup.show(
      context,
      emoji: emoji,
      message: 'บันทึกแล้ว',
      color: color,
      autoCloseDuration: const Duration(milliseconds: 800),
    );

    // ปิด dialog และ return ผลลัพธ์
    if (mounted) {
      Navigator.pop(context, DifficultyResult.withScore(_selectedScore!));
    }
  }

  @override
  Widget build(BuildContext context) {
    // กด back ได้ → ปิด dialog → return null (ยังไม่ได้เปลี่ยนสถานะ task)
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeRadius, // 24px for modals
      ),
      backgroundColor: AppColors.surface,
      contentPadding: EdgeInsets.zero,
      // ลด padding จากขอบจอเหลือ 16px เพื่อให้ modal กว้างขึ้น
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      content: SizedBox(
        width: double.maxFinite, // ให้กว้างเต็มที่ (ลบ insetPadding)
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(), // ไม่ให้ scroll ด้วยมือ
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            SizedBox(height: AppSpacing.lg),

            // Icon (scale/meter)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.tagPendingBg, // สีเหลืองอ่อน
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedChartLineData03,
                  color: AppColors.warning,
                  size: AppIconSize.xl,
                ),
              ),
            ),

            SizedBox(height: AppSpacing.md),

            // Title
            Text(
              'งานนี้ยากแค่ไหน?',
              style: AppTypography.title.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppSpacing.xs),

            // Subtitle (task title ถ้ามี)
            if (widget.taskTitle != null && widget.taskTitle!.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  widget.taskTitle!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // NOTE: ไม่แสดงค่าเฉลี่ยตอน rating เพื่อหลีกเลี่ยง anchoring bias
            // ถ้าต้องการแสดงในอนาคต ใช้ widget.avgScore ได้

            SizedBox(height: AppSpacing.lg),

            // แสดง Emoji ตามคะแนนที่เลือก (ใหญ่ๆ)
            // ไม่ใช้ AnimatedSwitcher เพราะทำให้เกิด duplicate keys ตอน drag เร็วๆ
            SizedBox(
              height: 72, // เพิ่มจาก 56 เพื่อให้ emoji มีพื้นที่พอ
              child: Center(
                child: _selectedScore != null
                    ? Text(
                        _scoreEmojis[_selectedScore] ?? '🤔',
                        style: const TextStyle(fontSize: 56),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            SizedBox(height: AppSpacing.md),

            // NPS Scale (1-10)
            // เมื่อปล่อยนิ้ว = ยืนยันทันที (ไม่ต้องกดปุ่ม)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: NpsScale(
                selectedValue: _selectedScore,
                onChanged: (value) {
                  setState(() {
                    _selectedScore = value;
                  });
                },
                // เมื่อปล่อยนิ้ว = auto-confirm
                onTouchEnd: _handleConfirm,
                minValue: 1,
                maxValue: 10,
                minLabel: '1 = ง่ายมาก',
                maxLabel: '10 = ยากมาก',
                thresholds: kDifficultyThresholds,
                itemSize: 32, // เล็กลงเพื่อให้พอดี
              ),
            ),

            SizedBox(height: AppSpacing.sm),

            // Hint text บอกวิธีใช้ (ปล่อยมือ หรือ กดปุ่มก็ได้)
            Text(
              '👆 ลากไปมาแล้วปล่อย หรือกดปุ่มยืนยัน',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),

            SizedBox(height: AppSpacing.md),

            // Legend (อธิบายความหมายทุกช่วง)
            Container(
              margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              padding: AppSpacing.paddingSm,
              decoration: BoxDecoration(
                color: AppColors.tagNeutralBg,
                borderRadius: AppRadius.smallRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem(
                    '1-3',
                    'ง่ายมาก',
                    const Color(0xFF55B1C9),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  _buildLegendItem(
                    '4-5',
                    'ง่าย',
                    const Color(0xFF0D9488),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  _buildLegendItem(
                    '6-7',
                    'ปานกลาง',
                    const Color(0xFFFFC107),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  _buildLegendItem(
                    '8',
                    'ยากที่สุดที่ทำคนเดียวได้',
                    const Color(0xFFFF9800),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  _buildLegendItem(
                    '9-10',
                    'ต้องมีคนช่วย',
                    const Color(0xFFE53935),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.md),

            // ปุ่มยืนยัน (primary button + floppy disk icon)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PrimaryButton(
                text: 'ยืนยัน',
                icon: HugeIcons.strokeRoundedFloppyDisk,
                width: double.infinity,
                onPressed: _handleConfirm,
              ),
            ),

            SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  /// สร้าง legend item (สี + ช่วง + คำอธิบาย)
  Widget _buildLegendItem(
    String range,
    String description,
    Color color,
  ) {
    return Row(
      children: [
        // สี indicator
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        // ช่วง
        Text(
          range,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(width: AppSpacing.xs),
        // คำอธิบาย
        Expanded(
          child: Text(
            description,
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}
