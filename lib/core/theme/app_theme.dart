import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pms_app/core/theme/app_colors_extension.dart';
import 'package:pms_app/core/theme/app_text_styles_extension.dart';

extension ThemeContextExtension on BuildContext {
  AppColorsExtension get colors => Theme.of(this).extension<AppColorsExtension>()!;
  AppTextStylesExtension get textStyles => Theme.of(this).extension<AppTextStylesExtension>()!;
}

class AppTheme {
  static const _primary = Color(0xFF1565C0);
  static const _primaryLight = Color(0xFF42A5F5);
  static const _primaryDark = Color(0xFF0D47A1);

  static const _accent = Color(0xFF00BFA5);
  static const _accentLight = Color(0xFF64FFDA);

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
      seedColor: _primary,
      brightness: Brightness.dark,
      primary: _primaryLight,
      onPrimary: Colors.white,
      secondary: _accentLight,
      surface: const Color(0xFF1E1E2C),
      onSurface: const Color(0xFFE2E8F0),
      background: const Color(0xFF12121D),
      onBackground: const Color(0xFFE2E8F0),
    ),
    scaffoldBackgroundColor: const Color(0xFF12121D),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: const Color(0xFF1E1E2C),
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
      backgroundColor: const Color(0xFF1E1E2C),
      hourMinuteColor: _primaryLight.withValues(alpha: 0.12),
      hourMinuteTextColor: const Color(0xFFE2E8F0),
      dialBackgroundColor: const Color(0xFF12121D),
      dialHandColor: _primaryLight,
      dialTextColor: const Color(0xFFE2E8F0),
      entryModeIconColor: const Color(0xFF94A3B8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF1E1E2C),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    extensions: [
      _darkColors,
      _createTextStyles(_darkColors),
    ],
  );

  static const _lightColors = AppColorsExtension(
    primary: _primary,
    primaryLight: _primaryLight,
    primaryDark: _primaryDark,
    accent: _accent,
    accentLight: _accentLight,
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF6B7280),
    textHint: Color(0xFF9CA3AF),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
    border: Color(0xFFE5E7EB),
    divider: Color(0xFFF3F4F6),
  );

  static const _darkColors = AppColorsExtension(
    primary: _primaryLight,
    primaryLight: _primary,
    primaryDark: _primaryLight,
    accent: _accentLight,
    accentLight: _accent,
    background: Color(0xFF12121D),
    surface: Color(0xFF1E1E2C),
    cardBackground: Color(0xFF1E1E2C),
    textPrimary: Color(0xFFE2E8F0),
    textSecondary: Color(0xFF94A3B8),
    textHint: Color(0xFF64748B),
    success: Color(0xFF10B981), // slightly brighter if needed, but 400/500 works
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
    border: Color(0xFF334155),
    divider: Color(0xFF1E293B),
  );

  static AppTextStylesExtension _createTextStyles(AppColorsExtension colors) {
    return AppTextStylesExtension(
      h1: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        height: 1.3,
      ),
      h2: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.3,
      ),
      h3: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.4,
      ),
      h4: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.4,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
        height: 1.5,
      ),
      label: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        height: 1.4,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
        height: 1.4,
      ),
      buttonLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      buttonMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      caption: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: colors.textHint,
        height: 1.4,
      ),
    );
  }
}
