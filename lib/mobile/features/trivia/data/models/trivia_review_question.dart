class TriviaReviewQuestion {
  final int triviaId;
  final int reviewStage;
  final DateTime nextReviewAt;

  const TriviaReviewQuestion({
    required this.triviaId,
    required this.reviewStage,
    required this.nextReviewAt,
  });

  factory TriviaReviewQuestion.fromJson(Map<String, dynamic> json) {
    return TriviaReviewQuestion(
      triviaId: (json['trivia_id'] as num).toInt(),
      reviewStage: (json['review_stage'] as num).toInt(),
      nextReviewAt: DateTime.parse(json['next_review_at'] as String),
    );
  }
}
