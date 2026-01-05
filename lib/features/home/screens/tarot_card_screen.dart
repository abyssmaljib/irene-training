import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/tarot_card.dart';

/// หน้าจอแสดงไพ่ทาโร่ก่อนขึ้นเวร
/// - แสดงไพ่ 6 ใบ หมุนวน
/// - วางเรียง 2 แถว (3 บน 3 ล่าง) ให้ user เลือก
/// - กดพลิกดูคำทำนาย
/// - กดยืนยันเพื่อขึ้นเวร
class TarotCardScreen extends StatefulWidget {
  final VoidCallback onConfirm;
  final ValueChanged<TarotCard>? onCardSelected;

  const TarotCardScreen({
    super.key,
    required this.onConfirm,
    this.onCardSelected,
  });

  /// แสดงหน้าจอไพ่ทาโร่แบบ full screen
  /// Returns the selected TarotCard if confirmed, null otherwise
  static Future<TarotCard?> show(BuildContext context) {
    TarotCard? selectedCard;
    return Navigator.of(context).push<TarotCard?>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return TarotCardScreen(
            onConfirm: () => Navigator.of(context).pop(selectedCard),
            onCardSelected: (card) => selectedCard = card,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  State<TarotCardScreen> createState() => _TarotCardScreenState();
}

class _TarotCardScreenState extends State<TarotCardScreen>
    with TickerProviderStateMixin {
  // ไพ่ทั้ง 6 ใบ (สลับลำดับ)
  late final List<TarotCard> _shuffledCards;
  TarotCard? _selectedCard;
  int? _selectedIndex;

  late final AnimationController _shuffleController;
  late final AnimationController _spreadController;
  late final AnimationController _zoomController; // ขยายไพ่ที่เลือก
  late final AnimationController _flipController;
  late final AnimationController _revealController;
  late final ConfettiController _confettiController;

  bool _isFlipped = false;
  bool _showPrediction = false;
  bool _cardRevealed = false;

  // Animation phases
  // Phase 1: Shuffling (ไพ่หมุนวน)
  // Phase 2: Spreading (ไพ่กระจายเป็น grid)
  // Phase 3: Selection (user เลือกไพ่)
  // Phase 4: Reveal (พลิกไพ่ที่เลือก)
  _AnimationPhase _phase = _AnimationPhase.shuffling;

  @override
  void initState() {
    super.initState();

    // สลับลำดับไพ่
    _shuffledCards = List.from(TarotCard.allCards)..shuffle();

    // Shuffle animation (ไพ่หมุนวน) - 1 วินาที
    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Spread animation (ไพ่กระจายเป็น grid)
    _spreadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Zoom animation (ขยายไพ่ที่เลือก) - ช้าลงเพื่อให้เห็น fade out ชัด
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Flip animation for revealing card
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Reveal animation for prediction text
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Confetti
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Start animation sequence
    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    // Phase 1: Shuffle animation (1 วินาที)
    _shuffleController.repeat();
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    // Transition to spread
    _shuffleController.stop();
    setState(() => _phase = _AnimationPhase.spreading);

    // Phase 2: Spread animation
    await _spreadController.forward();

    if (!mounted) return;

    // Phase 3: Ready for selection
    setState(() => _phase = _AnimationPhase.selection);
  }

  @override
  void dispose() {
    _shuffleController.dispose();
    _spreadController.dispose();
    _zoomController.dispose();
    _flipController.dispose();
    _revealController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handleCardSelection(int index) async {
    if (_phase != _AnimationPhase.selection) return;

    final card = _shuffledCards[index];
    setState(() {
      _selectedIndex = index;
      _selectedCard = card;
      _phase = _AnimationPhase.zooming;
    });

    // Notify parent about card selection
    widget.onCardSelected?.call(card);

    // Phase 1: Zoom animation (ขยายไพ่)
    await _zoomController.forward();

    if (!mounted) return;

    // Phase 2: Transition to reveal
    setState(() {
      _phase = _AnimationPhase.reveal;
    });

    // Phase 3: Flip animation (พลิกไพ่)
    await _flipController.forward();

    if (!mounted) return;

    // Phase 4: Show prediction
    setState(() {
      _isFlipped = true;
      _cardRevealed = true;
      _showPrediction = true;
    });
    _revealController.forward();
    _confettiController.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: Stack(
        children: [
          // Mystical background
          _buildMysticalBackground(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Card area
                Expanded(
                  child: Center(
                    child: _buildCardArea(),
                  ),
                ),

                // Prediction area (after reveal)
                if (_showPrediction) _buildPredictionArea(),

                // Bottom action
                if (_cardRevealed) _buildBottomAction(),

                AppSpacing.verticalGapLg,
              ],
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                Color(0xFFFFD700),
                Color(0xFFFFA500),
                Color(0xFFFF6B6B),
                Color(0xFF9B59B6),
                Color(0xFF3498DB),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMysticalBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
            Color(0xFF0F0F1A),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _StarsPainter(),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    String subtitle;

    switch (_phase) {
      case _AnimationPhase.shuffling:
        title = '✨ สับไพ่แห่งโชคชะตา ✨';
        subtitle = 'กำลังสับไพ่...';
        break;
      case _AnimationPhase.spreading:
        title = '✨ เลือกไพ่ของคุณ ✨';
        subtitle = 'รอสักครู่...';
        break;
      case _AnimationPhase.selection:
        title = '✨ เลือกไพ่ของคุณ ✨';
        subtitle = 'แตะไพ่ที่คุณรู้สึกว่าใช่';
        break;
      case _AnimationPhase.zooming:
        title = '🔮 ไพ่ของคุณวันนี้ 🔮';
        subtitle = 'กำลังเปิดไพ่...';
        break;
      case _AnimationPhase.reveal:
        title = '🔮 ไพ่ของคุณวันนี้ 🔮';
        subtitle = _isFlipped ? 'ค่านิยมหลักประจำวัน' : 'กำลังเปิดไพ่...';
        break;
    }

    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(
            title,
            style: AppTypography.heading2.copyWith(
              color: const Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          AppSpacing.verticalGapSm,
          Text(
            subtitle,
            style: AppTypography.body.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardArea() {
    switch (_phase) {
      case _AnimationPhase.shuffling:
        return _buildShufflingCards();
      case _AnimationPhase.spreading:
      case _AnimationPhase.selection:
        return _buildCardGrid();
      case _AnimationPhase.zooming:
        // แสดงทั้ง grid (fade out) และไพ่ที่เลือก (zoom in) พร้อมกัน
        return _buildZoomingTransition();
      case _AnimationPhase.reveal:
        return _buildRevealCard();
    }
  }

  Widget _buildShufflingCards() {
    return AnimatedBuilder(
      animation: _shuffleController,
      builder: (context, child) {
        return SizedBox(
          width: 300,
          height: 400,
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(6, (index) {
              final baseAngle = (index / 6) * 2 * math.pi;
              final currentAngle =
                  baseAngle + (_shuffleController.value * 4 * math.pi);
              final radius = 70.0 + (math.sin(_shuffleController.value * math.pi * 2) * 20);
              final x = math.cos(currentAngle) * radius;
              final y = math.sin(currentAngle) * radius * 0.4;
              final zIndex = math.sin(currentAngle);
              final scale = 0.7 + (zIndex * 0.15);
              final rotation = currentAngle + (_shuffleController.value * math.pi);

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..setEntry(0, 3, x)
                  ..setEntry(1, 3, y)
                  ..setEntry(2, 3, zIndex * 30)
                  ..rotateZ(rotation * 0.1),
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: scale,
                  child: _buildCardBack(width: 80, height: 120),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // สัดส่วนไพ่ 300:460 = 1:1.533
  static const double _cardAspectRatio = 460 / 300; // ≈ 1.533

  Widget _buildCardGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // คำนวณขนาดไพ่ให้พอดีกับหน้าจอ (ทั้ง 6 ใบต้องเห็นครบ)
        final availableWidth = constraints.maxWidth - 32; // padding 16 each side
        final availableHeight = constraints.maxHeight - 20; // gap between rows

        // คำนวณจากความกว้าง (3 ใบ + 2 gaps ขนาด 8px)
        final cardWidthFromScreen = (availableWidth - 16) / 3;

        // คำนวณจากความสูง (2 แถว) - ใช้สัดส่วน 300:460
        final maxCardHeightFromScreen = availableHeight / 2;
        final cardWidthFromHeight = maxCardHeightFromScreen / _cardAspectRatio;

        // ใช้ค่าที่เล็กกว่าเพื่อให้พอดีทั้งแนวกว้างและแนวสูง
        var cardWidth = cardWidthFromScreen < cardWidthFromHeight
            ? cardWidthFromScreen
            : cardWidthFromHeight;

        // จำกัดขนาดสูงสุด
        cardWidth = cardWidth.clamp(60.0, 120.0);
        final cardHeight = cardWidth * _cardAspectRatio;

        return AnimatedBuilder(
          animation: _spreadController,
          builder: (context, child) {
            final progress = _spreadController.value;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Cards 0, 1, 2
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildGridCard(i, progress, cardWidth, cardHeight),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  // Row 2: Cards 3, 4, 5
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildGridCard(i + 3, progress, cardWidth, cardHeight),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGridCard(int index, double progress, double cardWidth, double cardHeight) {
    // Scale: start stacked (smaller), end at full size
    final scale = 0.6 + (0.4 * progress);

    // Rotation: start with slight rotation, end upright
    final rotation = (1 - progress) * (index - 2.5) * 0.1;

    // Opacity: fade in during spread
    final opacity = progress.clamp(0.0, 1.0);

    final isSelected = _selectedIndex == index;

    return Opacity(
      opacity: opacity,
      child: Transform(
        transform: Matrix4.identity()..rotateZ(rotation),
        alignment: Alignment.center,
        child: Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: _phase == _AnimationPhase.selection
                ? () => _handleCardSelection(index)
                : null,
            child: AnimatedScale(
              scale: isSelected ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: _buildCardBack(
                width: cardWidth,
                height: cardHeight,
                glowing: _phase == _AnimationPhase.selection,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Transition: ไพ่ใบอื่นจางหายไป + ไพ่ที่เลือกขยายใหญ่ขึ้นตรงกลาง
  Widget _buildZoomingTransition() {
    if (_selectedCard == null || _selectedIndex == null) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 32;
        final availableHeight = constraints.maxHeight - 20;
        final cardWidthFromScreen = (availableWidth - 16) / 3;
        final maxCardHeightFromScreen = availableHeight / 2;
        final cardWidthFromHeight = maxCardHeightFromScreen / _cardAspectRatio;
        var cardWidth = cardWidthFromScreen < cardWidthFromHeight
            ? cardWidthFromScreen
            : cardWidthFromHeight;
        cardWidth = cardWidth.clamp(60.0, 120.0);
        final cardHeight = cardWidth * _cardAspectRatio;

        return AnimatedBuilder(
          animation: _zoomController,
          builder: (context, child) {
            final progress = _zoomController.value;

            // ไพ่ใบอื่น fade out ช้าๆ (หายไปที่ 70% ของ animation)
            final otherCardsOpacity = (1.0 - progress * 1.4).clamp(0.0, 1.0);

            // ไพ่ที่เลือก: scale จาก 1.0 → 1.8
            final selectedScale = 1.0 + (progress * 0.8);

            return Stack(
              alignment: Alignment.center,
              children: [
                // ไพ่ใบอื่นจางหายไป
                if (otherCardsOpacity > 0)
                  Opacity(
                    opacity: otherCardsOpacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (i) {
                              if (i == _selectedIndex) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: SizedBox(width: cardWidth, height: cardHeight),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildCardBack(
                                  width: cardWidth,
                                  height: cardHeight,
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (i) {
                              final idx = i + 3;
                              if (idx == _selectedIndex) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: SizedBox(width: cardWidth, height: cardHeight),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildCardBack(
                                  width: cardWidth,
                                  height: cardHeight,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ไพ่ที่เลือกขยายใหญ่ขึ้นตรงกลาง
                Transform.scale(
                  scale: selectedScale,
                  child: _buildCardBack(
                    width: cardWidth,
                    height: cardHeight,
                    glowing: true,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRevealCard() {
    if (_selectedCard == null) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 32;
        final availableHeight = constraints.maxHeight - 20;
        final cardWidthFromScreen = (availableWidth - 16) / 3;
        final maxCardHeightFromScreen = availableHeight / 2;
        final cardWidthFromHeight = maxCardHeightFromScreen / _cardAspectRatio;
        var cardWidth = cardWidthFromScreen < cardWidthFromHeight
            ? cardWidthFromScreen
            : cardWidthFromHeight;
        cardWidth = cardWidth.clamp(60.0, 120.0);
        final cardHeight = cardWidth * _cardAspectRatio;

        return AnimatedBuilder(
          animation: _flipController,
          builder: (context, child) {
            final angle = _flipController.value * math.pi;
            final isFront = angle > math.pi / 2;

            // Keep the zoomed scale (1.8x)
            return Transform.scale(
              scale: 1.8,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: isFront
                    ? Transform(
                        transform: Matrix4.identity()..rotateY(math.pi),
                        alignment: Alignment.center,
                        child: _buildCardFront(
                          width: cardWidth,
                          height: cardHeight,
                        ),
                      )
                    : _buildCardBack(
                        width: cardWidth,
                        height: cardHeight,
                        glowing: true,
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCardBack({
    double? width,
    double? height,
    bool glowing = false,
  }) {
    final w = width ?? 100.0;
    final h = height ?? 150.0;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C1654),
            Color(0xFF1A0F2E),
          ],
        ),
        border: Border.all(
          color: glowing ? const Color(0xFFFFD700) : const Color(0xFF9B59B6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: glowing
                ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                : const Color(0xFF9B59B6).withValues(alpha: 0.3),
            blurRadius: glowing ? 15 : 10,
            spreadRadius: glowing ? 2 : 1,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: w * 0.7,
          height: h * 0.7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: const Center(
            child: Text(
              '🌿',
              style: TextStyle(fontSize: 32),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront({double? width, double? height}) {
    if (_selectedCard == null) return const SizedBox();

    final w = width ?? 100.0;
    final h = height ?? 150.0;

    // Debug: print path
    debugPrint('Loading image: ${_selectedCard!.imagePath}');

    // แสดงแค่รูปไพ่อย่างเดียว ไม่มีตัวอักษรบัง
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          _selectedCard!.imagePath,
          fit: BoxFit.cover,
          width: w,
          height: h,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFF2C1654),
              child: Center(
                child: Icon(
                  Iconsax.magic_star,
                  color: const Color(0xFFFFD700),
                  size: 40,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPredictionArea() {
    if (_selectedCard == null) return const SizedBox();

    return FadeTransition(
      opacity: _revealController,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          ),
        ),
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ชื่อไพ่
              Row(
                children: [
                  Text(
                    _selectedCard!.name,
                    style: AppTypography.heading3.copyWith(
                      color: const Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.horizontalGapSm,
                  Text(
                    '(${_selectedCard!.thaiName})',
                    style: AppTypography.body.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              AppSpacing.verticalGapSm,

              // Core Value
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '💎 ${_selectedCard!.coreValue}',
                  style: AppTypography.body.copyWith(
                    color: const Color(0xFFFFD700),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppSpacing.verticalGapMd,

              // Prediction
              Text(
                '📜 คำทำนาย',
                style: AppTypography.title.copyWith(
                  color: Colors.white,
                ),
              ),
              AppSpacing.verticalGapSm,
              Text(
                _selectedCard!.prediction,
                style: AppTypography.body.copyWith(
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: widget.onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: const Color(0xFFFFD700).withValues(alpha: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚡', style: TextStyle(fontSize: 20)),
              AppSpacing.horizontalGapSm,
              Text(
                'รับพลังและขึ้นเวร!',
                style: AppTypography.heading3.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.horizontalGapSm,
              const Text('⚡', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animation phases
enum _AnimationPhase {
  shuffling, // ไพ่หมุนวน
  spreading, // ไพ่กระจายเป็น grid
  selection, // user เลือกไพ่
  zooming, // ขยายไพ่ที่เลือก
  reveal, // พลิกไพ่ที่เลือก
}

/// Custom painter for stars background
class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent stars
    for (var i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5 + 0.5;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
