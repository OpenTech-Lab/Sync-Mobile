import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, outlined }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case AppButtonVariant.primary:
        return FilledButton(onPressed: onPressed, child: Text(label));
      case AppButtonVariant.secondary:
        return FilledButton.tonal(onPressed: onPressed, child: Text(label));
      case AppButtonVariant.outlined:
        return OutlinedButton(onPressed: onPressed, child: Text(label));
    }
  }
}
