import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../profile_setup/providers/profile_setup_provider.dart';
import '../../profile_setup/screens/unified_profile_setup_screen.dart';

/// Card ชวน user กรอกข้อมูลโปรไฟล์ให้ครบ
/// แสดงใน Home screen เมื่อยังกรอกไม่ครบทั้ง 5 sections (required)
/// - Section 1: ข้อมูลพื้นฐาน (ชื่อ, ชื่อเล่น, เพศ, วันเกิด, น้ำหนัก, ส่วนสูง)
/// - Section 2: ข้อมูลติดต่อ (บัตรประชาชน, ที่อยู่, เบอร์โทร)
/// - Section 3: วุฒิการศึกษาและทักษะ
/// - Section 4: การเงิน (ธนาคาร, เลขบัญชี, หน้าบุ๊คแบงค์)
/// - Section 5: เอกสาร (สำเนาบัตรประชาชน, วุฒิบัตร)
///
/// Design:
/// - พื้นหลัง gradient สีอ่อน
/// - Progress bar แสดงเปอร์เซ็นต์
/// - ปุ่ม "กรอกเพิ่ม" ไปหน้า UnifiedProfileSetupScreen
class ProfileCompletionCard extends ConsumerWidget {
  const ProfileCompletionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionAsync = ref.watch(profileCompletionStatusProvider);

    return completionAsync.when(
      // กำลังโหลด - ไม่แสดงอะไร
      loading: () => const SizedBox.shrink(),
      // แสดง error แทน SizedBox.shrink() เพื่อให้ user รู้ว่าเกิดข้อผิดพลาด
      error: (error, _) => ErrorStateWidget(
        message: 'โหลดข้อมูลโปรไฟล์ไม่สำเร็จ',
        compact: true,
        onRetry: () => ref.invalidate(profileCompletionStatusProvider),
      ),
      // มีข้อมูล
      data: (status) {
        // ถ้ากรอกครบแล้ว ไม่ต้องแสดง card
        if (status.isComplete) {
          return const SizedBox.shrink();
        }

        return _buildCard(context, ref, status);
      },
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, ProfileCompletionStatus status) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        // Gradient พื้นหลังสีอ่อน
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // ไปหน้า Profile Setup และ refresh เมื่อกลับมา
            await Navigator.push(
              context,
              // showAsOnboarding: false → ไม่มี header gradient, มีปุ่มกลับ
              MaterialPageRoute(builder: (_) => const UnifiedProfileSetupScreen()),
            );
            // Refresh ข้อมูลเมื่อกลับมา เพื่ออัพเดทสถานะ completion
            ref.invalidate(profileCompletionStatusProvider);
          },
          borderRadius: AppRadius.mediumRadius,
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row - icon + title + arrow
                Row(
                  children: [
                    // Icon container
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: AppRadius.smallRadius,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedUserEdit01,
                        color: AppColors.primary,
                        size: AppIconSize.lg,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    // Title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'กรอกโปรไฟล์ให้ครบ',
                            style: AppTypography.label.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                          Text(
                            _getSubtitle(status),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Arrow
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      color: AppColors.primary,
                      size: AppIconSize.md,
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),

                // Progress bar
                _buildProgressBar(status),
                SizedBox(height: AppSpacing.sm),

                // Progress text - แสดงจำนวน section ที่ครบ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Completion status
                    Text(
                      '${status.completedSections}/5 ส่วนเสร็จสิ้น',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    // Percent text
                    Text(
                      '${status.completionPercent}%',
                      style: AppTypography.label.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// สร้าง progress bar แสดงเปอร์เซ็นต์ความสมบูรณ์
  Widget _buildProgressBar(ProfileCompletionStatus status) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.alternate,
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Progress fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: constraints.maxWidth * (status.completionPercent / 100),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// สร้าง subtitle ตามจำนวน section ที่ยังไม่ครบ
  String _getSubtitle(ProfileCompletionStatus status) {
    final incomplete = status.incompleteCount;
    if (incomplete >= 4) {
      return 'เริ่มกรอกข้อมูลเพื่อใช้งานแอปได้เต็มที่';
    } else if (incomplete >= 2) {
      return 'เหลืออีก $incomplete ส่วน';
    } else if (incomplete == 1) {
      return 'เหลืออีก 1 ส่วนสุดท้าย!';
    }
    return 'กรอกข้อมูลเพิ่มเติม';
  }
}
