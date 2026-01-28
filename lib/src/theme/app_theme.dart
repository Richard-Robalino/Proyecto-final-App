import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF1E88E5); // azul profesional (Material)
  static const _bgLight = Color(0xFFF7F9FC);
  static const _bgDark = Color(0xFF0E1320);

  static ThemeData light() {
    final cs = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs.copyWith(surface: _bgLight),
      scaffoldBackgroundColor: _bgLight,
      textTheme: _textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: _bgLight,
        elevation: 0,
        titleTextStyle: _textTheme(Brightness.light)
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs.copyWith(surface: _bgDark),
      scaffoldBackgroundColor: _bgDark,
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: _bgDark,
        elevation: 0,
        titleTextStyle: _textTheme(Brightness.dark)
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF141B2D),
        surfaceTintColor: const Color(0xFF141B2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141B2D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static TextTheme _textTheme(Brightness b) {
    final base = Typography.material2021().black;
    final isDark = b == Brightness.dark;
    final color = isDark ? Colors.white : const Color(0xFF0E1A2B);

    return base.copyWith(
      titleLarge: base.titleLarge?.copyWith(color: color),
      titleMedium: base.titleMedium?.copyWith(color: color),
      titleSmall: base.titleSmall?.copyWith(color: color),
      bodyLarge: base.bodyLarge?.copyWith(color: color),
      bodyMedium: base.bodyMedium?.copyWith(color: color.withOpacity(0.9)),
      bodySmall: base.bodySmall?.copyWith(color: color.withOpacity(0.75)),
      labelLarge: base.labelLarge?.copyWith(color: color),
      labelMedium: base.labelMedium?.copyWith(color: color),
      labelSmall: base.labelSmall?.copyWith(color: color),
    );
  }
}
