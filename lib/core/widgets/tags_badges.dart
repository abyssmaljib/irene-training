import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// Status Badge - For showing status (Passed, Pending, Failed, Neutral)
enum BadgeStatus { passed, pending, failed, neutral }

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeStatus status;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    required this.status,
    this.icon,
  });

  // Factory constructors for convenience
  factory StatusBadge.passed({String text = 'ผ่านแล้ว', IconData? icon = Iconsax.tick_circle}) {
    return StatusBadge(text: text, status: BadgeStatus.passed, icon: icon);
  }

  factory StatusBadge.pending({String text = 'รอดำเนินการ', IconData? icon = Iconsax.clock}) {
    return StatusBadge(text: text, status: BadgeStatus.pending, icon: icon);
  }

  factory StatusBadge.failed({String text = 'ล้มเหลว', IconData? icon = Iconsax.close_circle5}) {
    return StatusBadge(text: text, status: BadgeStatus.failed, icon: icon);
  }

  factory StatusBadge.neutral({String text = 'ยังไม่เริ่ม', IconData? icon}) {
    return StatusBadge(text: text, status: BadgeStatus.neutral, icon: icon);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: AppRadius.fullRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: _getTextColor(),
            ),
            AppSpacing.horizontalGapXs,
          ],
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: _getTextColor(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (status) {
      case BadgeStatus.passed:
        return AppColors.tagPassedBg;
      case BadgeStatus.pending:
        return AppColors.tagPendingBg;
      case BadgeStatus.failed:
        return AppColors.tagFailedBg;
      case BadgeStatus.neutral:
        return AppColors.tagNeutralBg;
    }
  }

  Color _getTextColor() {
    switch (status) {
      case BadgeStatus.passed:
        return AppColors.tagPassedText;
      case BadgeStatus.pending:
        return AppColors.tagPendingText;
      case BadgeStatus.failed:
        return AppColors.tagFailedText;
      case BadgeStatus.neutral:
        return AppColors.tagNeutralText;
    }
  }
}

/// Category Chip - For filtering/categorization
class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showRemoveIcon;
  final VoidCallback? onRemove;

  const CategoryChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.showRemoveIcon = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: AppRadius.smallRadius,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.inputBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? AppColors.surface : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (showRemoveIcon && isSelected) ...[
              AppSpacing.horizontalGapXs,
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Iconsax.close_square,
                  size: 16,
                  color: AppColors.surface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Progress Tag - For showing read/quiz status in topic cards
class ProgressTag extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final String? emoji;

  const ProgressTag({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    this.emoji,
  });

  // Factory constructors
  factory ProgressTag.notRead() {
    return ProgressTag(
      text: 'ยังไม่อ่าน',
      backgroundColor: AppColors.tagNeutralBg,
      textColor: AppColors.tagNeutralText,
      emoji: '📖',
    );
  }

  factory ProgressTag.read() {
    return ProgressTag(
      text: 'อ่านแล้ว',
      backgroundColor: AppColors.tagPassedBg,
      textColor: AppColors.tagPassedText,
      emoji: '✅',
    );
  }

  factory ProgressTag.notStarted() {
    return ProgressTag(
      text: 'ยังไม่ทำ',
      backgroundColor: AppColors.tagNeutralBg,
      textColor: AppColors.tagNeutralText,
      emoji: '📝',
    );
  }

  factory ProgressTag.passed({int? score}) {
    return ProgressTag(
      text: score != null ? 'ผ่านแล้ว ($score%)' : 'ผ่านแล้ว',
      backgroundColor: AppColors.tagPassedBg,
      textColor: AppColors.tagPassedText,
      emoji: '✅',
    );
  }

  factory ProgressTag.reviewDue() {
    return ProgressTag(
      text: 'ต้องทบทวน',
      backgroundColor: AppColors.tagPendingBg,
      textColor: AppColors.tagPendingText,
      emoji: '🔁',
    );
  }

  factory ProgressTag.failed() {
    return ProgressTag(
      text: 'ยังไม่ผ่าน',
      backgroundColor: AppColors.tagFailedBg,
      textColor: AppColors.tagFailedText,
      emoji: '❌',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        emoji != null ? '$emoji $text' : text,
        style: TextStyle(
          fontFamily: 'MiSansThai',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

/// Action Chip - For tab-like actions with icon support
/// Similar to FlutterFlow's button widget with selected state
class ActionChip extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double iconSize;
  final double height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const ActionChip({
    super.key,
    required this.text,
    this.isSelected = false,
    this.onPressed,
    this.icon,
    this.iconSize = 15.0,
    this.height = 35.0,
    this.padding,
    this.borderRadius,
  });

  /// Factory for left-positioned chip (rounded left corners only)
  factory ActionChip.left({
    required String text,
    bool isSelected = false,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    return ActionChip(
      text: text,
      isSelected: isSelected,
      onPressed: onPressed,
      icon: icon,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(8.0),
        bottomLeft: Radius.circular(8.0),
        topRight: Radius.zero,
        bottomRight: Radius.zero,
      ),
    );
  }

  /// Factory for right-positioned chip (rounded right corners only)
  factory ActionChip.right({
    required String text,
    bool isSelected = false,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    return ActionChip(
      text: text,
      isSelected: isSelected,
      onPressed: onPressed,
      icon: icon,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.zero,
        bottomLeft: Radius.zero,
        topRight: Radius.circular(8.0),
        bottomRight: Radius.circular(8.0),
      ),
    );
  }

  /// Factory for middle-positioned chip (no rounded corners)
  factory ActionChip.middle({
    required String text,
    bool isSelected = false,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    return ActionChip(
      text: text,
      isSelected: isSelected,
      onPressed: onPressed,
      icon: icon,
      borderRadius: BorderRadius.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        const EdgeInsets.symmetric(horizontal: 16.0);
    final effectiveBorderRadius = borderRadius ?? AppRadius.smallRadius;

    return Material(
      color: isSelected ? AppColors.accent1 : AppColors.secondaryBackground,
      borderRadius: effectiveBorderRadius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: effectiveBorderRadius,
        child: Container(
          height: height,
          padding: effectivePadding,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            border: Border.all(
              color: isSelected ? AppColors.secondary : AppColors.alternate,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: iconSize,
                  color: isSelected
                      ? AppColors.primaryText
                      : AppColors.secondaryText,
                ),
                AppSpacing.horizontalGapXs,
              ],
              Text(
                text,
                style: AppTypography.bodySmall.copyWith(
                  color: isSelected
                      ? AppColors.primaryText
                      : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Action Chip Group - For grouping multiple action chips together
class ActionChipGroup extends StatelessWidget {
  final List<ActionChipData> chips;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  const ActionChipGroup({
    super.key,
    required this.chips,
    this.selectedIndex = 0,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(chips.length, (index) {
        final chip = chips[index];
        final isSelected = index == selectedIndex;

        BorderRadius borderRadius;
        if (chips.length == 1) {
          borderRadius = AppRadius.smallRadius;
        } else if (index == 0) {
          borderRadius = const BorderRadius.only(
            topLeft: Radius.circular(8.0),
            bottomLeft: Radius.circular(8.0),
          );
        } else if (index == chips.length - 1) {
          borderRadius = const BorderRadius.only(
            topRight: Radius.circular(8.0),
            bottomRight: Radius.circular(8.0),
          );
        } else {
          borderRadius = BorderRadius.zero;
        }

        return ActionChip(
          text: chip.text,
          icon: chip.icon,
          isSelected: isSelected,
          borderRadius: borderRadius,
          onPressed: () => onSelected?.call(index),
        );
      }),
    );
  }
}

/// Data class for ActionChipGroup
class ActionChipData {
  final String text;
  final IconData? icon;

  const ActionChipData({
    required this.text,
    this.icon,
  });
}