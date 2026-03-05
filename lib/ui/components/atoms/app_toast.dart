import 'package:flutter/material.dart';

import '../../tokens/colors/app_palette.dart';

enum AppToastVariant { neutral, error }

/// Shows a styled floating snackbar consistent with the app's minimal design.
///
/// [variant] defaults to [AppToastVariant.neutral] (dark muted pill).
/// Use [AppToastVariant.error] for failure/warning feedback.
/// [duration] defaults to 2 400 ms; pass a shorter value for quick confirms.
void showAppToast(
  BuildContext context,
  String message, {
  AppToastVariant variant = AppToastVariant.neutral,
  Duration duration = const Duration(milliseconds: 2400),
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final Color background;
  switch (variant) {
    case AppToastVariant.neutral:
      background = isDark ? AppPalette.neutral800 : AppPalette.neutral700;
    case AppToastVariant.error:
      background = AppPalette.danger700;
  }

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w300,
          color: AppPalette.neutral100,
          letterSpacing: 0.2,
        ),
      ),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 20),
      backgroundColor: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}
