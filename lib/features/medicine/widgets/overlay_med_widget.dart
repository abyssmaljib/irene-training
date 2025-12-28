import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Widget แสดงจำนวนเม็ดยาเป็น visual circles
/// - วงเต็ม = กินทั้งเม็ด (โปร่งใส)
/// - วงไม่เต็ม = กินบางส่วน (สีเขียว = ส่วนที่ไม่ต้องกิน)
class OverlayMedWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final double? takeTab;

  const OverlayMedWidget({
    super.key,
    this.width,
    this.height,
    this.takeTab,
  });

  @override
  Widget build(BuildContext context) {
    final double w = width ?? 120.0;
    final double h = height ?? 120.0;

    // แปลง input เป็นจำนวนวงกลม + fraction ต่อวง
    final double raw = (takeTab ?? 0).clamp(0.0, double.infinity);

    final int fullPills = raw.floor(); // เม็ดเต็ม
    final double remainder = raw - fullPills; // เศษเม็ดสุดท้าย

    final List<double> fractions = [];
    for (int i = 0; i < fullPills; i++) {
      fractions.add(1.0); // เม็ดเต็ม = วงเต็ม
    }
    if (remainder > 0.001) {
      fractions.add(remainder); // เม็ดสุดท้ายเป็นเศษ
    }

    if (fractions.isEmpty) {
      return const SizedBox.shrink();
    }

    const double outerPadding = 8.0; // เว้นขอบจากขอบรูป
    const double spacing = 4.0; // ระยะห่างระหว่างวงในแนวนอน
    const double runSpacing = 4.0; // ระยะห่างระหว่างแถว
    const int maxPerRow = 5; // ไม่เกิน 5 วงต่อแถว

    return SizedBox(
      width: w,
      height: h,
      child: Padding(
        padding: const EdgeInsets.all(outerPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final int pillCount = fractions.length;
            final int columns = math.min(pillCount, maxPerRow);
            final int rows = (pillCount + maxPerRow - 1) ~/ maxPerRow;

            final double availableWidth = constraints.maxWidth;
            final double availableHeight = constraints.maxHeight;

            final double pillSizeByWidth =
                (availableWidth - spacing * (columns - 1)) / columns;
            final double pillSizeByHeight =
                (availableHeight - runSpacing * (rows - 1)) / rows;

            final double pillSize = math.min(pillSizeByWidth, pillSizeByHeight);

            return Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: spacing,
                runSpacing: runSpacing,
                children: [
                  for (final fraction in fractions)
                    SizedBox(
                      width: pillSize,
                      height: pillSize,
                      child: CustomPaint(
                        painter: _MedCirclePainter(
                          fraction: fraction.clamp(0.0, 1.0),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MedCirclePainter extends CustomPainter {
  /// fraction = สัดส่วนเม็ดยาที่ต้องการ (เช่น 0.25)
  /// แต่พื้นที่สีเขียวจะเป็น (1 - fraction)
  final double fraction;

  _MedCirclePainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 2.0;
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - strokeWidth;

    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    // ขอบวงกลมสีแดง (รอบนอก)
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFCC0044);

    canvas.drawCircle(center, radius, borderPaint);

    // สัดส่วนพื้นที่สีเขียว
    final double fillFraction = (1.0 - fraction).clamp(0.0, 1.0);

    if (fillFraction <= 0.0) {
      // กินเต็มเม็ด → โปร่งทั้งวง ไม่ต้องทาสี
      return;
    }

    // สีเขียว (invisible area) โปร่ง 85%
    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF00CC44).withValues(alpha: 0.85);

    // มุมของพายสีเขียว
    final double sweepAngle = 2 * math.pi * fillFraction;

    // พายเริ่มจากด้านบน วาดทวนเข็ม
    final Path slicePath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        rect,
        -math.pi / 2, // startAngle
        -sweepAngle, // ทวนเข็ม
        false,
      )
      ..close();

    // เติมสีเขียว
    canvas.drawPath(slicePath, fillPaint);

    // เส้นขอบของพาย (ด้านในทั้งสองขา + ส่วนโค้ง)
    final Paint sliceBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFCC0044);

    canvas.drawPath(slicePath, sliceBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _MedCirclePainter oldDelegate) {
    return oldDelegate.fraction != fraction;
  }
}
