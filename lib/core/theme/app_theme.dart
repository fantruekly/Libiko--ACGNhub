import 'package:flutter/material.dart';

/// Shared corner radii.
class AppRadii {
  static const double md = 12;
  static const double lg = 16;
}

/// Colors that carry meaning rather than belonging to the Material scheme.
class AppSemanticColors {
  static const Color success = Color(0xFF34C759);
  static const Color danger = Color(0xFFE81123);
  static const Color rating = Color(0xFFFFB300);
}

/// The app-wide near-white page background.
const Color kAppBackground = Color(0xFFF5F7FA);

const Color _seed = Color(0xFF527FAF);
const Color _darkBackground = Color(0xFF151A22);

/// The single source of truth for the app's Material 3 themes.
ThemeData buildAppTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.light,
  );
  final scheme = base.copyWith(
    primary: const Color(0xFF326EAA),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFDDEBFA),
    onPrimaryContainer: const Color(0xFF214E7A),
    secondary: const Color(0xFF58718E),
    secondaryContainer: const Color(0xFFE4EDF7),
    onSecondaryContainer: const Color(0xFF2B527C),
    surface: const Color(0xFFFFFFFF),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF0F3F7),
    surfaceContainer: const Color(0xFFECF0F5),
    surfaceContainerHigh: const Color(0xFFE7EDF4),
    surfaceContainerHighest: const Color(0xFFE1E8F0),
    onSurface: const Color(0xFF1C2736),
    onSurfaceVariant: const Color(0xFF626E7E),
    outline: const Color(0xFF8693A4),
    outlineVariant: const Color(0xFFD6DEE8),
  );
  return _buildTheme(scheme, kAppBackground);
}

ThemeData buildAppDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF92BDEB),
    onPrimary: const Color(0xFF173755),
    primaryContainer: const Color(0xFF2A4564),
    onPrimaryContainer: const Color(0xFFDCEBFD),
    secondary: const Color(0xFFADBED3),
    secondaryContainer: const Color(0xFF2D4058),
    onSecondaryContainer: const Color(0xFFD9E8FA),
    surface: const Color(0xFF1D242F),
    surfaceContainerLowest: const Color(0xFF131820),
    surfaceContainerLow: const Color(0xFF202834),
    surfaceContainer: const Color(0xFF252E3B),
    surfaceContainerHigh: const Color(0xFF2B3543),
    surfaceContainerHighest: const Color(0xFF323D4C),
    onSurface: const Color(0xFFE7EDF5),
    onSurfaceVariant: const Color(0xFFA7B3C3),
    outline: const Color(0xFF7C8B9E),
    outlineVariant: const Color(0xFF3B4757),
  );
  return _buildTheme(scheme, _darkBackground);
}

ThemeData _buildTheme(ColorScheme scheme, Color background) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'NotoSansSC',
    fontFamilyFallback: const [
      'Microsoft YaHei UI',
      'Microsoft YaHei',
      'Segoe UI',
    ],
    scaffoldBackgroundColor: background,
    textTheme: const TextTheme(
      headlineLarge:
          TextStyle(fontSize: 30, height: 1.35, fontWeight: FontWeight.w600),
      headlineMedium:
          TextStyle(fontSize: 26, height: 1.4, fontWeight: FontWeight.w600),
      headlineSmall:
          TextStyle(fontSize: 22, height: 1.4, fontWeight: FontWeight.w600),
      titleLarge:
          TextStyle(fontSize: 20, height: 1.4, fontWeight: FontWeight.w600),
      titleMedium:
          TextStyle(fontSize: 16, height: 1.45, fontWeight: FontWeight.w500),
      titleSmall:
          TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 16, height: 1.6),
      bodyMedium: TextStyle(fontSize: 14, height: 1.55),
      bodySmall: TextStyle(fontSize: 12, height: 1.5),
      labelLarge:
          TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w500),
      labelMedium:
          TextStyle(fontSize: 12, height: 1.35, fontWeight: FontWeight.w500),
      labelSmall:
          TextStyle(fontSize: 11, height: 1.35, fontWeight: FontWeight.w500),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontFamily: 'NotoSansSC',
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
        height: 1.4,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 44),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: const TextStyle(
            fontFamily: 'NotoSansSC',
            fontSize: 15,
            fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: const TextStyle(
            fontFamily: 'NotoSansSC',
            fontSize: 15,
            fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.secondaryContainer,
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      labelStyle: TextStyle(
        fontFamily: 'NotoSansSC',
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
      fillColor: scheme.surfaceContainerLow,
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
