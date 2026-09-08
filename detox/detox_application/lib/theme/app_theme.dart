import 'package:flutter/material.dart';

/// Central place for the app's look. Screens and widgets should always read
/// colors through `Theme.of(context).colorScheme` rather than `Colors.*`
/// literals, so a future theme-selection feature only needs to add more
/// [ThemeData] variants here instead of touching every screen.
class AppTheme {
  const AppTheme._();

  static const fontFamily = 'PeachesForBreakfast';

  /// Extra tracking (space between letters, in logical pixels) for the alarm
  /// clock time and its caption. `PeachesForBreakfast` packs its glyphs
  /// tightly, so the big time reads better with a little air. Applied only
  /// where the alarm time is shown, not to the whole app.
  static const clockLetterSpacing = 7.50;

  /// Default launch theme: plain paper white background, black ink.
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      surface: Colors.white,
      onSurface: Colors.black,
      primary: Colors.black,
      onPrimary: Colors.white,
      secondary: Colors.black,
      onSecondary: Colors.white,
      error: Color(0xFFB3261E),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurface,
          fontSize: 26,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurface,
          fontSize: 88,
          height: 1.0,
        ),
        displayMedium: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurface,
          fontSize: 64,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurface,
          fontSize: 40,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurface,
          fontSize: 28,
        ),
        titleMedium: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurface,
          fontSize: 22,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurface,
          fontSize: 22,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          color: colorScheme.onSurface,
          fontSize: 18,
        ),
      ),
    );
  }
}
