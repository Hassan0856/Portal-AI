import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFF2F1EF);
  static const coolWhite = Color(0xFFF8F8FC);
  static const ivory = Color(0xFFF0EFEA);
  static const paleBlue = Color(0xFFEAF0FC);

  static const primary = Color(0xFF172451);
  static const secondary = Color(0xFF7187AD);
  static const muted = Color(0xFF91A2C2);
  static const navy = Color(0xFF111936);

  static const indigo = Color(0xFF5559D9);
  static const iconBlue = Color(0xFF555ED6);
  static const peri = Color(0xFF7E8BFF);
  static const softBlue = Color(0xFF8999FF);
  static const lavender = Color(0xFFB7A5F1);
  static const paleLavender = Color(0xFFDCD7FF);
  static const purple = Color(0xFFC9B8F6);
  static const palePink = Color(0xFFE5C8F1);
  static const glowBlue = Color(0xFFD8E4FF);
  static const glowIndigo = Color(0xFF373A91);

  static const heat = [
    Color(0xFFC9F0DE),
    Color(0xFFF8EDB7),
    Color(0xFFF8D2C3),
    Color(0xFFF3BBD0),
  ];

  static const success = Color(0xFF72BFAE);
  static const warning = Color(0xFFE8C66C);
  static const high = Color(0xFFD77F99);
  static const critical = Color(0xFFE56B91);
  static const coral = Color(0xFFE78F91);

  static const buttonGradient = LinearGradient(
    colors: [Color(0xFF8999FF), Color(0xFFA1A0FA), Color(0xFFC3A4F4)],
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.indigo,
    surface: AppColors.bg,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: Typography.blackMountainView.apply(
      bodyColor: AppColors.primary,
      displayColor: AppColors.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
