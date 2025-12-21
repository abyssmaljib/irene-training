import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// App Text Field - Standard input field
/// States: Default, Focused, Error, Disabled
class AppTextField extends StatefulWidget {
  final String? label;
  final String? hintText;
  final String? errorText;
  final TextEditingController? controller;
  final bool obscureText;
  final bool enabled;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final int maxLines;
  final TextCapitalization textCapitalization;

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
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
          style: AppTypography.body.copyWith(
            color: widget.enabled ? AppColors.textPrimary : AppColors.textSecondary,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppTypography.body.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    color: _isFocused 
                        ? AppColors.primary 
                        : AppColors.textSecondary,
                    size: 22,
                  )
                : null,
            suffixIcon: widget.suffixIcon,
            filled: true,
            fillColor: widget.enabled 
                ? AppColors.surface 
                : AppColors.background,
            contentPadding: AppSpacing.inputPadding,
            border: OutlineInputBorder(
              borderRadius: AppRadius.smallRadius,
              borderSide: BorderSide(
                color: AppColors.inputBorder,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.smallRadius,
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.inputBorder,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.smallRadius,
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.primary,
                width: 2,
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
              borderSide: BorderSide(
                color: AppColors.inputBorder.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
        ),
        
        // Error Text
        if (hasError) ...[
          AppSpacing.verticalGapXs,
          Row(
            children: [
              Icon(
                Iconsax.warning_2,
                size: 14,
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

  const PasswordField({
    super.key,
    this.label,
    this.hintText,
    this.errorText,
    this.controller,
    this.enabled = true,
    this.onChanged,
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
      prefixIcon: Iconsax.lock,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? Iconsax.eye_slash : Iconsax.eye,
          color: AppColors.textSecondary,
          size: 22,
        ),
        onPressed: () {
          setState(() => _obscureText = !_obscureText);
        },
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

  const SearchField({
    super.key,
    this.hintText = 'ค้นหา...',
    this.controller,
    this.onChanged,
    this.onClear,
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
      prefixIcon: Iconsax.search_normal,
      onChanged: widget.onChanged,
      suffixIcon: _controller.text.isNotEmpty
          ? IconButton(
              icon: Icon(
                Iconsax.close_circle,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () {
                _controller.clear();
                widget.onClear?.call();
                widget.onChanged?.call('');
              },
            )
          : null,
    );
  }
}