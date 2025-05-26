import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color primaryColor = Color(0xFFE07A5F); // Warm Terracotta
const Color secondaryColor = Color(0xFF3D405B); // Deep Navy
const Color backgroundColor = Color(0xFFF7EDF0); // Soft Blush
const Color accentColor = Color(0xFFA5FFD6); // Mint Green
const Color neutralColor = Color(0xFFF2CC8F); // Muted Peach
const Color purpleColor = Color(0xFF6A0572); // Rich Purple

// Dark theme colors
const Color darkPrimaryColor = Color(0xFFE07A5F); // Keep primary color
const Color darkSecondaryColor = Color(0xFFA5B4D9); // Lighter navy
const Color darkBackgroundColor = Color(0xFF1A1B2E); // Darker navy background
const Color darkAccentColor = Color(0xFF4AFFB3); // Brighter mint
const Color darkNeutralColor = Color(0xFFD4B17A); // Brighter peach
const Color darkPurpleColor = Color(0xFF9A0AA2); // Brighter purple

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    colorScheme: const ColorScheme(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      onTertiary: purpleColor,
      surface: backgroundColor,
      error: Colors.red,
      onPrimary: backgroundColor,
      onSecondary: backgroundColor,
      onSurface: Colors.black,
      onError: backgroundColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: backgroundColor,
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: secondaryColor,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: secondaryColor,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: secondaryColor,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: backgroundColor,
      ),
      titleMedium: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: backgroundColor,
      ),
      titleSmall: GoogleFonts.playfairDisplay(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: backgroundColor,
      ),
      bodyLarge: GoogleFonts.sourceSans3(fontSize: 16, color: Colors.black),
      bodyMedium: GoogleFonts.sourceSans3(fontSize: 14, color: Colors.black),
      bodySmall: GoogleFonts.sourceSans3(fontSize: 12, color: Colors.black),
      labelLarge: GoogleFonts.sourceSans3(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      labelMedium: GoogleFonts.sourceSans3(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: secondaryColor,
      ),
      labelSmall: GoogleFonts.sourceSans3(fontSize: 12, color: backgroundColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dividerColor: secondaryColor,
    useMaterial3: true,
  );

  static final ThemeData darkTheme = ThemeData(
    colorScheme: const ColorScheme(
      primary: darkPrimaryColor,
      secondary: darkSecondaryColor,
      tertiary: darkAccentColor,
      onTertiary: darkPurpleColor,
      surface: darkBackgroundColor,
      error: Colors.red,
      onPrimary: backgroundColor,
      onSecondary: Colors.black,
      onSurface: backgroundColor,
      onError: backgroundColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: darkBackgroundColor,
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: backgroundColor,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: backgroundColor,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: backgroundColor,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: backgroundColor,
      ),
      titleMedium: GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: backgroundColor,
      ),
      titleSmall: GoogleFonts.playfairDisplay(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: backgroundColor,
      ),
      bodyLarge: GoogleFonts.sourceSans3(fontSize: 16, color: backgroundColor),
      bodyMedium: GoogleFonts.sourceSans3(fontSize: 14, color: backgroundColor),
      bodySmall: GoogleFonts.sourceSans3(fontSize: 12, color: backgroundColor),
      labelLarge: GoogleFonts.sourceSans3(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: darkSecondaryColor,
      ),
      labelMedium: GoogleFonts.sourceSans3(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: darkSecondaryColor,
      ),
      labelSmall: GoogleFonts.sourceSans3(fontSize: 12, color: backgroundColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimaryColor,
        foregroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    useMaterial3: true,
  );
}
