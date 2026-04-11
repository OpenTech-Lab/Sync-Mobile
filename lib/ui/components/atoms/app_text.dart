import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';

enum AppTextVariant { display, title, body, label, caption }

class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.variant = AppTextVariant.body,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.style,
  });

  final String data;
  final AppTextVariant variant;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final tt = context.appTypography;
    final baseStyle = switch (variant) {
      AppTextVariant.display => tt.display,
      AppTextVariant.title => tt.title,
      AppTextVariant.body => tt.body,
      AppTextVariant.label => tt.label,
      AppTextVariant.caption => tt.caption,
    };
    return Text(
      data,
      style: baseStyle.merge(style),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
