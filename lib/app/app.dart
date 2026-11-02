import 'package:flutter/material.dart';
import '/app/navigation/bottom_navigation.dart';
import '/core/theme/app_theme.dart';

class AnimalPediaApp extends StatelessWidget {
  const AnimalPediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnimalPedia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const BottomNavigation(),
    );
  }
}