import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/vital_sign_form_provider.dart';
import 'package:hugeicons/hugeicons.dart';

/// Widget for care activities: Input, Output, Defecation, Napkin
class CareInputSection extends ConsumerWidget {
  const CareInputSection({
    super.key,
    required this.residentId,
    this.vitalSignId,
  });

  final int residentId;
  final int? vitalSignId; // null = create mode, non-null = edit mode

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use appropriate provider based on mode
    final isEditMode = vitalSignId != null;
    final formState = isEditMode
        ? ref.watch(editVitalSignFormProvider((residentId: residentId, vitalSignId: vitalSignId!))).value
        : ref.watch(vitalSignFormProvider(residentId)).value;
    if (formState == null) return const SizedBox.shrink();

    // Get notifier based on mode
    final VitalSignFormNotifier createNotifier;
    final EditVitalSignFormNotifier? editNotifier;
    if (isEditMode) {
      editNotifier = ref.read(editVitalSignFormProvider((residentId: residentId, vitalSignId: vitalSignId!)).notifier);
      createNotifier = ref.read(vitalSignFormProvider(residentId).notifier);
    } else {
      createNotifier = ref.read(vitalSignFormProvider(residentId).notifier);
      editNotifier = null;
    }

    // Helper functions
    void setInput(String v) => isEditMode ? editNotifier!.setInput(v) : createNotifier.setInput(v);
    void setOutput(String v) => isEditMode ? editNotifier!.setOutput(v) : createNotifier.setOutput(v);
    void setDefecation(bool v) => isEditMode ? editNotifier!.setDefecation(v) : createNotifier.setDefecation(v);
    void setConstipation(String v) => isEditMode ? editNotifier!.setConstipation(v) : createNotifier.setConstipation(v);
    void setNapkin(String v) => isEditMode ? editNotifier!.setNapkin(v) : createNotifier.setNapkin(v);

    return Column(
      children: [
        // Input (Fluid Intake)
        _CareInputField(
          label: 'น้ำเข้า (Input)',
          icon: HugeIcons.strokeRoundedWaterPump,
          unit: 'ml',
          value: formState.input,
          onChanged: setInput,
          keyboardType: TextInputType.number,
          hint: 'ปริมาณน้ำที่ดื่ม/รับประทาน',
        ),
        const SizedBox(height: AppSpacing.md),

        // Output (Fluid Output)
        _CareInputField(
          label: 'น้ำออก (Output)',
          icon: HugeIcons.strokeRoundedWaterEnergy,
          unit: 'ml',
          value: formState.output,
          onChanged: setOutput,
          keyboardType: TextInputType.text,
          hint: 'ปริมาณปัสสาวะ หรือระบุรายละเอียด',
        ),
        const SizedBox(height: AppSpacing.md),

        // Defecation Section
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'วันนี้ได้อุจจาระหรือไม่?',
            style: AppTypography.label.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),

        // Defecation Toggle with background icon
        Stack(
          children: [
            // Background icon (shadow effect)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedActivity02,
                size: 80,
                color: AppColors.alternate.withValues(alpha: 0.3),
              ),
            ),

            // Main content
            Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                value: formState.defecation,
                onChanged: setDefecation,
                title: Text(
                  formState.defecation ? 'อุจจาระออก 💩🎉' : 'อุจจาระไม่ออก 😣',
                  style: AppTypography.heading3,
                ),
                activeTrackColor: AppColors.accent1,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Constipation field when NOT defecated
        if (!formState.defecation)
          _CareInputField(
            label: 'วันท้องผูก',
            icon: HugeIcons.strokeRoundedToilet01,
            unit: 'วัน',
            value: formState.constipation,
            onChanged: setConstipation,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            hint: 'แก้ไขได้ถ้าระบบคำนวณผิด',
            enabled: true,
          ),

        // Constipation field when defecated (read-only, shows 0)
        if (formState.defecation)
          _CareInputField(
            label: 'วันท้องผูก',
            icon: HugeIcons.strokeRoundedToilet01,
            unit: 'วัน',
            value: '0',
            onChanged: (_) {},
            keyboardType: TextInputType.number,
            hint: 'รีเซ็ตเป็น 0 เพราะถ่ายแล้ว',
            enabled: false,
          ),
        const SizedBox(height: AppSpacing.md),

        // Napkin Count
        _CareInputField(
          label: 'ผ้าอ้อม/แพ็ด',
          icon: HugeIcons.strokeRoundedNapkins01,
          unit: 'ชิ้น',
          value: formState.napkin,
          onChanged: setNapkin,
          keyboardType: TextInputType.number,
          hint: 'จำนวนผ้าอ้อมที่เปลี่ยน',
        ),
      ],
    );
  }
}

/// Reusable input field for care activities
class _CareInputField extends StatefulWidget {
  const _CareInputField({
    required this.label,
    required this.icon,
    required this.unit,
    required this.value,
    required this.onChanged,
    this.keyboardType,
    this.hint,
    this.enabled = true,
  });

  final String label;
  final dynamic icon; // HugeIcons SVG data
  final String unit;
  final String? value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final String? hint;
  final bool enabled;

  @override
  State<_CareInputField> createState() => _CareInputFieldState();
}

class _CareInputFieldState extends State<_CareInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_CareInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if value changed from external source (not from user typing)
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: widget.keyboardType ?? TextInputType.text,
      enabled: widget.enabled,
      inputFormatters: widget.keyboardType == TextInputType.number
          ? [
              FilteringTextInputFormatter.digitsOnly,
            ]
          : widget.keyboardType == const TextInputType.numberWithOptions(decimal: true)
              ? [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ]
              : null,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.unit,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: HugeIcon(
            icon: widget.icon,
            size: AppIconSize.input,
            color: widget.enabled ? AppColors.secondaryText : AppColors.secondaryText.withValues(alpha: 0.5),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: widget.hint,
        filled: true,
        fillColor: widget.enabled
            ? AppColors.background
            : AppColors.background.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}
