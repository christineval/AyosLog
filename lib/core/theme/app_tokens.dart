import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
  static const page = 22.0;
}

abstract final class AppRadii {
  static const field = 16.0, button = 16.0, card = 23.0, navigation = 29.0;
}

abstract final class AppTypography {
  static const heading =
      TextStyle(fontSize: 27, fontWeight: FontWeight.w700, height: 1.2);
  static const section = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const cardTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 14, height: 1.45);
  static const caption = TextStyle(fontSize: 12, height: 1.4);
}
