import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../learning/models/badge.dart';

/// Dialog แสดงเมื่อ user ได้รับ badge "The Perfect Starter"
/// พร้อม confetti animation สุดอลังการ
class BadgeCelebrationDialog extends StatefulWidget {
  final Badge badge;
  final VoidCallback? onDismiss;

  const BadgeCelebrationDialog({
    super.key,
    required this.badge,
    this.onDismiss,
  });

  /// แสดง celebration dialog พร้อม confetti
  static Future<void> show(BuildContext context, Badge badge) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => BadgeCelebrationDialog(
        badge: badge,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<BadgeCelebrationDialog> createState() => _BadgeCelebrationDialogState();
}

class _BadgeCelebrationDialogState extends State<BadgeCelebrationDialog>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _scaleController;
  late AnimationController _shineController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shineAnimation;

  // Confetti controller
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();

    // Scale animation - badge ปรากฏแบบ bounce
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Shine animation - เอฟเฟค glow วนลูป
    _shineController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _shineAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.easeInOut),
    );

    // Confetti controller
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // เริ่ม animations
    _scaleController.forward();
    _shineController.repeat(reverse: true);

    // ยิง confetti หลัง dialog โผล่มาแล้ว
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _confettiController.play();
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shineController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  /// สี rarity สำหรับ badge
  Color get _rarityColor {
    switch (widget.badge.rarity) {
      case 'legendary':
        return const Color(0xFFFFD700); // Gold
      case 'epic':
        return const Color(0xFF9B59B6); // Purple
      case 'rare':
        return const Color(0xFF3498DB); // Blue
      default:
        return AppColors.primary; // Teal
    }
  }

  /// สีพื้นหลัง rarity
  Color get _rarityBgColor {
    switch (widget.badge.rarity) {
      case 'legendary':
        return const Color(0xFFFFF9E6);
      case 'epic':
        return const Color(0xFFF5EEF8);
      case 'rare':
        return const Color(0xFFEBF5FB);
      default:
        return const Color(0xFFE8F5F3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Confetti ทั้ง 2 ข้าง
        _buildConfettiWidgets(),

        // Dialog content
        Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: _buildDialogContent(),
            ),
          ),
        ),
      ],
    );
  }

  /// สร้าง confetti widgets ทั้ง 2 ข้าง
  Widget _buildConfettiWidgets() {
    return Stack(
      children: [
        // Confetti ด้านซ้าย
        Positioned(
          top: MediaQuery.of(context).size.height * 0.2,
          left: 20,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: -0.5, // ยิงไปทางขวา-บน
            emissionFrequency: 0.05,
            numberOfParticles: 10,
            maxBlastForce: 30,
            minBlastForce: 10,
            gravity: 0.2,
            colors: const [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.purple,
              Colors.pink,
              Color(0xFFFFD700), // Gold
            ],
          ),
        ),
        // Confetti ด้านขวา
        Positioned(
          top: MediaQuery.of(context).size.height * 0.2,
          right: 20,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: 3.5, // ยิงไปทางซ้าย-บน
            emissionFrequency: 0.05,
            numberOfParticles: 10,
            maxBlastForce: 30,
            minBlastForce: 10,
            gravity: 0.2,
            colors: const [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.purple,
              Colors.pink,
              Color(0xFFFFD700), // Gold
            ],
          ),
        ),
        // Confetti ตรงกลางด้านบน
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.03,
            numberOfParticles: 20,
            maxBlastForce: 50,
            minBlastForce: 20,
            gravity: 0.15,
            particleDrag: 0.05,
            colors: const [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.purple,
              Colors.pink,
              Color(0xFFFFD700), // Gold
            ],
          ),
        ),
      ],
    );
  }

  /// สร้าง dialog content
  Widget _buildDialogContent() {
    final badge = widget.badge;

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _rarityColor.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - พื้นหลัง gradient สีทอง
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _rarityColor.withValues(alpha: 0.2),
                  _rarityBgColor,
                  _rarityColor.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Stars decoration
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 20)),
                    SizedBox(width: AppSpacing.sm),
                    const Text('✨', style: TextStyle(fontSize: 28)),
                    SizedBox(width: AppSpacing.sm),
                    const Text('⭐', style: TextStyle(fontSize: 20)),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                // Congratulations text
                Text(
                  'ยินดีด้วย!',
                  style: AppTypography.heading1.copyWith(
                    color: _rarityColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'คุณได้รับ Badge พิเศษ!',
                  style: AppTypography.body.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Badge content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Badge icon with glow animation
                AnimatedBuilder(
                  animation: _shineAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: _rarityBgColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _rarityColor,
                          width: 5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _rarityColor
                                .withValues(alpha: 0.4 * _shineAnimation.value),
                            blurRadius: 30 * _shineAnimation.value,
                            spreadRadius: 8 * _shineAnimation.value,
                          ),
                          BoxShadow(
                            color: _rarityColor.withValues(
                                alpha: 0.2 * _shineAnimation.value),
                            blurRadius: 50 * _shineAnimation.value,
                            spreadRadius: 15 * _shineAnimation.value,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          badge.icon ?? '🏆',
                          style: const TextStyle(fontSize: 56),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: AppSpacing.lg),

                // Rarity tag - Legendary
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _rarityColor.withValues(alpha: 0.2),
                        _rarityColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _rarityColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        badge.rarityEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Legendary',
                        style: AppTypography.label.copyWith(
                          color: _rarityColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppSpacing.md),

                // Badge name
                Text(
                  badge.name,
                  style: AppTypography.heading2.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (badge.description != null) ...[
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    badge.description!,
                    style: AppTypography.body.copyWith(
                      color: AppColors.secondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                // Points earned
                if (badge.points > 0) ...[
                  SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedStar,
                          size: 22,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+${badge.points} คะแนน',
                          style: AppTypography.label.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: AppSpacing.xl),

                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: widget.onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _rarityColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                      shadowColor: _rarityColor.withValues(alpha: 0.4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '🎉',
                          style: TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'เยี่ยมมาก!',
                          style: AppTypography.button.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
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
