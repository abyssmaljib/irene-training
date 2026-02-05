import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/network_image.dart';
import '../services/shift_summary_service.dart';

/// Modal แสดงสรุปเวรหลัง clock out สำเร็จ
/// แสดง: Points earned, Dead air penalty, New badges, Tier progress, Rank, Streak
class ClockOutSummaryModal extends StatefulWidget {
  final ShiftSummary summary;
  final VoidCallback? onClose;

  const ClockOutSummaryModal({
    super.key,
    required this.summary,
    this.onClose,
  });

  /// แสดง modal
  static Future<void> show(
    BuildContext context, {
    required ShiftSummary summary,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClockOutSummaryModal(
        summary: summary,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<ClockOutSummaryModal> createState() => _ClockOutSummaryModalState();
}

class _ClockOutSummaryModalState extends State<ClockOutSummaryModal>
    with TickerProviderStateMixin {
  // Confetti controller สำหรับ celebration effect
  late ConfettiController _confettiController;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _counterController;

  // Animations
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Coin animation state - แสดง animation เหรียญเมื่อกด "รับเลย"
  bool _showCoinAnimation = false;

  @override
  void initState() {
    super.initState();

    // Confetti setup - เล่น 3 วินาที
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Slide animation - modal slide up
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeIn),
    );

    // Counter animation - สำหรับ animate ตัวเลข points
    _counterController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Start animations
    _confettiController.play();
    _slideController.forward();
    _counterController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _slideController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Modal content
        SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Dialog(
              backgroundColor: AppColors.surface, // พื้นหลังขาว
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.largeRadius,
              ),
              child: Container(
                width: 360,
                constraints: const BoxConstraints(maxHeight: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      AppSpacing.verticalGapLg,
                      _buildPointsSection(),
                      AppSpacing.verticalGapMd,
                      _buildTierProgress(),
                      AppSpacing.verticalGapMd,
                      if (widget.summary.newBadges.isNotEmpty) ...[
                        _buildBadgesSection(),
                        AppSpacing.verticalGapMd,
                      ],
                      _buildStatsRow(),
                      AppSpacing.verticalGapLg,
                      _buildClaimButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Confetti overlay - ยิงจากบน
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2, // ลง
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [
              Color(0xFFFF6B6B),
              Color(0xFFFFE66D),
              Color(0xFF4ECDC4),
              Color(0xFF95E1D3),
              Color(0xFFF38181),
              Color(0xFFAA96DA),
              Color(0xFFFCBF49),
            ],
          ),
        ),
        // Coin animation overlay - แสดงเมื่อกด "รับเลย"
        if (_showCoinAnimation) _buildCoinAnimationOverlay(),
      ],
    );
  }

  /// Header - Success icon + message
  Widget _buildHeader() {
    return Column(
      children: [
        // Success icon with glow effect
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            color: AppColors.success,
            size: 48,
          ),
        ),
        AppSpacing.verticalGapMd,
        Text(
          'เยี่ยมมาก! 🎉',
          style: AppTypography.heading2.copyWith(
            color: AppColors.success,
          ),
        ),
        Text(
          'ขอบคุณที่ทำงานอย่างดีในเวรนี้',
          style: AppTypography.body.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  /// Points section - Gradient card with animated counter
  Widget _buildPointsSection() {
    final summary = widget.summary;
    final points = summary.points;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Points ที่ได้รับ',
            style: AppTypography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          AppSpacing.verticalGapSm,
          // Animated counter
          AnimatedBuilder(
            animation: _counterController,
            builder: (context, child) {
              final value =
                  (points.netPoints * _counterController.value).round();
              return Text(
                '+$value',
                style: AppTypography.heading1.copyWith(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          // Dead air penalty (ถ้ามี)
          if (points.deadAirPenalty > 0) ...[
            AppSpacing.verticalGapXs,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ทำไรอยู่อ่ะ: -${points.deadAirPenalty}',
                style: AppTypography.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
          AppSpacing.verticalGapMd,
          // Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPointBreakdown('งาน', points.taskPoints, '✅'),
              _buildPointBreakdown('จัดยา', points.medicinePhotoPoints, '💊'),
              _buildPointBreakdown('Quiz', points.quizPoints, '📝'),
              _buildPointBreakdown('อ่าน', points.contentPoints, '📖'),
            ],
          ),
        ],
      ),
    );
  }

  /// Point breakdown item
  Widget _buildPointBreakdown(String label, int points, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        Text(
          '+$points',
          style: AppTypography.subtitle.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  /// Tier progress section
  Widget _buildTierProgress() {
    final tierInfo = widget.summary.tierInfo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Current tier
              Text(
                tierInfo.currentTier.icon ?? '🥉',
                style: const TextStyle(fontSize: 24),
              ),
              AppSpacing.horizontalGapSm,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tierInfo.currentTier.displayName,
                    style: AppTypography.subtitle,
                  ),
                  Text(
                    '${tierInfo.totalPoints} points',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Next tier (ถ้ายังไม่ max)
              if (!tierInfo.isMaxTier && tierInfo.nextTier != null) ...[
                Text(
                  tierInfo.nextTier!.displayName,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                AppSpacing.horizontalGapXs,
                Text(
                  tierInfo.nextTier!.icon ?? '',
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ],
          ),
          AppSpacing.verticalGapMd,
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: tierInfo.progressToNextTier,
              backgroundColor: AppColors.alternate,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
          // Points to next tier
          if (!tierInfo.isMaxTier && tierInfo.nextTier != null) ...[
            AppSpacing.verticalGapXs,
            Text(
              'อีก ${tierInfo.pointsToNextTier} points ถึง ${tierInfo.nextTier!.displayName}',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// New badges section
  Widget _buildBadgesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏅', style: TextStyle(fontSize: 20)),
              AppSpacing.horizontalGapSm,
              Text(
                'เหรียญใหม่!',
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMd,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: widget.summary.newBadges.map((badge) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badge.imageUrl != null)
                      IreneNetworkImage(
                        imageUrl: badge.imageUrl!,
                        width: 24,
                        height: 24,
                        memCacheWidth: 48,
                      )
                    else
                      Text(
                        badge.rarityEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                    AppSpacing.horizontalGapXs,
                    Text(
                      badge.name,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Stats row - Rank & Streak
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: HugeIcons.strokeRoundedRanking,
            value: '#${widget.summary.leaderboardRank}',
            label: 'อันดับ',
            subLabel: 'จาก ${widget.summary.totalUsers} คน',
          ),
        ),
        AppSpacing.horizontalGapMd,
        Expanded(
          child: _buildStatCard(
            icon: HugeIcons.strokeRoundedFire,
            value: '${widget.summary.workStreak}',
            label: 'Streak',
            subLabel: 'วันติดต่อกัน',
          ),
        ),
      ],
    );
  }

  /// Stat card
  Widget _buildStatCard({
    required dynamic icon,
    required String value,
    required String label,
    required String subLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          HugeIcon(
            icon: icon,
            color: AppColors.primary,
            size: 24,
          ),
          AppSpacing.verticalGapXs,
          Text(
            value,
            style: AppTypography.heading3,
          ),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          Text(
            subLabel,
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// ปุ่ม "รับเลย" - กดแล้วแสดง coin animation แล้วปิด modal
  Widget _buildClaimButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _showCoinAnimation ? null : _handleClaim,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 20)),
            AppSpacing.horizontalGapSm,
            Text(
              'รับเลย!',
              style: AppTypography.subtitle.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle claim button press - แสดง coin animation แล้วปิด
  void _handleClaim() {
    setState(() => _showCoinAnimation = true);
  }

  /// Coin animation overlay - แสดงเหรียญตกลงมาตรงกลาง
  Widget _buildCoinAnimationOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Coin Lottie animation
            Lottie.asset(
              'assets/animations/coin_reward.json',
              width: 200,
              height: 200,
              repeat: false,
              onLoaded: (composition) {
                // เมื่อ animation เล่นจบ ให้ปิด modal
                Future.delayed(composition.duration, () {
                  if (mounted) {
                    widget.onClose?.call();
                  }
                });
              },
            ),
            AppSpacing.verticalGapMd,
            // แสดง points ที่ได้รับ
            Text(
              '+${widget.summary.points.netPoints} Points!',
              style: AppTypography.heading2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
