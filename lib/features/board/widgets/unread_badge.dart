import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Badge แสดงจำนวน unread items
class UnreadBadge extends StatelessWidget {
  final int count;
  final Color? backgroundColor;
  final Color? textColor;
  final double? size;
  final bool showZero;

  const UnreadBadge({
    super.key,
    required this.count,
    this.backgroundColor,
    this.textColor,
    this.size,
    this.showZero = false,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0 && !showZero) return SizedBox.shrink();

    final badgeSize = size ?? 18.0;
    final displayCount = count > 99 ? '99+' : '$count';

    return Container(
      constraints: BoxConstraints(
        minWidth: badgeSize,
        minHeight: badgeSize,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: count > 9 ? 4 : 0,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.error,
        borderRadius: BorderRadius.circular(badgeSize / 2),
      ),
      alignment: Alignment.center,
      child: Text(
        displayCount,
        style: AppTypography.caption.copyWith(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: badgeSize * 0.6,
          height: 1,
        ),
      ),
    );
  }
}

/// Badge ที่ใช้กับ tab (positioned)
class TabUnreadBadge extends StatelessWidget {
  final int count;
  final Widget child;
  final Offset? offset;

  const TabUnreadBadge({
    super.key,
    required this.count,
    required this.child,
    this.offset,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: offset?.dx ?? -6,
          top: offset?.dy ?? -6,
          child: UnreadBadge(count: count, size: 16),
        ),
      ],
    );
  }
}

/// Dot indicator (สำหรับ notification แบบ dot)
class UnreadDot extends StatelessWidget {
  final Color? color;
  final double size;

  const UnreadDot({
    super.key,
    this.color,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? AppColors.error,
        shape: BoxShape.circle,
      ),
    );
  }
}
