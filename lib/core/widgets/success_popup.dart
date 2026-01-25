import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Popup แสดงความสำเร็จพร้อม animated checkmark
///
/// ใช้หลังจากทำ action สำเร็จ เช่น ให้คะแนน, บันทึกข้อมูล
/// จะ auto-close หลังจาก delay ที่กำหนด
///
/// Features:
/// - Animated checkmark (draw animation)
/// - Optional emoji display
/// - Optional message
/// - Auto-close with configurable delay
/// - Haptic feedback
class SuccessPopup extends StatefulWidget {
  /// ข้อความแสดง (optional)
  final String? message;

  /// Emoji แสดงด้านบน (optional)
  final String? emoji;

  /// สีหลักของ checkmark (default: primary)
  final Color? color;

  /// ระยะเวลา auto-close (default: 1000ms)
  /// ถ้า null = ไม่ auto-close
  final Duration? autoCloseDuration;

  const SuccessPopup({
    super.key,
    this.message,
    this.emoji,
    this.color,
    this.autoCloseDuration = const Duration(milliseconds: 1000),
  });

  /// แสดง popup และ return เมื่อปิด
  ///
  /// [emoji] - emoji ที่จะแสดงด้านบน (เช่น 🎉, 😎)
  /// [message] - ข้อความด้านล่าง
  /// [color] - สีของ checkmark
  /// [autoCloseDuration] - ระยะเวลา auto-close (null = ไม่ auto)
  static Future<void> show(
    BuildContext context, {
    String? emoji,
    String? message,
    Color? color,
    Duration? autoCloseDuration = const Duration(milliseconds: 1000),
  }) async {
    // Haptic feedback เมื่อแสดง popup
    HapticFeedback.mediumImpact();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26, // สีจางลงเพื่อให้ดู lightweight
      builder: (context) => SuccessPopup(
        emoji: emoji,
        message: message,
        color: color,
        autoCloseDuration: autoCloseDuration,
      ),
    );
  }

  @override
  State<SuccessPopup> createState() => _SuccessPopupState();
}

class _SuccessPopupState extends State<SuccessPopup>
    with SingleTickerProviderStateMixin {
  /// Animation controller สำหรับ checkmark
  late AnimationController _controller;

  /// Animation สำหรับวาด checkmark (0.0 → 1.0)
  late Animation<double> _checkAnimation;

  /// Animation สำหรับ scale ของวงกลม (pop effect)
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // สร้าง animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Scale animation (pop effect) - เริ่มจาก 0.5 → 1.1 → 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    // Checkmark animation - เริ่มหลัง scale animation ไปครึ่งหนึ่ง
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // เริ่ม animation
    _controller.forward();

    // Auto-close หลังจาก delay
    if (widget.autoCloseDuration != null) {
      Future.delayed(widget.autoCloseDuration!, () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 200,
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.largeRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji (ถ้ามี)
              if (widget.emoji != null) ...[
                Text(
                  widget.emoji!,
                  style: const TextStyle(fontSize: 28),
                ),
                SizedBox(height: AppSpacing.xs),
              ],

              // Dabbing cat image
              Image.asset(
                'assets/images/dabbing cat5.webp',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
              SizedBox(height: AppSpacing.sm),

              // Animated checkmark
              SizedBox(
                width: 80,
                height: 80,
                child: AnimatedBuilder(
                  animation: _checkAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _CheckmarkPainter(
                        progress: _checkAnimation.value,
                        color: color,
                        strokeWidth: 5,
                      ),
                    );
                  },
                ),
              ),

              // Message (ถ้ามี)
              if (widget.message != null) ...[
                SizedBox(height: AppSpacing.md),
                Text(
                  widget.message!,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter สำหรับวาด animated checkmark
///
/// วาดวงกลมก่อน แล้วค่อยวาด checkmark
/// [progress] 0.0 → 0.5 = วาดวงกลม
/// [progress] 0.5 → 1.0 = วาด checkmark
class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Paint สำหรับวงกลม
    final circlePaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // Paint สำหรับขอบวงกลม
    final circleStrokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Paint สำหรับ checkmark
    final checkPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // วาดพื้นหลังวงกลม (เสมอ)
    canvas.drawCircle(center, radius, circlePaint);

    // คำนวณ progress แยกสำหรับ circle และ checkmark
    final circleProgress = (progress * 2).clamp(0.0, 1.0);
    final checkProgress = ((progress - 0.5) * 2).clamp(0.0, 1.0);

    // วาดขอบวงกลม (0% - 50% of total progress)
    if (circleProgress > 0) {
      final sweepAngle = 2 * pi * circleProgress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // เริ่มจากด้านบน
        sweepAngle,
        false,
        circleStrokePaint,
      );
    }

    // วาด checkmark (50% - 100% of total progress)
    if (checkProgress > 0) {
      // Checkmark points (relative to center, scaled by radius)
      final checkStart = Offset(
        center.dx - radius * 0.35,
        center.dy + radius * 0.05,
      );
      final checkMid = Offset(
        center.dx - radius * 0.05,
        center.dy + radius * 0.35,
      );
      final checkEnd = Offset(
        center.dx + radius * 0.4,
        center.dy - radius * 0.25,
      );

      // วาด checkmark path ตาม progress
      final path = Path();

      if (checkProgress <= 0.5) {
        // ส่วนแรกของ checkmark (ลงล่าง)
        final firstProgress = checkProgress * 2;
        final currentMid = Offset.lerp(checkStart, checkMid, firstProgress)!;
        path.moveTo(checkStart.dx, checkStart.dy);
        path.lineTo(currentMid.dx, currentMid.dy);
      } else {
        // ส่วนแรก + ส่วนที่สอง (ขึ้นบน)
        final secondProgress = (checkProgress - 0.5) * 2;
        final currentEnd = Offset.lerp(checkMid, checkEnd, secondProgress)!;
        path.moveTo(checkStart.dx, checkStart.dy);
        path.lineTo(checkMid.dx, checkMid.dy);
        path.lineTo(currentEnd.dx, currentEnd.dy);
      }

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
