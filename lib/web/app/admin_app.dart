import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../presentation/screens/admin_login_screen.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnimalPedia Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AdminLoginScreen(),
    );
  }
}
