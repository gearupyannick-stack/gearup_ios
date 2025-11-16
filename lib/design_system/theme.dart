import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';

/// GearUp app theme configuration
class GearUpTheme {
  GearUpTheme._();

  /// Dark theme (primary theme for the app)
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,

      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: DesignTokens.primaryRed,
        secondary: DesignTokens.accentGold,
        surface: DesignTokens.surface,
        error: DesignTokens.error,
      ),

      // Scaffold
      scaffoldBackgroundColor: DesignTokens.background,

      // App bar
      appBarTheme: const AppBarTheme(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: DesignTokens.heading3,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Card
      cardTheme: CardThemeData(
        color: DesignTokens.surfaceElevated,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusMedium,
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.primaryRed,
          foregroundColor: DesignTokens.white,
          minimumSize: const Size(0, DesignTokens.buttonHeightMedium),
          padding: DesignTokens.paddingHorizontalLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: DesignTokens.borderRadiusMedium,
          ),
          textStyle: DesignTokens.button,
          elevation: 0,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DesignTokens.primaryRed,
          minimumSize: const Size(0, DesignTokens.buttonHeightMedium),
          padding: DesignTokens.paddingHorizontalMedium,
          textStyle: DesignTokens.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DesignTokens.textPrimary,
          side: const BorderSide(color: DesignTokens.textSecondary),
          minimumSize: const Size(0, DesignTokens.buttonHeightMedium),
          padding: DesignTokens.paddingHorizontalLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: DesignTokens.borderRadiusMedium,
          ),
          textStyle: DesignTokens.button,
        ),
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: DesignTokens.displayLarge,
        displayMedium: DesignTokens.displayMedium,
        headlineLarge: DesignTokens.heading1,
        headlineMedium: DesignTokens.heading2,
        headlineSmall: DesignTokens.heading3,
        bodyLarge: DesignTokens.bodyLarge,
        bodyMedium: DesignTokens.bodyMedium,
        bodySmall: DesignTokens.bodySmall,
        labelLarge: DesignTokens.button,
        labelSmall: DesignTokens.caption,
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: DesignTokens.textPrimary,
        size: DesignTokens.iconSizeMedium,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: DesignTokens.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusLarge,
        ),
        titleTextStyle: DesignTokens.heading2,
        contentTextStyle: DesignTokens.bodyMedium,
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMedium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMedium,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMedium,
          borderSide: BorderSide(color: DesignTokens.primaryRed, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: DesignTokens.borderRadiusMedium,
          borderSide: BorderSide(color: DesignTokens.error, width: 2),
        ),
        contentPadding: DesignTokens.paddingMedium,
        labelStyle: DesignTokens.bodyMedium,
        hintStyle: TextStyle(color: DesignTokens.textTertiary),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: DesignTokens.textTertiary,
        thickness: 1,
        space: DesignTokens.space16,
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DesignTokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusXLarge),
          ),
        ),
      ),

      // Snackbar
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: DesignTokens.surfaceHighlighted,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.borderRadiusMedium,
        ),
        contentTextStyle: DesignTokens.bodyMedium,
      ),
    );
  }
}

/// Extension methods for BuildContext to easily access theme values
extension ThemeExtensions on BuildContext {
  /// Access color scheme
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Access text theme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Access media query
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Screen width
  double get screenWidth => mediaQuery.size.width;

  /// Screen height
  double get screenHeight => mediaQuery.size.height;

  /// Check if screen is small (< 600px wide)
  bool get isSmallScreen => screenWidth < 600;

  /// Check if screen is medium (600-900px wide)
  bool get isMediumScreen => screenWidth >= 600 && screenWidth < 900;

  /// Check if screen is large (>= 900px wide)
  bool get isLargeScreen => screenWidth >= 900;
}

/// Helper methods for common UI patterns
class UIHelper {
  UIHelper._();

  /// Create a standard container with elevation
  static Widget elevatedContainer({
    required Widget child,
    Color? backgroundColor,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
    List<BoxShadow>? shadows,
  }) {
    return Container(
      padding: padding ?? DesignTokens.paddingMedium,
      decoration: BoxDecoration(
        color: backgroundColor ?? DesignTokens.surfaceElevated,
        borderRadius: borderRadius ?? DesignTokens.borderRadiusMedium,
        boxShadow: shadows ?? DesignTokens.shadowLevel2,
      ),
      child: child,
    );
  }

  /// Create a gradient container
  static Widget gradientContainer({
    required Widget child,
    required Gradient gradient,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return Container(
      padding: padding ?? DesignTokens.paddingMedium,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius ?? DesignTokens.borderRadiusMedium,
      ),
      child: child,
    );
  }

  /// Create a shimmer loading effect
  static LinearGradient shimmerGradient() {
    return const LinearGradient(
      begin: Alignment(-1.0, 0.0),
      end: Alignment(1.0, 0.0),
      colors: [
        DesignTokens.surfaceElevated,
        DesignTokens.surfaceHighlighted,
        DesignTokens.surfaceElevated,
      ],
      stops: [0.0, 0.5, 1.0],
    );
  }

  /// Vertical spacing
  static Widget verticalSpace(double height) => SizedBox(height: height);

  /// Horizontal spacing
  static Widget horizontalSpace(double width) => SizedBox(width: width);

  /// Standard vertical spacers
  static Widget get vSpaceSmall => verticalSpace(DesignTokens.space8);
  static Widget get vSpaceMedium => verticalSpace(DesignTokens.space16);
  static Widget get vSpaceLarge => verticalSpace(DesignTokens.space24);
  static Widget get vSpaceXLarge => verticalSpace(DesignTokens.space32);

  /// Standard horizontal spacers
  static Widget get hSpaceSmall => horizontalSpace(DesignTokens.space8);
  static Widget get hSpaceMedium => horizontalSpace(DesignTokens.space16);
  static Widget get hSpaceLarge => horizontalSpace(DesignTokens.space24);
  static Widget get hSpaceXLarge => horizontalSpace(DesignTokens.space32);
}
