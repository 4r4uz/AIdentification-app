import '/supabase/supabase_service.dart';
import '/mobile/features/gamification/data/models/game_progress_model.dart';

class GameProgressService {
  final SupabaseService _supabaseService = SupabaseService();

  Future<GameProgressModel?> getMyProgress() async {
    if (_supabaseService.currentUser == null) return null;

    final response = await _supabaseService.client.rpc(
      'get_my_game_progress',
    );
    if (response is! List || response.length != 1) {
      throw const FormatException(
        'La respuesta del progreso de minijuegos es inválida.',
      );
    }

    final row = response.single;
    if (row is! Map) {
      throw const FormatException(
        'El resumen del progreso de minijuegos no es válido.',
      );
    }
    return GameProgressModel.fromJson(Map<String, dynamic>.from(row));
  }
}
