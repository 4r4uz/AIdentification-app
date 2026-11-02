import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient? _client;

  SupabaseClient get client {
    if (_client == null) {
      throw Exception('SupabaseService not initialized. Call init() first.');
    }
    return _client!;
  }

  Future<void> init() async {
    if (_client != null) return;

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '',
    );

    _client = Supabase.instance.client;
  }

  bool get isAuthenticated => _client?.auth.currentUser != null;

  User? get currentUser => _client?.auth.currentUser;

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }
}