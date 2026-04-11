import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: context.appTheme.mediumRadius,
        border: Border.all(color: context.colors.border),
        boxShadow: context.appTheme.shadowSm,
      ),
      child: child,
    );
  }
}
