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
    // defecation เป็น bool? (nullable) - null = ยังไม่ได้เลือก
    void setDefecation(bool? v) => isEditMode ? editNotifier!.setDefecation(v) : createNotifier.setDefecation(v);
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
          unit: '',
          value: formState.output,
          onChanged: setOutput,
          keyboardType: TextInputType.text,
          hint: 'ปริมาณปัสสาวะ หรือระบุรายละเอียด',
        ),
        const SizedBox(height: AppSpacing.md),

        // Defecation Section - Card ใหญ่เด่นชัด เตะตา
        _DefecationCard(
          defecation: formState.defecation,
          constipation: formState.constipation,
          onDefecationChanged: setDefecation,
          onConstipationChanged: setConstipation,
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
  });

  final String label;
  final dynamic icon; // HugeIcons SVG data
  final String unit;
  final String? value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final String? hint;

  @override
  State<_CareInputField> createState() => _CareInputFieldState();
}

/// Card สำหรับ section อุจจาระ - ออกแบบให้ใหญ่และเด่นชัด เตะตา
/// เพื่อให้ user สังเกตเห็นง่ายและไม่พลาดการกรอกข้อมูลส่วนนี้
class _DefecationCard extends StatelessWidget {
  const _DefecationCard({
    required this.defecation,
    required this.constipation,
    required this.onDefecationChanged,
    required this.onConstipationChanged,
  });

  // null = ยังไม่ได้เลือก, true = ถ่ายแล้ว, false = ยังไม่ถ่าย
  final bool? defecation;
  final String? constipation;
  final ValueChanged<bool?> onDefecationChanged;
  final ValueChanged<String> onConstipationChanged;

  @override
  Widget build(BuildContext context) {
    // สีพื้นหลังตามสถานะ:
    // - null (ยังไม่เลือก) = สีเทา/neutral เพื่อเตือนให้เลือก
    // - true (ถ่ายแล้ว) = สีเขียว
    // - false (ยังไม่ถ่าย) = สีแดง
    final Color backgroundColor;
    final Color borderColor;
    final Color accentColor;
    final String headerEmoji;

    if (defecation == null) {
      // ยังไม่ได้เลือก - ใช้สีส้ม warning เพื่อเตือน
      backgroundColor = AppColors.warning.withValues(alpha: 0.08);
      borderColor = AppColors.warning.withValues(alpha: 0.3);
      accentColor = AppColors.warning;
      headerEmoji = '❓';
    } else if (defecation!) {
      // ถ่ายแล้ว - สีเขียว
      backgroundColor = AppColors.success.withValues(alpha: 0.08);
      borderColor = AppColors.success.withValues(alpha: 0.3);
      accentColor = AppColors.success;
      headerEmoji = '💩';
    } else {
      // ยังไม่ถ่าย - สีเทาเข้ม (neutral/dark)
      backgroundColor = AppColors.secondaryText.withValues(alpha: 0.08);
      borderColor = AppColors.secondaryText.withValues(alpha: 0.3);
      accentColor = AppColors.secondaryText;
      headerEmoji = '🚽';
    }

    return Stack(
      children: [
        // Background icon ตกแต่ง - PoopIcon ใหญ่ๆ ด้านหลัง
        Positioned(
          right: 16,
          top: 16,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedPoop,
            size: 100,
            color: accentColor.withValues(alpha: 0.08),
          ),
        ),
        // Main content
        Container(
          margin: const EdgeInsets.only(top: AppSpacing.sm),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Column(
            children: [
              // Header พร้อม icon ใหญ่ๆ
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    // Icon วงกลมใหญ่
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          headerEmoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Title และ subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'การขับถ่าย',
                            style: AppTypography.heading3.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            defecation == null
                                ? 'กรุณาเลือกสถานะ *'
                                : 'วันนี้ได้อุจจาระหรือไม่?',
                            style: AppTypography.bodySmall.copyWith(
                              color: defecation == null
                                  ? AppColors.warning
                                  : AppColors.secondaryText,
                              fontWeight: defecation == null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Toggle buttons แบบ 2 ปุ่มใหญ่ๆ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    // ปุ่ม "ถ่ายแล้ว"
                    Expanded(
                      child: _DefecationToggleButton(
                        label: 'ถ่ายแล้ว',
                        emoji: '🎉',
                        isSelected: defecation == true,
                        selectedColor: AppColors.success,
                        onTap: () => onDefecationChanged(true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // ปุ่ม "ยังไม่ถ่าย" - ใช้สีเทาเข้ม
                    Expanded(
                      child: _DefecationToggleButton(
                        label: 'ยังไม่ถ่าย',
                        emoji: '😣',
                        isSelected: defecation == false,
                        selectedColor: AppColors.secondaryText,
                        onTap: () => onDefecationChanged(false),
                      ),
                    ),
                  ],
                ),
              ),

              // Constipation field - แสดงเมื่อเลือกแล้ว
              if (defecation != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _ConstipationField(
                    defecation: defecation!,
                    constipation: constipation,
                    onChanged: onConstipationChanged,
                  ),
                ),

              // เมื่อยังไม่ได้เลือก แสดงข้อความเตือน
              if (defecation == null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAlert02,
                          size: AppIconSize.md,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'กรุณาเลือกสถานะการขับถ่ายก่อนบันทึก',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ปุ่ม toggle สำหรับเลือกสถานะอุจจาระ - ออกแบบให้กดง่าย เห็นชัด
class _DefecationToggleButton extends StatelessWidget {
  const _DefecationToggleButton({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? selectedColor
                  : AppColors.alternate,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.body.copyWith(
                  color: isSelected ? selectedColor : AppColors.secondaryText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTick02,
                  size: AppIconSize.sm,
                  color: selectedColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Field สำหรับแสดงจำนวนวันท้องผูก
class _ConstipationField extends StatefulWidget {
  const _ConstipationField({
    required this.defecation,
    required this.constipation,
    required this.onChanged,
  });

  final bool defecation;
  final String? constipation;
  final ValueChanged<String> onChanged;

  @override
  State<_ConstipationField> createState() => _ConstipationFieldState();
}

class _ConstipationFieldState extends State<_ConstipationField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.defecation ? '0' : widget.constipation,
    );
  }

  @override
  void didUpdateWidget(_ConstipationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // อัปเดต text เมื่อ defecation เปลี่ยน หรือ constipation เปลี่ยนจากภายนอก
    if (widget.defecation != oldWidget.defecation) {
      _controller.text = widget.defecation ? '0' : (widget.constipation ?? '');
    } else if (!widget.defecation &&
        widget.constipation != oldWidget.constipation &&
        widget.constipation != _controller.text) {
      _controller.text = widget.constipation ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.defecation;
    final bgColor = enabled
        ? Colors.white
        : AppColors.background.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar03,
            size: AppIconSize.lg,
            color: enabled ? AppColors.secondaryText : AppColors.secondaryText.withValues(alpha: 0.5),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'วันท้องผูก',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                TextField(
                  controller: _controller,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: AppTypography.heading3.copyWith(
                    color: enabled ? AppColors.textPrimary : AppColors.secondaryText,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: enabled ? 'แก้ไขได้ถ้าระบบคำนวณผิด' : 'รีเซ็ตเป็น 0 เพราะถ่ายแล้ว',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: AppColors.secondaryText.withValues(alpha: 0.5),
                    ),
                  ),
                  onChanged: widget.onChanged,
                ),
              ],
            ),
          ),
          Text(
            'วัน',
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
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
            color: AppColors.secondaryText,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: widget.hint,
        filled: true,
        fillColor: AppColors.background,
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
