import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart'; // includes AppRadius and AppShadows

enum ChoiceState {
  normal,
  selected,
  correct,
  incorrect,
  disabled,
}

class ChoiceButton extends StatelessWidget {
  final String choiceKey;
  final String text;
  final ChoiceState state;
  final VoidCallback? onTap;

  const ChoiceButton({
    super.key,
    required this.choiceKey,
    required this.text,
    this.state = ChoiceState.normal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: state == ChoiceState.disabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: state == ChoiceState.disabled || state == ChoiceState.correct || state == ChoiceState.incorrect
            ? null
            : onTap,
        borderRadius: AppRadius.mediumRadius,
        child: Container(
          width: double.infinity,
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            border: Border.all(
              color: _getBorderColor(),
              width: 2,
            ),
            borderRadius: AppRadius.mediumRadius,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getKeyBackgroundColor(),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getBorderColor(),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    choiceKey.toUpperCase(),
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getKeyTextColor(),
                    ),
                  ),
                ),
              ),
              AppSpacing.horizontalGapSm,
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: state == ChoiceState.selected ||
                               state == ChoiceState.correct ||
                               state == ChoiceState.incorrect
                        ? FontWeight.w500
                        : FontWeight.w400,
                    color: _getTextColor(),
                  ),
                ),
              ),
              if (state == ChoiceState.correct)
                Icon(Iconsax.tick_circle, color: AppColors.success, size: 24),
              if (state == ChoiceState.incorrect)
                Icon(Iconsax.close_circle5, color: AppColors.error, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (state) {
      case ChoiceState.normal:
        return AppColors.secondaryBackground;
      case ChoiceState.selected:
        return AppColors.accent1;
      case ChoiceState.correct:
        return AppColors.tagPassedBg;
      case ChoiceState.incorrect:
        return AppColors.tagFailedBg;
      case ChoiceState.disabled:
        return AppColors.secondaryBackground;
    }
  }

  Color _getBorderColor() {
    switch (state) {
      case ChoiceState.normal:
        return AppColors.alternate;
      case ChoiceState.selected:
        return AppColors.primary;
      case ChoiceState.correct:
        return AppColors.success;
      case ChoiceState.incorrect:
        return AppColors.error;
      case ChoiceState.disabled:
        return AppColors.alternate;
    }
  }

  Color _getKeyBackgroundColor() {
    switch (state) {
      case ChoiceState.normal:
        return AppColors.primaryBackground;
      case ChoiceState.selected:
        return AppColors.primary;
      case ChoiceState.correct:
        return AppColors.success;
      case ChoiceState.incorrect:
        return AppColors.error;
      case ChoiceState.disabled:
        return AppColors.primaryBackground;
    }
  }

  Color _getKeyTextColor() {
    switch (state) {
      case ChoiceState.normal:
      case ChoiceState.disabled:
        return AppColors.secondaryText;
      case ChoiceState.selected:
      case ChoiceState.correct:
      case ChoiceState.incorrect:
        return AppColors.surface;
    }
  }

  Color _getTextColor() {
    switch (state) {
      case ChoiceState.normal:
      case ChoiceState.disabled:
        return AppColors.primaryText;
      case ChoiceState.selected:
        return AppColors.primary;
      case ChoiceState.correct:
        return AppColors.success;
      case ChoiceState.incorrect:
        return AppColors.error;
    }
  }
}
