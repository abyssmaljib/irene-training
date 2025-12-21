import 'package:flutter/material.dart';

/// Irene Plus Spacing System
/// Based on 8px grid system
class AppSpacing {
  // Base unit
  static const double unit = 8.0;
  
  // Spacing values
  static const double xs = 4.0;    // 0.5x
  static const double sm = 8.0;    // 1x
  static const double md = 16.0;   // 2x
  static const double lg = 24.0;   // 3x
  static const double xl = 32.0;   // 4x
  static const double xxl = 40.0;  // 5x
  static const double xxxl = 48.0; // 6x
  
  // Padding presets
  static const EdgeInsets paddingXs = EdgeInsets.all(4);
  static const EdgeInsets paddingSm = EdgeInsets.all(8);
  static const EdgeInsets paddingMd = EdgeInsets.all(16);
  static const EdgeInsets paddingLg = EdgeInsets.all(24);
  static const EdgeInsets paddingXl = EdgeInsets.all(32);
  
  // Horizontal padding
  static const EdgeInsets paddingHorizontalSm = EdgeInsets.symmetric(horizontal: 8);
  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets paddingHorizontalLg = EdgeInsets.symmetric(horizontal: 24);
  
  // Vertical padding
  static const EdgeInsets paddingVerticalSm = EdgeInsets.symmetric(vertical: 8);
  static const EdgeInsets paddingVerticalMd = EdgeInsets.symmetric(vertical: 16);
  static const EdgeInsets paddingVerticalLg = EdgeInsets.symmetric(vertical: 24);
  
  // Component specific
  static const double buttonHeight = 52.0;
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 12);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  
  // Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16);
  
  // Gap helpers (for use with SizedBox)
  static const SizedBox gapXs = SizedBox(height: 4, width: 4);
  static const SizedBox gapSm = SizedBox(height: 8, width: 8);
  static const SizedBox gapMd = SizedBox(height: 16, width: 16);
  static const SizedBox gapLg = SizedBox(height: 24, width: 24);
  static const SizedBox gapXl = SizedBox(height: 32, width: 32);
  
  // Vertical gaps
  static const SizedBox verticalGapXs = SizedBox(height: 4);
  static const SizedBox verticalGapSm = SizedBox(height: 8);
  static const SizedBox verticalGapMd = SizedBox(height: 16);
  static const SizedBox verticalGapLg = SizedBox(height: 24);
  static const SizedBox verticalGapXl = SizedBox(height: 32);
  
  // Horizontal gaps
  static const SizedBox horizontalGapXs = SizedBox(width: 4);
  static const SizedBox horizontalGapSm = SizedBox(width: 8);
  static const SizedBox horizontalGapMd = SizedBox(width: 16);
  static const SizedBox horizontalGapLg = SizedBox(width: 24);
  static const SizedBox horizontalGapXl = SizedBox(width: 32);
}

/// Border Radius tokens
class AppRadius {
  static const double small = 8.0;     // Buttons, inputs
  static const double medium = 16.0;   // Cards
  static const double large = 24.0;    // Modals, bottom sheets
  static const double full = 9999.0;   // Pills, avatars
  
  // BorderRadius presets
  static final BorderRadius smallRadius = BorderRadius.circular(small);
  static final BorderRadius mediumRadius = BorderRadius.circular(medium);
  static final BorderRadius largeRadius = BorderRadius.circular(large);
  static final BorderRadius fullRadius = BorderRadius.circular(full);
}

/// Shadow presets
class AppShadows {
  // Subtle shadow - for inputs, hover states
  static const BoxShadow subtle = BoxShadow(
    color: Color(0x14000000), // 8% opacity
    blurRadius: 8,
    spreadRadius: 0,
    offset: Offset(0, 2),
  );
  
  // Medium shadow - for cards
  static const BoxShadow medium = BoxShadow(
    color: Color(0x14000000), // 8% opacity
    blurRadius: 16,
    spreadRadius: 0,
    offset: Offset(0, 4),
  );
  
  // Elevated shadow - for modals, overlays
  static const BoxShadow elevated = BoxShadow(
    color: Color(0x1F000000), // 12% opacity
    blurRadius: 24,
    spreadRadius: 0,
    offset: Offset(0, 6),
  );
  
  // Card shadow (as shown in design)
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      spreadRadius: 0,
      offset: Offset(0, 0),
    ),
  ];
}