import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/tarot_card.dart';

/// Card แสดง Core Value จากไพ่ทาโร่ที่ได้รับตอนขึ้นเวร
/// แตะเพื่อดูคำทำนายเต็ม
class TarotCoreValueCard extends StatelessWidget {
  final TarotCard card;
  final VoidCallback? onTap;

  const TarotCoreValueCard({
    super.key,
    required this.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _showPredictionDialog(context),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2C1654),
              Color(0xFF1A0F2E),
            ],
          ),
          borderRadius: AppRadius.mediumRadius,
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9B59B6).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ไพ่ขนาดเล็ก
            _buildMiniCard(),
            AppSpacing.horizontalGapMd,
            // ข้อมูล Core Value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: ไพ่ประจำวัน
                  Row(
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 14)),
                      AppSpacing.horizontalGapXs,
                      Text(
                        'Core Value วันนี้',
                        style: AppTypography.caption.copyWith(
                          color: const Color(0xFFFFD700),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalGapXs,
                  // ชื่อไพ่
                  Text(
                    '${card.name} (${card.thaiName})',
                    style: AppTypography.title.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.verticalGapXs,
                  // Core Value
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '💎 ${card.coreValue}',
                      style: AppTypography.bodySmall.copyWith(
                        color: const Color(0xFFFFD700),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Tap hint
            Icon(
              Icons.touch_app_outlined,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCard() {
    return Container(
      width: 50,
      height: 77, // สัดส่วน 300:460
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          card.imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2C1654),
                    Color(0xFF1A0F2E),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                ),
              ),
              child: const Center(
                child: Text('🌿', style: TextStyle(fontSize: 20)),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showPredictionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TarotPredictionBottomSheet(card: card),
    );
  }
}

/// Bottom sheet แสดงคำทำนายเต็ม
class _TarotPredictionBottomSheet extends StatelessWidget {
  final TarotCard card;

  const _TarotPredictionBottomSheet({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
            Color(0xFF0F0F1A),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Card image
                  Container(
                    width: 150,
                    height: 230, // สัดส่วน 300:460
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        card.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF2C1654),
                                  Color(0xFF1A0F2E),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text('🌿', style: TextStyle(fontSize: 40)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  AppSpacing.verticalGapLg,
                  // Card name
                  Text(
                    card.name,
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
                  AppSpacing.verticalGapXs,
                  Text(
                    card.thaiName,
                    style: AppTypography.body.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  AppSpacing.verticalGapMd,
                  // Core Value
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '💎 ${card.coreValue}',
                      style: AppTypography.body.copyWith(
                        color: const Color(0xFFFFD700),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AppSpacing.verticalGapLg,
                  // Prediction
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('📜', style: TextStyle(fontSize: 16)),
                            AppSpacing.horizontalGapSm,
                            Text(
                              'คำทำนาย',
                              style: AppTypography.title.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.verticalGapMd,
                        Text(
                          card.prediction,
                          style: AppTypography.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.verticalGapLg,
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'รับทราบ ✨',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.verticalGapMd,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
