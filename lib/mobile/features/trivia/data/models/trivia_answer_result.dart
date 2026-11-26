class TriviaAnswerResult {
  final bool isCorrect;
  final int correctAnswer;
  final int pointsAwarded;
  final int? reviewStage;
  final DateTime? nextReviewAt;

  const TriviaAnswerResult({
    required this.isCorrect,
    required this.correctAnswer,
    required this.pointsAwarded,
    this.reviewStage,
    this.nextReviewAt,
  });

  factory TriviaAnswerResult.fromJson(Map<String, dynamic> json) {
    final nextReviewAt = json['next_review_at'];

    return TriviaAnswerResult(
      isCorrect: json['is_correct'] as bool,
      correctAnswer: (json['correct_answer'] as num).toInt(),
      pointsAwarded: (json['points_awarded'] as num).toInt(),
      reviewStage: (json['review_stage'] as num?)?.toInt(),
      nextReviewAt: nextReviewAt == null
          ? null
          : DateTime.parse(nextReviewAt as String),
    );
  }
}
