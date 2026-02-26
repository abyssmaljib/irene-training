import 'package:flutter/material.dart';

/// Irene Plus Color Palette
/// Based on Design System from Lovart
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF0D9488); // Teal
  static const Color secondary = Color(0xFF55B1C9); // Light Blue
  static const Color tertiary = Color(0xFFE689C4); // Pink
  static const Color alternate = Color.fromARGB(
    255,
    226,
    226,
    226,
  ); // Light Gray border

  // Background Colors
  static const Color background = Color(0xFFF1F4F8); // Light Gray
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color primaryBackground = Color(0xFFF1F4F8);
  static const Color secondaryBackground = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF13181F); // Dark
  static const Color textSecondary = Color(0xFF5B616D); // Gray
  static const Color primaryText = Color(0xFF13181F); // Alias
  static const Color secondaryText = Color(0xFF5B616D); // Alias

  // Status Colors
  static const Color success = Color(0xFF023618); // Green
  static const Color warning = Color(0xFFE67E22); // Orange (เข้มขึ้นจากเหลือง เห็นชัดกว่า)
  static const Color error = Color(0xFFC60031); // Red
  static const Color info = Color(0xFFFFFFFF); // White

  // Accents (with opacity)
  static const Color accent1 = Color(0x1A0D9488); // 10% Primary
  static const Color accent2 = Color(0x1A55B1C9); // 10% Secondary
  static const Color accent3 = Color(0x19E689C4); // 10% Tertiary
  static const Color accent4 = Color(0xFFFFFFFF); // White

  // Button States
  static const Color primaryHover = Color(0xFF0B7A70); // Darker Teal
  static const Color primaryFocused = Color(0xFF0D9488);
  static const Color primaryDisabled = Color(0xFFB0B0B0);

  // Input States
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color inputFocused = Color(0xFF0D9488);
  static const Color inputError = Color(0xFFC60031);

  // Tag/Badge Colors (Pastel - สบายตา)
  static const Color tagPassedBg = Color(0xFFE8F5E9); // Soft mint green
  static const Color tagPassedText = Color(0xFF2E7D4A); // Muted green
  static const Color tagPendingBg = Color(0xFFFFF8E7); // Soft cream yellow
  static const Color tagPendingText = Color(0xFF9A7B38); // Muted amber
  static const Color tagFailedBg = Color(0xFFFCE8EC); // Soft pink
  static const Color tagFailedText = Color(0xFFB5495B); // Muted rose
  static const Color tagNeutralBg = Color(0xFFF5F7FA); // Very soft gray
  static const Color tagNeutralText = Color(0xFF7A8599); // Muted gray

  // Additional Tag Colors (Pastel - สบายตา)
  static const Color tagReadBg = Color(0xFFE0F2F1); // Soft teal for "อ่านแล้ว"
  static const Color tagReadText = Color(0xFF26867A); // Muted teal text
  static const Color tagReviewBg = Color(
    0xFFFFF9E6,
  ); // Soft cream for "ต้องทบทวน"
  static const Color tagReviewText = Color(0xFFA68B3D); // Muted gold text
  static const Color tagUpdateBg = Color(
    0xFFFFF0E8,
  ); // Soft peach for "เนื้อหาอัพเดต"
  static const Color tagUpdateText = Color(0xFFBF6E40); // Muted coral text

  // Result Screen Background
  static const Color resultPassedBg = Color(
    0xFFE8F5E9,
  ); // Light Green background
  static const Color resultFailedBg = Color(
    0xFFFCE4EC,
  ); // Light Pink background

  // Custom Colors
  static const Color greenText = Color(0xFF005862);
  static const Color customColor2 = Color(0xFF554C6F);
  static const Color customColor3 = Color(0xFF4C719F);

  // Spatial Status Colors (for resident badges)
  static const Color spatialNewBg = Color(0xFF55B1C9); // Secondary - Light Blue
  static const Color spatialReferBg = Color(0xFFC60031); // Error - Red
  static const Color spatialHomeBg = Color(0xFF0D9488); // Primary - Teal

  // Pastels
  static const Color pastelYellow = Color(0xFFF1EF99);
  static const Color pastelOrange = Color(0xFFEBC49F);
  static const Color pastelRed = Color(0xFFD37676);
  static const Color pastelOrange1 = Color(0xFFFFD4B2);
  static const Color pastelYellow1 = Color(0xFFFFF6BD);
  static const Color pastelLightGreen1 = Color(0xFFCEEDC7);
  static const Color pastelDarkGreen1 = Color(0xFF86C8BC);
  static const Color pastelPurple = Color(0xFFD4C5E8); // Soft lavender for night section

  // Progress Bar Colors (Soft Teal - เข้ากับ theme)
  static const Color progressOnTime = Color(0xFF4DB6AC); // Soft Teal - ตรงเวลา
  static const Color progressSlightlyLate = Color(0xFFFFB74D); // Soft Amber - สาย
  static const Color progressVeryLate = Color(0xFFE57373); // Soft Red - สายมาก

  // น้ำใจ (Kindness) - งานช่วยคนอื่น
  static const Color kindnessBg = Color(0xFFFCE4EC); // Soft pink background
  static const Color kindnessText = Color(0xFFAD1457); // Deep pink text
  static const LinearGradient kindnessGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE91E63), Color(0xFF9C27B0)], // Pink to Purple
  );

  // Gradient for Header
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D9488), Color(0xFF55B1C9)],
  );

  // Tier/Rank Colors (ใช้ใน points ranking)
  static const Color tierGold = Color(0xFFFFD700); // ทอง
  static const Color tierSilver = Color(0xFFC0C0C0); // เงิน
  static const Color tierBronze = Color(0xFFCD7F32); // ทองแดง
  static const Color tierGoldBg = Color(0xFFFFF8E1); // พื้นหลังทอง (pastel)
  static const Color tierSilverBg = Color(0xFFF5F5F5); // พื้นหลังเงิน
  static const Color tierBronzeBg = Color(0xFFFBE9E7); // พื้นหลังทองแดง
  // เวอร์ชันเข้ม — ใช้ใน gradient pedestal
  static const Color tierGoldDark = Color(0xFFB8860B); // ทองเข้ม (DarkGoldenrod)
  static const Color tierSilverDark = Color(0xFF808080); // เงินเข้ม
  static const Color tierBronzeDark = Color(0xFF8B5A2B); // ทองแดงเข้ม (SaddleBrown)

  // DD Handover Status Colors
  static const Color ddPendingBg = Color(0xFFFFFFD9); // รอดำเนินการ - พื้นหลังเหลืองอ่อน
  static const Color ddPendingBorder = Color(0xFFF1EF99); // รอดำเนินการ - ขอบเหลือง
  static const Color ddUpcomingBg = Color(0xFFFFF9C4); // กำลังจะถึง - พื้นหลังครีม
  static const Color ddUpcomingAccent = Color(0xFFFFB300); // กำลังจะถึง - accent ส้ม
  static const Color ddOverdueBg = Color(0xFFFFEBEE); // เลยกำหนด - พื้นหลังชมพู
  static const Color ddOverdueBorder = Color(0xFFEF9A9A); // เลยกำหนด - ขอบแดง

  // Task Progress Badge Colors (ใช้ใน checklist time section)
  static const Color progressPendingText = Color(0xFFA08030); // เหลืองทองเข้ม - ยังมีงานค้าง
  static const Color progressPendingBg = Color(0xFFE8D5A0); // เหลืองครีม - ยังมีงานค้าง

  // Points Gradient (ใช้ใน points display)
  static const LinearGradient pointsGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
