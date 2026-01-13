import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/tutorial_target.dart';

/// Service สำหรับจัดการ Tutorial Coach Mark
/// ใช้ highlight widgets และแสดง tooltip อธิบายการใช้งาน
///
/// ใช้งาน:
/// ```dart
/// final tutorialService = TutorialService();
/// tutorialService.startTutorial(
///   context: context,
///   targets: [...],
///   onNavigate: (tabIndex) => setState(() => _currentTab = tabIndex),
///   onFinish: () => onboardingService.markTutorialCompleted(userId),
/// );
/// ```
class TutorialService {
  /// TutorialCoachMark instance
  TutorialCoachMark? _tutorialCoachMark;

  /// ตรวจสอบว่า tutorial กำลังแสดงอยู่หรือไม่
  bool get isShowing => _tutorialCoachMark != null;

  /// เริ่ม tutorial พร้อม targets และ callbacks
  ///
  /// Parameters:
  /// - [context]: BuildContext สำหรับแสดง overlay
  /// - [targets]: List ของ TutorialTarget ที่จะแสดง
  /// - [onNavigate]: Callback เมื่อต้อง navigate ไป tab อื่น
  /// - [onFinish]: Callback เมื่อ tutorial จบ (ไม่ว่าจะดูจบหรือ skip)
  /// - [onSkip]: Callback เมื่อ user กด skip (optional)
  void startTutorial({
    required BuildContext context,
    required List<TutorialTarget> targets,
    required Function(int tabIndex) onNavigate,
    required VoidCallback onFinish,
    VoidCallback? onSkip,
  }) {
    // สร้าง TargetFocus list จาก TutorialTarget
    final targetFocusList = _createTargetFocusList(
      targets: targets,
      onNavigate: onNavigate,
    );

    // สร้าง TutorialCoachMark
    _tutorialCoachMark = TutorialCoachMark(
      targets: targetFocusList,
      // สี overlay (พื้นหลังมืด)
      colorShadow: Colors.black,
      // ความทึบของ overlay
      opacityShadow: 0.8,
      // Padding รอบ highlight
      paddingFocus: 10,
      // ซ่อน skip button ใน content (เราจะใส่เองใน tooltip)
      hideSkip: true,
      // Animation duration
      focusAnimationDuration: const Duration(milliseconds: 300),
      unFocusAnimationDuration: const Duration(milliseconds: 300),
      pulseAnimationDuration: const Duration(milliseconds: 750),
      // Pulse effect รอบ highlight
      pulseEnable: true,
      // Callbacks
      onFinish: () {
        _tutorialCoachMark = null;
        onFinish();
      },
      onSkip: () {
        _tutorialCoachMark = null;
        onSkip?.call();
        onFinish();
        return true; // Return true เพื่อยืนยันการ skip
      },
      onClickTarget: (target) {
        // ไม่ต้องทำอะไร - tutorial จะไป step ถัดไปอัตโนมัติ
      },
    );

    // แสดง tutorial
    _tutorialCoachMark!.show(context: context);
  }

  /// หยุด tutorial ที่กำลังแสดง
  void stopTutorial() {
    _tutorialCoachMark?.skip();
    _tutorialCoachMark = null;
  }

  /// สร้าง List ของ TargetFocus จาก TutorialTarget
  List<TargetFocus> _createTargetFocusList({
    required List<TutorialTarget> targets,
    required Function(int tabIndex) onNavigate,
  }) {
    return targets.map((target) {
      // ตรวจสอบว่า target มี key หรือไม่
      if (target.key == null) {
        debugPrint('Warning: TutorialTarget ${target.id} has no key');
        return null;
      }

      return TargetFocus(
        identify: target.id,
        keyTarget: target.key,
        // รูปร่างของ highlight
        shape: target.shape == TutorialShape.circle
            ? ShapeLightFocus.Circle
            : ShapeLightFocus.RRect,
        // Radius สำหรับ RRect
        radius: 12,
        // สีของ highlight border (ถ้าต้องการ)
        enableOverlayTab: true,
        enableTargetTab: true,
        // Content ที่แสดงใน tooltip
        contents: [
          TargetContent(
            align: target.contentPosition == ContentPosition.top
                ? ContentAlign.top
                : ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTooltipContent(
                target: target,
                controller: controller,
                onNavigate: onNavigate,
                isLast: targets.last.id == target.id,
              );
            },
          ),
        ],
      );
    }).whereType<TargetFocus>().toList();
  }

  /// สร้าง widget สำหรับ tooltip content
  Widget _buildTooltipContent({
    required TutorialTarget target,
    required TutorialCoachMarkController controller,
    required Function(int tabIndex) onNavigate,
    required bool isLast,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            target.title,
            style: AppTypography.title.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            target.description,
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip button
              TextButton(
                onPressed: () => controller.skip(),
                child: Text(
                  'ข้าม',
                  style: AppTypography.button.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),

              // Next/Finish button
              ElevatedButton(
                onPressed: () {
                  // ถ้าต้อง navigate ไป tab อื่นก่อน step ถัดไป
                  // หา target ถัดไปและ check navigateToTab
                  controller.next();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isLast ? 'เสร็จสิ้น' : 'ถัดไป',
                  style: AppTypography.button.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
