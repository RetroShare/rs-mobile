import 'package:flutter/material.dart';

final lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF29ABE2),
    surface: Colors.white,
  ),
  fontFamily: 'Oxygen',
  appBarTheme: const AppBarWidgetTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
  ),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF29ABE2),
    brightness: Brightness.dark,
    surface: const Color(0xFF121212),
  ),
  fontFamily: 'Oxygen',
  appBarTheme: const AppBarWidgetTheme(
    backgroundColor: Color(0xFF121212),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
);

// Helper for older versions of Flutter if needed, though project is on 3.27+
typedef AppBarWidgetTheme = AppBarTheme;
