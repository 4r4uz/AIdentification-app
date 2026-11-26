import 'package:flutter/material.dart';

import '/mobile/core/theme/app_theme.dart';
import '/mobile/core/theme/colors.dart';
import '/mobile/features/gamification/data/models/game_progress_model.dart';

class GameProgressBadge extends StatelessWidget {
  final Future<GameProgressModel?> progressFuture;
  final VoidCallback onTap;

  const GameProgressBadge({
    required this.progressFuture,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return FutureBuilder<GameProgressModel?>(
      future: progressFuture,
      builder: (context, snapshot) {
        final progress = snapshot.data;
        final label = snapshot.hasError
            ? 'Progreso'
            : progress == null
            ? 'Minijuegos'
            : 'N${progress.currentRank.level} · ${progress.currentRank.name}';

        return Material(
          color: palette.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars_rounded, color: palette.primary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (progress != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      '${progress.totalXp} XP',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class GameProgressCard extends StatelessWidget {
  final GameProgressModel progress;
  final bool showAllRanks;

  const GameProgressCard({
    required this.progress,
    this.showAllRanks = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final nextRank = progress.nextRank;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.primarySoft, palette.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: palette.primary,
                  size: 31,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nivel ${progress.currentRank.level} · '
                      '${progress.currentRank.name}',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${progress.totalXp} XP total de minijuegos',
                      style: AppTheme.bodyStyle(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          if (nextRank == null)
            Text(
              '¡Has alcanzado el nivel máximo!',
              style: TextStyle(
                color: palette.primary,
                fontWeight: FontWeight.w700,
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.xpToNextRank} XP para Nivel ${nextRank.level}',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  nextRank.name,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.rankProgress,
                minHeight: 9,
                backgroundColor: palette.surfaceMuted,
                color: palette.primary,
              ),
            ),
          ],
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProgressPill(
                icon: Icons.quiz_rounded,
                label: '${progress.masteredQuestions} preguntas aprendidas',
              ),
              _ProgressPill(
                icon: Icons.check_circle_outline_rounded,
                label:
                    '${progress.correctAttempts}/${progress.totalAttempts} '
                    'aciertos',
              ),
              _ProgressPill(
                icon: Icons.sports_esports_rounded,
                label: 'Trivia activa · otros minijuegos próximamente',
              ),
            ],
          ),
          if (showAllRanks) ...[
            const SizedBox(height: 18),
            Text(
              'Niveles de Naturalista',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            ...GameProgressModel.ranks.map((rank) {
              final reached = progress.totalXp >= rank.minimumPoints;
              final current = progress.currentRank.level == rank.level;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      reached
                          ? Icons.check_circle_rounded
                          : Icons.lock_outline_rounded,
                      color: reached ? palette.success : palette.textSecondary,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Nivel ${rank.level} · ${rank.name}',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: current
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${rank.minimumPoints} XP',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProgressPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: palette.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
