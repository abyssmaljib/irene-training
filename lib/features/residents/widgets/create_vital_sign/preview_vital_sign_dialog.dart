import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/buttons.dart';
import '../../models/vital_sign.dart';
import '../../models/vital_sign_form_state.dart';

/// Bottom Sheet สำหรับ Preview ข้อมูล Vital Sign ก่อน Submit
/// แสดง 2 sections: สรุปข้อมูล + ตัวอย่างรายงานที่จะส่งให้ญาติ
class PreviewVitalSignDialog extends StatelessWidget {
  const PreviewVitalSignDialog({
    super.key,
    required this.formState,
    required this.residentName,
    this.userFullName,
    this.userNickname,
  });

  final VitalSignFormState formState;
  final String residentName;
  final String? userFullName;
  final String? userNickname;

  /// แสดง Preview Bottom Sheet
  /// Return: true = ยืนยัน, false = แก้ไข, null = ปิด
  static Future<bool?> show(
    BuildContext context, {
    required VitalSignFormState formState,
    required String residentName,
    String? userFullName,
    String? userNickname,
  }) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // ให้ bottom sheet ขยายได้เต็มจอ
      backgroundColor: Colors.transparent,
      builder: (context) => PreviewVitalSignDialog(
        formState: formState,
        residentName: residentName,
        userFullName: userFullName,
        userNickname: userNickname,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // สร้างข้อความรายงานสำหรับ preview
    final formattedReport = _buildFormattedReport(
      residentName: residentName,
      formState: formState,
      userFullName: userFullName,
      userNickname: userNickname,
    );

    return Container(
      // จำกัดความสูงไม่เกิน 85% ของหน้าจอ
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.large),
          topRight: Radius.circular(AppRadius.large),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          _buildDragHandle(),

          // Header
          _buildHeader(context),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Space หลัง header
                  const SizedBox(height: AppSpacing.md),

                  // Section 1: สรุปข้อมูล
                  _buildSummarySection(),
                  const SizedBox(height: AppSpacing.md),

                  // Section 2: ตัวอย่างรายงานที่จะส่ง
                  _buildFormattedReportSection(context, formattedReport),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),

          // Action Buttons
          _buildActionButtons(context),
        ],
      ),
    );
  }

  /// Drag handle สำหรับ bottom sheet
  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.alternate,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// สร้าง Header ของ Bottom Sheet
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedFileSearch,
                color: AppColors.primary,
                size: AppIconSize.lg,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ตรวจสอบข้อมูลก่อนบันทึก',
                  style: AppTypography.heading3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  formState.isFullReport ? 'รายงานฉบับเต็ม' : 'รายงานฉบับย่อ',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section 1: สรุปข้อมูล พร้อม validation
  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meta info
        _buildSectionTitle('📋 ข้อมูลทั่วไป'),
        _buildPreviewRow(
          '🗓️ วันที่/เวลา',
          _formatDateTime(formState.selectedDateTime),
        ),
        _buildPreviewRow('⏰ เวร', formState.shift),

        const SizedBox(height: AppSpacing.md),

        // Vital Signs พร้อม validation
        _buildSectionTitle('🌡️ สัญญาณชีพ'),
        if (formState.temp?.isNotEmpty == true)
          _buildVitalSignRow(
            'Temp',
            '${formState.temp} °C',
            _validateTemp(formState.temp),
          ),
        if (formState.rr?.isNotEmpty == true)
          _buildVitalSignRow(
            'RR',
            '${formState.rr} /min',
            _validateRR(formState.rr),
          ),
        if (formState.o2?.isNotEmpty == true)
          _buildVitalSignRow(
            'O2 Sat',
            '${formState.o2} %',
            _validateO2(formState.o2),
          ),
        if (formState.sBP?.isNotEmpty == true ||
            formState.dBP?.isNotEmpty == true)
          _buildVitalSignRow(
            'BP',
            '${formState.sBP ?? "-"}/${formState.dBP ?? "-"} mmHg',
            _validateBP(formState.sBP, formState.dBP),
          ),
        if (formState.pr?.isNotEmpty == true)
          _buildVitalSignRow(
            'PR',
            '${formState.pr} bpm',
            _validatePR(formState.pr),
          ),
        if (formState.isFullReport && formState.dtx?.isNotEmpty == true)
          _buildVitalSignRow(
            'DTX',
            '${formState.dtx} mg/dl',
            _validateDTX(formState.dtx),
          ),
        if (formState.isFullReport && formState.insulin?.isNotEmpty == true)
          _buildPreviewRow('Insulin', '${formState.insulin} units'),

        // Care Activities (Full Report only)
        if (formState.isFullReport) ...[
          const SizedBox(height: AppSpacing.md),
          _buildSectionTitle('💧 กิจกรรมดูแล'),
          if (formState.input?.isNotEmpty == true)
            _buildPreviewRow('น้ำเข้า', '${formState.input} ml'),
          if (formState.output?.isNotEmpty == true)
            _buildPreviewRow('น้ำออก', formState.output!),
          _buildPreviewRow(
            'อุจจาระ',
            formState.defecation == true ? 'ถ่ายแล้ว ✓' : 'ยังไม่ถ่าย',
            valueColor: formState.defecation == true
                ? AppColors.success
                : AppColors.secondaryText,
          ),
          if (formState.constipation?.isNotEmpty == true)
            _buildVitalSignRow(
              'วันท้องผูก',
              '${formState.constipation} วัน',
              _validateConstipation(formState.constipation),
            ),
          if (formState.napkin?.isNotEmpty == true)
            _buildPreviewRow('ผ้าอ้อม', '${formState.napkin} ชิ้น'),
        ],

        // Ratings (Full Report only)
        if (formState.isFullReport && formState.ratings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _buildSectionTitle('⭐ การประเมิน'),
          ...formState.ratings.values.map((rating) {
            // สร้างดาว ★
            final stars = rating.rating != null
                ? '★' * rating.rating! + '☆' * (5 - rating.rating!)
                : '-';
            final choiceText = rating.selectedChoiceText ?? '';
            return _buildPreviewRow(
              rating.subjectName,
              '$stars ${choiceText.isNotEmpty ? "($choiceText)" : ""}',
            );
          }),
        ],
      ],
    );
  }

  /// Section 2: ตัวอย่างรายงานที่จะส่ง
  Widget _buildFormattedReportSection(
      BuildContext context, String formattedReport) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('📝 ตัวอย่างรายงานที่จะส่ง'),
        const SizedBox(height: AppSpacing.xs),

        // Report box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.alternate),
          ),
          child: SelectableText(
            formattedReport,
            style: AppTypography.body.copyWith(
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Copy button
        Center(
          child: TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: formattedReport));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedTick02,
                        color: Colors.white,
                        size: AppIconSize.md,
                      ),
                      const SizedBox(width: 8),
                      const Text('คัดลอกรายงานแล้ว'),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCopy01,
              color: AppColors.primary,
              size: AppIconSize.md,
            ),
            label: Text(
              'คัดลอกรายงาน',
              style: AppTypography.body.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Action Buttons
  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        // เพิ่ม padding ล่างสำหรับ safe area (notch, home indicator)
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ปุ่มแก้ไข
          Expanded(
            child: SecondaryButton(
              text: '← แก้ไข',
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // ปุ่มยืนยัน
          Expanded(
            child: PrimaryButton(
              text: 'ยืนยันบันทึก',
              icon: HugeIcons.strokeRoundedFloppyDisk,
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
        ],
      ),
    );
  }

  /// สร้าง Section Title
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        title,
        style: AppTypography.label.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  /// สร้าง Row แสดง label + value (ธรรมดา)
  Widget _buildPreviewRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// สร้าง Row แสดง vital sign พร้อม validation warning
  /// ใช้ tuple (VitalStatus, String) เพื่อแสดงสีตามระดับความรุนแรง
  Widget _buildVitalSignRow(
    String label,
    String value,
    (VitalStatus, String)? validation,
  ) {
    final hasWarning = validation != null;
    final status = validation?.$1;
    final message = validation?.$2;

    // เลือกสีตาม VitalStatus
    Color getStatusColor() {
      if (status == null) return AppColors.textPrimary;
      return status.textColor;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: hasWarning ? getStatusColor() : AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Value
                Text(
                  value,
                  style: AppTypography.body.copyWith(
                    color: hasWarning ? getStatusColor() : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Warning message พร้อม status label
                if (hasWarning && message != null)
                  Text(
                    '(${status?.label ?? ""}: $message)',
                    style: AppTypography.caption.copyWith(
                      color: getStatusColor(),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Validation Functions
  // ใช้ค่าเดียวกับ VitalSign model และ VitalInputSection
  // ==========================================

  /// Validate อุณหภูมิ - ปกติ 36.0-37.4 °C
  /// Critical: >38.5 หรือ <36.0
  /// Warning: 37.5-38.5
  (VitalStatus, String)? _validateTemp(String? value) {
    if (value == null || value.isEmpty) return null;
    final temp = double.tryParse(value);
    if (temp == null) return null;

    if (temp > 38.5) return (VitalStatus.critical, 'ไข้สูง > 38.5°C');
    if (temp < 36.0) return (VitalStatus.critical, 'ต่ำกว่าปกติ < 36°C');
    if (temp >= 37.5) return (VitalStatus.warning, 'ไข้ต่ำ');
    return null; // ปกติ
  }

  /// Validate อัตราการหายใจ - ปกติ 16-26 /min
  /// Critical: >29 หรือ <12
  /// Warning: 25-29 หรือ 12-15
  (VitalStatus, String)? _validateRR(String? value) {
    if (value == null || value.isEmpty) return null;
    final rr = int.tryParse(value);
    if (rr == null) return null;

    if (rr > 29) return (VitalStatus.critical, 'เร็วมาก > 29');
    if (rr < 12) return (VitalStatus.critical, 'ช้ามาก < 12');
    if (rr >= 25 && rr <= 29) return (VitalStatus.warning, 'เร็วกว่าปกติ');
    if (rr >= 12 && rr < 16) return (VitalStatus.warning, 'ช้ากว่าปกติ');
    return null; // ปกติ
  }

  /// Validate O2 Saturation - ปกติ 95-100%
  /// Critical: <90 หรือ >100
  /// Warning: 90-94
  (VitalStatus, String)? _validateO2(String? value) {
    if (value == null || value.isEmpty) return null;
    final o2 = int.tryParse(value);
    if (o2 == null) return null;

    if (o2 < 90) return (VitalStatus.critical, 'ต่ำมาก < 90%');
    if (o2 > 100) return (VitalStatus.critical, 'ผิดปกติ > 100%');
    if (o2 >= 90 && o2 < 95) return (VitalStatus.warning, 'ต่ำกว่าปกติ');
    return null; // ปกติ
  }

  /// Validate Blood Pressure
  /// Systolic ปกติ 90-140 mmHg
  /// Diastolic ปกติ 60-90 mmHg
  (VitalStatus, String)? _validateBP(String? systolic, String? diastolic) {
    final warnings = <String>[];
    var worstStatus = VitalStatus.normal;

    if (systolic != null && systolic.isNotEmpty) {
      final sbp = int.tryParse(systolic);
      if (sbp != null) {
        if (sbp > 160 || sbp < 80) {
          worstStatus = VitalStatus.critical;
          warnings.add(sbp > 160 ? 'SBP สูงมาก' : 'SBP ต่ำมาก');
        } else if ((sbp > 140 && sbp <= 160) || (sbp >= 80 && sbp < 90)) {
          if (worstStatus != VitalStatus.critical) {
            worstStatus = VitalStatus.warning;
          }
          warnings.add(sbp > 140 ? 'SBP สูง' : 'SBP ต่ำ');
        }
      }
    }

    if (diastolic != null && diastolic.isNotEmpty) {
      final dbp = int.tryParse(diastolic);
      if (dbp != null) {
        if (dbp > 100 || dbp < 50) {
          worstStatus = VitalStatus.critical;
          warnings.add(dbp > 100 ? 'DBP สูงมาก' : 'DBP ต่ำมาก');
        } else if ((dbp > 90 && dbp <= 100) || (dbp >= 50 && dbp < 60)) {
          if (worstStatus != VitalStatus.critical) {
            worstStatus = VitalStatus.warning;
          }
          warnings.add(dbp > 90 ? 'DBP สูง' : 'DBP ต่ำ');
        }
      }
    }

    if (warnings.isEmpty) return null;
    return (worstStatus, warnings.join(', '));
  }

  /// Validate Pulse Rate - ปกติ 60-120 bpm
  /// Critical: >120 หรือ <50
  /// Warning: 50-59
  (VitalStatus, String)? _validatePR(String? value) {
    if (value == null || value.isEmpty) return null;
    final pr = int.tryParse(value);
    if (pr == null) return null;

    if (pr > 120) return (VitalStatus.critical, 'เร็วมาก > 120');
    if (pr < 50) return (VitalStatus.critical, 'ช้ามาก < 50');
    if (pr >= 50 && pr < 60) return (VitalStatus.warning, 'ช้ากว่าปกติ');
    return null; // ปกติ
  }

  /// Validate DTX (น้ำตาลปลายนิ้ว) - ปกติ 70-140 mg/dl
  /// Critical: <60 หรือ >180
  /// Warning: 60-69 หรือ 141-180
  (VitalStatus, String)? _validateDTX(String? value) {
    if (value == null || value.isEmpty) return null;
    final dtx = int.tryParse(value);
    if (dtx == null) return null;

    if (dtx < 60) return (VitalStatus.critical, 'น้ำตาลต่ำมาก < 60');
    if (dtx > 180) return (VitalStatus.critical, 'สูงมาก > 180');
    if (dtx >= 60 && dtx < 70) return (VitalStatus.warning, 'น้ำตาลต่ำ');
    if (dtx > 140 && dtx <= 180) return (VitalStatus.warning, 'สูงกว่าปกติ');
    return null; // ปกติ
  }

  /// Validate จำนวนวันท้องผูก - ≥ 3 วันถือว่าท้องผูก
  (VitalStatus, String)? _validateConstipation(String? value) {
    if (value == null || value.isEmpty) return null;
    final days = double.tryParse(value);
    if (days == null) return null;

    if (days >= 5) return (VitalStatus.critical, 'ท้องผูกรุนแรง');
    if (days >= 3) return (VitalStatus.warning, 'ท้องผูก');
    return null; // ปกติ
  }

  // ==========================================
  // Formatting Functions
  // ==========================================

  /// Format DateTime สำหรับแสดงผล
  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
  }

  /// Format Date สำหรับแสดงผล (ไม่มีเวลา)
  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  /// สร้างข้อความรายงานจริงที่จะส่งให้ญาติ
  /// Replicate logic จาก SQL view: formatted_vital_signs
  String _buildFormattedReport({
    required String residentName,
    required VitalSignFormState formState,
    required String? userFullName,
    required String? userNickname,
  }) {
    final buffer = StringBuffer();

    // Header: ชื่อผู้สูงอายุ
    buffer.writeln('#$residentName');

    // Shift info (ถ้าเป็น full report)
    if (formState.isFullReport) {
      if (formState.shift == 'เวรเช้า') {
        buffer.writeln(
            'เวรเช้า (ของวันที่ ${_formatDate(formState.selectedDateTime)}) ');
        buffer.writeln('ตั้งแต่ 07.00 - 19.00 น.');
      } else {
        // เวรดึก: วันที่ = วันก่อนหน้า
        final prevDay =
            formState.selectedDateTime.subtract(const Duration(days: 1));
        buffer.writeln('เวรดึก (ของวันที่ ${_formatDate(prevDay)}) ');
        buffer.writeln('ตั้งแต่ 19.00 - 07.00 น.');
      }
      buffer.writeln();
    }

    // สัญญาณชีพ
    buffer.writeln('สัญญาณชีพ');
    if (formState.temp?.isNotEmpty == true) {
      buffer.writeln('T = ${formState.temp} °C');
    }
    if (formState.pr?.isNotEmpty == true) {
      buffer.writeln('P = ${formState.pr} bpm');
    }
    if (formState.rr?.isNotEmpty == true) {
      buffer.writeln('R = ${formState.rr} /min');
    }
    if (formState.sBP?.isNotEmpty == true && formState.dBP?.isNotEmpty == true) {
      buffer.writeln('BP = ${formState.sBP}/${formState.dBP} mmHg');
    }
    if (formState.o2?.isNotEmpty == true) {
      buffer.writeln('O2sat = ${formState.o2} %');
    }

    // กิจกรรมดูแล (ถ้า full report)
    if (formState.isFullReport) {
      buffer.writeln();
      buffer.writeln('🍃ปริมาณน้ำเข้า: ${formState.input ?? ""}');
      buffer.writeln('🍃ปริมาณน้ำออก (โดยประมาณ): ${formState.output ?? ""}');
      buffer.writeln(
          '🍃การขับถ่าย = ${formState.defecation == true ? "อุจจาระ" : "ไม่อุจจาระ"}');
      buffer.writeln(
          '🍃นับรวมจำนวนวันที่ไม่ได้ถ่าย ${formState.constipation ?? "0"} วัน');

      if (formState.napkin?.isNotEmpty == true) {
        final napkinValue = int.tryParse(formState.napkin!) ?? 0;
        if (napkinValue > 0) {
          buffer.writeln('🍃ใช้ผ้าอ้อมจำนวน ${formState.napkin} ผืน');
        }
      }

      if (formState.dtx?.isNotEmpty == true) {
        final dtxValue = int.tryParse(formState.dtx!) ?? 0;
        if (dtxValue > 0) {
          buffer.writeln('🍃ค่าน้ำตาลปลายนิ้ว = ${formState.dtx} mg/dl');
        }
      }

      if (formState.insulin?.isNotEmpty == true) {
        final insulinValue = int.tryParse(formState.insulin!) ?? 0;
        if (insulinValue > 0) {
          buffer.writeln('🍃ฉีดอินซูลิน = ${formState.insulin} unit');
        }
      }
    }

    // การประเมิน (ถ้า full report)
    if (formState.isFullReport && formState.ratings.isNotEmpty) {
      buffer.writeln();

      // Sort ratings by subject id (เหมือน SQL view)
      final sortedRatings = formState.ratings.values.toList()
        ..sort((a, b) => a.subjectId.compareTo(b.subjectId));

      for (final rating in sortedRatings) {
        if (rating.rating != null) {
          final choiceText = rating.selectedChoiceText ?? '';
          buffer.writeln(
              '- ${rating.subjectName}: ${rating.rating} คะแนน ($choiceText)');

          if (rating.description?.isNotEmpty == true) {
            buffer.writeln('* ${rating.description}');
          }
        }
      }
    }

    // General Report
    if (formState.isFullReport) {
      final report =
          formState.shift == 'เวรเช้า' ? formState.reportD : formState.reportN;
      if (report?.isNotEmpty == true && report != '-') {
        buffer.writeln();
        buffer.writeln(report);
      }
    }

    // Footer
    buffer.writeln();
    final fullName = userFullName ?? '';
    final nickname = userNickname ?? '';
    buffer.writeln('👧ผู้ดูแล $fullName ($nickname)');
    buffer.writeln(_formatDateTime(formState.selectedDateTime));
    buffer.writeln('❤️THANK YOU🙏');

    return buffer.toString();
  }
}
