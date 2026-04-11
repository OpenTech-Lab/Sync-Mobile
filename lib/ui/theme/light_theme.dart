import 'package:flutter/material.dart';

import '../extensions/app_spacing.dart';
import '../extensions/app_theme.dart';
import '../extensions/app_typography.dart';

ThemeData buildLightTheme() {
  final appTheme = AppTheme.light();
  final appTypography = AppTypography.fromColors(appTheme.colors);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.light,
      seedColor: appTheme.colors.primary,
      primary: appTheme.colors.primary,
      onPrimary: appTheme.colors.onPrimary,
      surface: appTheme.colors.surface,
      onSurface: appTheme.colors.onSurface,
      error: appTheme.colors.error,
      onError: appTheme.colors.onError,
    ),
    scaffoldBackgroundColor: appTheme.colors.background,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: appTypography.title,
      backgroundColor: appTheme.colors.background,
      foregroundColor: appTheme.colors.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: appTheme.mediumRadius),
      enabledBorder: OutlineInputBorder(
        borderRadius: appTheme.mediumRadius,
        borderSide: BorderSide(color: appTheme.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: appTheme.mediumRadius,
        borderSide: BorderSide(color: appTheme.colors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: appTheme.mediumRadius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: appTheme.mediumRadius),
      ),
    ),
    extensions: [appTheme, appTypography, AppSpacing.regular()],
  );
}
