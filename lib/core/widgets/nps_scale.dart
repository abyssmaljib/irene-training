import 'dart:math' show cos, pi;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Configuration สำหรับแต่ละช่วงคะแนน (color zone)
/// ใช้กำหนดสีและ label สำหรับแต่ละช่วง เช่น 1-3 = ง่ายมาก (ฟ้า)
class NpsThreshold {
  final int from;
  final int to;
  final Color color;
  final String? label;

  const NpsThreshold({
    required this.from,
    required this.to,
    required this.color,
    this.label,
  });
}

/// NPS-style numeric scale widget (1-10)
///
/// ใช้สำหรับให้ user เลือกคะแนน เช่น ความยากของงาน, NPS score
/// แสดงเป็นแถวปุ่มตัวเลข 1-10 (หรือช่วงอื่นๆ)
///
/// Features:
/// - Horizontal row of clickable numbers
/// - Color zones ตาม thresholds
/// - Optional labels (min/max)
/// - Selected state มี background color
/// - Drag gesture: กดค้างแล้วลากซ้ายขวาเพื่อเปลี่ยนค่าได้ (เหมือน slider)
/// - Haptic feedback เมื่อเปลี่ยนค่า
class NpsScale extends StatefulWidget {
  /// คะแนนที่เลือกอยู่ (null = ยังไม่เลือก)
  final int? selectedValue;

  /// Callback เมื่อ user เลือกคะแนน
  final ValueChanged<int> onChanged;

  /// ค่าต่ำสุด (default: 1)
  final int minValue;

  /// ค่าสูงสุด (default: 10)
  final int maxValue;

  /// Label ที่แสดงใต้ค่าต่ำสุด (เช่น "ง่ายที่สุด")
  final String? minLabel;

  /// Label ที่แสดงใต้ค่าสูงสุด (เช่น "ยากที่สุด")
  final String? maxLabel;

  /// Color thresholds สำหรับแต่ละช่วงคะแนน
  /// ถ้าไม่กำหนด จะใช้สีเดียวกันทั้งหมด (primary)
  final List<NpsThreshold>? thresholds;

  /// ขนาดของแต่ละปุ่มตัวเลข (default: 36)
  final double itemSize;

  /// Callback เมื่อ user ปล่อยนิ้ว (touch end)
  /// ใช้สำหรับ auto-confirm เมื่อปล่อยนิ้ว
  final VoidCallback? onTouchEnd;

  const NpsScale({
    super.key,
    required this.selectedValue,
    required this.onChanged,
    this.minValue = 1,
    this.maxValue = 10,
    this.minLabel,
    this.maxLabel,
    this.thresholds,
    this.itemSize = 36,
    this.onTouchEnd,
  });

  @override
  State<NpsScale> createState() => _NpsScaleState();
}

class _NpsScaleState extends State<NpsScale> {
  /// ตำแหน่ง x ของนิ้วที่กำลังแตะ (สำหรับ dock magnification)
  double? _touchX;

  /// กำลังแตะอยู่หรือไม่
  bool _isTouching = false;

  /// ความกว้างของ widget (เก็บไว้คำนวณ scale factor)
  double _widgetWidth = 0;

  /// คำนวณ scale factor สำหรับแต่ละ item (dock-style magnification)
  /// item ที่ใกล้นิ้วจะขยายใหญ่ขึ้น, ไกลนิ้วจะเล็กลง
  double _getScaleFactor(int index) {
    // ถ้าไม่ได้แตะ หรือไม่รู้ตำแหน่ง = scale 1.0
    if (!_isTouching || _touchX == null || _widgetWidth <= 0) {
      return 1.0;
    }

    final itemCount = widget.maxValue - widget.minValue + 1;
    final itemWidth = _widgetWidth / itemCount;
    final itemCenterX = (index + 0.5) * itemWidth;
    final distance = (itemCenterX - _touchX!).abs();

    // Magnification parameters
    const maxScale = 1.5; // ขยายสูงสุด 1.5x
    const spreadRadius = 60.0; // รัศมีที่มีผล (pixels)

    // ถ้าไกลเกินรัศมี = scale 1.0
    if (distance > spreadRadius) return 1.0;

    // Smooth interpolation ด้วย cosine curve
    // ที่ distance=0 → scale=maxScale
    // ที่ distance=spreadRadius → scale=1.0
    final ratio = distance / spreadRadius;
    final scale = 1.0 + (maxScale - 1.0) * (1 + cos(ratio * pi)) / 2;
    return scale;
  }

  /// หาสีสำหรับคะแนนที่กำหนด
  Color _getColorForValue(int value) {
    if (widget.thresholds == null || widget.thresholds!.isEmpty) {
      return AppColors.primary;
    }

    for (final threshold in widget.thresholds!) {
      if (value >= threshold.from && value <= threshold.to) {
        return threshold.color;
      }
    }

    return AppColors.primary;
  }

  /// คำนวณค่าจากตำแหน่ง x
  int _getValueFromLocalX(double localX, double totalWidth) {
    if (totalWidth <= 0) return widget.minValue;

    final itemCount = widget.maxValue - widget.minValue + 1;
    final clampedX = localX.clamp(0.0, totalWidth);
    final ratio = clampedX / totalWidth;
    final index = (ratio * itemCount).floor().clamp(0, itemCount - 1);

    return widget.minValue + index;
  }

  /// จัดการ interaction (tap/drag) + track touch position สำหรับ magnification
  void _handleInteraction(Offset localPosition, double width) {
    // ป้องกัน setState หลัง unmount (เช่น ตอน dialog ปิด)
    if (!mounted) return;

    // Update touch position สำหรับ magnification effect
    setState(() {
      _touchX = localPosition.dx;
      _isTouching = true;
      _widgetWidth = width;
    });

    // คำนวณค่าที่เลือก
    final newValue = _getValueFromLocalX(localPosition.dx, width);

    if (newValue != widget.selectedValue) {
      HapticFeedback.selectionClick();
      widget.onChanged(newValue);
    }
  }

  /// เมื่อปล่อยนิ้ว (tap) - reset magnification แต่ไม่ auto-confirm
  void _handleTapEnd() {
    // ป้องกัน setState หลัง unmount
    if (!mounted) return;

    setState(() {
      _isTouching = false;
      // ไม่ reset _touchX เพื่อให้ animation กลับ smooth
    });

    // ไม่เรียก onTouchEnd เพราะเป็นแค่ tap ไม่ใช่ drag
  }

  /// เมื่อปล่อยนิ้ว (หลังลาก) - reset magnification + เรียก callback
  void _handlePanEnd() {
    // ป้องกัน setState หลัง unmount
    if (!mounted) return;

    setState(() {
      _isTouching = false;
      // ไม่ reset _touchX เพื่อให้ animation กลับ smooth
    });

    // เรียก callback (ถ้ามี) - ใช้สำหรับ auto-confirm
    // เรียกเฉพาะตอนลากแล้วปล่อย ไม่ใช่แค่กด
    widget.onTouchEnd?.call();
  }

  /// เมื่อเริ่มลาก - เริ่ม interaction และ update magnification
  void _handlePanStart(Offset localPosition, double width) {
    _handleInteraction(localPosition, width);
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.maxValue - widget.minValue + 1;

    // ใช้ RepaintBoundary เพื่อ isolate การ repaint ไม่ให้กระทบ parent
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ใช้ LayoutBuilder เพื่อรู้ความกว้างสำหรับคำนวณ magnification
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              return GestureDetector(
                // เมื่อแตะ - เริ่ม magnification + เลือกค่า (ไม่ auto-confirm)
                onTapDown: (details) =>
                    _handleInteraction(details.localPosition, width),
                onTapUp: (_) => _handleTapEnd(),
                onTapCancel: _handleTapEnd,
                // เมื่อลาก - update magnification + เลือกค่า
                // ปล่อยหลังลาก = auto-confirm
                onPanStart: (details) =>
                    _handlePanStart(details.localPosition, width),
                onPanUpdate: (details) =>
                    _handleInteraction(details.localPosition, width),
                onPanEnd: (_) => _handlePanEnd(),
                onPanCancel: _handlePanEnd,
                // ใช้ Stack เพื่อให้ขีดใน _RulerTick ประกบกับ baseline
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Layer 1: ตัวเลขและขีด - มี magnification effect
                    Row(
                      children: List.generate(itemCount, (index) {
                        final value = widget.minValue + index;
                        final isSelected = widget.selectedValue == value;
                        final color = _getColorForValue(value);
                        final scale = _getScaleFactor(index);

                        return Expanded(
                          // ใช้ Transform.scale เพื่อขยาย item ที่ใกล้นิ้ว
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.bottomCenter, // ขยายขึ้นด้านบน
                            child: _RulerTick(
                              value: value,
                              isSelected: isSelected,
                              color: color,
                            ),
                          ),
                        );
                      }),
                    ),

                    // Layer 2: baseline + minor ticks - วางด้านล่างประกบขีด
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0, // ติดขอบล่างของ Stack (= ขอบล่างของ _RulerTick)
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final totalWidth = constraints.maxWidth;
                          final slotWidth = totalWidth / itemCount;

                          return SizedBox(
                            height: 8, // baseline + minor tick height
                            child: Stack(
                              children: [
                                // เส้นแนวขวาง (baseline) - อยู่ล่างสุด
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryText
                                          .withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                                // ซี่ย่อย (minor ticks) - ระหว่างช่อง
                                for (int i = 0; i < itemCount - 1; i++)
                                  Positioned(
                                    left: slotWidth * (i + 1) - 0.5,
                                    bottom: 0,
                                    child: Container(
                                      width: 1,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: AppColors.secondaryText
                                            .withValues(alpha: 0.25),
                                        borderRadius:
                                            BorderRadius.circular(0.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        // Labels (min/max)
        if (widget.minLabel != null || widget.maxLabel != null) ...[
          SizedBox(height: AppSpacing.sm),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.minLabel != null)
                  Flexible(
                    child: Text(
                      widget.minLabel!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                if (widget.minLabel != null && widget.maxLabel != null)
                  const Spacer(),
                if (widget.maxLabel != null)
                  Flexible(
                    child: Text(
                      widget.maxLabel!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
              ],
            ),
          ),
        ],
        ],
      ),
    );
  }
}

/// Tick mark แบบ ruler - มีตัวเลขด้านบนและขีดยื่นลงมาหา track
/// เมื่อเลือก จะแสดงกรอบ pentagon (โล่) พร้อมพื้นหลังทึบ
class _RulerTick extends StatelessWidget {
  final int value;
  final bool isSelected;
  final Color color;

  const _RulerTick({
    required this.value,
    required this.isSelected,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // ใช้ Container กำหนดความสูงตายตัว + transparent background เพื่อให้ touch area ทำงาน
    // ขีด (tick) จะอยู่ติดขอบล่างเพื่อประกบกับ baseline
    return Container(
      height: 49, // fixed height: 35 (badge) + 2 (gap) + 12 (tick) - ไม่มี buffer
      color: Colors.transparent, // ทำให้ทั้งพื้นที่รับ touch ได้
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // พื้นที่สำหรับ pentagon badge หรือตัวเลข
          // ความสูง 35px สำหรับ touch area ที่ดี
          SizedBox(
            height: 35,
            child: Center(
              child: isSelected
                  ? _PentagonBadge(value: value, color: color)
                  : Text(
                      '$value',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 2),

          // ขีด (tick mark) - ติดขอบล่างเพื่อประกบ baseline
          Container(
            width: isSelected ? 3 : 2,
            height: isSelected ? 12 : 8,
            decoration: BoxDecoration(
              color: isSelected
                  ? color
                  : AppColors.secondaryText.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pentagon badge (รูปโล่/home plate) สำหรับแสดงค่าที่เลือก
class _PentagonBadge extends StatelessWidget {
  final int value;
  final Color color;

  const _PentagonBadge({
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PentagonPainter(color: color),
      child: SizedBox(
        width: 28,
        height: 32,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '$value',
              style: AppTypography.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter สำหรับวาด pentagon shape (โล่/home plate)
class _PentagonPainter extends CustomPainter {
  final Color color;

  _PentagonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final r = 4.0; // corner radius

    // วาด pentagon shape (คล้ายโล่/home plate)
    // เริ่มจากมุมซ้ายบน ไปตามเข็มนาฬิกา
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);
    path.lineTo(w, h * 0.6);
    path.quadraticBezierTo(w, h * 0.65, w - 2, h * 0.7);
    path.lineTo(w / 2 + 2, h - 2);
    path.quadraticBezierTo(w / 2, h, w / 2 - 2, h - 2);
    path.lineTo(2, h * 0.7);
    path.quadraticBezierTo(0, h * 0.65, 0, h * 0.6);
    path.lineTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.close();

    // วาด shadow
    canvas.drawShadow(path, Colors.black, 3, true);

    // วาด shape
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PentagonPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Default thresholds สำหรับ Task Difficulty (1-10)
/// - 1-3: ฟ้า (ง่ายมาก)
/// - 4-5: เขียว (ง่าย)
/// - 6-7: เหลือง (ปานกลาง)
/// - 8: ส้ม (ยากแต่ทำคนเดียวได้)
/// - 9-10: แดง (ยากมาก ต้องมีคนช่วย)
const kDifficultyThresholds = [
  NpsThreshold(
    from: 1,
    to: 3,
    color: Color(0xFF55B1C9), // Secondary Blue - ง่ายมาก
    label: 'ง่ายมาก',
  ),
  NpsThreshold(
    from: 4,
    to: 5,
    color: Color(0xFF0D9488), // Primary Teal - ง่าย
    label: 'ง่าย',
  ),
  NpsThreshold(
    from: 6,
    to: 7,
    color: Color(0xFFFFC107), // Amber - ปานกลาง
    label: 'ปานกลาง',
  ),
  NpsThreshold(
    from: 8,
    to: 8,
    color: Color(0xFFFF9800), // Orange - ยากแต่ทำคนเดียวได้
    label: 'ยากแต่ทำคนเดียวได้',
  ),
  NpsThreshold(
    from: 9,
    to: 10,
    color: Color(0xFFE53935), // Red - ต้องมีคนช่วย
    label: 'ต้องมีคนช่วย',
  ),
];
