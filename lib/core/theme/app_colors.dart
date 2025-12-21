import 'package:flutter/material.dart';

/// Irene Plus Color Palette
/// Based on Design System from Lovart
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF0D9488);        // Teal
  static const Color secondary = Color(0xFF55B1C9);      // Light Blue
  static const Color tertiary = Color(0xFFE689C4);       // Pink
  static const Color alternate = Color(0xFFD8D8D8);      // Light Gray border

  // Background Colors
  static const Color background = Color(0xFFF1F4F8);     // Light Gray
  static const Color surface = Color(0xFFFFFFFF);        // White
  static const Color primaryBackground = Color(0xFFF1F4F8);
  static const Color secondaryBackground = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF13181F);    // Dark
  static const Color textSecondary = Color(0xFF5B616D);  // Gray
  static const Color primaryText = Color(0xFF13181F);    // Alias
  static const Color secondaryText = Color(0xFF5B616D);  // Alias

  // Status Colors
  static const Color success = Color(0xFF023618);        // Green
  static const Color warning = Color(0xFFDEB841);        // Yellow
  static const Color error = Color(0xFFC60031);          // Red
  static const Color info = Color(0xFFFFFFFF);           // White

  // Accents (with opacity)
  static const Color accent1 = Color(0x1A0D9488);        // 10% Primary
  static const Color accent2 = Color(0x1A55B1C9);        // 10% Secondary
  static const Color accent3 = Color(0x19E689C4);        // 10% Tertiary
  static const Color accent4 = Color(0xFFFFFFFF);        // White

  // Button States
  static const Color primaryHover = Color(0xFF0B7A70);   // Darker Teal
  static const Color primaryFocused = Color(0xFF0D9488);
  static const Color primaryDisabled = Color(0xFFB0B0B0);

  // Input States
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color inputFocused = Color(0xFF0D9488);
  static const Color inputError = Color(0xFFC60031);

  // Tag/Badge Colors
  static const Color tagPassedBg = Color(0xFFD4EDDA);
  static const Color tagPassedText = Color(0xFF023618);
  static const Color tagPendingBg = Color(0xFFFFF3CD);
  static const Color tagPendingText = Color(0xFF856404);
  static const Color tagFailedBg = Color(0xFFF8D7DA);
  static const Color tagFailedText = Color(0xFFC60031);
  static const Color tagNeutralBg = Color(0xFFF1F4F8);
  static const Color tagNeutralText = Color(0xFF5B616D);

  // Additional Tag Colors
  static const Color tagReadBg = Color(0xFFBFFFF3);        // Light Teal for "อ่านแล้ว"
  static const Color tagReviewBg = Color(0xFFFFFCDB);     // Light Yellow for "ต้องทบทวน"
  static const Color tagReviewText = Color(0xFF835C00);   // Dark Yellow text
  static const Color tagUpdateBg = Color(0xFFFFE4D6);     // Light Orange for "เนื้อหาอัพเดต"
  static const Color tagUpdateText = Color(0xFFB84300);   // Dark Orange text

  // Result Screen Background
  static const Color resultPassedBg = Color(0xFFE8F5E9);  // Light Green background
  static const Color resultFailedBg = Color(0xFFFCE4EC);  // Light Pink background

  // Custom Colors
  static const Color greenText = Color(0xFF005862);
  static const Color customColor2 = Color(0xFF554C6F);
  static const Color customColor3 = Color(0xFF4C719F);

  // Pastels
  static const Color pastelYellow = Color(0xFFF1EF99);
  static const Color pastelOrange = Color(0xFFEBC49F);
  static const Color pastelRed = Color(0xFFD37676);
  static const Color pastelOrange1 = Color(0xFFFFD4B2);
  static const Color pastelYellow1 = Color(0xFFFFF6BD);
  static const Color pastelLightGreen1 = Color(0xFFCEEDC7);
  static const Color pastelDarkGreen1 = Color(0xFF86C8BC);

  // Gradient for Header
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D9488),
      Color(0xFF55B1C9),
    ],
  );
}