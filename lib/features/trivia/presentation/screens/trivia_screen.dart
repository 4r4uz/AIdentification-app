import 'dart:async';

import 'package:flutter/material.dart';

import '/core/service_locator.dart';
import '/core/theme/app_theme.dart';
import '/core/theme/colors.dart';
import '/features/trivia/data/models/trivia_model.dart';
import '/shared/widgets/common_widgets.dart';

class TriviaScreen extends StatefulWidget {
  const TriviaScreen({super.key});

  @override
  State<TriviaScreen> createState() => _TriviaScreenState();
}

class _TriviaScreenState extends State<TriviaScreen> {
  final _triviaService = ServiceLocator.trivia;
  final _authService = ServiceLocator.auth;

  static const _questionCountPresets = [5, 10, 15, 20];
  static const _timeLimits = <int?>[null, 60, 300, 600];
  static const _difficultyOptions = ['all', 'facil', 'medio', 'dificil'];

  List<TriviaModel> _allTrivias = [];
  List<TriviaModel> _trivias = [];
  int _selectedQuestionCount = 5;
  String _selectedDifficulty = 'all';
  String _selectedCategory = 'all';
  int? _selectedTimeLimit;
  int _remainingSeconds = 0;
  int _elapsedSeconds = 0;
  int _currentIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  int? _selectedAnswerIndex;
  List<int?> _selectedAnswers = [];
  bool _isLoading = true;
  bool _isInGame = false;
  bool _isShowingResults = false;
  bool _isReviewingResults = false;
  bool _isAnswered = false;
  bool? _isCorrect;
  bool _gameFinished = false;
  bool _finishedByTime = false;
  bool _isConfirmingGameExit = false;
  String? _loadError;
  Timer? _timer;
  final Stopwatch _gameStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _loadTrivias();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTrivias() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final trivias = await _triviaService.getAllTrivias();
      if (!mounted) return;
      setState(() {
        _allTrivias = trivias;
        _isLoading = false;
        _syncQuestionCount();
      });
    } catch (error) {
      debugPrint('Error loading trivias: $error');
      if (mounted) {
        setState(() {
          _loadError = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<TriviaModel> get _availableTrivias {
    return _allTrivias.where((trivia) {
      final matchesDifficulty =
          _selectedDifficulty == 'all' ||
          _normalizeDifficulty(trivia.difficulty) == _selectedDifficulty;
      final matchesCategory =
          _selectedCategory == 'all' ||
          _canonicalCategory(trivia.category) == _selectedCategory;
      return matchesDifficulty && matchesCategory;
    }).toList();
  }

  List<int> get _availableQuestionCounts {
    final availableCount = _availableTrivias.length;
    if (availableCount == 0) return [];
    if (availableCount < _questionCountPresets.first) return [availableCount];

    final options = _questionCountPresets
        .where((count) => count <= availableCount)
        .toList();
    if (options.last != availableCount) options.add(availableCount);
    return options;
  }

  List<String> get _availableCategories {
    final categories = _allTrivias
        .map((trivia) => _canonicalCategory(trivia.category))
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
    const categoryOrder = [
      'mammals',
      'birds',
      'reptiles',
      'amphibians',
      'fish',
      'insects',
      'arachnids',
      'crustaceans',
    ];
    categories.sort((first, second) {
      final firstIndex = categoryOrder.indexOf(first);
      final secondIndex = categoryOrder.indexOf(second);
      if (firstIndex == -1 && secondIndex == -1) {
        return _categoryLabel(first).compareTo(_categoryLabel(second));
      }
      if (firstIndex == -1) return 1;
      if (secondIndex == -1) return -1;
      return firstIndex.compareTo(secondIndex);
    });
    return ['all', ...categories];
  }

  void _syncQuestionCount() {
    final options = _availableQuestionCounts;
    if (options.isEmpty) return;
    if (!options.contains(_selectedQuestionCount)) {
      final validOptions = options
          .where((count) => count <= _selectedQuestionCount)
          .toList();
      _selectedQuestionCount = validOptions.isEmpty
          ? options.first
          : validOptions.last;
    }
  }

  String _normalizeDifficulty(String value) {
    return value.trim().toLowerCase();
  }

  String _canonicalCategory(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    return switch (normalized) {
      'mamifero' ||
      'mamiferos' ||
      'mammal' ||
      'mammals' ||
      'mammalia' => 'mammals',
      'ave' || 'aves' || 'bird' || 'birds' => 'birds',
      'reptil' || 'reptiles' || 'reptile' || 'reptilia' => 'reptiles',
      'anfibio' ||
      'anfibios' ||
      'amphibian' ||
      'amphibians' ||
      'amphibia' => 'amphibians',
      'pez' || 'peces' || 'fish' || 'actinopterygii' => 'fish',
      'insecto' ||
      'insectos' ||
      'insect' ||
      'insects' ||
      'insecta' => 'insects',
      'aracnido' ||
      'aracnidos' ||
      'arachnid' ||
      'arachnids' ||
      'arachnida' => 'arachnids',
      'crustaceo' ||
      'crustaceos' ||
      'crustacean' ||
      'crustaceans' ||
      'malacostraca' => 'crustaceans',
      _ => normalized,
    };
  }

  String _categoryLabel(String category) {
    return switch (category) {
      'all' => 'Todos',
      'mammals' => 'Mamíferos',
      'birds' => 'Aves',
      'reptiles' => 'Reptiles',
      'amphibians' => 'Anfibios',
      'fish' => 'Peces',
      'insects' => 'Insectos',
      'arachnids' => 'Arácnidos',
      'crustaceans' => 'Crustáceos',
      _ when category.isEmpty => 'Sin categoría',
      _ => '${category[0].toUpperCase()}${category.substring(1)}',
    };
  }

  String _difficultyLabel(String difficulty) {
    return switch (difficulty) {
      'all' => 'Todas',
      'facil' => 'Fácil',
      'medio' => 'Media',
      'dificil' => 'Difícil',
      _ => difficulty,
    };
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'all' => Icons.public_rounded,
      'mammals' => Icons.pets_rounded,
      'birds' => Icons.flutter_dash_rounded,
      'reptiles' => Icons.pest_control_rounded,
      'amphibians' => Icons.water_drop_rounded,
      'fish' => Icons.set_meal_rounded,
      'insects' => Icons.bug_report_rounded,
      'arachnids' => Icons.hexagon_rounded,
      'crustaceans' => Icons.waves_rounded,
      _ => Icons.category_rounded,
    };
  }

  void _setDifficulty(String difficulty) {
    setState(() {
      _selectedDifficulty = difficulty;
      _syncQuestionCount();
    });
  }

  void _setCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _syncQuestionCount();
    });
  }

  void _startGame() {
    final questions = _availableTrivias.toList()..shuffle();
    if (questions.isEmpty) return;
    final selectedQuestions = questions.take(_selectedQuestionCount).toList();
    setState(() {
      _trivias = selectedQuestions;
      _currentIndex = 0;
      _score = 0;
      _correctAnswers = 0;
      _selectedAnswerIndex = null;
      _selectedAnswers = List<int?>.filled(selectedQuestions.length, null);
      _isAnswered = false;
      _isCorrect = null;
      _gameFinished = false;
      _finishedByTime = false;
      _isShowingResults = false;
      _isReviewingResults = false;
      _isInGame = true;
      _remainingSeconds = _selectedTimeLimit ?? 0;
      _elapsedSeconds = 0;
    });
    _gameStopwatch
      ..reset()
      ..start();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_selectedTimeLimit == null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _gameFinished) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        setState(() => _remainingSeconds = 0);
        _finishGame(timeExpired: true);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  Future<void> _handleAnswer(int selectedIndex) async {
    if (_isAnswered || _gameFinished) return;

    final answeredQuestionIndex = _currentIndex;
    final currentTrivia = _trivias[_currentIndex];
    final isCorrect = selectedIndex == currentTrivia.correctAnswer;

    setState(() {
      _isAnswered = true;
      _selectedAnswerIndex = selectedIndex;
      _selectedAnswers[_currentIndex] = selectedIndex;
      _isCorrect = isCorrect;
      if (isCorrect) {
        _score += currentTrivia.points;
        _correctAnswers++;
      }
    });

    final user = _authService.currentUser;
    if (user != null) {
      unawaited(_recordTriviaAttempt(user.id, currentTrivia.id, isCorrect));
    }

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted ||
        !_isInGame ||
        _gameFinished ||
        !_isAnswered ||
        _currentIndex != answeredQuestionIndex) {
      return;
    }

    _advanceQuestion();
  }

  Future<void> _recordTriviaAttempt(
    String userId,
    int triviaId,
    bool isCorrect,
  ) async {
    try {
      await _triviaService.recordTriviaAttempt(userId, triviaId, isCorrect);
    } catch (error) {
      debugPrint('Error recording trivia attempt: $error');
    }
  }

  void _advanceQuestion() {
    if (!_isAnswered || _gameFinished) return;
    if (_currentIndex < _trivias.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _isCorrect = null;
        _selectedAnswerIndex = null;
      });
    } else {
      _finishGame();
    }
  }

  void _finishGame({bool timeExpired = false}) {
    if (_gameFinished || !mounted) return;
    _timer?.cancel();
    _gameStopwatch.stop();
    setState(() {
      _gameFinished = true;
      _finishedByTime = timeExpired;
      _isInGame = false;
      _isShowingResults = true;
      _isReviewingResults = false;
      _elapsedSeconds = _gameStopwatch.elapsed.inSeconds;
    });
  }

  void _returnToConfiguration() {
    _timer?.cancel();
    _gameStopwatch.stop();
    setState(() {
      _isInGame = false;
      _gameFinished = false;
      _isShowingResults = false;
      _isReviewingResults = false;
      _isAnswered = false;
      _isCorrect = null;
      _selectedAnswerIndex = null;
    });
  }

  Future<void> _confirmExitGame() async {
    if (_isConfirmingGameExit || !_isInGame) return;
    _isConfirmingGameExit = true;
    _timer?.cancel();
    _gameStopwatch.stop();

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir de la partida?'),
        content: const Text(
          'Si sales ahora, perderás el progreso y los resultados de esta partida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir jugando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.error,
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    _isConfirmingGameExit = false;
    if (!mounted) return;
    if (shouldExit == true) {
      _timer?.cancel();
      Navigator.of(context).pop();
      return;
    }

    if (_isInGame && !_gameFinished) {
      _gameStopwatch.start();
      _startTimer();
    }
  }

  void _handlePopAttempt(bool didPop) {
    if (didPop) return;
    if (_isReviewingResults) {
      _showResultSummary();
    } else if (_isInGame) {
      _confirmExitGame();
    }
  }

  void _showReviewResults() {
    setState(() => _isReviewingResults = true);
  }

  void _showResultSummary() {
    setState(() => _isReviewingResults = false);
  }

  String _formatElapsedTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  String get _resultDifficulty {
    final difficulties = _trivias
        .map((trivia) => _normalizeDifficulty(trivia.difficulty))
        .toSet();
    if (difficulties.length != 1) return 'Mixta';
    return _difficultyLabel(difficulties.first);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_isInGame && !_isReviewingResults,
      onPopInvokedWithResult: (didPop, _) => _handlePopAttempt(didPop),
      child: Scaffold(
        appBar: _isInGame
            ? null
            : AppBar(
                title: Text(
                  _isShowingResults
                      ? (_isReviewingResults
                            ? 'Revisar resultados'
                            : 'Resultados')
                      : 'Configurar trivia',
                ),
                backgroundColor: context.palette.primarySoft,
                leading: _isReviewingResults
                    ? IconButton(
                        tooltip: 'Volver a resultados',
                        onPressed: _showResultSummary,
                        icon: const Icon(Icons.arrow_back_rounded),
                      )
                    : null,
              ),
        body: _isLoading
            ? const LoadingIndicator(message: 'Cargando preguntas...')
            : _loadError != null
            ? EmptyStateWidget(
                icon: Icons.cloud_off_outlined,
                title: 'No se pudieron cargar las preguntas',
                message: _loadError,
                buttonText: 'Reintentar',
                onButtonPressed: _loadTrivias,
              )
            : _allTrivias.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.quiz_outlined,
                title: 'No hay trivias disponibles',
              )
            : _isInGame
            ? _buildGame(context)
            : _isShowingResults
            ? (_isReviewingResults
                  ? _buildResultsReview(context)
                  : _buildResultsSummary(context))
            : _buildConfiguration(context),
      ),
    );
  }

  Widget _buildResultsSummary(BuildContext context) {
    final total = _trivias.length;
    final incorrect = _selectedAnswers.indexed.where((entry) {
      final (index, answer) = entry;
      return answer != null && answer != _trivias[index].correctAnswer;
    }).length;
    final unanswered = total - _correctAnswers - incorrect;
    final accuracy = total == 0 ? 0 : (_correctAnswers * 100 ~/ total);
    final palette = context.palette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.textPrimary.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _finishedByTime
                      ? Icons.timer_off_rounded
                      : Icons.emoji_events_rounded,
                  color: palette.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _finishedByTime
                    ? '¡Se acabó el tiempo!'
                    : _correctAnswers == total
                    ? '¡Excelente trabajo!'
                    : 'Partida completada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$_correctAnswers / $total',
                style: TextStyle(
                  color: palette.primary,
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$accuracy% de precisión · Dificultad $_resultDifficulty',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ResultMetric(
                    icon: Icons.check_rounded,
                    value: '$_correctAnswers',
                    label: 'Correctas',
                    color: palette.success,
                  ),
                  _ResultMetric(
                    icon: Icons.close_rounded,
                    value: '$incorrect',
                    label: 'Incorrectas',
                    color: palette.error,
                  ),
                  if (unanswered > 0)
                    _ResultMetric(
                      icon: Icons.remove_rounded,
                      value: '$unanswered',
                      label: 'Sin responder',
                      color: palette.textSecondary,
                    ),
                  _ResultMetric(
                    icon: Icons.schedule_rounded,
                    value: _formatElapsedTime(_elapsedSeconds),
                    label: 'Tiempo',
                    color: palette.primary,
                  ),
                  _ResultMetric(
                    icon: Icons.stars_rounded,
                    value: '$_score',
                    label: 'Puntos',
                    color: palette.warning,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _startGame,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Jugar de nuevo'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _showReviewResults,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Revisar resultados'),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _returnToConfiguration,
          child: const Text('Volver a configurar'),
        ),
      ],
    );
  }

  Widget _buildResultsReview(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      itemCount: _trivias.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: context.palette.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_correctAnswers correctas de ${_trivias.length}. '
              'Revisa tus respuestas y la opción correcta.',
              style: TextStyle(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        final questionIndex = index - 1;
        final trivia = _trivias[questionIndex];
        final selectedAnswer = _selectedAnswers[questionIndex];
        final isCorrect = selectedAnswer == trivia.correctAnswer;
        final wasAnswered = selectedAnswer != null;
        final statusColor = !wasAnswered
            ? context.palette.textSecondary
            : isCorrect
            ? context.palette.success
            : context.palette.error;

        return Container(
          padding: const EdgeInsets.all(17),
          decoration: AppTheme.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      !wasAnswered
                          ? Icons.remove_rounded
                          : isCorrect
                          ? Icons.check_rounded
                          : Icons.close_rounded,
                      color: statusColor,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pregunta ${questionIndex + 1}',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    wasAnswered
                        ? (isCorrect ? 'Correcta' : 'Incorrecta')
                        : 'Sin responder',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                trivia.question,
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (wasAnswered)
                _ReviewAnswer(
                  label: 'Tu respuesta',
                  text: trivia.options[selectedAnswer],
                  isCorrect: isCorrect,
                  isNeutral: false,
                ),
              if (wasAnswered && !isCorrect) const SizedBox(height: 8),
              if (!isCorrect)
                _ReviewAnswer(
                  label: 'Respuesta correcta',
                  text: trivia.options[trivia.correctAnswer],
                  isCorrect: true,
                  isNeutral: !wasAnswered,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfiguration(BuildContext context) {
    final availableCount = _availableTrivias.length;
    final questionCounts = _availableQuestionCounts;

    return ListView(
      padding: AppTheme.defaultPadding,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [context.palette.primarySoft, context.palette.surface],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: context.palette.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.quiz_rounded,
                  color: context.palette.primary,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prepara tu partida',
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$availableCount preguntas disponibles con estos filtros',
                      style: AppTheme.bodyStyle(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _ConfigSection(
          icon: Icons.format_list_numbered_rounded,
          title: 'Cantidad de preguntas',
          subtitle: 'Elige cuántas preguntas tendrá la partida',
          child: _availableQuestionCounts.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: questionCounts
                      .map(
                        (count) => _ChoiceChip(
                          label: '$count',
                          selected: count == _selectedQuestionCount,
                          onTap: () =>
                              setState(() => _selectedQuestionCount = count),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 18),
        _ConfigSection(
          icon: Icons.speed_rounded,
          title: 'Dificultad',
          subtitle: 'Filtra las preguntas por nivel',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _difficultyOptions
                .map(
                  (difficulty) => _ChoiceChip(
                    label: _difficultyLabel(difficulty),
                    selected: difficulty == _selectedDifficulty,
                    onTap: () => _setDifficulty(difficulty),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        _ConfigSection(
          icon: Icons.category_rounded,
          title: 'Categoría',
          subtitle: 'Escoge el grupo de fauna',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _availableCategories
                .map(
                  (category) => _ChoiceChip(
                    label: _categoryLabel(category),
                    icon: _categoryIcon(category),
                    selected: category == _selectedCategory,
                    onTap: () => _setCategory(category),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        _ConfigSection(
          icon: Icons.timer_outlined,
          title: 'Tiempo',
          subtitle: 'El límite se aplica a toda la partida',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _timeLimits
                .map(
                  (timeLimit) => _ChoiceChip(
                    label: timeLimit == null
                        ? 'Sin límite'
                        : '${timeLimit ~/ 60} min',
                    icon: Icons.timer_rounded,
                    selected: timeLimit == _selectedTimeLimit,
                    onTap: () => setState(() => _selectedTimeLimit = timeLimit),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 26),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: availableCount == 0 ? null : _startGame,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              availableCount == 0
                  ? 'No hay preguntas con estos filtros'
                  : 'Comenzar partida',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGame(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.palette.primarySoft.withValues(alpha: 0.55),
            context.palette.background,
            context.palette.background,
          ],
          stops: const [0, 0.38, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: _buildProgressIndicator(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildQuestionCard(),
                    const SizedBox(height: 18),
                    _buildAnswers(),
                    if (_isAnswered) ...[
                      const SizedBox(height: 4),
                      _AnswerFeedback(
                        isCorrect: _isCorrect!,
                        isLastQuestion: _currentIndex == _trivias.length - 1,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(color: palette.border),
              ),
              child: IconButton(
                tooltip: 'Salir de la partida',
                onPressed: _confirmExitGame,
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back_rounded, color: palette.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Pregunta ${_currentIndex + 1} de ${_trivias.length}',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / _trivias.length,
                      backgroundColor: palette.surface,
                      color: palette.primary,
                      minHeight: 7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (_selectedTimeLimit != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _remainingSeconds <= 10
                      ? palette.error.withValues(alpha: 0.12)
                      : palette.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _remainingSeconds <= 10
                        ? palette.error.withValues(alpha: 0.3)
                        : palette.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      size: 18,
                      color: _remainingSeconds <= 10
                          ? palette.error
                          : palette.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: TextStyle(
                        color: _remainingSeconds <= 10
                            ? palette.error
                            : palette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestionCard() {
    final trivia = _trivias[_currentIndex];
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 21, 22, 25),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.textPrimary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDifficultyBadge(context, trivia.difficulty),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '+${trivia.points} pts',
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            trivia.question,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnswers() {
    final trivia = _trivias[_currentIndex];
    const optionLetters = ['A', 'B', 'C', 'D', 'E', 'F'];

    return Column(
      children: List.generate(trivia.options.length, (index) {
        final isCorrectOption = index == trivia.correctAnswer;
        final isSelectedOption = index == _selectedAnswerIndex;
        final isRevealedCorrect = _isAnswered && isCorrectOption;
        final isRevealedIncorrect =
            _isAnswered && isSelectedOption && !_isCorrect!;
        final palette = context.palette;
        final backgroundColor = isRevealedCorrect
            ? palette.success
            : isRevealedIncorrect
            ? palette.error
            : palette.surface.withValues(alpha: 0.55);
        final foregroundColor = isRevealedCorrect || isRevealedIncorrect
            ? Colors.white
            : palette.textPrimary;
        final borderColor = isRevealedCorrect
            ? palette.success
            : isRevealedIncorrect
            ? palette.error
            : palette.border;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: _isAnswered ? null : () => _handleAnswer(index),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: Icon(
                          isRevealedCorrect
                              ? Icons.check_rounded
                              : isRevealedIncorrect
                              ? Icons.close_rounded
                              : null,
                          color: foregroundColor,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!_isAnswered ||
                        (!isRevealedCorrect && !isRevealedIncorrect)) ...[
                      Text(
                        index < optionLetters.length
                            ? optionLetters[index]
                            : '${index + 1}',
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        trivia.options[index],
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: 16,
                          fontWeight: isRevealedCorrect || isRevealedIncorrect
                              ? FontWeight.w700
                              : FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDifficultyBadge(BuildContext context, String difficulty) {
    final color = switch (_normalizeDifficulty(difficulty)) {
      'facil' => context.palette.success,
      'medio' => context.palette.primary,
      'dificil' => context.palette.error,
      _ => context.palette.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _difficultyLabel(_normalizeDifficulty(difficulty)).toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ConfigSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _ConfigSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: palette.primary, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 31),
            child: Text(subtitle, style: AppTheme.bodyStyle(context)),
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ChoiceChip(
      label: Text(label),
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 17,
              color: selected ? palette.primary : palette.textSecondary,
            ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? palette.primary : palette.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      backgroundColor: palette.surface,
      selectedColor: palette.primarySoft,
      side: BorderSide(
        color: selected ? palette.primary : palette.border,
        width: selected ? 1.4 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _ResultMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewAnswer extends StatelessWidget {
  final String label;
  final String text;
  final bool isCorrect;
  final bool isNeutral;

  const _ReviewAnswer({
    required this.label,
    required this.text,
    required this.isCorrect,
    required this.isNeutral,
  });

  @override
  Widget build(BuildContext context) {
    final color = isNeutral
        ? context.palette.primary
        : isCorrect
        ? context.palette.success
        : context.palette.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            text,
            style: TextStyle(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  final bool isCorrect;
  final bool isLastQuestion;

  const _AnswerFeedback({
    required this.isCorrect,
    required this.isLastQuestion,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = isCorrect ? palette.success : palette.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isCorrect
                  ? '¡Correcto!'
                  : 'Incorrecto. La respuesta correcta está marcada en verde.',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isLastQuestion ? Icons.fact_check_rounded : Icons.chevron_right,
            color: color,
          ),
        ],
      ),
    );
  }
}
