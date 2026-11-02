import 'package:flutter_dotenv/flutter_dotenv.dart';
import '/core/network/supabase_service.dart';

Future<void> bootstrap() async {
  await dotenv.load(fileName: '.env');
  await SupabaseService().init();
}