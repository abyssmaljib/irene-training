import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// Primary Button - Filled teal button
/// States: Default, Hover, Focused, Disabled, Loading
class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final dynamic icon;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.width,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !widget.isDisabled && !widget.isLoading && widget.onPressed != null;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: AppSpacing.buttonHeight,
          child: Material(
            color: _getBackgroundColor(isEnabled),
            borderRadius: AppRadius.smallRadius,
            child: InkWell(
              onTap: isEnabled ? widget.onPressed : null,
              borderRadius: AppRadius.smallRadius,
              child: Container(
                height: AppSpacing.buttonHeight,
                padding: AppSpacing.buttonPadding,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.smallRadius,
                  border: _isFocused
                      ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2)
                      : null,
                ),
                child: Row(
                  mainAxisSize: widget.width != null ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isLoading) ...[
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.surface,
                          ),
                        ),
                      ),
                    ] else ...[
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: AppColors.surface,
                          size: AppIconSize.lg,
                        ),
                        AppSpacing.horizontalGapSm,
                      ],
                      Text(
                        widget.text,
                        style: AppTypography.button.copyWith(
                          color: AppColors.surface,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(bool isEnabled) {
    if (!isEnabled) return AppColors.primaryDisabled;
    if (_isHovered) return AppColors.primaryHover;
    return AppColors.primary;
  }
}

/// Secondary Button - Outlined button
class SecondaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final dynamic icon;
  final double? width;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.width,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !widget.isDisabled && !widget.isLoading && widget.onPressed != null;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.width,
        height: AppSpacing.buttonHeight,
        child: OutlinedButton(
          onPressed: isEnabled ? widget.onPressed : null,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, AppSpacing.buttonHeight),
            padding: AppSpacing.buttonPadding,
            side: BorderSide(
              color: isEnabled
                  ? (_isHovered ? AppColors.primaryHover : AppColors.primary)
                  : AppColors.primaryDisabled,
              width: 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.smallRadius,
            ),
            backgroundColor: _isHovered && isEnabled
                ? AppColors.primary.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              : Row(
                  mainAxisSize: widget.width != null ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      HugeIcon(icon: widget.icon, size: AppIconSize.lg),
                      AppSpacing.horizontalGapSm,
                    ],
                    Text(
                      widget.text,
                      style: AppTypography.button.copyWith(
                        color: isEnabled ? AppColors.primary : AppColors.primaryDisabled,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Danger Button - Red/Warning button for destructive actions
class DangerButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final dynamic icon;
  final double? width;

  const DangerButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.width,
  });

  @override
  State<DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<DangerButton> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !widget.isDisabled && !widget.isLoading && widget.onPressed != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: AppSpacing.buttonHeight,
          child: Material(
            color: _getBackgroundColor(isEnabled),
            borderRadius: AppRadius.smallRadius,
            child: InkWell(
              onTap: isEnabled ? widget.onPressed : null,
              borderRadius: AppRadius.smallRadius,
              child: Container(
                height: AppSpacing.buttonHeight,
                padding: AppSpacing.buttonPadding,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.smallRadius,
                  border: _isFocused
                      ? Border.all(color: AppColors.error.withValues(alpha: 0.5), width: 2)
                      : null,
                ),
                child: Row(
                  mainAxisSize: widget.width != null ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isLoading) ...[
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.surface,
                          ),
                        ),
                      ),
                    ] else ...[
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: AppColors.surface,
                          size: AppIconSize.lg,
                        ),
                        AppSpacing.horizontalGapSm,
                      ],
                      Text(
                        widget.text,
                        style: AppTypography.button.copyWith(
                          color: AppColors.surface,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(bool isEnabled) {
    if (!isEnabled) return AppColors.error.withValues(alpha: 0.5);
    if (_isHovered) return AppColors.error.withValues(alpha: 0.8);
    return AppColors.error;
  }
}

/// Text Button - No background, just text
class AppTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isDisabled;
  final dynamic icon;

  const AppTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isDisabled = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !isDisabled && onPressed != null;
    
    return SizedBox(
      height: AppSpacing.buttonHeight,
      child: TextButton(
        onPressed: isEnabled ? onPressed : null,
        style: TextButton.styleFrom(
          minimumSize: Size(0, AppSpacing.buttonHeight),
          padding: AppSpacing.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smallRadius,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              HugeIcon(
                icon: icon,
                size: AppIconSize.lg,
                color: isEnabled ? AppColors.primary : AppColors.primaryDisabled,
              ),
              AppSpacing.horizontalGapSm,
            ],
            Text(
              text,
              style: AppTypography.button.copyWith(
                color: isEnabled ? AppColors.primary : AppColors.primaryDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
