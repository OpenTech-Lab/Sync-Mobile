import 'package:flutter/material.dart';

import '../colors/app_colors.dart';

abstract final class AppTextStyles {
  static TextStyle display(AppColors colors) => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: colors.onSurface,
    height: 1.25,
  );

  static TextStyle title(AppColors colors) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: colors.onSurface,
    height: 1.3,
  );

  static TextStyle body(AppColors colors) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: colors.onSurface,
    height: 1.45,
  );

  static TextStyle label(AppColors colors) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: colors.muted,
    letterSpacing: 0.2,
  );

  static TextStyle caption(AppColors colors) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: colors.muted,
    letterSpacing: 0.3,
  );
}
