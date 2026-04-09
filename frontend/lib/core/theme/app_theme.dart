import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF1A5276); // Mine safety blue
  static const _warningColor = Color(0xFFF39C12); // Amber warning
  static const _dangerColor = Color(0xFFC0392B);  // Safety red

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.dark,
    ),
  );

  // Semantic colours for PPE status badges
  static Color statusColor(String status) {
    switch (status) {
      case 'valid': return Colors.green;
      case 'expiring_soon': return _warningColor;
      case 'expired': return _dangerColor;
      case 'blocked': return Colors.grey;
      case 'pending_issue': return Colors.blue;
      default: return Colors.grey;
    }
  }
}
