import '/supabase/supabase_service.dart';
import '/mobile/features/trivia/data/models/trivia_answer_result.dart';
import '/mobile/features/trivia/data/models/trivia_model.dart';
import '/mobile/features/trivia/data/models/trivia_review_question.dart';

class TriviaService {
  final SupabaseService _supabaseService = SupabaseService();

  Future<List<TriviaModel>> getAllTrivias() async {
    final rows = _asRows(
      await _supabaseService.client.rpc('get_public_trivias'),
    );
    return rows.map(TriviaModel.fromJson).toList(growable: false);
  }

  Future<List<TriviaModel>> getTriviasByCategory(String category) async {
    final trivias = await getAllTrivias();
    return trivias.where((trivia) => trivia.category == category).toList();
  }

  Future<List<TriviaModel>> getRandomTrivias(
    int count, {
    String? difficulty,
  }) async {
    final trivias = await getAllTrivias();
    final filtered = difficulty == null
        ? trivias
        : trivias.where((trivia) => trivia.difficulty == difficulty).toList();
    filtered.shuffle();
    return filtered.take(count).toList();
  }

  Future<TriviaAnswerResult> submitAnswer(
    int triviaId,
    int selectedOption,
  ) async {
    final rows = _asRows(
      await _supabaseService.client.rpc(
        'submit_trivia_answer',
        params: {'p_trivia_id': triviaId, 'p_selected_option': selectedOption},
      ),
    );
    if (rows.length != 1) {
      throw const FormatException(
        'La respuesta del servidor no contiene un único resultado.',
      );
    }
    return TriviaAnswerResult.fromJson(rows.single);
  }

  Future<List<TriviaReviewQuestion>> getMyReviewQueue() async {
    if (_supabaseService.currentUser == null) return const [];

    final rows = _asRows(
      await _supabaseService.client.rpc('get_my_trivia_review_queue'),
    );
    return rows.map(TriviaReviewQuestion.fromJson).toList(growable: false);
  }

  List<Map<String, dynamic>> _asRows(dynamic response) {
    if (response is! List) {
      throw const FormatException('Respuesta inesperada del servidor.');
    }
    return response
        .map((row) {
          if (row is! Map) {
            throw const FormatException('Fila inesperada en la respuesta.');
          }
          return Map<String, dynamic>.from(row);
        })
        .toList(growable: false);
  }
}
