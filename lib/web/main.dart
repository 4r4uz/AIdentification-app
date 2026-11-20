import 'package:flutter/material.dart';

import '/supabase/bootstrap.dart';
import 'app/admin_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  runApp(const AdminApp());
}
