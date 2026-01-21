// Widget สำหรับแสดง chat bubble ในหน้า chat
// แยก style ระหว่าง user (ขวา) และ AI (ซ้าย)

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/chat_message.dart';

/// Chat bubble สำหรับแสดงข้อความในหน้า chat
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    // ถ้าเป็น loading message แสดง typing indicator
    if (message.isLoading) {
      return _buildLoadingBubble();
    }

    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: AppSpacing.sm,
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.secondaryBackground,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.content,
          style: AppTypography.body.copyWith(
            color: isUser ? Colors.white : AppColors.primaryText,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  /// สร้าง loading bubble (typing indicator)
  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: AppSpacing.sm,
          right: 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const TypingIndicator(),
      ),
    );
  }
}

/// Typing indicator animation (3 dots)
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // คำนวณ offset สำหรับแต่ละจุด
            final value = _controller.value;
            final offset = (value + index * 0.25) % 1.0;
            final opacity = (1 - (offset * 2 - 1).abs()).clamp(0.3, 1.0);
            final yOffset = -4 * (1 - (offset * 2 - 1).abs());

            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
