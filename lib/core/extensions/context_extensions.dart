import 'package:flutter/material.dart';

import '../../ui/extensions/app_spacing.dart';
import '../../ui/extensions/app_theme.dart';
import '../../ui/extensions/app_typography.dart';
import '../../ui/tokens/colors/app_colors.dart';

extension BuildContextThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);

  AppTheme get appTheme => theme.extension<AppTheme>() ?? AppTheme.light();

  AppColors get colors => appTheme.colors;

  AppTypography get appTypography =>
      theme.extension<AppTypography>() ?? AppTypography.fromColors(colors);

  AppSpacing get spacing =>
      theme.extension<AppSpacing>() ?? AppSpacing.regular();
}
