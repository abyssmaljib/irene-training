import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../services/force_update_service.dart';
import 'buttons.dart';

/// Dialog บังคับให้ user update app
///
/// แสดงเมื่อ app version ต่ำกว่าที่กำหนดใน nursinghomes.app_version
/// User ไม่สามารถปิด dialog ได้ ต้องกดอัปเดตเท่านั้น
///
/// Features:
/// - ไม่สามารถปิดได้ด้วยปุ่ม back หรือกดนอก dialog
/// - แสดง version ปัจจุบัน
/// - ปุ่มอัปเดตจะเปิด Play Store หรือ App Store ตาม device
/// - ปุ่มถูก disable ระหว่างกำลังเปิด store (กัน double-tap)
class ForceUpdateDialog extends StatefulWidget {
  const ForceUpdateDialog({super.key});

  /// แสดง dialog บังคับ update
  ///
  /// ใช้ barrierDismissible: false เพื่อไม่ให้ปิด dialog ได้
  /// ใช้ PopScope เพื่อไม่ให้กดปุ่ม back ปิดได้
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false, // ไม่ให้กดนอก dialog ปิดได้
      barrierColor: Colors.black87, // ทำ background มืดกว่าปกติ
      builder: (context) => const ForceUpdateDialog(),
    );
  }

  @override
  State<ForceUpdateDialog> createState() => _ForceUpdateDialogState();
}

class _ForceUpdateDialogState extends State<ForceUpdateDialog> {
  // กัน double-tap ปุ่มอัปเดต
  bool _isOpening = false;

  @override
  Widget build(BuildContext context) {
    // PopScope แทน WillPopScope (deprecated)
    // canPop: false เพื่อไม่ให้กด back ปิดได้
    return PopScope(
      canPop: false, // ไม่ให้ pop ออกจาก dialog
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedDownload04,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ),

              SizedBox(height: AppSpacing.md),

              // Title
              Text(
                'กรุณาอัปเดตแอป',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.primaryText,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppSpacing.sm),

              // Description
              Text(
                'มีเวอร์ชันใหม่ของแอปพร้อมให้ดาวน์โหลดแล้ว\n'
                'กรุณาอัปเดตเพื่อใช้งานฟีเจอร์ใหม่และแก้ไขบั๊ก',
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppSpacing.sm),

              // Current version info
              FutureBuilder<String>(
                future: ForceUpdateService.instance.getCurrentVersion(),
                builder: (context, snapshot) {
                  final version = snapshot.data ?? '...';
                  return Text(
                    'เวอร์ชันปัจจุบัน: $version',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  );
                },
              ),

              SizedBox(height: AppSpacing.lg),

              // Update button - disable ระหว่างเปิด store กัน double-tap
              PrimaryButton(
                text: _isOpening ? 'กำลังเปิด...' : 'อัปเดตเลย',
                icon: HugeIcons.strokeRoundedDownload04,
                onPressed: _isOpening ? null : _handleUpdate,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// เปิด Store เมื่อกดปุ่มอัปเดต
  /// disable ปุ่มระหว่าง loading กัน double-tap
  Future<void> _handleUpdate() async {
    setState(() => _isOpening = true);

    try {
      final success = await ForceUpdateService.instance.openStore();

      if (!success && mounted) {
        // ถ้าเปิด store ไม่ได้ แสดง SnackBar แจ้ง
        // ใช้ try-catch เพราะ ScaffoldMessenger อาจหา Scaffold ไม่เจอ
        // (dialog อยู่บน overlay ไม่มี Scaffold ancestor)
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('ไม่สามารถเปิด Store ได้ กรุณาอัปเดตด้วยตนเอง'),
              backgroundColor: AppColors.error,
            ),
          );
        } catch (_) {
          // ถ้าไม่มี ScaffoldMessenger → ไม่แสดง snackbar (ไม่ crash)
          debugPrint('ForceUpdateDialog: ScaffoldMessenger not found');
        }
      }
    } finally {
      // enable ปุ่มกลับหลังเปิด store (ให้ user กดได้อีกถ้ากลับมา)
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }
}
