import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();

  static const _preferenceKey = 'app_theme_mode';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    mode.value = switch (preferences.getString(_preferenceKey)) {
      'system' => ThemeMode.system,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  static Future<void> setMode(ThemeMode themeMode) async {
    final preferences = await SharedPreferences.getInstance();
    final storedValue = switch (themeMode) {
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
    };
    final saved = await preferences.setString(_preferenceKey, storedValue);
    if (!saved) throw StateError('No se pudo guardar el tema seleccionado');
    mode.value = themeMode;
  }
}
