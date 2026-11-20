import 'package:flutter/material.dart';
import '/mobile/app/navigation/bottom_navigation.dart';
import '/mobile/core/theme/app_theme.dart';
import '/mobile/core/theme/theme_controller.dart';

class AnimalPediaApp extends StatelessWidget {
  const AnimalPediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'AnimalPedia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const BottomNavigation(),
      ),
    );
  }
}