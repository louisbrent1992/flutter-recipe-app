import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color primaryColor = Color(0xFFE07A5F); // Warm Terracotta
Color secondaryColor = Color(0xFF3D405B).withValues(alpha: 0.8); // Deep Navy
const Color backgroundColor = Color(0xFFF7EDF0); // Soft Blush
const Color accentColor = Color(0xFFA5FFD6); // Mint Green
const Color neutralColor = Color(0xFFF2CC8F); // Muted Peach
const Color purpleColor = Color(0xFF6A0572); // Rich Purple

// Dark theme colors
const Color darkPrimaryColor = Color(0xFFE07A5F); // Keep primary color
const Color darkSecondaryColor = Color(
  0xFF2A2B3F,
); // Darker version of secondary color
const Color darkBackgroundColor = Color(0xFF1A1B2E); // Darker navy background
const Color darkAccentColor = Color(0xFF4AFFB3); // Brighter mint
const Color darkNeutralColor = Color(0xFFD4B17A); // Brighter peach
const Color darkPurpleColor = Color(0xFF9A0AA2); // Brighter purple

// Semantic colors for light theme
const Color lightSuccessColor = Color(0xFF4CAF50); // Green
const Color lightWarningColor = Color(0xFFFF9800); // Orange
const Color lightInfoColor = Color(0xFF2196F3); // Blue
const Color lightErrorColor = Color(0xFFF44336); // Red
const Color lightOnSurfaceColor = Color(0xFF1C1B1F); // Dark text
const Color lightOutlineColor = Color(0xFF79747E); // Border/outline
const Color lightSurfaceVariantColor = Color(0xFFF3EDF7); // Surface variant

// Semantic colors for dark theme
const Color darkSuccessColor = Color(0xFF81C784); // Light green
const Color darkWarningColor = Color(0xFFFFB74D); // Light orange
const Color darkInfoColor = Color(0xFF64B5F6); // Light blue
const Color darkErrorColor = Color(0xFFEF5350); // Light red
const Color darkOnSurfaceColor = Color(0xFFE6E1E5); // Light text
const Color darkOutlineColor = Color(0xFF938F99); // Light border/outline
const Color darkSurfaceVariantColor = Color(0xFF49454F); // Dark surface variant

/// Responsive breakpoints for consistent screen size handling
class AppBreakpoints {
  static const double mobile = 480;
  static const double tablet = 768;
  static const double desktop = 1024;
  static const double ultraWide = 1440;

  // Legacy breakpoints for backwards compatibility
  static const double small = 400;
  static const double medium = 600;
  static const double large = 900;

  /// Check if current screen is mobile size
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobile;
  }

  /// Check if current screen is tablet size
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < desktop;
  }

  /// Check if current screen is desktop size
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
  }

  /// Get the current screen category
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobile) return ScreenSize.mobile;
    if (width < desktop) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }
}

/// Screen size enumeration
enum ScreenSize { mobile, tablet, desktop }

/// Responsive spacing system
class AppSpacing {
  // Base spacing units
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  /// Get responsive spacing based on screen size
  static double responsive(
    BuildContext context, {
    double mobile = md,
    double tablet = lg,
    double desktop = xl,
  }) {
    if (AppBreakpoints.isMobile(context)) return mobile;
    if (AppBreakpoints.isTablet(context)) return tablet;
    return desktop;
  }

  /// Get responsive horizontal padding
  static EdgeInsets horizontalResponsive(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: responsive(context, mobile: md, tablet: lg, desktop: xl),
    );
  }

  /// Get responsive all-around padding
  static EdgeInsets allResponsive(BuildContext context) {
    return EdgeInsets.all(
      responsive(context, mobile: md, tablet: lg, desktop: xl),
    );
  }
}

/// Responsive typography system
class AppTypography {
  /// Get responsive font size
  static double responsiveFontSize(
    BuildContext context, {
    double mobile = 14.0,
    double tablet = 18.0,
    double desktop = 20.0,
  }) {
    if (AppBreakpoints.isMobile(context)) return mobile;
    if (AppBreakpoints.isTablet(context)) return tablet;
    return desktop;
  }

  /// Get responsive heading font size
  static double responsiveHeadingSize(
    BuildContext context, {
    double mobile = 20.0,
    double tablet = 24.0,
    double desktop = 28.0,
  }) {
    if (AppBreakpoints.isMobile(context)) return mobile;
    if (AppBreakpoints.isTablet(context)) return tablet;
    return desktop;
  }

  /// Get responsive caption font size
  static double responsiveCaptionSize(
    BuildContext context, {
    double mobile = 11.0,
    double tablet = 12.0,
    double desktop = 14.0,
  }) {
    if (AppBreakpoints.isMobile(context)) return mobile;
    if (AppBreakpoints.isTablet(context)) return tablet;
    return desktop;
  }
}

/// Responsive sizing utilities
class AppSizing {
  /// Get responsive icon size
  static double responsiveIconSize(
    BuildContext context, {
    double mobile = 20.0,
    double tablet = 24.0,
    double desktop = 28.0,
  }) {
    if (AppBreakpoints.isMobile(context)) return mobile;
    if (AppBreakpoints.isTablet(context)) return tablet;
    return desktop;
  }

  /// Get responsive card padding
  static EdgeInsets responsiveCardPadding(BuildContext context) {
    final size = AppBreakpoints.getScreenSize(context);
    switch (size) {
      case ScreenSize.mobile:
        return const EdgeInsets.all(12.0);
      case ScreenSize.tablet:
        return const EdgeInsets.all(16.0);
      case ScreenSize.desktop:
        return const EdgeInsets.all(20.0);
    }
  }

  /// Get responsive grid cross axis count
  static int responsiveGridCount(
    BuildContext context, {
    int mobile = 2,
    int tablet = 2,
    int desktop = 2,
  }) {
    if (AppBreakpoints.isMobile(context)) return mobile;
    if (AppBreakpoints.isTablet(context)) return tablet;
    return desktop;
  }

  /// Get responsive grid aspect ratio
  static double responsiveAspectRatio(
    BuildContext context, {
    double mobile = 0.72,
    double tablet = 0.80,
    double desktop = 0.85,
  }) {
    if (AppBreakpoints.isMobile(context)) return mobile;
    if (AppBreakpoints.isTablet(context)) return tablet;
    return desktop;
  }

  /// Get responsive container max width
  static double responsiveMaxWidth(BuildContext context) {
    final size = AppBreakpoints.getScreenSize(context);
    switch (size) {
      case ScreenSize.mobile:
        return double.infinity;
      case ScreenSize.tablet:
        return 600.0;
      case ScreenSize.desktop:
        return 1200.0;
    }
  }
}

/// Elevation system for consistent shadow depths throughout the app
/// Following Material Design 3 elevation guidelines
class AppElevation {
  static const double level0 = 0.0; // No elevation (app bars, backgrounds)
  static const double level1 =
      1.0; // Minimal elevation (search bars, text fields)
  static const double level2 = 3.0; // Low elevation (cards, chips)
  static const double level3 = 6.0; // Medium elevation (FABs, snackbars)
  static const double level4 = 8.0; // High elevation (navigation drawers)
  static const double level5 = 12.0; // Highest elevation (modal dialogs)

  // Semantic aliases for common use cases
  static const double appBar = level0;
  static const double card = level2;
  static const double button = level1;
  static const double fab = level3;
  static const double dialog = level5;
  static const double bottomSheet = level4;
  static const double menu = level3;

  /// Get responsive elevation
  static double responsive(
    BuildContext context, {
    double mobile = level2,
    double tablet = level3,
    double desktop = level4,
  }) {
    if (AppBreakpoints.isMobile(context)) return mobile;
    if (AppBreakpoints.isTablet(context)) return tablet;
    return desktop;
  }
}

/// Semantic color extension for theme
extension AppColors on ColorScheme {
  Color get success =>
      brightness == Brightness.light ? lightSuccessColor : darkSuccessColor;
  Color get warning =>
      brightness == Brightness.light ? lightWarningColor : darkWarningColor;
  Color get info =>
      brightness == Brightness.light ? lightInfoColor : darkInfoColor;
  Color get successContainer => success.withValues(alpha: 0.1);
  Color get warningContainer => warning.withValues(alpha: 0.1);
  Color get infoContainer => info.withValues(alpha: 0.1);
  Color get onSuccess =>
      brightness == Brightness.light ? lightOnSurfaceColor : darkOnSurfaceColor;
  Color get onWarning =>
      brightness == Brightness.light ? lightOnSurfaceColor : darkOnSurfaceColor;
  Color get onInfo =>
      brightness == Brightness.light ? lightOnSurfaceColor : darkOnSurfaceColor;

  /// Get appropriate text color for different emphasis levels
  Color get textPrimary => onSurface;
  Color get textSecondary => onSurfaceVariant;
  Color get textTertiary => outline;

  /// Get appropriate background colors for different surface levels
  Color get surfaceContainer => surfaceContainerHighest;
  Color get surfaceContainerLow => surface.withValues(alpha: 0.8);

  /// Theme-aware alpha values that adjust based on brightness
  double get alphaLow => brightness == Brightness.light ? 0.1 : 0.2;
  double get alphaMedium => brightness == Brightness.light ? 0.3 : 0.5;
  double get alphaHigh => brightness == Brightness.light ? 0.6 : 0.8;
  double get alphaVeryHigh => brightness == Brightness.light ? 0.8 : 0.9;

  /// Theme-aware overlay alphas
  double get overlayLight => brightness == Brightness.light ? 0.05 : 0.1;
  double get overlayMedium => brightness == Brightness.light ? 0.1 : 0.2;
  double get overlayHeavy => brightness == Brightness.light ? 0.2 : 0.4;

  /// Theme-aware shadow alphas
  double get shadowLight => brightness == Brightness.light ? 0.08 : 0.15;
  double get shadowMedium => brightness == Brightness.light ? 0.15 : 0.3;
  double get shadowHeavy => brightness == Brightness.light ? 0.3 : 0.5;

  /// Theme-aware surface alphas
  double get surfaceLight => brightness == Brightness.light ? 0.3 : 0.5;
  double get surfaceMedium => brightness == Brightness.light ? 0.5 : 0.7;
  double get surfaceHeavy => brightness == Brightness.light ? 0.8 : 0.9;
}

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      onTertiary: purpleColor,
      surface: backgroundColor,
      surfaceContainerHighest: lightSurfaceVariantColor,
      onSurface: lightOnSurfaceColor,
      onSurfaceVariant: lightOnSurfaceColor.withValues(alpha: 0.6),
      outline: lightOutlineColor,
      outlineVariant: lightOutlineColor.withValues(alpha: 0.3),
      error: lightErrorColor,
      onPrimary: backgroundColor,
      onSecondary: backgroundColor,
      onError: backgroundColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: neutralColor,
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: lightOnSurfaceColor,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: lightOnSurfaceColor,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: lightOnSurfaceColor,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: lightOnSurfaceColor,
      ),
      titleMedium: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: lightOnSurfaceColor,
      ),
      titleSmall: GoogleFonts.playfairDisplay(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: lightOnSurfaceColor,
      ),
      bodyLarge: GoogleFonts.sourceSans3(
        fontSize: 16,
        color: lightOnSurfaceColor,
      ),
      bodyMedium: GoogleFonts.sourceSans3(
        fontSize: 14,
        color: lightOnSurfaceColor,
      ),
      bodySmall: GoogleFonts.sourceSans3(
        fontSize: 12,
        color: lightOnSurfaceColor,
      ),
      labelLarge: GoogleFonts.sourceSans3(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: lightOnSurfaceColor,
      ),
      labelMedium: GoogleFonts.sourceSans3(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: lightOnSurfaceColor,
      ),
      labelSmall: GoogleFonts.sourceSans3(
        fontSize: 12,
        color: lightOnSurfaceColor,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    dividerColor: primaryColor,
    useMaterial3: true,
  );

  static final ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.dark(
      primary: darkPrimaryColor,
      secondary: darkSecondaryColor,
      tertiary: darkAccentColor,
      onTertiary: darkPurpleColor,
      surface: darkBackgroundColor,
      surfaceContainerHighest: darkOnSurfaceColor,
      onSurface: darkOnSurfaceColor,
      onSurfaceVariant: darkOnSurfaceColor.withValues(alpha: 0.6),
      outline: darkOutlineColor,
      outlineVariant: darkOutlineColor.withValues(alpha: 0.3),
      error: darkErrorColor,
      onPrimary: backgroundColor,
      onSecondary: lightOnSurfaceColor,
      onError: backgroundColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: darkSecondaryColor,
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: darkOnSurfaceColor,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: darkOnSurfaceColor,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: darkOnSurfaceColor,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: darkOnSurfaceColor,
      ),
      titleMedium: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: darkOnSurfaceColor,
      ),
      titleSmall: GoogleFonts.playfairDisplay(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: darkOnSurfaceColor,
      ),
      bodyLarge: GoogleFonts.sourceSans3(
        fontSize: 16,
        color: darkOnSurfaceColor,
      ),
      bodyMedium: GoogleFonts.sourceSans3(
        fontSize: 14,
        color: darkOnSurfaceColor,
      ),
      bodySmall: GoogleFonts.sourceSans3(
        fontSize: 12,
        color: darkOnSurfaceColor,
      ),
      labelLarge: GoogleFonts.sourceSans3(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: darkOnSurfaceColor,
      ),
      labelMedium: GoogleFonts.sourceSans3(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: darkOnSurfaceColor,
      ),
      labelSmall: GoogleFonts.sourceSans3(
        fontSize: 12,
        color: darkOnSurfaceColor,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimaryColor,
        foregroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    useMaterial3: true,
  );
}

/// Responsive dialog utilities
class AppDialog {
  /// Get responsive max width for dialogs
  static double responsiveMaxWidth(BuildContext context) {
    if (AppBreakpoints.isDesktop(context)) return 500;
    if (AppBreakpoints.isTablet(context)) return 450;
    return 400;
  }

  /// Get responsive padding for dialog content
  static EdgeInsets responsivePadding(BuildContext context) {
    return EdgeInsets.all(
      AppBreakpoints.isDesktop(context)
          ? 28
          : AppBreakpoints.isTablet(context)
              ? 24
              : 20,
    );
  }

  /// Get responsive title font size
  static double responsiveTitleSize(BuildContext context) {
    return AppBreakpoints.isDesktop(context)
        ? 24
        : AppBreakpoints.isTablet(context)
            ? 22
            : 20;
  }

  /// Get responsive content font size
  static double responsiveContentSize(BuildContext context) {
    return AppBreakpoints.isDesktop(context)
        ? 16
        : AppBreakpoints.isTablet(context)
            ? 15
            : 14;
  }

  /// Get responsive border radius for dialogs
  static double responsiveBorderRadius(BuildContext context) {
    return AppBreakpoints.isDesktop(context)
        ? 24
        : AppBreakpoints.isTablet(context)
            ? 20
            : 16;
  }

  /// Get responsive button padding
  static EdgeInsets responsiveButtonPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: AppBreakpoints.isDesktop(context)
          ? 24
          : AppBreakpoints.isTablet(context)
              ? 20
              : 16,
      vertical: AppBreakpoints.isDesktop(context)
          ? 14
          : AppBreakpoints.isTablet(context)
              ? 12
              : 10,
    );
  }
}
