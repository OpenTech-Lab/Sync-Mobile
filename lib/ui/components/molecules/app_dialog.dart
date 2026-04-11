import 'package:flutter/material.dart';

import '../../tokens/colors/app_palette.dart';

@immutable
class AppDialogColors {
  const AppDialogColors._({
    required this.background,
    required this.ink,
    required this.muted,
    required this.rule,
  });

  final Color background;
  final Color ink;
  final Color muted;
  final Color rule;

  static AppDialogColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppDialogColors._(
      background: isDark ? AppPalette.neutral900 : AppPalette.neutral50,
      ink: isDark ? AppPalette.neutral100 : AppPalette.neutral800,
      muted: AppPalette.neutral500,
      rule: isDark ? AppPalette.neutral700 : AppPalette.neutral300,
    );
  }
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.eyebrow,
    required this.title,
    this.message,
    this.body,
    this.actions,
    this.showDividerAboveActions = false,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 44,
    ),
    this.contentPadding = const EdgeInsets.fromLTRB(24, 24, 24, 20),
    this.borderRadius = 6,
    this.bodySpacing = 18,
  });

  final String? eyebrow;
  final String title;
  final String? message;
  final Widget? body;
  final Widget? actions;
  final bool showDividerAboveActions;
  final EdgeInsets insetPadding;
  final EdgeInsets contentPadding;
  final double borderRadius;
  final double bodySpacing;

  @override
  Widget build(BuildContext context) {
    final colors = AppDialogColors.of(context);
    final children = <Widget>[
      if (eyebrow != null) ...[
        Text(
          eyebrow!,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2.4,
            color: colors.muted,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
      ],
      Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w300,
          color: colors.ink,
          height: 1.35,
        ),
      ),
      if (message != null) ...[
        const SizedBox(height: 12),
        Text(
          message!,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w300,
            color: colors.muted,
            height: 1.45,
          ),
        ),
      ],
      if (body != null) ...[SizedBox(height: bodySpacing), body!],
      if (actions != null) ...[
        const SizedBox(height: 18),
        if (showDividerAboveActions) ...[
          Divider(height: 1, color: colors.rule),
          const SizedBox(height: 14),
        ],
        actions!,
      ],
    ];

    return Dialog(
      backgroundColor: colors.background,
      surfaceTintColor: AppPalette.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      insetPadding: insetPadding,
      child: Padding(
        padding: contentPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class AppDialogActions extends StatelessWidget {
  const AppDialogActions({
    super.key,
    required this.children,
    this.spacing = 24,
    this.runSpacing = 10,
    this.alignment = WrapAlignment.end,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      spacing: spacing,
      runSpacing: runSpacing,
      children: children,
    );
  }
}

class AppDialogTextAction extends StatelessWidget {
  const AppDialogTextAction({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
    this.fontSize = 13,
    this.letterSpacing = 0.3,
    this.fontWeight = FontWeight.w400,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double fontSize;
  final double letterSpacing;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (!states.contains(WidgetState.pressed)) {
            return null;
          }
          return color.withValues(alpha: 0.08);
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              letterSpacing: letterSpacing,
              fontWeight: fontWeight,
            ),
          ),
        ),
      ),
    );
  }
}
