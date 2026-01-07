import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../models/vital_sign.dart';
import '../../providers/vital_sign_form_provider.dart';

/// Widget สำหรับกรอกสัญญาณชีพ 8 ช่อง
class VitalInputSection extends ConsumerWidget {
  const VitalInputSection({
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
      createNotifier = ref.read(vitalSignFormProvider(residentId).notifier); // Won't be used
    } else {
      createNotifier = ref.read(vitalSignFormProvider(residentId).notifier);
      editNotifier = null;
    }

    // Helper functions that call the right notifier
    void setTemp(String v) => isEditMode ? editNotifier!.setTemp(v) : createNotifier.setTemp(v);
    void setRR(String v) => isEditMode ? editNotifier!.setRR(v) : createNotifier.setRR(v);
    void setO2(String v) => isEditMode ? editNotifier!.setO2(v) : createNotifier.setO2(v);
    void setSBP(String v) => isEditMode ? editNotifier!.setSBP(v) : createNotifier.setSBP(v);
    void setDBP(String v) => isEditMode ? editNotifier!.setDBP(v) : createNotifier.setDBP(v);
    void setPR(String v) => isEditMode ? editNotifier!.setPR(v) : createNotifier.setPR(v);
    void setDTX(String v) => isEditMode ? editNotifier!.setDTX(v) : createNotifier.setDTX(v);
    void setInsulin(String v) => isEditMode ? editNotifier!.setInsulin(v) : createNotifier.setInsulin(v);

    return Column(
      children: [
        // Temperature
        _VitalInputField(
          label: 'Temp - อุณหภูมิ🔥🔥🔥',
          icon: HugeIcons.strokeRoundedTemperature,
          unit: '°C',
          value: formState.temp,
          onChanged: setTemp,
          mask: '##.#',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _validateTemp,
          normalRange: '36.0-37.4',
        ),
        const SizedBox(height: AppSpacing.md),

        // RR (Respiratory Rate)
        _VitalInputField(
          label: 'RR - อัตราการหายใจ🐽🐽🐽',
          icon: HugeIcons.strokeRoundedFastWind,
          unit: '/min',
          value: formState.rr,
          onChanged: setRR,
          keyboardType: TextInputType.number,
          validator: _validateRR,
          normalRange: '16-26',
        ),
        const SizedBox(height: AppSpacing.md),

        // O2 (Oxygen Saturation)
        _VitalInputField(
          label: 'O2 Sat - ออกซิเจนในเลือด❄️❄️❄️',
          icon: HugeIcons.strokeRoundedCloud,
          unit: '%',
          value: formState.o2,
          onChanged: setO2,
          keyboardType: TextInputType.number,
          validator: _validateO2,
          normalRange: '95-100',
        ),
        const SizedBox(height: AppSpacing.md),

        // Blood Pressure (sBP/dBP)
        Row(
          children: [
            Expanded(
              child: _VitalInputField(
                label: 'sBP - ความดันโลหิตตัวบน🔼🔼🔼',
                icon: HugeIcons.strokeRoundedArrowUp05,
                unit: 'mmHg',
                value: formState.sBP,
                onChanged: setSBP,
                keyboardType: TextInputType.number,
                validator: _validateSBP,
                normalRange: '90-140',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _VitalInputField(
                label: 'dBP - ความดันโลหิตตัวล่าง🔽🔽🔽',
                icon: HugeIcons.strokeRoundedArrowDown05,
                unit: 'mmHg',
                value: formState.dBP,
                onChanged: setDBP,
                keyboardType: TextInputType.number,
                validator: _validateDBP,
                normalRange: '60-90',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Pulse
        _VitalInputField(
          label: 'PR - อัตราการเต้นของหัวใจ❤️❤️❤️',
          icon: HugeIcons.strokeRoundedFavouriteCircle,
          unit: 'bpm',
          value: formState.pr,
          onChanged: setPR,
          keyboardType: TextInputType.number,
          validator: _validatePR,
          normalRange: '60-120',
        ),

        // DTX and Insulin - Only for Full Report
        if (formState.isFullReport) ...[
          const SizedBox(height: AppSpacing.md),
          _VitalInputField(
            label: 'น้ำตาลในเลือด (DTX)',
            icon: HugeIcons.strokeRoundedCottonCandy,
            unit: 'mg/dl',
            value: formState.dtx,
            onChanged: setDTX,
            keyboardType: TextInputType.number,
            validator: _validateDTX,
            normalRange: '70-140',
          ),
          const SizedBox(height: AppSpacing.md),
          _VitalInputField(
            label: 'อินซูลิน',
            icon: HugeIcons.strokeRoundedInjection,
            unit: 'units',
            value: formState.insulin,
            onChanged: setInsulin,
            keyboardType: TextInputType.number,
            validator: null,
            normalRange: null,
          ),
        ],
      ],
    );
  }

  // Validation functions
  VitalStatus? _validateTemp(String? value) {
    if (value == null || value.isEmpty) return null;
    final temp = double.tryParse(value);
    if (temp == null) return null;
    if (temp > 38.5 || temp < 36.0) return VitalStatus.critical;
    if (temp >= 37.5) return VitalStatus.warning;
    return VitalStatus.normal;
  }

  VitalStatus? _validateRR(String? value) {
    if (value == null || value.isEmpty) return null;
    final rr = int.tryParse(value);
    if (rr == null) return null;
    if (rr > 29 || rr < 12) return VitalStatus.critical;
    if ((rr >= 25 && rr <= 29) || (rr >= 12 && rr < 16)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  VitalStatus? _validateO2(String? value) {
    if (value == null || value.isEmpty) return null;
    final o2 = int.tryParse(value);
    if (o2 == null) return null;
    if (o2 < 90 || o2 > 100) return VitalStatus.critical;
    if (o2 >= 90 && o2 < 95) return VitalStatus.warning;
    return VitalStatus.normal;
  }

  VitalStatus? _validateSBP(String? value) {
    if (value == null || value.isEmpty) return null;
    final sBP = int.tryParse(value);
    if (sBP == null) return null;
    if (sBP > 160 || sBP < 80) return VitalStatus.critical;
    if ((sBP > 140 && sBP <= 160) || (sBP >= 80 && sBP < 90)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  VitalStatus? _validateDBP(String? value) {
    if (value == null || value.isEmpty) return null;
    final dBP = int.tryParse(value);
    if (dBP == null) return null;
    if (dBP > 100 || dBP < 50) return VitalStatus.critical;
    if ((dBP > 90 && dBP <= 100) || (dBP >= 50 && dBP < 60)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  VitalStatus? _validatePR(String? value) {
    if (value == null || value.isEmpty) return null;
    final pr = int.tryParse(value);
    if (pr == null) return null;
    if (pr < 50) return VitalStatus.critical;
    if (pr >= 50 && pr < 60) return VitalStatus.warning;
    if (pr > 120) return VitalStatus.critical;
    return VitalStatus.normal;
  }

  VitalStatus? _validateDTX(String? value) {
    if (value == null || value.isEmpty) return null;
    final dtx = int.tryParse(value);
    if (dtx == null) return null;
    if (dtx < 60 || dtx > 180) return VitalStatus.critical;
    if ((dtx >= 60 && dtx < 70) || (dtx > 140 && dtx <= 180)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }
}

/// Reusable input field with validation border colors
class _VitalInputField extends StatefulWidget {
  const _VitalInputField({
    required this.label,
    required this.icon,
    required this.unit,
    required this.value,
    required this.onChanged,
    this.mask,
    this.keyboardType,
    this.validator,
    this.normalRange,
  });

  final String label;
  final dynamic icon; // HugeIcons SVG data
  final String unit;
  final String? value;
  final ValueChanged<String> onChanged;
  final String? mask;
  final TextInputType? keyboardType;
  final VitalStatus? Function(String?)? validator;
  final String? normalRange;

  @override
  State<_VitalInputField> createState() => _VitalInputFieldState();
}

class _VitalInputFieldState extends State<_VitalInputField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  VitalStatus? _status;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _status = widget.validator?.call(widget.value);

    // Listen to focus changes
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Validate when field loses focus
      setState(() {
        _status = widget.validator?.call(_controller.text);
      });
    }
  }

  @override
  void didUpdateWidget(_VitalInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if value changed from external source (not from user typing)
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value ?? '';
      _status = widget.validator?.call(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType ?? TextInputType.text,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: widget.label,
            suffixText: widget.unit,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: HugeIcon(
                icon: widget.icon,
                size: AppIconSize.input,
                color: AppColors.secondaryText,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: AppColors.background, // Light grey background
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _getBorderColor(),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppColors.error,
                width: 2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppColors.error,
                width: 2,
              ),
            ),
          ),
          inputFormatters: widget.mask != null
              ? [
                  // Allow decimal numbers for temperature (e.g., 36.5)
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ]
              : widget.keyboardType == TextInputType.number ||
                      widget.keyboardType == const TextInputType.numberWithOptions(decimal: true)
                  ? [
                      // Allow only numbers (and decimal if specified)
                      FilteringTextInputFormatter.allow(
                        widget.keyboardType == const TextInputType.numberWithOptions(decimal: true)
                            ? RegExp(r'^\d*\.?\d*')
                            : RegExp(r'^\d*'),
                      ),
                    ]
                  : null,
          onChanged: (value) {
            widget.onChanged(value);
            // Don't validate while typing - wait for unfocus
          },
        ),

        // Warning/helper text
        if (_status != null && _status != VitalStatus.normal && widget.normalRange != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              'ค่าปกติ: ${widget.normalRange} - กรุณาตรวจสอบอีกครั้ง',
              style: TextStyle(
                fontSize: 12,
                color: _status!.textColor,
              ),
            ),
          ),
      ],
    );
  }

  Color _getBorderColor() {
    if (_status == null) return const Color(0x00000000); // Transparent when normal
    return _status!.textColor;
  }
}
