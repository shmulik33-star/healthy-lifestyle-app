import 'package:flutter/material.dart';

/// "Energetic/playful" palette -- the direction the product owner picked
/// out of three mockup options drafted for the home-screen redesign, now
/// wired into the base theme so it cascades to every screen (per explicit
/// follow-up feedback: "continue with this design for the secondary
/// screens too"). `purple` is kept separate from `lavender` -- it's an
/// existing small accent (fitness_screen's workout icon) that predates
/// this palette and wasn't part of the redesign, left alone on purpose.
class AppTheme {
  static const coral = Color(0xFFFF6B4A);
  static const teal = Color(0xFF3AB6C9);
  static const lavender = Color(0xFF8B7FE8);
  static const sunny = Color(0xFFFFC93C);
  static const mint = Color(0xFF38B27A);
  static const softMint = Color(0xFFEFF9F1);
  static const purple = Color(0xFF8B5CF6);
  static const background = Color(0xFFFFF8EE);
  static const ink = Color(0xFF221A12);
  static const warmMuted = Color(0xFF7A6E5F);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: coral,
      brightness: Brightness.light,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Assistant',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontFamily: 'Rubik', fontWeight: FontWeight.w800, color: ink),
        titleLarge: TextStyle(fontFamily: 'Rubik', fontWeight: FontWeight.w800, color: ink),
        titleMedium: TextStyle(fontFamily: 'Rubik', fontWeight: FontWeight.w700, color: ink),
        bodyLarge: TextStyle(height: 1.45, color: ink),
        bodyMedium: TextStyle(height: 1.4, color: ink),
      ),
      cardTheme: CardThemeData(
        elevation: 1.5,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shadowColor: ink.withValues(alpha: .10),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
