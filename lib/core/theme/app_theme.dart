import 'package:flutter/material.dart';

/// Shared corner radii.
class AppRadii {
  static const double md = 10;
  static const double lg = 12;
}

/// Colors that carry meaning rather than belonging to the Material scheme.
class AppSemanticColors {
  static const Color success = Color(0xFF34C759);
  static const Color danger = Color(0xFFE81123);
  static const Color rating = Color(0xFFFFB300);
}

/// The app-wide near-white page background.
const Color kAppBackground = Color(0xFFFCFDFF);

const Color _seed = Color(0xFFA8D8FF);

/// The single source of truth for the app's Material 3 theme.
ThemeData buildAppTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.light,
  );
  final scheme = base.copyWith(
    primary: const Color(0xFF5FB2FF),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFD9ECFF),
    onPrimaryContainer: const Color(0xFF0B3D66),
    secondary: const Color(0xFF6FB8FF),
    secondaryContainer: const Color(0xFFE3F0FF),
    onSecondaryContainer: const Color(0xFF0B3D66),
    surface: const Color(0xFFFFFFFF),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'NotoSansSC',
    fontFamilyFallback: const [
      'Microsoft YaHei UI',
      'Microsoft YaHei',
      'Segoe UI',
    ],
    scaffoldBackgroundColor: kAppBackground,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
        height: 1.4,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 40),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.secondaryContainer,
      labelStyle: TextStyle(
        fontSize: 12,
        color: scheme.onSecondaryContainer,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      padding: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.primary),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.5,
    ),
  );
}
