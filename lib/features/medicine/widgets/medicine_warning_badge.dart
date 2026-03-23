import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/theme/app_colors.dart';
import '../models/medicine_warning.dart';

/// Badge เตือนประเด็นยา — ติดข้างชื่อยาใน MedicineCard
/// 3 ระดับ:
/// - critical (แดง) = ยาอันตรายสูง (warfarin, insulin, opioids ฯลฯ)
/// - warning (ส้ม) = ยาซ้ำซ้อน (generic name เดียวกัน)
/// - info (ฟ้า) = ยากลุ่มเดียวกัน (ATC Level 2 เดียวกัน)
///
/// กดที่ badge → เปิด BottomSheet แสดงรายละเอียดเป็นภาษาไทยง่ายๆ
class MedicineWarningBadge extends StatelessWidget {
  final List<MedicineWarning> warnings;
  final VoidCallback? onTap;

  const MedicineWarningBadge({
    super.key,
    required this.warnings,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    // ใช้ severity สูงสุดเป็นตัวแทน (critical > warning > info)
    final highestSeverity = _getHighestSeverity();
    final config = _badgeConfig(highestSeverity);

    return GestureDetector(
      onTap: onTap ?? () => _showWarningDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: config.bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: config.icon, size: 10, color: config.textColor),
            const SizedBox(width: 2),
            Text(
              config.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: config.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// หา severity สูงสุดจาก warnings ทั้งหมด
  String _getHighestSeverity() {
    if (warnings.any((w) => w.severity == 'critical')) return 'critical';
    if (warnings.any((w) => w.severity == 'warning')) return 'warning';
    return 'info';
  }

  /// config สี + icon + label ตาม severity
  _BadgeConfig _badgeConfig(String severity) {
    switch (severity) {
      case 'critical':
        return _BadgeConfig(
          bgColor: AppColors.tagFailedBg,
          textColor: AppColors.tagFailedText,
          icon: HugeIcons.strokeRoundedAlert02,
          label: 'ยาอันตรายสูง',
        );
      case 'warning':
        return _BadgeConfig(
          bgColor: AppColors.tagPendingBg,
          textColor: AppColors.tagPendingText,
          icon: HugeIcons.strokeRoundedAlert01,
          label: 'ประเด็นยา',
        );
      default: // info
        return _BadgeConfig(
          bgColor: const Color(0xFFE3F2FD),
          textColor: const Color(0xFF1565C0),
          icon: HugeIcons.strokeRoundedInformationCircle,
          label: 'ประเด็นยา',
        );
    }
  }

  /// แสดง BottomSheet อธิบายประเด็นยาเป็นภาษาไทยง่ายๆ
  /// ออกแบบให้ผู้ช่วยพยาบาลที่จบ ม.3 เข้าใจได้
  void _showWarningDetails(BuildContext context) {
    final highestSeverity = _getHighestSeverity();
    final config = _badgeConfig(highestSeverity);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ให้ sheet ขยายตาม content + scroll ได้บนจอเล็ก
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => ConstrainedBox(
        // จำกัดความสูงไม่เกิน 60% ของหน้าจอ
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Row(
              children: [
                HugeIcon(icon: config.icon, color: config.textColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  highestSeverity == 'critical'
                      ? 'ยาที่ต้องระวังเป็นพิเศษ'
                      : 'มีประเด็นที่ต้องตรวจสอบ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: config.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Warning list — ข้อความภาษาไทยง่ายๆ
            // ใช้ Set เพื่อไม่แสดงซ้ำ (A→B และ B→A เป็นเรื่องเดียวกัน)
            ..._getUniqueDisplayMessages().map((msg) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '• $msg',
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                )),

            const SizedBox(height: 8),
          ],
        ),
        ),
      ),
    );
  }

  /// ดึงข้อความ display ไม่ซ้ำ (dedup A→B / B→A)
  List<String> _getUniqueDisplayMessages() {
    final seen = <String>{};
    final messages = <String>[];
    for (final w in warnings) {
      final msg = w.displayMessage;
      if (!seen.contains(msg)) {
        seen.add(msg);
        messages.add(msg);
      }
    }
    return messages;
  }
}

/// Config สำหรับ badge styling
class _BadgeConfig {
  final Color bgColor;
  final Color textColor;
  final dynamic icon;
  final String label;

  _BadgeConfig({
    required this.bgColor,
    required this.textColor,
    required this.icon,
    required this.label,
  });
}
