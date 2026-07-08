import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Self-contained theme constants for Needil authentication screens.
///
/// Provides auth-specific colors and typography that complement
/// the main app theme but use the warm off-white / deep-teal palette
/// unique to the authentication experience.
class NeedilAuthTheme {
  NeedilAuthTheme._();

  // ── Light mode ─────────────────────────────────────────────────────
  static const lightBg          = Color(0xFFFAFAF7);
  static const lightCard        = Color(0xFFFFFFFF);
  static const lightPrimary     = Color(0xFF0F5D4F);
  static const lightPrimaryHover = Color(0xFF0D4F43);
  static const lightText        = Color(0xFF1D1D1F);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightBorder      = Color(0xFFE7E7E7);
  static const lightInputFill   = Color(0xFFF5F5F3);
  static const lightDivider     = Color(0xFFE5E5E5);

  // ── Dark mode ──────────────────────────────────────────────────────
  static const darkBg           = Color(0xFF0B0D10);
  static const darkSurface      = Color(0xFF14171C);
  static const darkPrimary      = Color(0xFF2D8C7F);
  static const darkPrimaryHover = Color(0xFF349E8F);
  static const darkText         = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF9CA3AF);
  static const darkBorder       = Color(0xFF1F2329);
  static const darkInputFill    = Color(0xFF14171C);
  static const darkDivider      = Color(0xFF1F2329);

  // ── Brightness-aware helpers ───────────────────────────────────────

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      _isDark(context) ? darkBg : lightBg;

  static Color card(BuildContext context) =>
      _isDark(context) ? darkSurface : lightCard;

  static Color primary(BuildContext context) =>
      _isDark(context) ? darkPrimary : lightPrimary;

  static Color primaryHover(BuildContext context) =>
      _isDark(context) ? darkPrimaryHover : lightPrimaryHover;

  static Color text(BuildContext context) =>
      _isDark(context) ? darkText : lightText;

  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color border(BuildContext context) =>
      _isDark(context) ? darkBorder : lightBorder;

  static Color inputFill(BuildContext context) =>
      _isDark(context) ? darkInputFill : lightInputFill;

  static Color divider(BuildContext context) =>
      _isDark(context) ? darkDivider : lightDivider;

  // ── Typography ─────────────────────────────────────────────────────

  static TextStyle heading(BuildContext context) => GoogleFonts.dmSerifDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: text(context),
        height: 1.2,
      );

  static TextStyle headingLarge(BuildContext context) => GoogleFonts.dmSerifDisplay(
        fontSize: 40,
        fontWeight: FontWeight.w400,
        color: text(context),
        height: 1.2,
      );

  static TextStyle subheading(BuildContext context) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textSecondary(context),
        height: 1.5,
      );

  static TextStyle body(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: text(context),
        height: 1.5,
      );

  static TextStyle label(BuildContext context) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textSecondary(context),
      );

  static TextStyle caption(BuildContext context) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary(context),
        letterSpacing: 0.2,
      );

  static TextStyle buttonText(BuildContext context) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.2,
      );
}
