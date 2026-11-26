import 'package:flutter/material.dart';

import '/mobile/core/service_locator.dart';
import '/mobile/core/theme/colors.dart';
import '/mobile/features/gamification/data/models/game_progress_model.dart';
import '/mobile/features/gamification/presentation/widgets/game_progress_widgets.dart';
import '/mobile/widgets/common_widgets.dart';

class GameProgressScreen extends StatefulWidget {
  const GameProgressScreen({super.key});

  @override
  State<GameProgressScreen> createState() => _GameProgressScreenState();
}

class _GameProgressScreenState extends State<GameProgressScreen> {
  Future<GameProgressModel?>? _progressFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _progressFuture = ServiceLocator.gameProgress.getMyProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progreso de minijuegos'),
        backgroundColor: context.palette.primarySoft,
      ),
      body: FutureBuilder<GameProgressModel?>(
        future: _progressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Cargando tu progreso...');
          }
          if (snapshot.hasError) {
            return EmptyStateWidget(
              icon: Icons.cloud_off_outlined,
              title: 'No se pudo cargar el progreso',
              message: snapshot.error.toString(),
              buttonText: 'Reintentar',
              onButtonPressed: _reload,
            );
          }

          final progress = snapshot.data;
          if (progress == null) {
            return const EmptyStateWidget(
              icon: Icons.person_outline_rounded,
              title: 'Inicia sesión para ver tu progreso',
              message:
                  'Tu XP y nivel se guardan en la cuenta y se compartirán '
                  'entre los minijuegos.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _progressFuture;
            },
            color: context.palette.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                GameProgressCard(progress: progress, showAllRanks: true),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Text(
                    'El XP y el nivel son globales para tu cuenta, no se '
                    'reinician entre minijuegos. Trivia ya aporta XP mediante '
                    'respuestas correctas y repasos espaciados. Los próximos '
                    'minijuegos usarán el mismo progreso. Fallar no quita XP.',
                    style: TextStyle(
                      color: context.palette.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
