import 'package:flutter/material.dart';

import '../tokens/colors/app_colors.dart';
import '../tokens/radius.dart';
import '../tokens/shadows.dart';

@immutable
class AppTheme extends ThemeExtension<AppTheme> {
  const AppTheme({
    required this.colors,
    required this.smallRadius,
    required this.mediumRadius,
    required this.largeRadius,
    required this.shadowSm,
    required this.shadowMd,
  });

  final AppColors colors;
  final BorderRadius smallRadius;
  final BorderRadius mediumRadius;
  final BorderRadius largeRadius;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;

  factory AppTheme.light() {
    return AppTheme(
      colors: AppColors.light(),
      smallRadius: const BorderRadius.all(Radius.circular(AppRadiusToken.sm)),
      mediumRadius: AppRadiusToken.mdRadius,
      largeRadius: AppRadiusToken.lgRadius,
      shadowSm: AppShadowsToken.sm,
      shadowMd: AppShadowsToken.md,
    );
  }

  factory AppTheme.dark() {
    return AppTheme(
      colors: AppColors.dark(),
      smallRadius: const BorderRadius.all(Radius.circular(AppRadiusToken.sm)),
      mediumRadius: AppRadiusToken.mdRadius,
      largeRadius: AppRadiusToken.lgRadius,
      shadowSm: AppShadowsToken.sm,
      shadowMd: AppShadowsToken.md,
    );
  }

  @override
  AppTheme copyWith({
    AppColors? colors,
    BorderRadius? smallRadius,
    BorderRadius? mediumRadius,
    BorderRadius? largeRadius,
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
  }) {
    return AppTheme(
      colors: colors ?? this.colors,
      smallRadius: smallRadius ?? this.smallRadius,
      mediumRadius: mediumRadius ?? this.mediumRadius,
      largeRadius: largeRadius ?? this.largeRadius,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
    );
  }

  @override
  AppTheme lerp(ThemeExtension<AppTheme>? other, double t) {
    if (other is! AppTheme) {
      return this;
    }
    return AppTheme(
      colors: t < 0.5 ? colors : other.colors,
      smallRadius:
          BorderRadius.lerp(smallRadius, other.smallRadius, t) ?? smallRadius,
      mediumRadius:
          BorderRadius.lerp(mediumRadius, other.mediumRadius, t) ??
          mediumRadius,
      largeRadius:
          BorderRadius.lerp(largeRadius, other.largeRadius, t) ?? largeRadius,
      shadowSm: t < 0.5 ? shadowSm : other.shadowSm,
      shadowMd: t < 0.5 ? shadowMd : other.shadowMd,
    );
  }
}
