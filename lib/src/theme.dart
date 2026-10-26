import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF141414);
  static const surface = Color(0xFF1F1F1F);
  static const raised = Color(0xFF242424);
  static const border = Color(0xFF383838);
  static const muted = Color(0xFF999999);
  static const blue = Color(0xFF2995FF);
  static const green = Color(0xFF8BE0B2);
  static const yellow = Color(0xFFFFDD55);
  static const purple = Color(0xFF7373FF);
  static const coral = Color(0xFFFF8573);
}

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.blue,
    onPrimary: Colors.white,
    secondary: AppColors.green,
    surface: AppColors.surface,
    error: AppColors.coral,
  ),
  useMaterial3: true,
  fontFamily: 'DMSans',
  fontFamilyFallback: const ['NotoSansSC'],
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -.8,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -.3,
    ),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, height: 1.6),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.raised,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  dividerTheme: const DividerThemeData(color: AppColors.border, space: 28),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.raised,
    contentTextStyle: const TextStyle(color: Colors.white),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
);
