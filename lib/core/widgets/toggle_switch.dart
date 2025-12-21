import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// Segmented Control - Toggle between 2 options
class SegmentedControl extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const SegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.smallRadius,
      ),
      child: Row(
        children: List.generate(options.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: AppRadius.smallRadius,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  options[index],
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: isSelected ? AppColors.surface : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Standard iOS-style Switch
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  const AppSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: AppColors.primary,
      activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
      inactiveThumbColor: AppColors.surface,
      inactiveTrackColor: AppColors.inputBorder,
    );
  }
}

/// Login Method Toggle - Specific for login screen
class LoginMethodToggle extends StatelessWidget {
  final bool isPasswordMode;
  final ValueChanged<bool> onChanged;

  const LoginMethodToggle({
    super.key,
    required this.isPasswordMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedControl(
      options: const ['รหัสผ่าน', 'OTP'],
      selectedIndex: isPasswordMode ? 0 : 1,
      onChanged: (index) => onChanged(index == 0),
    );
  }
}