import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Newer shared color system for the app UI.
  static const Color primary = Color(0xFF0B6B43);
  static const Color primaryLight = Color(0xFFEAF7F0);

  static const Color background = Color.fromARGB(255, 252, 252, 254);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFDC2626);
  static const Color muted = Color(0xFF9CA3AF);

  // Backward-compatible aliases so older teammate code still compiles.
  static const Color darkGreen = primary;
  static const Color brightGreen = Color(0xFF2DBF73);

  static const Color white = Colors.white;
  static const Color black = Colors.black;

  static const Color grayText = textSecondary;
  static const Color mediumGray = muted;
  static const Color lightGray = Color(0xFFEDEDED);
  static const Color darkGray = Color(0xFF484444);
}
