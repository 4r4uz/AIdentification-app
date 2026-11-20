import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color primary;
  final Color primarySoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color error;
  final Color warning;
  final Color cameraSurface;
  final Color cameraForeground;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.primary,
    required this.primarySoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.error,
    required this.warning,
    required this.cameraSurface,
    required this.cameraForeground,
  });

  static const light = AppPalette(
    background: Color(0xFFF7FAF7),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEAF4EC),
    border: Color(0xFFE1EAE3),
    primary: Color(0xFF287548),
    primarySoft: Color(0xFFE3F1E6),
    textPrimary: Color(0xFF1B2B20),
    textSecondary: Color(0xFF647269),
    success: Color(0xFF287548),
    error: Color(0xFFB3261E),
    warning: Color(0xFF8A5A00),
    cameraSurface: Color(0xB31B2B20),
    cameraForeground: Color(0xFFFFFFFF),
  );

  static const dark = AppPalette(
    background: Color(0xFF111A14),
    surface: Color(0xFF1B281F),
    surfaceMuted: Color(0xFF24372B),
    border: Color(0xFF34483A),
    primary: Color(0xFF8DD4A0),
    primarySoft: Color(0xFF263D2D),
    textPrimary: Color(0xFFE8F1E9),
    textSecondary: Color(0xFFB4C4B7),
    success: Color(0xFF8DD4A0),
    error: Color(0xFFFFB4AB),
    warning: Color(0xFFFFD180),
    cameraSurface: Color(0xB3000000),
    cameraForeground: Color(0xFFFFFFFF),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? primary,
    Color? primarySoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? error,
    Color? warning,
    Color? cameraSurface,
    Color? cameraForeground,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      cameraSurface: cameraSurface ?? this.cameraSurface,
      cameraForeground: cameraForeground ?? this.cameraForeground,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      cameraSurface: Color.lerp(cameraSurface, other.cameraSurface, t)!,
      cameraForeground: Color.lerp(
        cameraForeground,
        other.cameraForeground,
        t,
      )!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
