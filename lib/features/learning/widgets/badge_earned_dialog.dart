import 'package:flutter/material.dart' hide Badge;
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/badge.dart';

/// Dialog แสดงเมื่อ user ได้รับ badge ใหม่
class BadgeEarnedDialog extends StatefulWidget {
  final List<Badge> badges;
  final VoidCallback? onDismiss;

  const BadgeEarnedDialog({
    super.key,
    required this.badges,
    this.onDismiss,
  });

  /// แสดง dialog
  static Future<void> show(BuildContext context, List<Badge> badges) async {
    if (badges.isEmpty) return;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BadgeEarnedDialog(
        badges: badges,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<BadgeEarnedDialog> createState() => _BadgeEarnedDialogState();
}

class _BadgeEarnedDialogState extends State<BadgeEarnedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Badge get _currentBadge => widget.badges[_currentIndex];
  bool get _hasMore => _currentIndex < widget.badges.length - 1;

  void _next() {
    if (_hasMore) {
      _controller.reset();
      setState(() => _currentIndex++);
      _controller.forward();
    } else {
      widget.onDismiss?.call();
    }
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
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

  Color _getRarityBgColor(String rarity) {
    switch (rarity) {
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

  String _getRarityLabel(String rarity) {
    switch (rarity) {
      case 'legendary':
        return 'Legendary';
      case 'epic':
        return 'Epic';
      case 'rare':
        return 'Rare';
      default:
        return 'Common';
    }
  }

  double _getRarityBorderWidth(String rarity) {
    switch (rarity) {
      case 'legendary':
        return 5;
      case 'epic':
        return 4;
      case 'rare':
        return 3.5;
      default:
        return 3;
    }
  }

  List<BoxShadow> _getRarityShadows(String rarity, Color color) {
    switch (rarity) {
      case 'legendary':
        return [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 24,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ];
      case 'epic':
        return [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 6,
          ),
        ];
      case 'rare':
        return [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: 3,
          ),
        ];
      default:
        return [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = _currentBadge;
    final rarityColor = _getRarityColor(badge.rarity);
    final rarityBgColor = _getRarityBgColor(badge.rarity);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: child,
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: rarityColor.withValues(alpha: 0.3),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with confetti effect
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: rarityBgColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // Badge count indicator
                    if (widget.badges.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.badges.length}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),

                    // Congratulations text
                    Text(
                      'ยินดีด้วย!',
                      style: AppTypography.heading2.copyWith(
                        color: rarityColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppSpacing.verticalGapXs,
                    Text(
                      'คุณได้รับ Badge ใหม่',
                      style: AppTypography.body.copyWith(
                        color: AppColors.secondaryText,
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
                    // Badge icon with rarity-based styling
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: rarityBgColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: rarityColor,
                          width: _getRarityBorderWidth(badge.rarity),
                        ),
                        boxShadow: _getRarityShadows(badge.rarity, rarityColor),
                      ),
                      child: Center(
                        child: badge.imageUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  badge.imageUrl!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  // จำกัดขนาดใน memory เพื่อป้องกัน crash บน iOS/Android สเปคต่ำ
                                  cacheWidth: 200,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildIconFallback(badge, rarityColor),
                                ),
                              )
                            : _buildIconFallback(badge, rarityColor),
                      ),
                    ),

                    AppSpacing.verticalGapMd,

                    // Category & Rarity tags
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Category tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.alternate,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                badge.categoryIcon,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                badge.categoryDisplayName,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.secondaryText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Rarity tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: rarityColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                badge.rarityEmoji,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getRarityLabel(badge.rarity),
                                style: AppTypography.caption.copyWith(
                                  color: rarityColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    AppSpacing.verticalGapSm,

                    // Badge name
                    Text(
                      badge.name,
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (badge.description != null) ...[
                      AppSpacing.verticalGapXs,
                      Text(
                        badge.description!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.secondaryText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    // Points
                    if (badge.points > 0) ...[
                      AppSpacing.verticalGapMd,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedStar,
                            size: 20,
                            color: rarityColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+${badge.points} คะแนน',
                            style: AppTypography.label.copyWith(
                              color: rarityColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],

                    AppSpacing.verticalGapLg,

                    // Action button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: rarityColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _hasMore ? 'ถัดไป' : 'เยี่ยม!',
                          style: AppTypography.button.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconFallback(Badge badge, Color color) {
    return Text(
      badge.icon ?? badge.rarityEmoji,
      style: const TextStyle(fontSize: 48),
    );
  }
}
