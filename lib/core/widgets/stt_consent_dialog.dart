// Consent dialog ครั้งแรกของการใช้ STT
//
// แสดงครั้งเดียวต่อ device (เก็บ flag ใน SharedPreferences)
// ถ้า user ยินยอม → ไม่เด้งอีก
// ถ้า user ปฏิเสธ → เด้งอีกครั้งครั้งหน้าที่กดไมค์
//
// PDPA disclosure:
//   - เสียงถูกส่งไป Groq (US) เพื่อแปลงเป็นข้อความ
//   - ไม่เก็บไฟล์เสียง/ข้อความไว้ในระบบ
//   - มีเพียง audit log (ใคร, เมื่อไหร่) สำหรับ rate limit + cost monitoring

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class SttConsentDialog {
  /// SharedPreferences key — bump version ถ้าต้องให้ user ยืนยันใหม่
  static const String _consentKey = 'stt_consent_v1';

  /// แสดง consent dialog ถ้ายังไม่เคยยินยอม
  /// - Return `true` ถ้าเคยยินยอมแล้ว หรือเพิ่งยินยอม
  /// - Return `false` ถ้า user ปฏิเสธ / ยกเลิก
  static Future<bool> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_consentKey) == true) return true;

    if (!context.mounted) return false;

    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // บังคับให้เลือกก่อน ปิดข้างไม่ได้
      builder: (ctx) => const _SttConsentDialogWidget(),
    );

    if (agreed == true) {
      await prefs.setBool(_consentKey, true);
      return true;
    }
    return false;
  }

  /// Reset consent (สำหรับ debug/test)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_consentKey);
  }
}

class _SttConsentDialogWidget extends StatelessWidget {
  const _SttConsentDialogWidget();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeRadius,
      ),
      backgroundColor: AppColors.surface,
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSpacing.lg),

            // Icon mic ด้านบน
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMic01,
                    color: AppColors.primary,
                    size: AppIconSize.lg,
                  ),
                ),
              ),
            ),

            SizedBox(height: AppSpacing.md),

            // Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'แปลงเสียงเป็นข้อความ',
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: AppSpacing.sm),

            // Body
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เสียงที่อัดจะถูกส่งไปประมวลผลที่ Groq (สหรัฐอเมริกา) เพื่อแปลงเป็นข้อความ',
                    style: AppTypography.body.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  _BulletRow(text: 'ไม่มีการเก็บไฟล์เสียงไว้ที่ใดทั้งสิ้น'),
                  SizedBox(height: AppSpacing.xs),
                  _BulletRow(text: 'ไม่มีการเก็บข้อความที่แปลงได้ไว้ในระบบ'),
                  SizedBox(height: AppSpacing.xs),
                  _BulletRow(text: 'มีเพียง log การใช้งาน (ใคร, เมื่อไหร่) เพื่อ audit'),
                ],
              ),
            ),

            SizedBox(height: AppSpacing.lg),

            // Buttons
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        side: BorderSide(color: AppColors.inputBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mediumRadius,
                        ),
                      ),
                      child: Text(
                        'ยกเลิก',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mediumRadius,
                        ),
                      ),
                      child: Text(
                        'ยินยอม',
                        style: AppTypography.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String text;
  const _BulletRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 8),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            color: AppColors.success,
            size: AppIconSize.sm,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
