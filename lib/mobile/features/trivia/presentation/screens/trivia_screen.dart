import 'dart:async';

import 'package:flutter/material.dart';

import '/mobile/core/service_locator.dart';
import '/mobile/core/theme/app_theme.dart';
import '/mobile/core/theme/colors.dart';
import '/mobile/features/gamification/data/models/game_progress_model.dart';
import '/mobile/features/trivia/data/models/trivia_model.dart';
import '/mobile/features/trivia/data/models/trivia_review_question.dart';
import '/mobile/widgets/common_widgets.dart';

class TriviaScreen extends StatefulWidget {
  const TriviaScreen({super.key});

  @override
  State<TriviaScreen> createState() => _TriviaScreenState();
}

class _TriviaScreenState extends State<TriviaScreen> {
  final _triviaService = ServiceLocator.trivia;
  final _authService = ServiceLocator.auth;

  static const _questionCountPresets = [10, 20, 30, 40];
  static const _timeLimits = <int?>[null, 60, 300, 600];
  static const _difficultyOptions = ['all', 'facil', 'medio', 'dificil'];

  List<TriviaModel> _allTrivias = [];
  List<TriviaModel> _trivias = [];
  List<TriviaReviewQuestion> _reviewQueue = [];
  GameProgressModel? _progressSummary;
  List<int?> _correctAnswerIndexes = [];
  List<int> _pointsAwardedByQuestion = [];
  List<DateTime?> _nextReviewAtByQuestion = [];
  int _selectedQuestionCount = 10;
  String _selectedDifficulty = 'all';
  String _selectedCategory = 'all';
  int? _selectedTimeLimit;
  bool _showMoreOptions = false;
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
  bool _isSubmittingAnswer = false;
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
      final progressSummary = await ServiceLocator.gameProgress.getMyProgress();
      final reviewQueue = await _triviaService.getMyReviewQueue();
      if (!mounted) return;
      setState(() {
        _allTrivias = trivias;
        _progressSummary = progressSummary;
        _reviewQueue = reviewQueue;
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
    return _questionCountPresets
        .where((count) => count <= availableCount)
        .toList(growable: false);
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

  void _startGame({bool focusReviews = false}) {
    final available = _availableTrivias;
    final reviewIds = _reviewQueue.map((question) => question.triviaId).toSet();
    final dueQuestions = available
        .where((trivia) => reviewIds.contains(trivia.id))
        .toList();
    final newQuestions =
        available.where((trivia) => !reviewIds.contains(trivia.id)).toList()
          ..shuffle();
    final questions = [...dueQuestions, ...newQuestions];
    if (!focusReviews) questions.shuffle();
    if (questions.isEmpty) return;
    final selectedQuestions = questions.take(_selectedQuestionCount).toList();
    setState(() {
      _trivias = selectedQuestions;
      _currentIndex = 0;
      _score = 0;
      _correctAnswers = 0;
      _selectedAnswerIndex = null;
      _selectedAnswers = List<int?>.filled(selectedQuestions.length, null);
      _correctAnswerIndexes = List<int?>.filled(selectedQuestions.length, null);
      _pointsAwardedByQuestion = List<int>.filled(selectedQuestions.length, 0);
      _nextReviewAtByQuestion = List<DateTime?>.filled(
        selectedQuestions.length,
        null,
      );
      _isAnswered = false;
      _isSubmittingAnswer = false;
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
      if (_isSubmittingAnswer) return;
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
    if (_isAnswered || _isSubmittingAnswer || _gameFinished) return;

    setState(() {
      _isSubmittingAnswer = true;
      _selectedAnswerIndex = selectedIndex;
      _selectedAnswers[_currentIndex] = selectedIndex;
    });
    _timer?.cancel();

    try {
      final currentTrivia = _trivias[_currentIndex];
      final result = await _triviaService.submitAnswer(
        currentTrivia.id,
        selectedIndex,
      );
      if (!mounted) return;
      setState(() {
        _isSubmittingAnswer = false;
        _isAnswered = true;
        _isCorrect = result.isCorrect;
        _correctAnswerIndexes[_currentIndex] = result.correctAnswer;
        _pointsAwardedByQuestion[_currentIndex] = result.pointsAwarded;
        _nextReviewAtByQuestion[_currentIndex] = result.nextReviewAt;
        if (result.isCorrect) _correctAnswers++;
        _score += result.pointsAwarded;
      });
      unawaited(_refreshTriviaProgress());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmittingAnswer = false;
        _selectedAnswerIndex = null;
        _selectedAnswers[_currentIndex] = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo comprobar la respuesta: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _startTimer();
    }
  }

  Future<void> _refreshTriviaProgress() async {
    if (_authService.currentUser == null) return;
    try {
      final summary = await ServiceLocator.gameProgress.getMyProgress();
      final reviewQueue = await _triviaService.getMyReviewQueue();
      if (!mounted) return;
      setState(() {
        _progressSummary = summary;
        _reviewQueue = reviewQueue;
      });
    } catch (error) {
      debugPrint('Error refreshing trivia progress: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La respuesta se guardó, pero no se pudo actualizar tu progreso: $error',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _advanceQuestion() {
    if (!_isAnswered || _isSubmittingAnswer || _gameFinished) return;
    if (_currentIndex < _trivias.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _isCorrect = null;
        _selectedAnswerIndex = null;
      });
      _startTimer();
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
    unawaited(_refreshTriviaProgress());
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
      final correctAnswer = _correctAnswerIndexes[index];
      return answer != null && correctAnswer != null && answer != correctAnswer;
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
              if (_authService.currentUser == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Inicia sesión para guardar XP y sincronizar tus repasos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
              ],
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
                    label: 'XP ganados',
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
        final correctAnswer = _correctAnswerIndexes[questionIndex];
        final isCorrect =
            selectedAnswer != null && selectedAnswer == correctAnswer;
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
              if (wasAnswered &&
                  correctAnswer != null &&
                  selectedAnswer != correctAnswer) ...[
                const SizedBox(height: 8),
                _ReviewAnswer(
                  label: 'Respuesta correcta',
                  text: trivia.options[correctAnswer],
                  isCorrect: true,
                  isNeutral: !wasAnswered,
                ),
              ],
              if ((trivia.explanation ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(trivia.explanation!, style: AppTheme.bodyStyle(context)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfiguration(BuildContext context) {
    final availableCount = _availableTrivias.length;
    final reviewIds = _reviewQueue.map((question) => question.triviaId).toSet();
    final dueReviewCount = _availableTrivias
        .where((trivia) => reviewIds.contains(trivia.id))
        .length;
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
                      '$availableCount preguntas disponibles · '
                      '$dueReviewCount para repasar',
                      style: AppTheme.bodyStyle(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildTriviaProgressCard(context, dueReviewCount),
        const SizedBox(height: 24),
        _ConfigSection(
          icon: Icons.tune_rounded,
          title: 'Configura tu partida',
          subtitle: 'Elige la duración y la dificultad',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cantidad de preguntas', style: AppTheme.bodyStyle(context)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                runSpacing: 8,
                children: _questionCountPresets
                    .map(
                      (count) => _ChoiceChip(
                        label: '$count',
                        selected: count == _selectedQuestionCount,
                        enabled: questionCounts.contains(count),
                        onTap: () =>
                            setState(() => _selectedQuestionCount = count),
                      ),
                    )
                    .toList(),
              ),
              if (questionCounts.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Se necesitan al menos 10 preguntas con estos filtros.',
                  style: TextStyle(color: context.palette.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              Text('Dificultad', style: AppTheme.bodyStyle(context)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                runSpacing: 8,
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.palette.border),
          ),
          child: ExpansionTile(
            initiallyExpanded: _showMoreOptions,
            onExpansionChanged: (expanded) {
              setState(() => _showMoreOptions = expanded);
            },
            leading: Icon(
              Icons.more_horiz_rounded,
              color: context.palette.primary,
            ),
            title: const Text('Más opciones'),
            subtitle: const Text('Categoría y límite de tiempo'),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            children: [
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
              const SizedBox(height: 12),
              _ConfigSection(
                icon: Icons.timer_outlined,
                title: 'Límite de tiempo',
                subtitle: 'Opcional; no aumenta la XP',
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
                          onTap: () =>
                              setState(() => _selectedTimeLimit = timeLimit),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        if (dueReviewCount > 0) ...[
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _startGame(focusReviews: true),
              icon: const Icon(Icons.replay_circle_filled_rounded),
              label: Text('Priorizar $dueReviewCount repasos vencidos'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: questionCounts.isEmpty ? null : _startGame,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              questionCounts.isEmpty
                  ? 'Se necesitan al menos 10 preguntas'
                  : 'Comenzar partida',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTriviaProgressCard(BuildContext context, int dueReviewCount) {
    final user = _authService.currentUser;
    final summary = _progressSummary;
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: user == null
          ? Row(
              children: [
                Icon(Icons.sync_disabled_rounded, color: palette.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Inicia sesión para guardar XP y sincronizar tus repasos.',
                    style: AppTheme.bodyStyle(context),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _ProgressValue(
                    label: 'XP',
                    value: '${summary?.totalXp ?? 0}',
                    icon: Icons.stars_rounded,
                  ),
                ),
                Expanded(
                  child: _ProgressValue(
                    label: 'Rango',
                    value: _naturalistRank(summary?.totalXp ?? 0),
                    icon: Icons.workspace_premium_rounded,
                  ),
                ),
                Expanded(
                  child: _ProgressValue(
                    label: 'Por repasar',
                    value: '$dueReviewCount',
                    icon: Icons.replay_rounded,
                  ),
                ),
              ],
            ),
    );
  }

  String _naturalistRank(int points) {
    return GameProgressModel.rankForXp(points).name;
  }

  String _nextReviewLabel(DateTime? nextReviewAt) {
    if (nextReviewAt == null) return '';
    final remaining = nextReviewAt.difference(DateTime.now());
    if (remaining.inDays >= 1) return '${remaining.inDays} d';
    if (remaining.inHours >= 1) return '${remaining.inHours} h';
    return '${remaining.inMinutes.clamp(1, 59)} min';
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
                    if (_isSubmittingAnswer) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Center(child: Text('Comprobando respuesta...')),
                    ],
                    if (_isAnswered) ...[
                      const SizedBox(height: 4),
                      _AnswerFeedback(
                        isCorrect: _isCorrect!,
                        message: _answerFeedbackMessage(),
                        explanation: _trivias[_currentIndex].explanation,
                        nextReviewLabel: _nextReviewLabel(
                          _nextReviewAtByQuestion[_currentIndex],
                        ),
                        nextButtonLabel: _currentIndex == _trivias.length - 1
                            ? 'Ver resultados'
                            : 'Siguiente pregunta',
                        onContinue: _advanceQuestion,
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

  String _answerFeedbackMessage() {
    if (!_isCorrect!) {
      return 'No fue esta vez. La respuesta correcta está marcada en verde.';
    }
    if (_authService.currentUser == null) {
      return '¡Correcto! Inicia sesión para guardar XP y programar repasos.';
    }
    if (_pointsAwardedByQuestion[_currentIndex] > 0) {
      return '¡Correcto! Ganaste '
          '${_pointsAwardedByQuestion[_currentIndex]} XP.';
    }
    return '¡Correcto! Esta respuesta quedó registrada; sigue practicando '
        'y volveremos a mostrarla para reforzar tu memoria.';
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
                  'Hasta ${trivia.points} XP',
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
        final correctAnswer = _correctAnswerIndexes[_currentIndex];
        final isCorrectOption = correctAnswer != null && index == correctAnswer;
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
              onTap: _isAnswered || _isSubmittingAnswer
                  ? null
                  : () => _handleAnswer(index),
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
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
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
              color: !enabled
                  ? palette.textSecondary.withValues(alpha: 0.45)
                  : selected
                  ? palette.primary
                  : palette.textSecondary,
            ),
      selected: selected,
      onSelected: enabled ? (_) => onTap() : null,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: !enabled
            ? palette.textSecondary.withValues(alpha: 0.45)
            : selected
            ? palette.primary
            : palette.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      backgroundColor: palette.surface,
      selectedColor: palette.primarySoft,
      side: BorderSide(
        color: !enabled
            ? palette.border.withValues(alpha: 0.5)
            : selected
            ? palette.primary
            : palette.border,
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

class _ProgressValue extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProgressValue({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: context.palette.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.palette.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.textSecondary, fontSize: 11),
        ),
      ],
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
  final String message;
  final String? explanation;
  final String nextReviewLabel;
  final String nextButtonLabel;
  final VoidCallback onContinue;

  const _AnswerFeedback({
    required this.isCorrect,
    required this.message,
    required this.explanation,
    required this.nextReviewLabel,
    required this.nextButtonLabel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = isCorrect ? palette.success : palette.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (nextReviewLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Próximo repaso: $nextReviewLabel',
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
          if (explanation != null && explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              explanation!,
              style: TextStyle(color: palette.textPrimary, height: 1.35),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onContinue,
              icon: Icon(
                isCorrect ? Icons.arrow_forward_rounded : Icons.school_rounded,
              ),
              label: Text(nextButtonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
