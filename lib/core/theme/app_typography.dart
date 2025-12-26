import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Irene Plus Typography
/// Design System - Anuphan
///
/// เลือก Anuphan เพราะ:
/// - Loopless version ของ IBM Plex Thai โดย Cadson Demak
/// - Soft, friendly แต่ยังคง minimal และ professional
/// - Thai และ Latin weight สม่ำเสมอกัน
/// - มี weights ครบ: 100-700
/// - Open source (SIL OFL), ใช้เชิงพาณิชย์ได้
///
/// Download: https://fonts.google.com/specimen/Anuphan
///
/// pubspec.yaml:
/// fonts:
///   - family: Anuphan
///     fonts:
///       - asset: assets/fonts/Anuphan-Regular.ttf
///         weight: 400
///       - asset: assets/fonts/Anuphan-Medium.ttf
///         weight: 500
///       - asset: assets/fonts/Anuphan-SemiBold.ttf
///         weight: 600
///       - asset: assets/fonts/Anuphan-Bold.ttf
///         weight: 700
///
class AppTypography {
  static const String fontFamily = 'Anuphan';

  // ===========================================
  // HEADINGS
  // ===========================================

  // Heading 1 - 32px, SemiBold
  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.5,
  );

  // Heading 2 - 24px, SemiBold
  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.3,
  );

  // Heading 3 - 20px, SemiBold
  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // ===========================================
  // TITLES & SUBTITLES
  // ===========================================

  // Title - 16px, SemiBold
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // Subtitle - 14px, Medium
  static const TextStyle subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // ===========================================
  // BODY TEXT
  // ===========================================

  // Body Large - 16px, Regular
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // Body - 14px, Regular
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // Body Small - 12px, Regular
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // ===========================================
  // UI ELEMENTS
  // ===========================================

  // Button - 14px, SemiBold
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
  );

  // Button Small - 12px, SemiBold
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
  );

  // Label - 12px, Medium
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Caption - 11px, Regular
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Overline - 10px, Medium, Uppercase
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
    letterSpacing: 0.8,
  );

  // ===========================================
  // HELPER METHODS
  // ===========================================

  /// สร้าง style ที่เน้น (bold) จาก style ที่มีอยู่
  static TextStyle emphasized(TextStyle style) {
    return style.copyWith(fontWeight: FontWeight.w600);
  }

  /// สร้าง style สำหรับ link
  static TextStyle link(TextStyle style, {Color? color}) {
    return style.copyWith(
      color: color ?? AppColors.primary,
      decoration: TextDecoration.underline,
    );
  }

  /// สร้าง style สำหรับ error text
  static TextStyle error(TextStyle style) {
    return style.copyWith(color: AppColors.error);
  }

  /// สร้าง style สำหรับ success text
  static TextStyle success(TextStyle style) {
    return style.copyWith(color: AppColors.success);
  }
}
