import '/core/network/supabase_service.dart';
import '/features/trivia/data/models/trivia_model.dart';
import '/core/extensions/supabase_extensions.dart';

class TriviaService {
  final SupabaseService _supabaseService = SupabaseService();

  Future<List<TriviaModel>> getAllTrivias() async {
    return _supabaseService.client.safeListFrom(
      _supabaseService.client.from('trivias').select().order('id'),
      fromJson: TriviaModel.fromJson,
      errorMessage: 'Error al obtener trivias',
    );
  }

  Future<List<TriviaModel>> getTriviasByCategory(String category) async {
    return _supabaseService.client.safeListFrom(
      _supabaseService.client.from('trivias').select().eq('category', category).order('id'),
      fromJson: TriviaModel.fromJson,
      errorMessage: 'Error al obtener trivias por categoría',
    );
  }

  Future<List<TriviaModel>> getRandomTrivias(int count, {String? difficulty}) async {
    try {
      var query = _supabaseService.client
          .from('trivias')
          .select();

      if (difficulty != null) {
        query = query.eq('difficulty', difficulty);
      }

      final response = await query;

      final allTrivias = (response as List)
          .map((json) => TriviaModel.fromJson(json as Map<String, dynamic>))
          .toList();

      allTrivias.shuffle();
      return allTrivias.take(count).toList();
    } catch (e) {
      throw Exception('Error al obtener trivias aleatorias: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getUserTriviaStats(String userId) async {
    try {
      final response = await _supabaseService.client
          .from('user_trivia_progress')
          .select()
          .eq('user_id', userId);

      final List<dynamic> progressList = response as List;

      int totalAttempts = 0;
      int totalCorrect = 0;

      for (var item in progressList) {
        totalAttempts += item['attempts'] as int;
        totalCorrect += item['correct_attempts'] as int;
      }

      return {
        'total_attempts': totalAttempts,
        'total_correct': totalCorrect,
        'accuracy': totalAttempts > 0 ? totalCorrect / totalAttempts : 0.0,
      };
    } catch (e) {
      return {
        'total_attempts': 0,
        'total_correct': 0,
        'accuracy': 0.0,
      };
    }
  }

  Future<void> recordTriviaAttempt(String userId, int triviaId, bool isCorrect) async {
    try {
      final existing = await _supabaseService.client
          .from('user_trivia_progress')
          .select('attempts, correct_attempts')
          .eq('user_id', userId)
          .eq('trivia_id', triviaId)
          .maybeSingle();

      if (existing != null) {
        await _supabaseService.client
            .from('user_trivia_progress')
            .update({
              'attempts': (existing['attempts'] as int) + 1,
              'correct_attempts': (existing['correct_attempts'] as int) + (isCorrect ? 1 : 0),
              'last_attempt': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('trivia_id', triviaId);
      } else {
        await _supabaseService.client
            .from('user_trivia_progress')
            .insert({
              'user_id': userId,
              'trivia_id': triviaId,
              'attempts': 1,
              'correct_attempts': isCorrect ? 1 : 0,
              'last_attempt': DateTime.now().toIso8601String(),
            });
      }
    } catch (e) {
      throw Exception('Error al registrar intento de trivia: ${e.toString()}');
    }
  }
}