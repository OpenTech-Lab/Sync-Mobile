import 'package:flutter/material.dart';

import 'app_palette.dart';

@immutable
class AppColors {
  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.muted,
    required this.border,
    required this.success,
    required this.error,
    required this.onError,
  });

  final Color primary;
  final Color onPrimary;
  final Color background;
  final Color surface;
  final Color onSurface;
  final Color muted;
  final Color border;
  final Color success;
  final Color error;
  final Color onError;

  factory AppColors.light() {
    return const AppColors(
      primary: AppPalette.blue600,
      onPrimary: AppPalette.white,
      background: AppPalette.neutral50,
      surface: AppPalette.neutral50,
      onSurface: AppPalette.neutral800,
      muted: AppPalette.neutral500,
      border: AppPalette.neutral300,
      success: AppPalette.green600,
      error: AppPalette.danger700,
      onError: AppPalette.white,
    );
  }

  factory AppColors.dark() {
    return const AppColors(
      primary: AppPalette.blue700,
      onPrimary: AppPalette.white,
      background: AppPalette.neutral900,
      surface: AppPalette.neutral900,
      onSurface: AppPalette.neutral100,
      muted: AppPalette.neutral500,
      border: AppPalette.neutral700,
      success: AppPalette.green600,
      error: AppPalette.red600,
      onError: AppPalette.white,
    );
  }
}
