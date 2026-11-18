import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Medixmart Plus Design System color tokens (`--mm-color-*`).
abstract final class MmColors {
  // Background tokens
  static const Color bgCanvas = Color(0xFFF8FAFC);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgSubtle = Color(0xFFF1F5F9);
  static const Color bgBrand = Color(0xFF49944F);
  static const Color bgBrandSubtle = Color(0xFFF2F8F3);
  static const Color bgWarningSubtle = Color(0xFFFFFBEB);
  static const Color bgDanger = Color(0xFFEE4655);
  static const Color bgDangerSubtle = Color(0xFFFEF2F3);
  static const Color bgInfoSubtle = Color(0xFFEFF6FF);

  // Text tokens
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textBrand = Color(0xFF3B7A40);
  static const Color textOnBrand = Color(0xFFFFFFFF);
  static const Color textWarning = Color(0xFFB45309);
  static const Color textDanger = Color(0xFFDB293B);
  static const Color textInfo = Color(0xFF2563EB);

  // Border tokens
  static const Color borderDefault = Color(0xFFE2E8F0);
  static const Color borderBrand = Color(0xFF49944F);
  static const Color borderWarning = Color(0xFFF59E0B);
  static const Color borderDanger = Color(0xFFEE4655);

  // Icon tokens
  static const Color iconPrimary = Color(0xFF334155);
  static const Color iconBrand = Color(0xFF49944F);
  static const Color iconOnBrand = Color(0xFFFFFFFF);
}

/// Medixmart Plus Design System spacing tokens (`--mm-spacing-*`).
abstract final class MmSpacing {
  static const double none = 0.0;
  static const double xxs = 2.0; // --mm-spacing-2xs
  static const double xs = 4.0; // --mm-spacing-xs
  static const double sm = 8.0; // --mm-spacing-sm
  static const double md = 12.0; // --mm-spacing-md
  static const double lg = 16.0; // --mm-spacing-lg
  static const double xl = 20.0; // --mm-spacing-xl
  static const double xxl = 24.0; // --mm-spacing-2xl
  static const double xxxl = 32.0; // --mm-spacing-3xl
}

/// Medixmart Plus Design System radius tokens (`--mm-radius-*`).
abstract final class MmRadius {
  static const double sm = 6.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double emblem = 20.0;
  static const double full = 9999.0;
}

/// Medixmart Plus Design System stroke and elevation tokens.
abstract final class MmElevation {
  static const double strokeThin = 1.0;

  /// Elevation/XS: offset (0, 1), blur 2, spread 0, color #0F17290A
  static const List<BoxShadow> xs = [
    BoxShadow(
      color: Color(0x0A0F1729),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];
}

/// Medixmart Plus Design System typography styles.
abstract final class MmTypography {
  /// Heading/H1: Inter Bold, 28px / 36px, letterSpacing -0.5
  static TextStyle get headingH1 => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        letterSpacing: -0.5,
        color: MmColors.textPrimary,
      );

  /// Heading/H2: Inter SemiBold, 22px / 30px, letterSpacing -0.3
  static TextStyle get headingH2 => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 30 / 22,
        letterSpacing: -0.3,
        color: MmColors.textPrimary,
      );

  /// Heading/H3: Inter SemiBold, 18px / 26px, letterSpacing -0.2
  static TextStyle get headingH3 => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 26 / 18,
        letterSpacing: -0.2,
        color: MmColors.textPrimary,
      );

  /// Heading/H4: Inter SemiBold, 15px / 22px, letterSpacing 0
  static TextStyle get headingH4 => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 22 / 15,
        letterSpacing: 0,
        color: MmColors.textPrimary,
      );

  /// Label/Large: Inter Medium, 14px / 20px, letterSpacing 0
  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0,
        color: MmColors.textPrimary,
      );

  /// Label/Medium: Inter Medium, 12px / 16px, letterSpacing 0.1
  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.1,
        color: MmColors.textPrimary,
      );

  /// Label/Small: Inter SemiBold, 11px / 16px, letterSpacing 0.3
  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 16 / 11,
        letterSpacing: 0.3,
        color: MmColors.textPrimary,
      );

  /// Body/Medium: Inter Regular, 14px / 20px, letterSpacing 0
  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        letterSpacing: 0,
        color: MmColors.textPrimary,
      );

  /// Body/Small: Inter Regular, 12px / 18px, letterSpacing 0
  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 18 / 12,
        letterSpacing: 0,
        color: MmColors.textSecondary,
      );

  /// Code/Mono: Roboto Mono Medium, 13px / 18px, letterSpacing 0
  static TextStyle get codeMono => GoogleFonts.robotoMono(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 18 / 13,
        letterSpacing: 0,
        color: MmColors.textSecondary,
      );
}

/// Application ThemeData builder using Medixmart Plus tokens.
abstract final class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: MmColors.bgCanvas,
      textTheme: GoogleFonts.interTextTheme(),
      colorScheme: const ColorScheme.light(
        primary: MmColors.bgBrand,
        onPrimary: MmColors.textOnBrand,
        surface: MmColors.bgSurface,
        onSurface: MmColors.textPrimary,
        error: MmColors.bgDanger,
        onError: MmColors.textOnBrand,
      ),
      dividerColor: MmColors.borderDefault,
    );
  }
}
