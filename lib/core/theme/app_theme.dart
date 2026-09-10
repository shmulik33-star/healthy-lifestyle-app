import 'package:flutter/material.dart';

/// "Navy/terracotta" palette -- approved design refresh (mockup: 5 screens,
/// see `claude/design_handoff_navy_terracotta.md`). Replaces the previous
/// coral/energetic palette. Existing constant *names* are kept unchanged so
/// every screen that already references `AppTheme.coral`, `AppTheme.ink`,
/// etc. picks up the new colors automatically -- only `purple` (fitness
/// screen's workout icon accent) is intentionally left untouched, as it
/// predates any of these palettes and isn't part of this redesign.
class AppTheme {
  /// Primary accent -- buttons, active tab, protein bar, steps icon, links.
  static const navy = Color(0xFF28536B);

  /// Secondary (warm) accent -- carbs bar, water icon/cups, "not yet done"
  /// pill, coach note, "meat" kosher dot.
  static const terracotta = Color(0xFFC2948A);

  /// Tertiary (warm neutral) accent -- fat bar, "parve" kosher dot, inactive
  /// nav label.
  static const khaki = Color(0xFFBBB193);

  /// Quaternary (decorative) accent -- calorie-ring backdrop, "dairy"
  /// kosher dot.
  static const softBlue = Color(0xFF7EA8BE);

  static const screenBackground = Color(0xFFF6F0ED);
  static const cardBackground = Color(0xFFFFFFFF);

  // Legacy names kept for source compatibility, remapped onto the new
  // palette above (see class doc).
  static const coral = navy;
  static const teal = softBlue;
  static const lavender = navy;
  static const sunny = terracotta;
  static const background = screenBackground;
  static const ink = navy;

  // Unchanged -- not covered by the navy/terracotta mapping.
  static const mint = Color(0xFF38B27A);
  static const softMint = Color(0xFFEFF9F1);
  static const purple = Color(0xFF8B5CF6);

  /// Secondary/subtitle text -- navy at reduced opacity, per design spec
  /// (not a `const` since `Color.withValues` isn't a const constructor).
  static final warmMuted = navy.withValues(alpha: .62);

  /// Tint background for chips/active state/progress track.
  static final navyTint = navy.withValues(alpha: .10);

  /// Tint background for the "not yet done" pill / coach card.
  static final terracottaTint = terracotta.withValues(alpha: .18);

  static List<BoxShadow> get pillShadow => [
        BoxShadow(color: navy.withValues(alpha: .32), blurRadius: 24, offset: const Offset(0, 12)),
        BoxShadow(color: navy.withValues(alpha: .22), blurRadius: 8, offset: const Offset(0, 3)),
      ];

  static List<BoxShadow> get secondaryPillShadow => [
        BoxShadow(color: navy.withValues(alpha: .13), blurRadius: 14, offset: const Offset(0, 5)),
      ];

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: screenBackground,
      fontFamily: 'Rubik',
      textTheme: const TextTheme(
        // כותרת מסך ("תזונה", "כושר" וכו') / ברכה
        headlineSmall: TextStyle(fontFamily: 'Rubik', fontSize: 23, fontWeight: FontWeight.w700, color: navy),
        titleLarge: TextStyle(fontFamily: 'Rubik', fontSize: 23, fontWeight: FontWeight.w700, color: navy),
        // כותרת מדור (למשל "ארוחת בוקר")
        titleMedium: TextStyle(fontFamily: 'Rubik', fontSize: 15, fontWeight: FontWeight.w600, color: navy),
        // כותרת כרטיס / תווית מוטה
        titleSmall: TextStyle(fontFamily: 'Rubik', fontSize: 14, fontWeight: FontWeight.w600, color: navy),
        bodyLarge: TextStyle(fontFamily: 'Rubik', fontSize: 14.5, height: 1.45, color: navy),
        bodyMedium: TextStyle(fontFamily: 'Rubik', fontSize: 14, height: 1.4, color: navy),
        // תווית ניווט תחתון
        labelSmall: TextStyle(fontFamily: 'Rubik', fontSize: 12, fontWeight: FontWeight.w500, color: navy),
        // טקסט כפתור
        labelLarge: TextStyle(fontFamily: 'Rubik', fontSize: 16, fontWeight: FontWeight.w600, color: navy),
      ),
      cardTheme: CardThemeData(
        elevation: 1.5,
        margin: EdgeInsets.zero,
        color: cardBackground,
        shadowColor: navy.withValues(alpha: .10),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(22))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          shape: const StadiumBorder(),
          elevation: 8,
          shadowColor: navy.withValues(alpha: .35),
          textStyle: const TextStyle(fontFamily: 'Rubik', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          shape: const StadiumBorder(),
          elevation: 8,
          shadowColor: navy.withValues(alpha: .35),
          textStyle: const TextStyle(fontFamily: 'Rubik', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          shape: const StadiumBorder(),
          side: BorderSide(color: navy.withValues(alpha: .25)),
          textStyle: const TextStyle(fontFamily: 'Rubik', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: navy,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: 'Rubik', fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardBackground,
        selectedColor: navy,
        labelStyle: const TextStyle(fontFamily: 'Rubik', fontSize: 13.5, fontWeight: FontWeight.w500, color: navy),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        elevation: 1,
        shadowColor: navy.withValues(alpha: .12),
      ),
    );
  }
}
