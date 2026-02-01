import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// รายการวุฒิบัตร/ประกาศนียบัตร ด้านการบริบาล
/// ตรงกับ Google Form สำหรับสมัครงาน
const List<Map<String, String>> careCertifications = [
  {'value': 'none', 'label': 'ไม่มี (ผู้ดูแลทั่วไป)'},
  {'value': 'CG', 'label': 'ผู้ช่วยเหลือดูแลผู้สูงอายุ (CG)'},
  {'value': 'NA', 'label': 'เจ้าหน้าที่บริบาล (NA)'},
  {'value': 'PN', 'label': 'ผู้ช่วยพยาบาล (PN)'},
  {'value': 'RN', 'label': 'พยาบาล (RN)'},
  {'value': 'PT', 'label': 'นักกายภาพบำบัด (PT)'},
  {'value': 'TCM', 'label': 'แพทย์แผนจีน (TCM)'},
  {'value': 'nutritionist', 'label': 'นักโภชนาการ'},
  {'value': 'housekeeper', 'label': 'แม่บ้าน/แม่ครัว'},
  {'value': 'ST', 'label': 'นักอรรถบำบัด'},
  {'value': 'OT', 'label': 'นักกิจกรรมบำบัด'},
  {'value': 'MD', 'label': 'แพทย์ (MD)'},
];

/// Dropdown สำหรับเลือกวุฒิบัตรด้านการบริบาล
/// มี style ตรงกับ design system ของแอป
class CertificationDropdown extends StatelessWidget {
  /// ค่าที่เลือกอยู่ (value ไม่ใช่ label)
  final String? value;

  /// Callback เมื่อเลือกค่าใหม่
  final ValueChanged<String?> onChanged;

  /// Label แสดงด้านบน
  final String? label;

  /// Hint text เมื่อยังไม่เลือก
  final String hintText;

  /// มี error หรือไม่
  final bool hasError;

  /// Error message
  final String? errorText;

  /// Disabled state
  final bool enabled;

  /// แสดง required asterisk (*) หรือไม่
  final bool isRequired;

  const CertificationDropdown({
    super.key,
    this.value,
    required this.onChanged,
    this.label,
    this.hintText = 'เลือกวุฒิบัตร',
    this.hasError = false,
    this.errorText,
    this.enabled = true,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label พร้อม required asterisk
        if (label != null) ...[
          Row(
            children: [
              Text(
                label!,
                style: AppTypography.label.copyWith(
                  color: hasError ? AppColors.error : AppColors.primaryText,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: AppTypography.label.copyWith(
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
          AppSpacing.verticalGapXs,
        ],

        // Dropdown
        Container(
          decoration: BoxDecoration(
            color: enabled ? AppColors.primaryBackground : AppColors.alternate,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError
                  ? AppColors.error
                  : (enabled ? Colors.transparent : AppColors.alternate),
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Row(
                children: [
                  // Icon วุฒิบัตร
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCertificate01,
                    color: AppColors.secondaryText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    hintText,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              isExpanded: true,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                color: enabled ? AppColors.secondaryText : AppColors.alternate,
                size: 20,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Colors.white,
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 14,
              ),
              // แสดง icon + label เมื่อเลือกแล้ว
              selectedItemBuilder: (context) {
                return careCertifications.map((cert) {
                  return Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCertificate01,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          cert['label']!,
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
              onChanged: enabled ? onChanged : null,
              items: careCertifications.map((cert) {
                return DropdownMenuItem<String>(
                  value: cert['value'],
                  child: Text(cert['label']!),
                );
              }).toList(),
            ),
          ),
        ),

        // Error text
        if (errorText != null && hasError) ...[
          AppSpacing.verticalGapXs,
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlertCircle,
                color: AppColors.error,
                size: 14,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Helper function เพื่อ get label จาก value
String? getCertificationLabel(String? value) {
  if (value == null) return null;
  final cert = careCertifications.firstWhere(
    (c) => c['value'] == value,
    orElse: () => {'value': '', 'label': ''},
  );
  return cert['label']!.isNotEmpty ? cert['label'] : null;
}

/// Helper function เพื่อ normalize certification value
/// รองรับกรณีที่ database เก็บเป็น label แทน value code
/// เช่น "ผู้ช่วยเหลือดูแลผู้สูงอายุ (CG)" → "CG"
String? normalizeCertificationValue(String? rawValue) {
  if (rawValue == null || rawValue.isEmpty) return null;

  // ถ้าเป็น value code อยู่แล้ว ส่งกลับเลย
  final isValidCode = careCertifications.any((c) => c['value'] == rawValue);
  if (isValidCode) return rawValue;

  // ถ้าเป็น label ให้หา value code
  final matchByLabel = careCertifications.firstWhere(
    (c) => c['label'] == rawValue,
    orElse: () => {'value': '', 'label': ''},
  );
  if (matchByLabel['value']!.isNotEmpty) return matchByLabel['value'];

  // ถ้าเป็น label บางส่วน (เช่น มีแค่ชื่อย่อในวงเล็บ)
  // ลองหาจาก pattern (XX) ใน string
  final codeMatch = RegExp(r'\(([A-Z]{2,3})\)').firstMatch(rawValue);
  if (codeMatch != null) {
    final extractedCode = codeMatch.group(1);
    final matchByCode = careCertifications.firstWhere(
      (c) => c['value'] == extractedCode,
      orElse: () => {'value': '', 'label': ''},
    );
    if (matchByCode['value']!.isNotEmpty) return matchByCode['value'];
  }

  // ไม่เจอ - return null เพื่อให้ user เลือกใหม่
  return null;
}
