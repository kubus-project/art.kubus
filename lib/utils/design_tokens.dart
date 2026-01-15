import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central source of truth for all Kubus design tokens.
/// This file defines the palette, spacing, radii, and typography to be used across the app.

class KubusColors {
  // Private constructor to prevent instantiation
  KubusColors._();

  // --- Brand Colors (Primary) ---
  static const Color primary = Color(0xFF00838F); // Deep Blue-Cyan
  static const Color primaryVariantLight = Color(0xFF0097A7);
  static const Color primaryVariantDark = Color(0xFF00ACC1); // Cyan 600

  // --- Secondary / Accents ---
  static const Color secondary = Color(0xCC00838F); // 80% opacity primary
  
  // --- Semantic Colors ---
  static const Color error = Color(0xFFE53935); // Red 600
  static const Color errorDark = Color(0xFFFF6B6B); // Coral Red
  
  static const Color success = Color(0xFF43A047); // Green 600
  static const Color successDark = Color(0xFF4CAF50); // Green 500

  static const Color warning = Color(0xFFFFA000); // Amber 700
  static const Color warningDark = Color(0xFFFFB300); // Amber 600

  // --- Neutrals (Backgrounds & Surfaces) ---
  static const Color backgroundLight = Color(0xFFF8F9FA); // Off-white
  static const Color backgroundDark = Color(0xFF0A0A0A); // Deep black

  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceDark = Color(0xFF1A1A1A); // Dark grey

  static const Color outlineLight = Color(0xFFE0E0E0); // Grey 300
  static const Color outlineDark = Color(0xFF424242); // Grey 800

  // --- Text Colors ---
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);

  static const Color textSecondaryLight = Color(0xFF757575); // Grey 600
  static const Color textSecondaryDark = Color(0xFFB0B0B0); // Grey 400
}

class KubusSpacing {
  KubusSpacing._();

  /// 0.0
  static const double none = 0.0;
  
  /// 2.0 - Tiny offsets
  static const double xxs = 2.0;
  
  /// 4.0 - Tight grouping
  static const double xs = 4.0;
  
  /// 8.0 - Standard inner spacing
  static const double sm = 8.0;
  
  /// 16.0 - Standard padding/margin
  static const double md = 16.0;
  
  /// 24.0 - Section separation
  static const double lg = 24.0;
  
  /// 32.0 - Major separation
  static const double xl = 32.0;
  
  /// 48.0 - Hero or large separation
  static const double xxl = 48.0;
}

class KubusRadius {
  KubusRadius._();

  /// 4.0 - Small inner elements
  static const double xs = 4.0;
  
  /// 8.0 - Buttons, Inputs
  static const double sm = 8.0;
  
  /// 12.0 - Cards, Dialogs standard
  static const double md = 12.0;

  /// 16.0 - Large Containers, bottom sheets
  static const double lg = 16.0;

  /// 24.0 - Pills, large rounded edges
  static const double xl = 24.0;
  
  /// Returns a circular border radius for a given value
  static BorderRadius circular(double radius) => BorderRadius.circular(radius);
}

class KubusTypography {
  KubusTypography._();
  
  static TextTheme get textTheme {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 32),
      displayMedium: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 28),
      displaySmall: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 24),
      
      headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20),
      headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
      
      titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
      
      bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 16),
      bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 14),
      
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      labelMedium: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
      labelSmall: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 10),
    );
  }
}
