import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '/core/theme/colors.dart';
import '/features/trivia/presentation/screens/trivia_screen.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  void _openTrivia(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TriviaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: palette.primarySoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.pets_rounded,
                          color: palette.primary,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AnimalPedia',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Explora la vida silvestre',
                            style: AppTheme.bodyStyle(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _CameraHeroCard(onPressed: () => onNavigate?.call(1)),
                  const SizedBox(height: 32),
                  Text(
                    'Sigue explorando',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aprende y descubre nuevas especies.',
                    style: AppTheme.bodyStyle(context),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 186,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      children: [
                        _ExploreCard(
                          title: 'Trivia animal',
                          subtitle: 'Pon a prueba lo que sabes',
                          icon: Icons.quiz_rounded,
                          tint: palette.primarySoft,
                          accent: palette.primary,
                          onTap: () => _openTrivia(context),
                        ),
                        const SizedBox(width: 14),
                        _ExploreCard(
                          title: 'Galería',
                          subtitle: 'Conoce las especies',
                          icon: Icons.auto_awesome_mosaic_rounded,
                          tint: palette.primarySoft,
                          accent: palette.primary,
                          onTap: () => onNavigate?.call(2),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraHeroCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _CameraHeroCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.palette.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.center_focus_strong_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '¿Qué animal encontraste?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toma una foto y descubre su especie.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .88),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.camera_alt_rounded, size: 19),
            label: const Text('Identificar animal'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: context.palette.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;

  const _ExploreCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 235,
      child: Material(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: context.palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 23),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppTheme.bodyStyle(context)),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.arrow_forward_rounded, color: accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
