import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color neonPink = Color(0xFFFF00CC);
  static const Color neonBlue = Color(0xFF33CCFF);
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: neonPink,
        secondary: neonBlue,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonPink,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonPink, width: 2),
        ),
      ),
    );
  }
}
