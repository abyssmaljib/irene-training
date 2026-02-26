import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/buttons.dart';
import '../../providers/vital_sign_form_provider.dart';

/// ปุ่มเล็กสำหรับเรียก AI สรุปรายงานเวร
/// ออกแบบให้วางไว้มุมบนขวาของ card "มีรายงานเพิ่มเติมมั้ย?"
/// กดแล้วจะแสดง modal ยืนยันก่อนเรียก AI
class AiShiftSummaryButton extends ConsumerWidget {
  const AiShiftSummaryButton({
    super.key,
    required this.residentId,
    required this.residentName,
  });

  final int residentId;
  final String residentName;

  /// แสดง modal ยืนยันก่อนเรียก AI สรุปเวร
  /// ใช้ design pattern เดียวกับ ConfirmDialog ของโปรเจค
  /// (icon วงกลม → title → รูปแมว → เนื้อหา → ปุ่ม)
  Future<bool> _showConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // ใช้ AppRadius.largeRadius (24px) ตามแบบ dialog อื่นๆ ในโปรเจค
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.largeRadius,
        ),
        backgroundColor: AppColors.surface,
        contentPadding: EdgeInsets.zero,
        content: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: AppSpacing.lg),

              // Icon วงกลม (ด้านบน) — ตาม pattern ConfirmDialog
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMagicWand01,
                    color: AppColors.primary,
                    size: AppIconSize.lg,
                  ),
                ),
              ),

              SizedBox(height: AppSpacing.sm),

              // Title
              Text(
                'น้องไอรีนน์ช่วยสรุปเวร',
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: AppSpacing.xs),

              // รูปแมว — ตาม pattern ConfirmDialog
              Image.asset(
                'assets/images/confirm_cat.webp',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),

              SizedBox(height: AppSpacing.xs),

              // เนื้อหาอธิบาย (แทน message ปกติ ใช้เป็น numbered list)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    // ข้อ 1: อธิบายว่า AI ดูข้อมูลอะไรบ้าง
                    _buildInfoItem(
                      number: '1',
                      text:
                          'น้องไอรีนน์จะดูจากความเคลื่อนไหวทั้งหมดในเวรปัจจุบัน และสัญญาณชีพกับคะแนนที่น้องกรอกเข้ามา เท่านั้น',
                    ),
                    SizedBox(height: AppSpacing.sm),
                    // ข้อ 2: AI จะเอาข้อความที่ NA พิมพ์ไว้ไปปรับปรุงด้วย
                    _buildInfoItem(
                      number: '2',
                      text:
                          'น้องไอรีนน์จะปรับปรุงข้อความที่น้องพิมพ์ไว้ในช่องรายงานด้วยนะ',
                    ),
                    SizedBox(height: AppSpacing.sm),
                    // ข้อ 3: เตือนว่าจะเขียนทับข้อความเดิม
                    _buildInfoItem(
                      number: '3',
                      text:
                          'ถ้ากดตกลง น้องไอรีนน์จะวางทับข้อความที่เขียนอยู่นะ',
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.md),

              // ปุ่มยกเลิก + ตกลง — ใช้ SecondaryButton / PrimaryButton ตาม core widgets
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    // ยกเลิก (Secondary)
                    Expanded(
                      child: SecondaryButton(
                        text: 'ยกเลิก',
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    // ตกลง (Primary) — เรียก AI สรุป
                    Expanded(
                      child: PrimaryButton(
                        text: 'ตกลง',
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  /// สร้างแต่ละข้อในรายการอธิบาย (เลขลำดับ + ข้อความ)
  Widget _buildInfoItem({required String number, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // วงกลมแสดงเลขลำดับ
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // ข้อความอธิบาย
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.secondaryText,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(vitalSignFormProvider(residentId));

    return formState.when(
      loading: () => const SizedBox.shrink(),
      // แสดง error แทน SizedBox.shrink() เพื่อให้ user รู้ว่าเกิดข้อผิดพลาด
      error: (error, _) => ErrorStateWidget(
        message: 'โหลดข้อมูลไม่สำเร็จ',
        compact: true,
        onRetry: () => ref.invalidate(vitalSignFormProvider(residentId)),
      ),
      data: (data) {
        final isLoading = data.isLoadingAI;

        // ขณะโหลด: แสดง spinner + ข้อความสถานะแทนปุ่ม
        if (isLoading) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'กำลังสรุป...',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        }

        // ปุ่มปกติ: ขนาดเล็ก แสดง icon + ข้อความ
        return InkWell(
          onTap: () async {
            // แสดง modal ยืนยันก่อน
            final confirmed = await _showConfirmationDialog(context);
            if (!confirmed) return;

            // ดึง nursinghome_id ของ user ปัจจุบัน แล้วเรียก AI สรุปเวร
            final nursinghomeId =
                await UserService().getNursinghomeId() ?? 1;
            ref
                .read(vitalSignFormProvider(residentId).notifier)
                .generateAIShiftSummary(
                  residentName: residentName,
                  nursinghomeId: nursinghomeId,
                );
          },
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // icon magic wand
                HugeIcon(
                  icon: HugeIcons.strokeRoundedMagicWand01,
                  size: AppIconSize.sm,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                // ข้อความปุ่ม
                Text(
                  'AI ปรับปรุงข้อความ',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
