import 'package:flutter/material.dart';

import '../tokens/colors/app_colors.dart';
import '../tokens/typography/app_text_styles.dart';

@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.display,
    required this.title,
    required this.body,
    required this.label,
    required this.caption,
  });

  final TextStyle display;
  final TextStyle title;
  final TextStyle body;
  final TextStyle label;
  final TextStyle caption;

  factory AppTypography.fromColors(AppColors colors) {
    return AppTypography(
      display: AppTextStyles.display(colors),
      title: AppTextStyles.title(colors),
      body: AppTextStyles.body(colors),
      label: AppTextStyles.label(colors),
      caption: AppTextStyles.caption(colors),
    );
  }

  @override
  AppTypography copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? body,
    TextStyle? label,
    TextStyle? caption,
  }) {
    return AppTypography(
      display: display ?? this.display,
      title: title ?? this.title,
      body: body ?? this.body,
      label: label ?? this.label,
      caption: caption ?? this.caption,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) {
      return this;
    }
    return AppTypography(
      display: TextStyle.lerp(display, other.display, t) ?? display,
      title: TextStyle.lerp(title, other.title, t) ?? title,
      body: TextStyle.lerp(body, other.body, t) ?? body,
      label: TextStyle.lerp(label, other.label, t) ?? label,
      caption: TextStyle.lerp(caption, other.caption, t) ?? caption,
    );
  }
}
