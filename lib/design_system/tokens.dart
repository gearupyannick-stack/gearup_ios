import 'package:flutter/material.dart';

/// Design tokens for GearUp app
/// Provides consistent colors, spacing, typography, and animation values
class DesignTokens {
  DesignTokens._(); // Private constructor to prevent instantiation

  // ============================================================================
  // COLORS
  // ============================================================================

  /// Primary brand colors
  static const Color primaryRed = Color(0xFFE53935);
  static const Color primaryRedDark = Color(0xFFC62828);
  static const Color primaryRedLight = Color(0xFFEF5350);

  /// Secondary colors
  static const Color accentGold = Color(0xFFFFD700);
  static const Color accentGoldDark = Color(0xFFFFC107);

  /// Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successDark = Color(0xFF388E3C);
  static const Color error = Color(0xFFF44336);
  static const Color errorDark = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  /// Surface colors (dark theme optimized)
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceElevated = Color(0xFF2D2D2D);
  static const Color surfaceHighlighted = Color(0xFF3D3D3D);
  static const Color surfaceOverlay = Color(0xFF424242);

  /// Background colors
  static const Color background = Color(0xFF121212);
  static const Color backgroundDark = Color(0xFF000000);

  /// Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textDisabled = Color(0xFF606060);

  /// Overlay colors
  static const Color overlay10 = Color(0x1A000000); // 10% black
  static const Color overlay20 = Color(0x33000000); // 20% black
  static const Color overlay30 = Color(0x4D000000); // 30% black
  static const Color overlay40 = Color(0x66000000); // 40% black
  static const Color overlay50 = Color(0x80000000); // 50% black
  static const Color overlay60 = Color(0x99000000); // 60% black

  /// Special colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  /// Racing position colors
  static const Color position1st = Color(0xFFFFD700); // Gold
  static const Color position2nd = Color(0xFFC0C0C0); // Silver
  static const Color position3rd = Color(0xFFCD7F32); // Bronze

  /// Streak/fire color
  static const Color streakOrange = Color(0xFFFF6B35);
  static const Color streakYellow = Color(0xFFFFAA00);

  // ============================================================================
  // SPACING (8px grid system)
  // ============================================================================

  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  /// Common edge insets
  static const EdgeInsets paddingSmall = EdgeInsets.all(space8);
  static const EdgeInsets paddingMedium = EdgeInsets.all(space16);
  static const EdgeInsets paddingLarge = EdgeInsets.all(space24);
  static const EdgeInsets paddingXLarge = EdgeInsets.all(space32);

  static const EdgeInsets paddingHorizontalSmall = EdgeInsets.symmetric(horizontal: space8);
  static const EdgeInsets paddingHorizontalMedium = EdgeInsets.symmetric(horizontal: space16);
  static const EdgeInsets paddingHorizontalLarge = EdgeInsets.symmetric(horizontal: space24);

  static const EdgeInsets paddingVerticalSmall = EdgeInsets.symmetric(vertical: space8);
  static const EdgeInsets paddingVerticalMedium = EdgeInsets.symmetric(vertical: space16);
  static const EdgeInsets paddingVerticalLarge = EdgeInsets.symmetric(vertical: space24);

  // ============================================================================
  // BORDER RADIUS
  // ============================================================================

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusFull = 9999.0; // Fully rounded

  static const BorderRadius borderRadiusSmall = BorderRadius.all(Radius.circular(radiusSmall));
  static const BorderRadius borderRadiusMedium = BorderRadius.all(Radius.circular(radiusMedium));
  static const BorderRadius borderRadiusLarge = BorderRadius.all(Radius.circular(radiusLarge));
  static const BorderRadius borderRadiusXLarge = BorderRadius.all(Radius.circular(radiusXLarge));
  static const BorderRadius borderRadiusFull = BorderRadius.all(Radius.circular(radiusFull));

  // ============================================================================
  // TYPOGRAPHY
  // ============================================================================

  /// Font family
  static const String fontFamily = 'Roboto'; // Default Flutter font

  /// Font sizes
  static const double fontSize12 = 12.0;
  static const double fontSize14 = 14.0;
  static const double fontSize16 = 16.0;
  static const double fontSize18 = 18.0;
  static const double fontSize20 = 20.0;
  static const double fontSize24 = 24.0;
  static const double fontSize28 = 28.0;
  static const double fontSize32 = 32.0;
  static const double fontSize48 = 48.0;
  static const double fontSize64 = 64.0;

  /// Font weights
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightSemiBold = FontWeight.w600;
  static const FontWeight weightBold = FontWeight.w700;
  static const FontWeight weightExtraBold = FontWeight.w800;

  /// Text styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: fontSize64,
    fontWeight: weightBold,
    color: textPrimary,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: fontSize48,
    fontWeight: weightBold,
    color: textPrimary,
    height: 1.2,
  );

  static const TextStyle heading1 = TextStyle(
    fontSize: fontSize32,
    fontWeight: weightBold,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: fontSize28,
    fontWeight: weightSemiBold,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: fontSize24,
    fontWeight: weightSemiBold,
    color: textPrimary,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: fontSize18,
    fontWeight: weightRegular,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: fontSize16,
    fontWeight: weightRegular,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: fontSize14,
    fontWeight: weightRegular,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: fontSize12,
    fontWeight: weightRegular,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle button = TextStyle(
    fontSize: fontSize16,
    fontWeight: weightSemiBold,
    color: textPrimary,
    height: 1.2,
    letterSpacing: 0.5,
  );

  // ============================================================================
  // ANIMATION DURATIONS
  // ============================================================================

  static const Duration durationInstant = Duration(milliseconds: 100);
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationXSlow = Duration(milliseconds: 800);

  /// Animation curves
  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveEmphasized = Curves.easeOutCubic;
  static const Curve curveElastic = Curves.elasticOut;
  static const Curve curveSnappy = Curves.easeOutBack;

  // ============================================================================
  // SHADOWS & ELEVATION
  // ============================================================================

  static const List<BoxShadow> shadowLevel1 = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowLevel2 = [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowLevel3 = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> shadowLevel4 = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  // ============================================================================
  // BUTTON SIZES
  // ============================================================================

  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightMedium = 48.0;
  static const double buttonHeightLarge = 56.0;

  /// Minimum touch target size (accessibility)
  static const double minTouchTarget = 48.0;

  // ============================================================================
  // ICON SIZES
  // ============================================================================

  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;

  // ============================================================================
  // GRADIENTS
  // ============================================================================

  static const LinearGradient gradientWinner = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4CAF50),
      Color(0xFF2E7D32),
    ],
  );

  static const LinearGradient gradientLoser = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF44336),
      Color(0xFFC62828),
    ],
  );

  static const LinearGradient gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryRed,
      primaryRedDark,
    ],
  );

  static const LinearGradient gradientGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accentGold,
      accentGoldDark,
    ],
  );

  static const LinearGradient gradientOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      transparent,
      overlay60,
    ],
  );

  // ============================================================================
  // OPACITY VALUES
  // ============================================================================

  static const double opacityDisabled = 0.5;
  static const double opacityHover = 0.8;
  static const double opacityPressed = 0.6;
  static const double opacitySubtle = 0.7;
}
