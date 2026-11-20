import 'package:flutter/material.dart';

import 'colors.dart';

class AppTheme {
  static const double cardRadius = 20;
  static const double buttonRadius = 16;
  static const EdgeInsets cardPadding = EdgeInsets.all(18);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceElevated,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(buttonRadius)),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(buttonRadius)),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      );

  static BoxDecoration cardDecoration() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AppColors.divider),
      );

  static TextStyle headingStyle() => const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      );

  static TextStyle bodyStyle() => const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      );
}
