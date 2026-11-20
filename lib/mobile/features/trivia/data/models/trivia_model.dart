class TriviaModel {
  final int id;
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String category;
  final String difficulty;
  final int points;

  TriviaModel({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.category,
    required this.difficulty,
    required this.points,
  });

  factory TriviaModel.fromJson(Map<String, dynamic> json) {
    return TriviaModel(
      id: json['id'] as int,
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: json['correct_answer'] as int,
      category: json['category'] as String,
      difficulty: json['difficulty'] as String,
      points: json['points'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correct_answer': correctAnswer,
      'category': category,
      'difficulty': difficulty,
      'points': points,
    };
  }
}