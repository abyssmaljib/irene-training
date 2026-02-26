// CoinRewardOverlay - Reusable widget แสดง Lottie coin animation พร้อมคะแนน
// ใช้หลังจาก action ที่ได้/เสียคะแนน เช่น clock-out, ถอดบทเรียนเสร็จ
//
// Features:
// - Lottie coin animation (coin_reward.json)
// - แสดงจำนวนคะแนนเป็นตัวใหญ่สีขาว
// - Optional title + subtitle
// - Auto-close หลัง animation จบ
// - กดที่ไหนก็ได้เพื่อปิด (กรณี animation ค้าง)
// - Safety timeout 3 วินาที (กัน animation ไม่ทำงาน)
// - Haptic feedback

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Overlay แสดง coin animation + คะแนนที่ได้/เสีย
///
/// ใช้งานง่ายผ่าน static method:
/// ```dart
/// await CoinRewardOverlay.show(
///   context,
///   points: 50,
///   title: 'ได้รับคะแนนคืน!',
///   subtitle: 'ถอดบทเรียนเสร็จสิ้น',
/// );
/// ```
class CoinRewardOverlay extends StatefulWidget {
  /// จำนวนคะแนน (แสดงเป็น +XX หรือ -XX)
  final int points;

  /// หัวข้อ (optional) เช่น "ได้รับคะแนนคืน!"
  final String? title;

  /// คำอธิบายเพิ่มเติม (optional)
  final String? subtitle;

  /// format ข้อความคะแนน (default: "+{points} คะแนน" หรือ "+{points} Points!")
  /// ถ้าไม่กำหนด จะใช้ "+{points} Points!"
  final String? pointsLabel;

  const CoinRewardOverlay({
    super.key,
    required this.points,
    this.title,
    this.subtitle,
    this.pointsLabel,
  });

  /// แสดง coin reward overlay แล้ว return เมื่อปิด
  ///
  /// [points] - จำนวนคะแนน (เช่น 50 แสดงเป็น +50)
  /// [title] - หัวข้อด้านบน (optional)
  /// [subtitle] - คำอธิบายด้านล่าง (optional)
  /// [pointsLabel] - custom format เช่น "+50 คะแนน" (ถ้าไม่กำหนด = "+50 Points!")
  static Future<void> show(
    BuildContext context, {
    required int points,
    String? title,
    String? subtitle,
    String? pointsLabel,
  }) async {
    // Haptic feedback ตอนแสดง
    HapticFeedback.mediumImpact();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // ต้องกดที่ overlay หรือรอ animation จบ
      barrierColor: Colors.transparent, // เราจัดการ background color เอง
      builder: (context) => CoinRewardOverlay(
        points: points,
        title: title,
        subtitle: subtitle,
        pointsLabel: pointsLabel,
      ),
    );
  }

  @override
  State<CoinRewardOverlay> createState() => _CoinRewardOverlayState();
}

class _CoinRewardOverlayState extends State<CoinRewardOverlay> {
  // ป้องกันการปิดซ้ำหลายครั้ง (กรณี animation callback + tap + timeout พร้อมกัน)
  bool _hasClosed = false;

  @override
  void initState() {
    super.initState();
    // ไม่มี auto-close — user ต้องกด (tap) ที่ไหนก็ได้เพื่อปิด
  }

  /// ปิด overlay อย่างปลอดภัย (เรียกได้ครั้งเดียว)
  void _close() {
    if (_hasClosed || !mounted) return;
    _hasClosed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // สร้าง label คะแนน
    final prefix = widget.points >= 0 ? '+' : '';
    final label =
        widget.pointsLabel ?? '$prefix${widget.points} Points!';

    return GestureDetector(
      // กดที่ไหนก็ได้เพื่อปิด (กรณี animation ค้าง)
      onTap: _close,
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title (ถ้ามี) — แสดงก่อน animation
              if (widget.title != null) ...[
                Text(
                  widget.title!,
                  style: AppTypography.heading3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.verticalGapSm,
              ],

              // Coin Lottie animation พร้อม error handling
              Lottie.asset(
                'assets/animations/coin_reward.json',
                width: 200,
                height: 200,
                repeat: false,
                // ไม่ auto-close หลัง animation จบ — รอ user tap ปิดเอง
                errorBuilder: (context, error, stackTrace) {
                  // ถ้าโหลด Lottie ไม่ได้ → แสดง emoji แทน (รอ tap ปิด)
                  return const Text(
                    '🪙',
                    style: TextStyle(fontSize: 100),
                  );
                },
              ),
              AppSpacing.verticalGapMd,

              // จำนวนคะแนน — ตัวใหญ่สีขาว
              Text(
                label,
                style: AppTypography.heading2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Subtitle (ถ้ามี)
              if (widget.subtitle != null) ...[
                AppSpacing.verticalGapSm,
                Text(
                  widget.subtitle!,
                  style: AppTypography.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              AppSpacing.verticalGapMd,

              // Hint ให้ user รู้ว่ากดปิดได้
              Text(
                'แตะเพื่อปิด',
                style: AppTypography.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
