import 'package:flutter/material.dart';
import '/core/theme/colors.dart';
import '/core/theme/app_theme.dart';
import '/features/trivia/data/services/trivia_service.dart';
import '/features/auth/data/services/auth_service.dart';
import '/features/trivia/data/models/trivia_model.dart';
import '/shared/widgets/common_widgets.dart';

class TriviaScreen extends StatefulWidget {
  const TriviaScreen({super.key});

  @override
  State<TriviaScreen> createState() => _TriviaScreenState();
}

class _TriviaScreenState extends State<TriviaScreen> {
  final TriviaService _triviaService = TriviaService();
  final AuthService _authService = AuthService();

  List<TriviaModel> _trivias = [];
  int _currentIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  bool _isLoading = true;
  bool _isAnswered = false;
  bool? _isCorrect;

  @override
  void initState() {
    super.initState();
    _loadTrivias();
  }

  Future<void> _loadTrivias() async {
    setState(() => _isLoading = true);
    try {
      final trivias = await _triviaService.getRandomTrivias(5);
      if (mounted) {
        setState(() {
          _trivias = trivias;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trivias: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAnswer(int selectedIndex) async {
    if (_isAnswered) return;

    final currentTrivia = _trivias[_currentIndex];
    final isCorrect = selectedIndex == currentTrivia.correctAnswer;

    setState(() {
      _isAnswered = true;
      _isCorrect = isCorrect;
      if (isCorrect) {
        _score += currentTrivia.points;
        _correctAnswers++;
      }
    });

    final user = _authService.currentUser;
    if (user != null) {
      try {
        await _triviaService.recordTriviaAttempt(
          user.id,
          currentTrivia.id,
          isCorrect,
        );
      } catch (e) {
        debugPrint('Error recording trivia attempt: $e');
      }
    }

    await Future.delayed(const Duration(seconds: 2));

    if (_currentIndex < _trivias.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _isCorrect = null;
      });
    } else {
      _showResults();
    }
  }

  void _showResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          '¡Trivia Completada!',
          style: TextStyle(
            color: context.palette.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Puntuación: $_score',
              style: TextStyle(
                color: context.palette.primary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Correctas: $_correctAnswers/${_trivias.length}',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _resetTrivia();
              },
              child: const Text('Jugar de nuevo'),
            ),
          ),
        ],
      ),
    );
  }

  void _resetTrivia() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _correctAnswers = 0;
      _isAnswered = false;
      _isCorrect = null;
    });
    _loadTrivias();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trivia animal')),
      body: RefreshIndicator(
        onRefresh: _refreshTrivia,
        color: context.palette.primary,
        child: _isLoading
            ? const LoadingIndicator(message: 'Cargando trivia...')
            : _trivias.isEmpty
            ? EmptyStateWidget(
                icon: Icons.quiz_outlined,
                title: 'No hay trivias disponibles',
                buttonText: 'Reintentar',
                onButtonPressed: _loadTrivias,
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppTheme.defaultPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProgressIndicator(context),
                    const SizedBox(height: 24),
                    _buildQuestionCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _trivias.length,
          backgroundColor: context.palette.primarySoft,
          color: context.palette.primary,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text(
          'Pregunta ${_currentIndex + 1} de ${_trivias.length}',
          style: TextStyle(color: context.palette.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _refreshTrivia() async {
    _resetTrivia();
  }

  Widget _buildQuestionCard() {
    final trivia = _trivias[_currentIndex];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Padding(
        padding: AppTheme.cardPadding,
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
                    color: context.palette.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '+${trivia.points} pts',
                    style: TextStyle(
                      color: context.palette.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              trivia.question,
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trivia.options.length,
              itemBuilder: (context, index) {
                final option = trivia.options[index];
                Color? optionColor;

                if (_isAnswered) {
                  if (index == trivia.correctAnswer) {
                    optionColor = context.palette.success;
                  } else if (index == _getSelectedIndex() && !_isCorrect!) {
                    optionColor = context.palette.error;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    onPressed: _isAnswered ? null : () => _handleAnswer(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          optionColor ?? context.palette.surfaceMuted,
                      foregroundColor: optionColor == null
                          ? context.palette.textPrimary
                          : Colors.white,
                      padding: const EdgeInsets.all(20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.buttonRadius,
                        ),
                        side: BorderSide(
                          color: _isAnswered && index == trivia.correctAnswer
                              ? context.palette.success
                              : _isAnswered &&
                                    index == _getSelectedIndex() &&
                                    !_isCorrect!
                              ? context.palette.error
                              : context.palette.border,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      option,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(BuildContext context, String difficulty) {
    Color color;
    switch (difficulty) {
      case 'facil':
        color = context.palette.success;
      case 'medio':
        color = context.palette.primary;
      case 'dificil':
        color = context.palette.error;
      default:
        color = context.palette.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  int? _getSelectedIndex() {
    if (!_isAnswered || _isCorrect != null) return null;
    return _currentIndex;
  }
}
