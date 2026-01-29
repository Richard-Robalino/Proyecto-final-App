import 'package:flutter/material.dart';

class AppTheme {
  // Paleta TecniGO
  static const _brandOrange = Color(0xFFFF6B00); // Naranja Seguridad (Primary)
  static const _brandBlue = Color(0xFF0984E3);   // Azul Eléctrico (Secondary)
  static const _darkGrey = Color(0xFF2D3436);    // Gris Oscuro (Text/Nav)
  static const _bgLight = Color(0xFFFFFFFF);     // Blanco Limpio
  static const _bgDark = Color(0xFF1E272E);      // Gris Oscuro Profundo (Dark Mode)
  static const _surfaceGrey = Color(0xFFF5F6FA); // Gris suave para inputs

  static ThemeData light() {
    final cs = ColorScheme.fromSeed(
      seedColor: _brandOrange,
      primary: _brandOrange,
      secondary: _brandBlue,
      onSurface: _darkGrey,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs.copyWith(
        surface: _bgLight,
        // Forzamos el blanco puro en el fondo
        background: _bgLight, 
      ),
      scaffoldBackgroundColor: _bgLight,
      
      // Tipografía ajustada al Gris Oscuro
      textTheme: _textTheme(Brightness.light),
      
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: _bgLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: _darkGrey),
        titleTextStyle: _textTheme(Brightness.light)
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, color: _darkGrey),
      ),
      
      // Tarjetas: Sombras suaves y Radius 16px
      cardTheme: CardThemeData(
        elevation: 8, // Un poco más de elevación para destacar sobre blanco
        shadowColor: _brandOrange.withOpacity(0.25),
        color: Colors.white,
        surfaceTintColor: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Botones de Acción (Estilo Rappi/Uber)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandOrange,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5
          ),
        ),
      ),
      
      // Inputs: Fondo gris suave
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceGrey,
        labelStyle: TextStyle(color: _darkGrey.withOpacity(0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none, // Sin borde por defecto (más moderno)
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _brandOrange, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _darkGrey,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: _brandOrange,
      primary: _brandOrange,
      secondary: _brandBlue,
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
            ?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF2D3436),
        surfaceTintColor: const Color(0xFF2D3436),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2D3436),
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
    );
  }

  static TextTheme _textTheme(Brightness b) {
    final base = Typography.material2021().black;
    final isDark = b == Brightness.dark;
    
    // En modo claro usamos el Gris Oscuro (_darkGrey) en lugar de negro puro
    final primaryColor = isDark ? Colors.white : _darkGrey;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(color: primaryColor, fontWeight: FontWeight.bold),
      titleLarge: base.titleLarge?.copyWith(color: primaryColor, fontWeight: FontWeight.bold),
      titleMedium: base.titleMedium?.copyWith(color: primaryColor, fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(color: primaryColor, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(color: primaryColor),
      bodyMedium: base.bodyMedium?.copyWith(color: primaryColor.withOpacity(0.9)),
      bodySmall: base.bodySmall?.copyWith(color: primaryColor.withOpacity(0.75)),
      labelLarge: base.labelLarge?.copyWith(color: primaryColor, fontWeight: FontWeight.bold),
    );
  }
}