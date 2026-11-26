class GameRank {
  final int level;
  final String name;
  final int minimumPoints;

  const GameRank({
    required this.level,
    required this.name,
    required this.minimumPoints,
  });
}

class GameProgressModel {
  static const ranks = <GameRank>[
    GameRank(level: 1, name: 'Aprendiz', minimumPoints: 0),
    GameRank(level: 2, name: 'Explorador', minimumPoints: 100),
    GameRank(level: 3, name: 'Naturalista', minimumPoints: 300),
    GameRank(level: 4, name: 'Investigador', minimumPoints: 700),
    GameRank(level: 5, name: 'Experto de campo', minimumPoints: 1500),
  ];

  final int totalXp;
  final int masteredQuestions;
  final int totalAttempts;
  final int correctAttempts;

  const GameProgressModel({
    required this.totalXp,
    required this.masteredQuestions,
    required this.totalAttempts,
    required this.correctAttempts,
  });

  factory GameProgressModel.fromJson(Map<String, dynamic> json) {
    return GameProgressModel(
      totalXp: (json['total_xp'] as num).toInt(),
      masteredQuestions: (json['mastered_questions'] as num).toInt(),
      totalAttempts: (json['total_attempts'] as num).toInt(),
      correctAttempts: (json['correct_attempts'] as num).toInt(),
    );
  }

  static GameRank rankForXp(int totalXp) {
    return ranks.lastWhere((rank) => totalXp >= rank.minimumPoints);
  }

  GameRank get currentRank => rankForXp(totalXp);

  GameRank? get nextRank {
    final nextIndex = currentRank.level;
    return nextIndex < ranks.length ? ranks[nextIndex] : null;
  }

  double get rankProgress {
    final next = nextRank;
    if (next == null) return 1;
    final xpInRank = totalXp - currentRank.minimumPoints;
    final xpRequired = next.minimumPoints - currentRank.minimumPoints;
    return (xpInRank / xpRequired).clamp(0, 1).toDouble();
  }

  int get xpToNextRank {
    final next = nextRank;
    return next == null ? 0 : next.minimumPoints - totalXp;
  }

  factory GameProgressModel.empty() => const GameProgressModel(
    totalXp: 0,
    masteredQuestions: 0,
    totalAttempts: 0,
    correctAttempts: 0,
  );
}
