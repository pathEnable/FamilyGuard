import 'package:flutter/material.dart';

class SafeChildColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFFDBEAFE);
  
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF97316); // Orange
  static const Color danger = Color(0xFFEF4444);
  
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
}

class SafeChildTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: SafeChildColors.primary,
      scaffoldBackgroundColor: SafeChildColors.background,
      cardColor: SafeChildColors.surface,
      fontFamily: 'Inter', // Note: Need to add Inter font in pubspec.yaml if desired
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: SafeChildColors.textMain, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: SafeChildColors.textMain, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: SafeChildColors.textMain, fontSize: 16),
        bodyMedium: TextStyle(color: SafeChildColors.textMuted, fontSize: 14),
      ),
      colorScheme: const ColorScheme.light(
        primary: SafeChildColors.primary,
        secondary: SafeChildColors.success,
        error: SafeChildColors.danger,
        surface: SafeChildColors.surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SafeChildColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SafeChildColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: SafeChildColors.primary),
        ),
      ),
    );
  }
}
