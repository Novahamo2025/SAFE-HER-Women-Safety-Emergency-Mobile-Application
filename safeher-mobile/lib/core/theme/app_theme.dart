import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand & Semantic Colors
  static const Color brandPrimary = Color(0xFF4F46E5); // Indigo 600 - Trust & Authority
  static const Color brandPrimaryDark = Color(0xFF3730A3); // Indigo 800
  static const Color brandPrimaryLight = Color(0xFFEEF2FF); // Indigo 50

  static const Color emergencyRed = Color(0xFFDC2626); // Red 600 - SOS & Urgent
  static const Color emergencyDarkRed = Color(0xFF991B1B); // Red 800
  static const Color emergencyLightRed = Color(0xFFFEF2F2); // Red 50

  static const Color safeGreen = Color(0xFF059669); // Emerald 600 - Confirmed Safe
  static const Color safeGreenDark = Color(0xFF065F46); // Emerald 800
  static const Color safeGreenLight = Color(0xFFECFDF5); // Emerald 50

  static const Color warningAmber = Color(0xFFD97706); // Amber 600 - Timers & Alerts
  static const Color warningLightAmber = Color(0xFFFFFBEB); // Amber 50

  static const Color infoBlue = Color(0xFF2563EB); // Blue 600
  static const Color infoLightBlue = Color(0xFFEFF6FF); // Blue 50

  // Neutral Palette
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9); // Slate 100
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color borderMedium = Color(0xFFCBD5E1); // Slate 300

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textTertiary = Color(0xFF94A3B8); // Slate 400

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: brandPrimary,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: brandPrimary,
        onPrimary: Colors.white,
        primaryContainer: brandPrimaryLight,
        onPrimaryContainer: brandPrimaryDark,
        secondary: Color(0xFF0EA5E9), // Sky 500
        onSecondary: Colors.white,
        error: emergencyRed,
        onError: Colors.white,
        errorContainer: emergencyLightRed,
        onErrorContainer: emergencyDarkRed,
        surface: surfaceWhite,
        onSurface: textPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
        displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        displaySmall: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
        headlineSmall: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        titleSmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary, height: 1.5),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary, height: 1.4),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: textTertiary),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brandPrimary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: emergencyRed, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: emergencyRed, width: 1.8),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: textTertiary, fontSize: 14),
        errorStyle: GoogleFonts.inter(color: emergencyRed, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: borderMedium),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandPrimary,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceWhite,
        elevation: 8,
        selectedItemColor: brandPrimary,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceWhite,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: textSecondary, height: 1.4),
      ),
    );
  }
}
