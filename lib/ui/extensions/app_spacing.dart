import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/spacing.dart';

@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.pagePadding,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final EdgeInsets pagePadding;

  factory AppSpacing.regular() {
    return const AppSpacing(
      xs: AppSpacingToken.xs,
      sm: AppSpacingToken.sm,
      md: AppSpacingToken.md,
      lg: AppSpacingToken.lg,
      xl: AppSpacingToken.xl,
      pagePadding: AppSpacingToken.pagePadding,
    );
  }

  @override
  AppSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    EdgeInsets? pagePadding,
  }) {
    return AppSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      pagePadding: pagePadding ?? this.pagePadding,
    );
  }

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) {
      return this;
    }
    return AppSpacing(
      xs: lerpDouble(xs, other.xs, t) ?? xs,
      sm: lerpDouble(sm, other.sm, t) ?? sm,
      md: lerpDouble(md, other.md, t) ?? md,
      lg: lerpDouble(lg, other.lg, t) ?? lg,
      xl: lerpDouble(xl, other.xl, t) ?? xl,
      pagePadding:
          EdgeInsets.lerp(pagePadding, other.pagePadding, t) ?? pagePadding,
    );
  }
}
