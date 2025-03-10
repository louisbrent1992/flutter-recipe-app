import 'package:flutter/material.dart';

const Color primaryColor = Color(0xFFE07A5F); // Warm Terracotta
const Color secondaryColor = Color(0xFF3D405B); // Deep Navy
const Color backgroundColor = Color(0xFFF7EDF0); // Soft Blush
const Color accentColor = Color(0xFFA5FFD6); // Mint Green
const Color neutralColor = Color(0xFFF2CC8F); // Muted Peach

final ThemeData appThemeData = ThemeData(
  colorScheme: const ColorScheme(
    primary: primaryColor,
    secondary: secondaryColor,
    tertiary: accentColor,
    surface: backgroundColor,
    error: Colors.red, // Default error color
    onPrimary: Colors.white, // Text/icons on primary color
    onSecondary: Colors.white, // Text/icons on secondary color
    onSurface: Colors.black, // Text/icons on white surfaces
    onError: Colors.white, // Text/icons on error color
    brightness: Brightness.light, // Light theme
  ),
  scaffoldBackgroundColor: backgroundColor,
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      color: secondaryColor, // Deep navy for emphasis
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
    titleLarge: TextStyle(
      color: secondaryColor, // Deep navy for emphasis
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    bodyMedium: TextStyle(
      color: Colors.black, // Keeping body text readable
      fontSize: 14,
    ),
    bodySmall: TextStyle(color: Colors.black, fontSize: 12),
    labelLarge: TextStyle(
      color: Colors.black, // Warm terracotta for standout labels
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
    labelMedium: TextStyle(
      color: secondaryColor,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    ),
    labelSmall: TextStyle(color: secondaryColor, fontSize: 12),
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
