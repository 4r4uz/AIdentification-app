import 'package:supabase_flutter/supabase_flutter.dart';

import '/core/network/supabase_service.dart';
import '/features/auth/data/models/user_model.dart';

class AuthService {
  final SupabaseService _supabaseService = SupabaseService();

  User? get currentUser => _supabaseService.currentUser;

  bool get isAuthenticated => _supabaseService.isAuthenticated;

  Future<UserModel?> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      final response = await _supabaseService.client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (username != null && username.trim().isNotEmpty)
            'username': username.trim(),
        },
      );

      if (response.user != null) {
        return UserModel(
          id: response.user!.id,
          email: response.user!.email ?? email,
          username: username,
          createdAt: DateTime.parse(response.user!.createdAt),
        );
      }
      return null;
    } catch (e) {
      throw Exception('Error en registro: ${e.toString()}');
    }
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        return UserModel(
          id: response.user!.id,
          email: response.user!.email ?? email,
          createdAt: DateTime.parse(response.user!.createdAt),
        );
      }
      return null;
    } catch (e) {
      throw Exception('Error en inicio de sesión: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    await _supabaseService.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabaseService.client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Error al restablecer contraseña: ${e.toString()}');
    }
  }

  Future<void> updateProfile({String? username, String? avatarUrl}) async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final payload = <String, dynamic>{};
      if (username != null) payload['username'] = username.trim();
      if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
      if (payload.isEmpty) return;

      await _supabaseService.client
          .from('profiles')
          .update(payload)
          .eq('id', user.id);
    } catch (e) {
      throw Exception('Error al actualizar perfil: ${e.toString()}');
    }
  }

  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) return null;

      final response = await _supabaseService.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Stream<AuthState> get authStateChanges =>
      _supabaseService.client.auth.onAuthStateChange;
}
