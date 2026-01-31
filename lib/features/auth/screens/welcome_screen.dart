import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../widgets/login_bottom_sheet.dart';
import 'invitation_screen.dart';

/// หน้า Welcome Screen - หน้าแรกที่แสดงให้ผู้ใช้ที่ยังไม่ได้ล็อกอิน
/// แสดงรูป mascot และปุ่มสำหรับสมัครสมาชิกหรือเข้าสู่ระบบ
///
/// เมื่อเปิด bottom sheet จะเปลี่ยนรูปเป็น feeding_cat
/// เมื่อปิด bottom sheet จะกลับเป็น wheel_chair_cat2
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // รูป mascot ที่แสดง - เปลี่ยนเมื่อเปิด/ปิด bottom sheet
  bool _isBottomSheetOpen = false;

  /// เปิด bottom sheet และเปลี่ยนรูป
  Future<void> _showLoginBottomSheet() async {
    // เปลี่ยนรูปเป็น feeding_cat
    setState(() => _isBottomSheetOpen = true);

    // เปิด bottom sheet และรอให้ปิด
    await LoginBottomSheet.show(context);

    // กลับมาเป็นรูปเดิมเมื่อปิด bottom sheet
    if (mounted) {
      setState(() => _isBottomSheetOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              // Spacer ด้านบน - ดัน content ลงมาตรงกลาง
              const Spacer(flex: 1),

              // Title "เข้าสู่ระบบ" - แสดงด้านบนรูปเมื่อเปิด bottom sheet
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: _isBottomSheetOpen
                    ? Column(
                        children: [
                          Text(
                            'เข้าสู่ระบบ',
                            style: AppTypography.heading1.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: AppSpacing.lg),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),

              // รูป mascot - เปลี่ยนตาม state
              // flex: 4 ตอนปกติ (รูปใหญ่), flex: 1 ตอน login (รูปเล็กลงให้มีที่สำหรับ form)
              Flexible(
                flex: _isBottomSheetOpen ? 1 : 4,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // ใช้ความสูงสูงสุดที่มี หรือ 400 ถ้าไม่มีข้อจำกัด
                    final maxHeight = constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : 400.0;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      // ใช้ scale + fade transition ให้ดู hero-like
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.8, end: 1.0)
                                .animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack,
                            )),
                            child: child,
                          ),
                        );
                      },
                      child: Image.asset(
                        _isBottomSheetOpen
                            ? 'assets/images/login/feeding_cat.webp'
                            : 'assets/images/login/wheel_chair_cat2.webp',
                        key: ValueKey(_isBottomSheetOpen),
                        height: maxHeight,
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
              ),

              // Title + Description - แสดงด้านล่างรูปเมื่อปิด bottom sheet
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: _isBottomSheetOpen
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          SizedBox(height: AppSpacing.xl),
                          Text(
                            'ยินดีต้อนรับสู่ ไอรีนน์',
                            style: AppTypography.heading1.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            'แอพสำหรับเรียนรู้ สื่อสาร และทำงานที่\nไอรีนน์ เนอร์สซิ่งโฮม',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),

              // Spacer ด้านล่าง - ดันปุ่มไปด้านล่าง
              const Spacer(flex: 2),

              // ปุ่ม "เข้าสู่ระบบ" - สำหรับผู้ใช้ที่มีบัญชีอยู่แล้ว
              // แสดง Bottom Sheet สำหรับ login ด้วย email + password หรือ OTP
              PrimaryButton(
                text: 'เข้าสู่ระบบ',
                width: double.infinity,
                onPressed: _showLoginBottomSheet,
              ),

              SizedBox(height: AppSpacing.md),

              // ปุ่ม "ค้นหาคำเชิญ" - สำหรับผู้ใช้ใหม่ที่มีคำเชิญ
              // ไปหน้า InvitationScreen เพื่อค้นหาคำเชิญด้วยอีเมล
              SecondaryButton(
                text: 'ค้นหาคำเชิญ',
                width: double.infinity,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvitationScreen(),
                    ),
                  );
                },
              ),

              SizedBox(height: AppSpacing.xl),

              // Logo + Copyright
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo เล็กๆ
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/app_icon.png',
                      height: 20,
                      width: 20,
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    '© 2025 Irene Plus',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
