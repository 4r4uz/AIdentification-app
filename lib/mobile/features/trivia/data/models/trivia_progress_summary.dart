class TriviaProgressSummary {
  final int totalPoints;
  final int masteredQuestions;
  final int totalAttempts;
  final int correctAttempts;

  const TriviaProgressSummary({
    required this.totalPoints,
    required this.masteredQuestions,
    required this.totalAttempts,
    required this.correctAttempts,
  });

  factory TriviaProgressSummary.fromJson(Map<String, dynamic> json) {
    return TriviaProgressSummary(
      totalPoints: (json['total_points'] as num).toInt(),
      masteredQuestions: (json['mastered_questions'] as num).toInt(),
      totalAttempts: (json['total_attempts'] as num).toInt(),
      correctAttempts: (json['correct_attempts'] as num).toInt(),
    );
  }
}
