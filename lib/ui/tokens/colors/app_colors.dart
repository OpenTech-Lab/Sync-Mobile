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
      onPrimary: Colors.white,
      background: AppPalette.mujiPaper,
      surface: AppPalette.mujiPaper,
      onSurface: AppPalette.mujiInk,
      muted: AppPalette.mujiMuted,
      border: AppPalette.mujiRule,
      success: AppPalette.green600,
      error: AppPalette.mujiRed,
      onError: Colors.white,
    );
  }

  factory AppColors.dark() {
    return const AppColors(
      primary: AppPalette.blue700,
      onPrimary: Colors.white,
      background: AppPalette.mujiPaperDark,
      surface: AppPalette.mujiPaperDark,
      onSurface: AppPalette.mujiInkDark,
      muted: AppPalette.mujiMuted,
      border: AppPalette.mujiRuleDark,
      success: AppPalette.green600,
      error: AppPalette.red600,
      onError: Colors.white,
    );
  }
}
