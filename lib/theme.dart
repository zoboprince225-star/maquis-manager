import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF232647);
  static const background = Color(0xFF14162B);
  static const card = Color(0xFF1E2140);
  static const orange = Color(0xFFE8801E);
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.orange,
      secondary: AppColors.orange,
      surface: AppColors.card,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.navy,
      indicatorColor: Color(0x40E8801E),
    ),
  );
}
