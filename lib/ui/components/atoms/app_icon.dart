import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = 20, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color ?? context.colors.onSurface);
  }
}
