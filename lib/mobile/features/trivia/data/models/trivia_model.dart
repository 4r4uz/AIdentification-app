class TriviaModel {
  final int id;
  final String question;
  final List<String> options;
  final String category;
  final String difficulty;
  final int points;
  final int? speciesId;
  final String? explanation;
  final String? sourceUrl;

  TriviaModel({
    required this.id,
    required this.question,
    required this.options,
    required this.category,
    required this.difficulty,
    required this.points,
    this.speciesId,
    this.explanation,
    this.sourceUrl,
  });

  factory TriviaModel.fromJson(Map<String, dynamic> json) {
    return TriviaModel(
      id: json['id'] as int,
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      category: json['category']?.toString() ?? '',
      difficulty: json['difficulty']?.toString() ?? '',
      points: (json['points'] as num?)?.toInt() ?? 10,
      speciesId: (json['species_id'] as num?)?.toInt(),
      explanation: json['explanation'] as String?,
      sourceUrl: json['source_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'category': category,
      'difficulty': difficulty,
      'points': points,
      'species_id': speciesId,
      'explanation': explanation,
      'source_url': sourceUrl,
    };
  }
}