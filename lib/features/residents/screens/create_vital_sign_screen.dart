import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/success_popup.dart';
import '../providers/resident_detail_provider.dart';
import '../providers/vital_sign_form_provider.dart';
import '../widgets/create_vital_sign/vital_input_section.dart';
import '../widgets/create_vital_sign/care_input_section.dart';
import '../widgets/create_vital_sign/shift_card.dart';
import '../widgets/create_vital_sign/ai_shift_summary_button.dart';
import '../widgets/create_vital_sign/preview_vital_sign_dialog.dart';

/// Single-page scrollable form for creating vital sign records
class CreateVitalSignScreen extends ConsumerWidget {
  const CreateVitalSignScreen({
    super.key,
    required this.residentId,
    this.residentName,
  });

  final int residentId;
  final String? residentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(vitalSignFormProvider(residentId));

    return Scaffold(
      appBar: IreneSecondaryAppBar(
        // TaskAdd01Icon แทนคำว่า "บันทึกสัญญาณชีพ"
        titleIcon: HugeIcons.strokeRoundedTaskAdd01,
        title: residentName,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        // เว้นระยะขอบขวา md
        actions: const [SizedBox(width: AppSpacing.md)],
      ),
      body: formState.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'กำลังโหลดข้อมูล...',
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: AppIconSize.xxxl, color: Colors.red),
              const SizedBox(height: 16),
              Text('เกิดข้อผิดพลาด: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(vitalSignFormProvider(residentId)),
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
        data: (data) => _buildForm(context, ref, data),
      ),
    );
  }

  Widget _buildForm(BuildContext context, WidgetRef ref, dynamic data) {
    final notifier = ref.read(vitalSignFormProvider(residentId).notifier);

    return SingleChildScrollView(
      clipBehavior: Clip.none,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Report Type Toggle
          _buildReportTypeToggle(context, ref, data),
          const SizedBox(height: AppSpacing.md),

          // Date/Time & Shift Section
          _buildMetaSection(context, ref, data),
          const SizedBox(height: AppSpacing.lg),

          // Vital Signs Section (Collapsible)
          _buildCollapsibleSection(
            context: context,
            title: '🌡️ สัญญาณชีพ *',
            subtitle: 'กรอกอย่างน้อย 1 รายการ',
            initiallyExpanded: true,
            children: [
              VitalInputSection(residentId: residentId),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Care Activities Section (Collapsible) - Always shown
          _buildCollapsibleSection(
            context: context,
            title: '💧 กิจกรรมดูแล',
            initiallyExpanded: true,
            children: [
              CareInputSection(residentId: residentId),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Rating Section ย้ายไป checklist task completion แล้ว
          // ผู้ช่วยพยาบาลจะประเมินตอนทำ task แทน

          // General Report Section - Only for Full Report
          if (data.isFullReport) ...[
            const SizedBox(height: AppSpacing.md),
            _buildGeneralReportSection(context, ref, data),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Error message
          if (data.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                data.errorMessage!,
                style: AppTypography.body.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Submit button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: data.isLoading
                  ? null
                  : () async {
                      // 1. Validate ก่อนแสดง Preview
                      final validationError = notifier.validateForPreview();
                      if (validationError != null) {
                        // แสดง error snackbar
                        if (context.mounted) {
                          AppToast.error(context, validationError);
                        }
                        return;
                      }

                      // 2. ดึงข้อมูล user สำหรับแสดงใน preview (รองรับ impersonation)
                      // ใช้ getUserNames() เพื่อดึงทั้ง fullName และ nickname แยกกัน
                      final userNames = await UserService().getUserNames();
                      final userFullName = userNames.fullName;
                      final userNickname = userNames.nickname;

                      // 3. ดึงข้อมูล resident สำหรับแสดงใน preview card
                      final residentDetail =
                          await ref.read(residentDetailProvider(residentId).future);

                      // 4. แสดง Preview Dialog
                      if (!context.mounted) return;
                      final confirmed = await PreviewVitalSignDialog.show(
                        context,
                        formState: data,
                        residentName: residentName ?? '',
                        userFullName: userFullName,
                        userNickname: userNickname,
                        // ส่งข้อมูล resident สำหรับ preview card
                        residentImageUrl: residentDetail?.imageUrl,
                        zoneName: residentDetail?.zoneName,
                        underlyingDiseases:
                            residentDetail?.underlyingDiseases ?? [],
                      );

                      // 4. ถ้ายืนยัน → submit
                      if (confirmed == true && context.mounted) {
                        final success = await notifier.submit();

                        if (success && context.mounted) {
                          await SuccessPopup.show(
                            context,
                            emoji: '📝',
                            message: 'บันทึกสำเร็จ',
                          );
                          if (context.mounted) Navigator.of(context).pop(true);
                        } else if (!success && context.mounted) {
                          // แสดง error snackbar ถ้า submit ไม่สำเร็จ
                          AppToast.error(context, data.errorMessage ?? 'เกิดข้อผิดพลาด');
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: data.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedFloppyDisk, size: AppIconSize.lg, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'บันทึก',
                          style: AppTypography.button.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildReportTypeToggle(BuildContext context, WidgetRef ref, dynamic data) {
    final notifier = ref.read(vitalSignFormProvider(residentId).notifier);

    return Stack(
      children: [
        // Background icon (shadow effect)
        Positioned(
          right: 16,
          top: 0,
          bottom: 0,
          child: HugeIcon(
            icon: data.isFullReport ? HugeIcons.strokeRoundedBook02 : HugeIcons.strokeRoundedNoteEdit,
            size: 80,
            color: AppColors.alternate.withValues(alpha: 0.3),
          ),
        ),

        // Main content
        Material(
          color: Colors.transparent,
          child: SwitchListTile.adaptive(
            value: data.isFullReport,
            onChanged: (value) {
              notifier.setIsFullReport(value);
            },
            title: Text(
              data.isFullReport ? 'สร้างรายงานฉบับเต็ม' : 'สร้างรายงานฉบับย่อ',
              style: AppTypography.heading3.copyWith(
                color: data.isFullReport ? AppColors.primary : AppColors.secondaryText,
              ),
            ),
            subtitle: Text(
              data.isFullReport
                  ? 'ต้องรายงานเรื่องอุจจาระและรายงานประจำวันด้วย ใช้รายงานในเวลาประจำที่ศูนย์กำหนด'
                  : 'จะมีเพียงสัญญาณชีพพื้นฐาน เป็นการรายงานนอกเวลาประจำ',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaSection(BuildContext context, WidgetRef ref, dynamic data) {
    final notifier = ref.read(vitalSignFormProvider(residentId).notifier);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date/Time picker
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, size: AppIconSize.lg, color: AppColors.secondaryText),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: data.selectedDateTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(data.selectedDateTime),
                        );
                        if (time != null) {
                          final dateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                          notifier.setDateTime(dateTime);
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        border: Border.all(color: AppColors.alternate),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${data.selectedDateTime.day}/${data.selectedDateTime.month}/${data.selectedDateTime.year} ${data.selectedDateTime.hour}:${data.selectedDateTime.minute.toString().padLeft(2, '0')}',
                        style: AppTypography.body,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Shift selector with custom cards
            Row(
              children: [
                Expanded(
                  child: ShiftCard(
                    shift: 'เวรเช้า',
                    selected: data.shift == 'เวรเช้า',
                    onTap: () => notifier.setShift('เวรเช้า'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShiftCard(
                    shift: 'เวรดึก',
                    selected: data.shift == 'เวรดึก',
                    onTap: () => notifier.setShift('เวรดึก'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralReportSection(BuildContext context, WidgetRef ref, dynamic data) {
    final notifier = ref.read(vitalSignFormProvider(residentId).notifier);

    // ปุ่ม AI สรุปเวร — ส่งเข้าไปวางมุมบนขวาของ card
    final aiButton = AiShiftSummaryButton(
      residentId: residentId,
      residentName: residentName ?? '',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text field สำหรับรายงาน + ปุ่ม AI อยู่มุมบนขวาของ card
        if (data.shift == 'เวรเช้า')
          _GeneralReportField(
            label: 'รายงานเพิ่มเติมนอกเหนือจากการประเมินด้วยดาว',
            initialValue: data.reportD,
            onChanged: notifier.setReportD,
            minLines: 5,
            aiButton: aiButton,
          )
        else
          _GeneralReportField(
            label: 'รายงานเพิ่มเติมนอกเหนือจากการประเมินด้วยดาว',
            initialValue: data.reportN,
            onChanged: notifier.setReportN,
            minLines: 3,
            aiButton: aiButton,
          ),

        // Disclaimer — เตือนให้ตรวจสอบก่อน save
        const SizedBox(height: 4),
        Text(
          'โปรดตรวจสอบข้อมูลก่อนบันทึก เนื่องจาก AI อาจสรุปไม่ครบถ้วน',
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsibleSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
    bool initiallyExpanded = false,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          title: Text(
            title,
            style: AppTypography.heading3,
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                )
              : null,
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateful widget for General Report text field to prevent selection issue
class _GeneralReportField extends StatefulWidget {
  const _GeneralReportField({
    this.label,
    required this.initialValue,
    required this.onChanged,
    this.minLines = 5,
    this.aiButton,
  });

  final String? label;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final int minLines;
  /// ปุ่ม AI สรุปเวร — วางไว้มุมบนขวาของ card (ถ้ามี)
  final Widget? aiButton;

  @override
  State<_GeneralReportField> createState() => _GeneralReportFieldState();
}

class _GeneralReportFieldState extends State<_GeneralReportField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_GeneralReportField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if value changed from external source (not from user typing)
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: ชื่อ card + ปุ่ม AI (ถ้ามี) อยู่มุมบนขวา
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'มีรายงานเพิ่มเติมมั้ย?',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.aiButton != null) widget.aiButton!,
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: null,
              minLines: widget.minLines,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: widget.label ?? 'รายงานเพิ่มเติมนอกเหนือจากการประเมินด้วยดาว',
                hintText: 'บันทึกข้อสังเกตและรายงานทั่วไป...',
                filled: true,
                fillColor: AppColors.background,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedEdit01,
                    size: AppIconSize.input,
                    color: AppColors.secondaryText,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
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
            ),
          ],
        ),
      ),
    );
  }
}
