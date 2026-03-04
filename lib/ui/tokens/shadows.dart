import 'package:flutter/material.dart';

abstract final class AppShadowsToken {
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x14000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 10),
  ];
}
