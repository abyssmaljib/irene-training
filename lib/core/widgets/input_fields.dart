import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// App Text Field - Standard input field
/// States: Default, Focused, Error, Disabled
///
/// Sizes:
/// - Default: ~48px height (with padding 12px vertical)
/// - Dense: ~40px height (with padding 8px vertical)
class AppTextField extends StatefulWidget {
  final String? label;
  final String? hintText;
  final String? errorText;
  final TextEditingController? controller;
  final bool obscureText;
  final bool enabled;
  final dynamic prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  /// Use dense mode for smaller height (~40px vs ~48px)
  final bool isDense;
  /// Auto focus when widget is mounted
  final bool autofocus;
  /// Custom fill color for the input field
  /// Default is AppColors.background (gray)
  /// Use AppColors.surface (white) for gray backgrounds
  final Color? fillColor;

  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.errorText,
    this.controller,
    this.obscureText = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.onChanged,
    this.onTap,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.isDense = false,
    this.autofocus = false,
    this.fillColor,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _internalFocusNode;
  bool _isFocused = false;

  FocusNode get _focusNode => widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChange);
      _internalFocusNode?.removeListener(_handleFocusChange);
      _focusNode.addListener(_handleFocusChange);
    }
  }

  void _handleFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.label,
          ),
          AppSpacing.verticalGapXs,
        ],
        
        // Text Field
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          maxLines: widget.maxLines,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          autofocus: widget.autofocus,
          style: AppTypography.body.copyWith(
            color: widget.enabled ? AppColors.textPrimary : AppColors.textSecondary,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppTypography.body.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            prefixIcon: widget.prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: HugeIcon(
                      icon: widget.prefixIcon,
                      color: _isFocused
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: AppIconSize.input,
                    ),
                  )
                : null,
            prefixIconConstraints: widget.prefixIcon != null
                ? const BoxConstraints(minWidth: 0, minHeight: 0)
                : null,
            suffixIcon: widget.suffixIcon,
            suffixIconConstraints: widget.suffixIcon != null
                ? const BoxConstraints(minWidth: 0, minHeight: 0)
                : null,
            isDense: widget.isDense,
            filled: true,
            // ใช้ fillColor ที่กำหนด หรือ default เป็น AppColors.background
            fillColor: widget.enabled
                ? (widget.fillColor ?? AppColors.background)
                : (widget.fillColor ?? AppColors.background).withValues(alpha: 0.5),
            contentPadding: widget.isDense
                ? EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                : AppSpacing.inputPadding,
            // Minimal style: no border, only filled background
            border: OutlineInputBorder(
              borderRadius: AppRadius.smallRadius,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.smallRadius,
              borderSide: hasError
                  ? BorderSide(color: AppColors.error, width: 1)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.smallRadius,
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.smallRadius,
              borderSide: BorderSide(
                color: AppColors.error,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadius.smallRadius,
              borderSide: BorderSide(
                color: AppColors.error,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.smallRadius,
              borderSide: BorderSide.none,
            ),
          ),
        ),
        
        // Error Text
        if (hasError) ...[
          AppSpacing.verticalGapXs,
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: AppIconSize.sm,
                color: AppColors.error,
              ),
              AppSpacing.horizontalGapXs,
              Text(
                widget.errorText!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Password Field - With show/hide toggle
class PasswordField extends StatefulWidget {
  final String? label;
  final String? hintText;
  final String? errorText;
  final TextEditingController? controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const PasswordField({
    super.key,
    this.label,
    this.hintText,
    this.errorText,
    this.controller,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      hintText: widget.hintText,
      errorText: widget.errorText,
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscureText,
      onChanged: widget.onChanged,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      prefixIcon: HugeIcons.strokeRoundedLockPassword,
      suffixIcon: GestureDetector(
        onTap: () => setState(() => _obscureText = !_obscureText),
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 12),
          child: HugeIcon(
            icon: _obscureText ? HugeIcons.strokeRoundedViewOff : HugeIcons.strokeRoundedView,
            color: AppColors.textSecondary,
            size: AppIconSize.input,
          ),
        ),
      ),
    );
  }
}

/// Search Field - With search icon and clear button
class SearchField extends StatefulWidget {
  final String? hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  /// Use dense mode for smaller height (~40px vs ~48px)
  final bool isDense;
  /// Auto focus when widget is mounted
  final bool autofocus;
  /// Focus node for programmatic focus control
  final FocusNode? focusNode;

  const SearchField({
    super.key,
    this.hintText = 'ค้นหา...',
    this.controller,
    this.onChanged,
    this.onClear,
    this.isDense = false,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late TextEditingController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      hintText: widget.hintText,
      prefixIcon: HugeIcons.strokeRoundedSearch01,
      onChanged: widget.onChanged,
      isDense: widget.isDense,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      suffixIcon: _controller.text.isNotEmpty
          ? GestureDetector(
              onTap: () {
                _controller.clear();
                widget.onClear?.call();
                widget.onChanged?.call('');
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 12),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancelCircle,
                  color: AppColors.textSecondary,
                  size: AppIconSize.input,
                ),
              ),
            )
          : null,
    );
  }
}