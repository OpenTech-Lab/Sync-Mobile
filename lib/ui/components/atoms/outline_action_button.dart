import 'package:flutter/material.dart';
import '../../tokens/colors/app_palette.dart';

enum OutlineActionVariant { normal, danger }

/// A bordered, spaced-caps action button.
///
/// Supports two variants:
/// - [OutlineActionVariant.normal] – neutral border with no background tint.
/// - [OutlineActionVariant.danger] – red border with a subtle red background
///   tint, used for destructive actions.
///
/// Set [disabled] to grey out the button without removing it from the layout.
/// Set [compact] for a tighter padding (e.g. AppBar), otherwise uses the
/// standard row/full-width padding.
class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    super.key,
    required this.label,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
    this.variant = OutlineActionVariant.normal,
    this.disabled = false,
    this.compact = false,
  });

  final String label;
  final Color borderColor;
  final Color textColor;
  final VoidCallback? onTap;
  final OutlineActionVariant variant;
  final bool disabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDanger = variant == OutlineActionVariant.danger;
    final effectiveBorder =
        disabled ? borderColor.withValues(alpha: 0.3) : borderColor;
    final effectiveText =
        disabled ? textColor.withValues(alpha: 0.35) : textColor;
    final bgColor =
        isDanger ? AppPalette.danger700.withValues(alpha: 0.06) : null;
    final splashColor =
        isDanger ? AppPalette.danger700.withValues(alpha: 0.12) : null;
    final radius = compact ? 8.0 : 10.0;
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.symmetric(vertical: 14);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: effectiveBorder, width: 1),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: splashColor,
          child: Padding(
            padding: padding,
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w500,
                color: effectiveText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
