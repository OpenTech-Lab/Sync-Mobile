import 'package:flutter/widgets.dart';

abstract final class AppRadiusToken {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
}
