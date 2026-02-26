import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/irene_app_bar.dart';
import '../../../core/widgets/success_popup.dart';
import '../providers/vital_sign_form_provider.dart';
import '../widgets/create_vital_sign/vital_input_section.dart';
import '../widgets/create_vital_sign/care_input_section.dart';
import '../widgets/create_vital_sign/rating_section.dart';

/// Screen for editing existing vital sign records
class EditVitalSignScreen extends ConsumerWidget {
  const EditVitalSignScreen({
    super.key,
    required this.vitalSignId,
    required this.residentId,
    this.residentName,
  });

  final int vitalSignId;
  final int residentId;
  final String? residentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (residentId: residentId, vitalSignId: vitalSignId);
    final formState = ref.watch(editVitalSignFormProvider(params));

    return Scaffold(
      appBar: IreneSecondaryAppBar(
        // ใช้ TaskEdit01Icon แทนคำว่า "แก้ไขสัญญาณชีพ"
        titleIcon: HugeIcons.strokeRoundedTaskEdit01,
        title: residentName,
        actions: [
          // Delete button
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedDelete01,
              color: AppColors.error,
              size: AppIconSize.lg,
            ),
            onPressed: () => _showDeleteConfirmation(context, ref),
          ),
          // เว้นระยะขอบขวา md
          const SizedBox(width: AppSpacing.md),
        ],
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
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: AppIconSize.xxxl,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text('เกิดข้อผิดพลาด: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(editVitalSignFormProvider(params)),
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
        data: (data) => _buildForm(context, ref, data),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      type: ConfirmDialogType.delete,
      title: 'ลบบันทึกสัญญาณชีพ',
      message: 'คุณต้องการลบบันทึกนี้หรือไม่?\nการดำเนินการนี้ไม่สามารถยกเลิกได้',
    );

    if (confirmed && context.mounted) {
      final params = (residentId: residentId, vitalSignId: vitalSignId);
      final notifier = ref.read(editVitalSignFormProvider(params).notifier);
      final success = await notifier.delete();

      if (success && context.mounted) {
        await SuccessPopup.show(context, emoji: '🗑️', message: 'ลบสำเร็จ');
        if (context.mounted) Navigator.of(context).pop(true);
      }
    }
  }

  Widget _buildForm(BuildContext context, WidgetRef ref, dynamic data) {
    final params = (residentId: residentId, vitalSignId: vitalSignId);
    final notifier = ref.read(editVitalSignFormProvider(params).notifier);

    return SingleChildScrollView(
      clipBehavior: Clip.none,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Meta Info (Read-only display)
          _buildReadOnlyMetaInfo(data),
          const SizedBox(height: AppSpacing.lg),

          // Vital Signs Section (Collapsible)
          _buildCollapsibleSection(
            context: context,
            title: '🌡️ สัญญาณชีพ *',
            subtitle: 'กรอกอย่างน้อย 1 รายการ',
            initiallyExpanded: true,
            children: [
              _EditVitalInputSection(params: params),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Care Activities Section (Collapsible)
          _buildCollapsibleSection(
            context: context,
            title: '💧 กิจกรรมดูแล',
            initiallyExpanded: true,
            children: [
              _EditCareInputSection(params: params),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Ratings Section (Collapsible) - Only for Full Report
          if (data.isFullReport)
            _buildCollapsibleSection(
              context: context,
              title: '⭐ การประเมิน (${data.shift}) *',
              subtitle: 'ให้คะแนนครบทุกหัวข้อ',
              initiallyExpanded: true,
              children: [
                _EditRatingSection(params: params),
              ],
            ),

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
                      final success = await notifier.update();

                      if (success && context.mounted) {
                        await SuccessPopup.show(context, emoji: '📝', message: 'บันทึกสำเร็จ');
                        if (context.mounted) Navigator.of(context).pop(true);
                      } else if (!success && context.mounted && data.errorMessage != null) {
                        AppSnackbar.error(context, data.errorMessage ?? 'เกิดข้อผิดพลาด');
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
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedFloppyDisk,
                          size: AppIconSize.lg,
                          color: Colors.white,
                        ),
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

  /// Read-only display of report type, date/time, and shift
  Widget _buildReadOnlyMetaInfo(dynamic data) {
    final thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final dt = data.selectedDateTime as DateTime;
    // แสดงปี ค.ศ. (Christian Era)
    final dateStr = '${dt.day} ${thaiMonths[dt.month - 1]} ${dt.year}';
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';

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
        child: Row(
          children: [
            // Report type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: data.isFullReport
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.secondaryText.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: data.isFullReport
                        ? HugeIcons.strokeRoundedBook02
                        : HugeIcons.strokeRoundedNoteEdit,
                    size: AppIconSize.sm,
                    color: data.isFullReport
                        ? AppColors.primary
                        : AppColors.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    data.isFullReport ? 'ฉบับเต็ม' : 'ฉบับย่อ',
                    style: AppTypography.bodySmall.copyWith(
                      color: data.isFullReport
                          ? AppColors.primary
                          : AppColors.secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Shift badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: data.shift == 'เวรเช้า'
                    ? AppColors.warning.withValues(alpha: 0.15)
                    : AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: data.shift == 'เวรเช้า'
                        ? HugeIcons.strokeRoundedSun03
                        : HugeIcons.strokeRoundedMoon02,
                    size: AppIconSize.sm,
                    color: data.shift == 'เวรเช้า'
                        ? AppColors.warning
                        : AppColors.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    data.shift,
                    style: AppTypography.bodySmall.copyWith(
                      color: data.shift == 'เวรเช้า'
                          ? AppColors.warning
                          : AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Date/Time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dateStr,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  timeStr,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
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
    final params = (residentId: residentId, vitalSignId: vitalSignId);
    final notifier = ref.read(editVitalSignFormProvider(params).notifier);

    // Show different field based on shift
    if (data.shift == 'เวรเช้า') {
      return _GeneralReportField(
        label: 'รายงานเพิ่มเติมนอกเหนือจากการประเมินด้วยดาว',
        initialValue: data.reportD,
        onChanged: notifier.setReportD,
        minLines: 5,
      );
    } else {
      return _GeneralReportField(
        label: 'รายงานเพิ่มเติมนอกเหนือจากการประเมินด้วยดาว',
        initialValue: data.reportN,
        onChanged: notifier.setReportN,
        minLines: 3,
      );
    }
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

/// Wrapper for VitalInputSection that uses edit provider
class _EditVitalInputSection extends StatelessWidget {
  const _EditVitalInputSection({required this.params});

  final EditVitalSignParams params;

  @override
  Widget build(BuildContext context) {
    return VitalInputSection(
      residentId: params.residentId,
      vitalSignId: params.vitalSignId,
    );
  }
}

/// Wrapper for CareInputSection that uses edit provider
class _EditCareInputSection extends StatelessWidget {
  const _EditCareInputSection({required this.params});

  final EditVitalSignParams params;

  @override
  Widget build(BuildContext context) {
    return CareInputSection(
      residentId: params.residentId,
      vitalSignId: params.vitalSignId,
    );
  }
}

/// Wrapper for RatingSection that uses edit provider
class _EditRatingSection extends StatelessWidget {
  const _EditRatingSection({required this.params});

  final EditVitalSignParams params;

  @override
  Widget build(BuildContext context) {
    return RatingSection(
      residentId: params.residentId,
      vitalSignId: params.vitalSignId,
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
  });

  final String? label;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final int minLines;

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
            Text(
              'มีรายงานเพิ่มเติมมั้ย?',
              style: AppTypography.label.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
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
