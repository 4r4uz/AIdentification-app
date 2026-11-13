import 'package:flutter/material.dart';

import '/app/app.dart';
import '/app/bootstrap.dart';
import '/core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  await ThemeController.load();
  runApp(const AnimalPediaApp());
}
