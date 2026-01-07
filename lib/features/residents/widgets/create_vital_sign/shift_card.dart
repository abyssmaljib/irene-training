import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:hugeicons/hugeicons.dart';

/// Card widget for shift selection (เวรเช้า/เวรดึก)
class ShiftCard extends StatelessWidget {
  final String shift; // 'เวรเช้า' | 'เวรดึก'
  final bool selected;
  final VoidCallback onTap;

  const ShiftCard({
    super.key,
    required this.shift,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMorning = shift == 'เวรเช้า';

    // Colors using AppColors theme
    final backgroundColor = selected
        ? (isMorning
            ? AppColors.tagPendingBg // Warm cream yellow for morning
            : AppColors.pastelPurple) // Soft lavender for night
        : AppColors.surface;

    final borderColor = selected
        ? (isMorning
            ? AppColors.pastelOrange1 // Orange border for morning
            : AppColors.customColor2) // Purple border for night
        : AppColors.alternate;

    final textColor = selected
        ? (isMorning
            ? AppColors.tagPendingText // Muted amber text
            : AppColors.customColor2) // Purple text
        : AppColors.secondaryText;

    final iconColor = selected
        ? (isMorning
            ? AppColors.warning // Yellow/amber icon for morning
            : AppColors.customColor2) // Purple icon for night
        : AppColors.secondaryText;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 1,
              color: borderColor.withValues(alpha: 0.3),
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: isMorning ? HugeIcons.strokeRoundedSun01 : HugeIcons.strokeRoundedMoon02,
              color: iconColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              shift,
              style: AppTypography.title.copyWith(
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
