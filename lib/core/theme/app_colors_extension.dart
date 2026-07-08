import 'package:flutter/material.dart';

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  // Primary palette
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;

  // Accent
  final Color accent;
  final Color accentLight;

  // Background
  final Color background;
  final Color surface;
  final Color cardBackground;
  final Color cardBackgroundAlt; // Secondary / nested card background

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color textMuted;     // Very low emphasis (replaces white30/white38 in dark)
  final Color textOnPrimary; // Text colour on primary-coloured surfaces (always white)

  // Status
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Borders & Dividers
  final Color border;
  final Color divider;

  // Utility
  final Color shadowColor; // Base shadow colour — callers add alpha via withValues()

  // ── Gradient getters ──────────────────────────────────────────

  LinearGradient get primaryGradient => LinearGradient(
        colors: [primary, primaryLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get accentGradient => LinearGradient(
        colors: [accent, accentLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get heroGradient => LinearGradient(
        colors: [primaryDark, primary, primaryLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Subtle tinted gradient for stat cards (adapts per mode).
  LinearGradient get cardGradient => LinearGradient(
        colors: [cardBackground, cardBackgroundAlt],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// For sidebar / panel surfaces.
  LinearGradient get surfaceGradient => LinearGradient(
        colors: [
          surface.withValues(alpha: 0.85),
          cardBackground.withValues(alpha: 0.60),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  const AppColorsExtension({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.accent,
    required this.accentLight,
    required this.background,
    required this.surface,
    required this.cardBackground,
    required this.cardBackgroundAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.textMuted,
    required this.textOnPrimary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.border,
    required this.divider,
    required this.shadowColor,
  });

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? accent,
    Color? accentLight,
    Color? background,
    Color? surface,
    Color? cardBackground,
    Color? cardBackgroundAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? textMuted,
    Color? textOnPrimary,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? border,
    Color? divider,
    Color? shadowColor,
  }) {
    return AppColorsExtension(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBackgroundAlt: cardBackgroundAlt ?? this.cardBackgroundAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      textMuted: textMuted ?? this.textMuted,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBackgroundAlt: Color.lerp(cardBackgroundAlt, other.cardBackgroundAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}
