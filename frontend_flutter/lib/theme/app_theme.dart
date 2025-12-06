import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const primaryColor = Color(0xFF1C6758); // 深树林绿
  const accentColor = Color(0xFFF4A261); // 柔和橙金
  const background = Color(0xFFF5F5F2); // 暖白灰

  final colorScheme = ColorScheme.fromSeed(
    seedColor: primaryColor,
    primary: primaryColor,
    secondary: accentColor,
    background: background,
    surface: Colors.white,
  );

  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: background,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: Colors.black87,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: const Color(0xFF293241),
      displayColor: const Color(0xFF293241),
      fontFamily: 'Roboto',
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withOpacity(0.9),
      indicatorColor: primaryColor.withOpacity(0.12),
      elevation: 8,
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
  );
}
