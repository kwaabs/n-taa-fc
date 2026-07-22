import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Field Collector brand seed — deeper blue for outdoor readability.
const Color brandSeed = Color(0xFF2563EB); // blue-600

/// Light surfaces: cool tint instead of pure white (friendlier contrast).
const Color _lightScaffold = Color(0xFFEEF2F7);
const Color _lightSurface = Color(0xFFF8FAFC);
const Color _lightCard = Color(0xFFFFFFFF);

ThemeData lightTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: brandSeed,
    brightness: Brightness.light,
  );

  final scheme = base.copyWith(
    primary: brandSeed,
    onPrimary: Colors.white,
    surface: _lightSurface,
    onSurface: const Color(0xFF0F172A),
    surfaceContainerLowest: _lightCard,
    surfaceContainerLow: const Color(0xFFE8EEF5),
    surfaceContainerHighest: const Color(0xFFD9E2EC),
    outlineVariant: const Color(0xFFCBD5E1),
  );

  return _buildTheme(
    scheme: scheme,
    textTheme: GoogleFonts.interTextTheme(),
    scaffoldBackground: _lightScaffold,
    appBarBackground: brandSeed,
    appBarForeground: Colors.white,
  );
}

ThemeData darkTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: brandSeed,
    brightness: Brightness.dark,
  );

  final scheme = base.copyWith(
    primary: const Color(0xFF60A5FA), // blue-400 — readable on dark
    onPrimary: const Color(0xFF0B1220),
    surface: const Color(0xFF0F172A),
    onSurface: const Color(0xFFE2E8F0),
    surfaceContainerLowest: const Color(0xFF1E293B),
    surfaceContainerLow: const Color(0xFF1E293B),
    surfaceContainerHighest: const Color(0xFF334155),
    outlineVariant: const Color(0xFF475569),
  );

  return _buildTheme(
    scheme: scheme,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    scaffoldBackground: const Color(0xFF0B1220),
    appBarBackground: const Color(0xFF1E293B),
    appBarForeground: const Color(0xFFF1F5F9),
  );
}

ThemeData _buildTheme({
  required ColorScheme scheme,
  required TextTheme textTheme,
  required Color scaffoldBackground,
  required Color appBarBackground,
  required Color appBarForeground,
}) {
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: scheme.brightness,
    scaffoldBackgroundColor: scaffoldBackground,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: appBarBackground,
      foregroundColor: appBarForeground,
      iconTheme: IconThemeData(color: appBarForeground),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: appBarForeground,
        fontWeight: FontWeight.w600,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.primary,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
    ),
  );
}

/// Persistable theme preference: `system` | `light` | `dark`.
enum AppThemeMode {
  system,
  light,
  dark;

  static AppThemeMode fromString(String? raw) {
    switch (raw) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
      default:
        return AppThemeMode.system;
    }
  }

  ThemeMode toFlutter() {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  String get storageValue => name;

  String get label {
    switch (this) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  String get description {
    switch (this) {
      case AppThemeMode.system:
        return 'Match device light/dark setting';
      case AppThemeMode.light:
        return 'Light theme with stronger contrast';
      case AppThemeMode.dark:
        return 'Dark theme for low light / maps';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.system:
        return Icons.brightness_auto;
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
    }
  }
}
