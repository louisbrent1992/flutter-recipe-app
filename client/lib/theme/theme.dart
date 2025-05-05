import 'package:flutter/material.dart';

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
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black,
      onError: Colors.white,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: backgroundColor,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: secondaryColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: secondaryColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(color: Colors.black, fontSize: 14),
      bodySmall: TextStyle(color: Colors.black, fontSize: 12),
      labelLarge: TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      labelMedium: TextStyle(
        color: secondaryColor,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      labelSmall: TextStyle(color: backgroundColor, fontSize: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
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
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Colors.white,
      onError: Colors.white,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: darkBackgroundColor,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: darkSecondaryColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: darkSecondaryColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(color: Colors.white, fontSize: 14),
      bodySmall: TextStyle(color: Colors.white, fontSize: 12),
      labelLarge: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      labelMedium: TextStyle(
        color: darkSecondaryColor,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      labelSmall: TextStyle(color: backgroundColor, fontSize: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    useMaterial3: true,
  );
}
