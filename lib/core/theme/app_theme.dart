import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pms_app/core/theme/app_colors_extension.dart';
import 'package:pms_app/core/theme/app_text_styles_extension.dart';

extension ThemeContextExtension on BuildContext {
  AppColorsExtension get colors => Theme.of(this).extension<AppColorsExtension>()!;
  AppTextStylesExtension get textStyles => Theme.of(this).extension<AppTextStylesExtension>()!;
}

class AppTheme {
  // Needil brand palette — deep teal-green
  static const _primary     = Color(0xFF0F5D4F); // Deep teal-green — Needil brand
  static const _primaryLight = Color(0xFF2D8C7F); // Lighter teal — hover/highlight
  static const _primaryDark  = Color(0xFF0A4A3E); // Darker teal — depth shade

  static const _accent      = Color(0xFF2D8C7F); // Teal accent
  static const _accentLight  = Color(0xFF4DB8A9); // Light teal accent


  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
      primary: _primary,
      secondary: _accent,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: const Color(0xFFFFFFFF),
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: _primary,
      headerForegroundColor: Colors.white,
      weekdayStyle: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold, fontSize: 13),
      yearStyle: const TextStyle(color: Color(0xFF1F2937), fontSize: 14),
      headerHeadlineStyle: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      headerHelpStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        if (states.contains(WidgetState.disabled)) return const Color(0xFF9CA3AF);
        return const Color(0xFF1F2937);
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _primary;
        return Colors.transparent;
      }),
      todayForegroundColor: WidgetStateProperty.all(_primary),
      todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
      todayBorder: const BorderSide(color: _primary, width: 1.5),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return const Color(0xFF1F2937);
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _primary;
        return Colors.transparent;
      }),
      dayOverlayColor: WidgetStateProperty.all(_primary.withValues(alpha: 0.1)),
      rangePickerBackgroundColor: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: const Color(0xFFFFFFFF),
      hourMinuteColor: _primary.withValues(alpha: 0.08),
      hourMinuteTextColor: _primary,
      dialBackgroundColor: const Color(0xFFF3F4F6),
      dialHandColor: _primary,
      dialTextColor: const Color(0xFF1F2937),
      entryModeIconColor: const Color(0xFF6B7280),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFFFFFFFF),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    extensions: [
      _lightColors,
      _createTextStyles(_lightColors),
    ],
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2D8C7F),
      brightness: Brightness.dark,
      primary: const Color(0xFF2D8C7F),
      onPrimary: Colors.white,
      secondary: const Color(0xFF4DB8A9),
      surface: const Color(0xFF1E2129),      // cardBackground
      onSurface: const Color(0xFFFFFFFF),    // textPrimary
    ),
    scaffoldBackgroundColor: const Color(0xFF111216), // background

    datePickerTheme: DatePickerThemeData(
      backgroundColor: const Color(0xFF1E2129),
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: _primaryLight.withValues(alpha: 0.15),
      headerForegroundColor: const Color(0xFFE2E8F0),
      weekdayStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13),
      yearStyle: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
      headerHeadlineStyle: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 24, fontWeight: FontWeight.bold),
      headerHelpStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        if (states.contains(WidgetState.disabled)) return const Color(0xFF475569);
        return const Color(0xFFE2E8F0);
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _primaryLight;
        return Colors.transparent;
      }),
      todayForegroundColor: WidgetStateProperty.all(_primaryLight),
      todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
      todayBorder: BorderSide(color: _primaryLight, width: 1.5),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return const Color(0xFFE2E8F0);
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _primaryLight;
        return Colors.transparent;
      }),
      dayOverlayColor: WidgetStateProperty.all(_primaryLight.withValues(alpha: 0.12)),
      rangePickerBackgroundColor: const Color(0xFF1E1E2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: const Color(0xFF1E2129),
      hourMinuteColor: _primaryLight.withValues(alpha: 0.12),
      hourMinuteTextColor: const Color(0xFFE2E8F0),
      dialBackgroundColor: const Color(0xFF111216),
      dialHandColor: _primaryLight,
      dialTextColor: const Color(0xFFE2E8F0),
      entryModeIconColor: const Color(0xFF94A3B8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF1E2129),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    extensions: [
      _darkColors,
      _createTextStyles(_darkColors),
    ],
  );

  // ── Light colour tokens ── (Needil green-teal palette) ─────────────
  static const _lightColors = AppColorsExtension(
    primary:        _primary,
    primaryLight:   _primaryLight,
    primaryDark:    _primaryDark,
    accent:         _accent,
    accentLight:    _accentLight,

    // Backgrounds: warm cream base, pure white surface for sidebar/cards
    background:     Color(0xFFFAF8F5),   // Warm cream canvas
    surface:        Color(0xFFFFFFFF),   // Pure white sidebar / panels
    cardBackground: Color(0xFFFFFFFF),   // Pure white cards
    cardBackgroundAlt: Color(0xFFFAF8F5), // Nesting warm cream

    // Text: high contrast hierarchy
    textPrimary:    Color(0xFF1D1D1F),   // Near black — Apple-style
    textSecondary:  Color(0xFF475569),   // Slate-600 — comfortable secondary
    textHint:       Color(0xFF94A3B8),   // Slate-400
    textMuted:      Color(0xFFCBD5E1),   // Slate-300 — ultra low emphasis
    textOnPrimary:  Color(0xFFFFFFFF),

    // Status
    success:  Color(0xFF10B981),   // Emerald-500
    warning:  Color(0xFFF59E0B),   // Amber-500
    error:    Color(0xFFEF4444),   // Red-500
    info:     Color(0xFF0F5D4F),   // Teal — matches primary

    // Borders & dividers — visible but not heavy
    border:   Color(0xFFE2E8F0),   // Slate-200
    divider:  Color(0xFFEFF2F5),   // Slightly lighter separation line

    // Shadow — cool neutral, casts cleanly on white
    shadowColor: Color(0xFF64748B), // Slate-500 base — callers add alpha
  );


  // ── Dark colour tokens ── (Needil green-teal palette, dark mode) ───────────
  // References: Linear, Raycast, Attio — dark mode with no glow, no gradients.
  // Elevation is achieved by using progressively darker surface colours.
  static const _darkColors = AppColorsExtension(
    primary:       Color(0xFF2D8C7F),    // Teal — used for CTAs, active state
    primaryLight:  Color(0xFF4DB8A9),    // Hover/lighter variant
    primaryDark:   Color(0xFF1A6B5E),    // Pressed/darker variant
    accent:        Color(0xFF4DB8A9),    // Secondary accent
    accentLight:   Color(0xFF6FCFBF),    // Light teal

    // ── Backgrounds — depth through darkness, never gradient ──────
    background:     Color(0xFF111216),   // Primary canvas
    surface:        Color(0xFF181A20),   // Sidebar, panels, secondary surfaces
    cardBackground: Color(0xFF1E2129),   // Elevated cards
    cardBackgroundAlt: Color(0xFF16181E), // Deeper nested elements

    // ── Text hierarchy ────────────────────────────────────────────
    textPrimary:   Color(0xFFFFFFFF),    // Pure white — main content
    textSecondary: Color(0xFF9AA4B2),    // Secondary labels
    textHint:      Color(0xFF6E7682),    // Placeholder / muted captions
    textMuted:     Color(0xFF4A5260),    // Ultra low emphasis
    textOnPrimary: Color(0xFFFFFFFF),    // Text on coloured surfaces

    // ── Semantic colours ─────────────────────────────────────────
    success: Color(0xFF22C55E),          // Green-500
    warning: Color(0xFFF59E0B),          // Amber-500
    error:   Color(0xFFEF4444),          // Red-500
    info:    Color(0xFF2D8C7F),          // Teal — matches primary

    // ── Borders & dividers — rgba equivalent in opaque form ───────
    border:  Color(0xFF1F2230),          // rgba(255,255,255,0.06) on #111216
    divider: Color(0xFF181B28),          // rgba(255,255,255,0.04) on #111216

    // ── Shadow — almost none, elevation via surface colour ────────
    shadowColor: Color(0xFF000000),
  );


  static AppTextStylesExtension _createTextStyles(AppColorsExtension colors) {
    return AppTextStylesExtension(
      // ── Display: big stat numbers in cards ─────────────────────
      // Tabular figures keep numbers from jumping width as they update
      displayNumber: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: colors.textPrimary,
        height: 1.0,
        letterSpacing: -1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),

      // ── Headings: Plus Jakarta Sans (editorial, premium) ────────
      h1: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: colors.textPrimary,
        height: 1.2,
        letterSpacing: -0.8,
      ),
      h2: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        height: 1.25,
        letterSpacing: -0.4,
      ),
      h3: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.3,
        letterSpacing: -0.2,
      ),

      // ── Sub-headers: Inter (functional, grounded) ───────────────
      h4: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.4,
        letterSpacing: -0.1,
      ),

      // ── Body: Inter w400 — never bold ──────────────────────────
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.6,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.55,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
        height: 1.5,
      ),

      // ── Labels: Inter w500 — medium only ───────────────────────
      label: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        height: 1.4,
        letterSpacing: 0.1,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
        height: 1.4,
        letterSpacing: 0.2,
      ),

      // ── Buttons: Plus Jakarta Sans — action-oriented personality
      buttonLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.1,
      ),
      buttonMedium: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.1,
      ),

      // ── Caption: Inter light ────────────────────────────────────
      caption: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: colors.textHint,
        height: 1.4,
        letterSpacing: 0.2,
      ),
    );
  }
}
