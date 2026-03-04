import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import 'app_text.dart';

class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: (color ?? context.colors.border).withValues(alpha: 0.25),
        borderRadius: context.appTheme.smallRadius,
      ),
      child: AppText(label, variant: AppTextVariant.caption),
    );
  }
}
