import 'package:flutter/widgets.dart';

abstract final class AppSpacingToken {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 16,
  );
}
