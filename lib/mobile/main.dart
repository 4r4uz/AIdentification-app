import 'package:flutter/material.dart';

import '/mobile/app/app.dart';
import '/supabase/bootstrap.dart';
import '/mobile/core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  await ThemeController.load();
  runApp(const AnimalPediaApp());
}
