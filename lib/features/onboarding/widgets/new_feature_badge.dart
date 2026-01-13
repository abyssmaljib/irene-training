import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Badge แสดง "NEW" สำหรับ feature ใหม่
/// ใช้แสดงบน navigation items หรือ menu items
class NewFeatureBadge extends StatelessWidget {
  /// ขนาดของ badge
  final NewFeatureBadgeSize size;

  const NewFeatureBadge({
    super.key,
    this.size = NewFeatureBadgeSize.small,
  });

  @override
  Widget build(BuildContext context) {
    // กำหนดขนาดตาม size
    final (paddingH, paddingV, fontSize) = switch (size) {
      NewFeatureBadgeSize.small => (5.0, 2.0, 8.0),
      NewFeatureBadgeSize.medium => (8.0, 3.0, 10.0),
      NewFeatureBadgeSize.large => (10.0, 4.0, 12.0),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
      decoration: BoxDecoration(
        // สีแดงสดใส
        color: AppColors.error,
        borderRadius: BorderRadius.circular(8),
        // Shadow เพื่อให้เด่น
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// ขนาดของ NewFeatureBadge
enum NewFeatureBadgeSize {
  /// ขนาดเล็ก - สำหรับ navigation items
  small,

  /// ขนาดกลาง - สำหรับ menu items
  medium,

  /// ขนาดใหญ่ - สำหรับ cards
  large,
}

/// Widget ที่ wrap child พร้อม NEW badge
/// ใช้สำหรับเพิ่ม badge ให้ widget ใดๆ
class WithNewBadge extends StatelessWidget {
  /// Widget ที่จะแสดง
  final Widget child;

  /// แสดง badge หรือไม่
  final bool showBadge;

  /// ขนาดของ badge
  final NewFeatureBadgeSize badgeSize;

  /// ตำแหน่งของ badge (offset จากมุมขวาบน)
  final Offset badgeOffset;

  const WithNewBadge({
    super.key,
    required this.child,
    this.showBadge = true,
    this.badgeSize = NewFeatureBadgeSize.small,
    this.badgeOffset = const Offset(-8, -4),
  });

  @override
  Widget build(BuildContext context) {
    if (!showBadge) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: badgeOffset.dx,
          top: badgeOffset.dy,
          child: NewFeatureBadge(size: badgeSize),
        ),
      ],
    );
  }
}
