// MicButton — ปุ่มไมค์สำหรับใส่ใน TextField / TextFormField
//
// UX:
//   - Tap → ขอ consent (ครั้งแรก) → เปิด bottom sheet ที่จัดการ recording/processing
//   - Bottom sheet แสดง: pulsing mic, elapsed time, ปุ่มยกเลิก/หยุด
//   - หยุด → ถอดเสียง → insert ข้อความที่ cursor → ปิด sheet
//
// Logic ทั้งหมด (recording, transcribing, insert) อยู่ใน SttRecordingSheet
// MicButton เป็นแค่ trigger + icon
//
// Usage:
// ```dart
// MicButton(
//   controller: myTextController,
//   context: SttContext.post,
//   nursinghomeId: 1,
// )
// ```

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../services/stt_service.dart';
import '../theme/app_colors.dart';
import 'stt_consent_dialog.dart';
import 'stt_recording_sheet.dart';

class MicButton extends ConsumerWidget {
  /// TextField controller ที่จะ insert transcript เข้าไป
  final TextEditingController controller;

  /// Context ของ STT — กำหนด cleanup rules ที่ backend
  final SttContext context;

  /// nursinghome_id ใช้ดึงรายชื่อ resident → bias Gemini ถอดชื่อถูก
  /// ถ้า 0 หรือ null → ไม่ใช้ resident context
  final int? nursinghomeId;

  /// resident_id — ถ้ารู้ว่ากำลังพูดถึงคนไหน (เช่นหน้า vital sign, tagged post)
  /// backend จะดึงข้อมูลคนนั้น (อายุ, เพศ, โรคประจำตัว) มาเป็น context เพิ่ม
  final int? residentId;

  /// Callback หลัง transcript ถูก insert เข้าช่อง (optional)
  /// ใช้ในกรณีที่ parent ต้องรู้ว่ามีข้อความใหม่ (เช่น notify onChanged ของ TextField)
  final VoidCallback? onTranscribed;

  /// ขนาดปุ่ม (default 40)
  final double size;

  const MicButton({
    super.key,
    required this.controller,
    required this.context,
    this.nursinghomeId,
    this.residentId,
    this.onTranscribed,
    this.size = 40,
  });

  Future<void> _onTap(BuildContext ctx) async {
    // 1. ขอ consent ครั้งแรก
    final agreed = await SttConsentDialog.showIfNeeded(ctx);
    if (!agreed || !ctx.mounted) return;

    // 2. เปิด bottom sheet — ภายใน sheet จะเริ่มอัดอัตโนมัติ
    await showSttRecordingSheet(
      context: ctx,
      controller: controller,
      sttContext: context,
      nursinghomeId: (nursinghomeId ?? 0) > 0 ? nursinghomeId : null,
      residentId: (residentId ?? 0) > 0 ? residentId : null,
      onTranscribed: onTranscribed,
    );
  }

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onTap(ctx),
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.1),
          ),
          child: Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedMic01,
              size: size * 0.5,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
