import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/core/service_locator.dart';
import '/core/theme/app_theme.dart';
import '/core/theme/colors.dart';
import '/features/auth/data/services/auth_service.dart';
import '/features/profile/data/services/profile_service.dart';
import '/features/profile/presentation/screens/profile_settings_screen.dart';
import '/features/trivia/presentation/screens/trivia_screen.dart';
import '/features/gallery/data/models/species_fact_model.dart';
import '/features/gallery/data/services/species_service.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  final VoidCallback? onProfileTap;

  const HomeScreen({super.key, this.onNavigate, this.onProfileTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = ServiceLocator.auth;
  final ProfileService _profileService = ServiceLocator.profile;
  final SpeciesService _speciesService = ServiceLocator.species;
  String? _imageUrl;
  late Future<List<SpeciesFactModel>> _factsFuture;
  late Future<({int total, int? discovered})> _speciesStatsFuture;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authService.authStateChanges.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.signedOut ||
          _authService.currentUser == null) {
        setState(() {
          _imageUrl = null;
          _speciesStatsFuture = _loadSpeciesStats();
        });
      } else if (state.event == AuthChangeEvent.signedIn) {
        setState(() => _speciesStatsFuture = _loadSpeciesStats());
        _loadProfileImage();
      }
    });
    _factsFuture = _speciesService.getAllSpeciesFacts();
    _speciesStatsFuture = _loadSpeciesStats();
    _loadProfileImage();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileImage() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final imageUrl = await _profileService.getProfilePictureUrl(user.id);
    if (mounted && _authService.currentUser?.id == user.id) {
      setState(() => _imageUrl = imageUrl);
    }
  }

  Future<void> _refreshHome() async {
    setState(() {
      _factsFuture = _speciesService.getAllSpeciesFacts();
      _speciesStatsFuture = _loadSpeciesStats();
    });
    await Future.wait([_loadProfileImage(), _factsFuture, _speciesStatsFuture]);
  }

  Future<({int total, int? discovered})> _loadSpeciesStats() async {
    final species = await _speciesService.getAllSpecies();
    final userId = _authService.currentUser?.id;
    if (userId == null) {
      return (total: species.length, discovered: null);
    }

    final discovered = await _speciesService.getDiscoveredSpecies(userId);
    return (
      total: species.length,
      discovered: discovered.length.clamp(0, species.length),
    );
  }

  void _openTrivia(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TriviaScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
    );
  }

  void _openAchievements(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Logros'),
        content: Text('Esta sección estará disponible próximamente.'),
      ),
    );
  }

  Widget _buildExploreSectionHeader(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(Icons.sports_esports_rounded, color: palette.primary, size: 25),
        const SizedBox(width: 9),
        Text(
          'Minijuegos',
          style: AppTheme.headingStyle(context)
              .copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.palette.primarySoft.withValues(alpha: 0.55),
              context.palette.background,
              context.palette.background,
            ],
            stops: const [0, 0.34, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: _HomeHeader(
                  imageUrl: _imageUrl,
                  onProfileTap: widget.onProfileTap,
                  onAchievementsTap: () => _openAchievements(context),
                  onSettingsTap: () => _openSettings(context),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshHome,
                  color: context.palette.primary,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _CollectionSummary(
                              statsFuture: _speciesStatsFuture,
                              onTap: () => widget.onNavigate?.call(2),
                            ),
                            const SizedBox(height: 18),
                            _FactsCarousel(factsFuture: _factsFuture),
                            const SizedBox(height: 26),
                            _buildExploreSectionHeader(context),
                            const SizedBox(height: 12),
                            _ExploreGridSection(
                              onTriviaTap: () => _openTrivia(context),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionSummary extends StatelessWidget {
  final Future<({int total, int? discovered})> statsFuture;
  final VoidCallback onTap;

  const _CollectionSummary({required this.statsFuture, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.border.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: FutureBuilder(
                  future: statsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text(
                        'Cargando colección...',
                        style: AppTheme.bodyStyle(context),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Text(
                        'Explora la colección de especies',
                        style: AppTheme.bodyStyle(context),
                      );
                    }

                    final stats = snapshot.data!;
                    final discovered = stats.discovered;
                    if (discovered == null) {
                      return Text(
                        '${stats.total} especies para descubrir',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }

                    return Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: '$discovered especies descubiertas',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(text: '   •   '),
                          TextSpan(
                            text: '${stats.total - discovered} por descubrir',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: palette.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback? onProfileTap;
  final VoidCallback onAchievementsTap;
  final VoidCallback onSettingsTap;

  const _HomeHeader({
    required this.imageUrl,
    required this.onProfileTap,
    required this.onAchievementsTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Abrir perfil',
          child: GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 54,
              height: 54,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: palette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: palette.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: palette.textPrimary.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: imageUrl == null
                  ? Icon(Icons.person_rounded, color: palette.primary, size: 30)
                  : Transform.scale(
                      scale: 1.12,
                      child: Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        cacheWidth:
                            (60 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        cacheHeight:
                            (60 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person_rounded,
                          color: palette.primary,
                          size: 30,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: palette.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(30),
          child: InkWell(
            onTap: onAchievementsTap,
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded, color: palette.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Logros',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        Material(
          color: palette.surface.withValues(alpha: 0.8),
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: onSettingsTap,
            tooltip: 'Configuración',
            icon: Icon(Icons.settings_rounded, color: palette.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _FactsCarousel extends StatefulWidget {
  final Future<List<SpeciesFactModel>> factsFuture;

  const _FactsCarousel({required this.factsFuture});

  @override
  State<_FactsCarousel> createState() => _FactsCarouselState();
}

class _FactsCarouselState extends State<_FactsCarousel> {
  static const _initialPage = 9999;

  final PageController _pageController = PageController(
    initialPage: _initialPage,
  );
  Timer? _rotationTimer;
  List<SpeciesFactModel> _facts = [];
  final List<int> _recentFactIds = [];
  final Map<int, SpeciesFactModel> _factsByPage = {};
  String? _factsError;
  bool _isLoadingFacts = true;

  @override
  void initState() {
    super.initState();
    _loadFacts();
    _rotationTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!_pageController.hasClients) return;

      final nextPage = (_pageController.page ?? _initialPage).round() + 1;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadFacts() async {
    try {
      final facts = await widget.factsFuture;
      if (mounted) {
        setState(() {
          _facts = facts;
          _factsError = null;
          _isLoadingFacts = false;
        });
      }
    } catch (error) {
      debugPrint('Error cargando datos curiosos: $error');
      if (mounted) {
        setState(() {
          _factsError = 'No se pudieron cargar los datos curiosos.';
          _isLoadingFacts = false;
        });
      }
    }
  }

  SpeciesFactModel _selectFact() {
    final available = _facts
        .where((fact) => !_recentFactIds.contains(fact.id))
        .toList();
    final pool = available.isEmpty
        ? List<SpeciesFactModel>.from(_facts)
        : available;
    pool.shuffle();
    final selected = pool.first;

    _recentFactIds.add(selected.id);
    if (_recentFactIds.length > 3) _recentFactIds.removeAt(0);
    return selected;
  }

  SpeciesFactModel _factForPage(int page) {
    final existing = _factsByPage[page];
    if (existing != null) return existing;

    final fact = _selectFact();
    _factsByPage[page] = fact;
    return fact;
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FactsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.factsFuture != widget.factsFuture) {
      _recentFactIds.clear();
      _factsByPage.clear();
      _facts = [];
      _factsError = null;
      _isLoadingFacts = true;
      _loadFacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (_isLoadingFacts) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_factsError != null) {
      return _FactsMessage(
        message: _factsError!,
        onRetry: () {
          setState(() {
            _isLoadingFacts = true;
            _factsError = null;
          });
          _loadFacts();
        },
      );
    }

    if (_facts.isEmpty) {
      return const _FactsMessage(
        message: 'Aún no hay datos curiosos en Supabase.',
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: _pageController,
            itemBuilder: (context, index) {
              final fact = _factForPage(index);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          palette.primarySoft,
                          Color.lerp(
                            palette.primarySoft,
                            palette.surface,
                            0.35,
                          )!,
                          palette.surfaceMuted,
                        ],
                        stops: const [0, 0.52, 1],
                      ),
                      border: Border.all(
                        color: palette.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -68,
                          right: -42,
                          child: _GradientDecoration(
                            size: 250,
                            color: palette.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        Positioned(
                          bottom: -105,
                          left: -52,
                          child: _GradientDecoration(
                            size: 270,
                            color: palette.primary.withValues(alpha: 0.16),
                          ),
                        ),
                        Positioned(
                          top: 62,
                          left: 120,
                          child: _GradientDecoration(
                            size: 185,
                            color: palette.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.surface.withValues(
                                    alpha: 0.72,
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lightbulb_rounded,
                                      color: palette.primary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      'DATO CURIOSO',
                                      style: TextStyle(
                                        color: palette.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                fact.speciesName ?? 'Fauna silvestre',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 25,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (fact.scientificName != null &&
                                  fact.scientificName!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  fact.scientificName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                fact.fact,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GradientDecoration extends StatelessWidget {
  final double size;
  final Color color;

  const _GradientDecoration({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _FactsMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _FactsMessage({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _MiniGame {
  final String title;
  final String description;
  final IconData icon;

  const _MiniGame({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _ExploreGame {
  final String title;
  final String description;
  final IconData icon;

  const _ExploreGame({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _ExploreGridSection extends StatelessWidget {
  final VoidCallback onTriviaTap;

  const _ExploreGridSection({required this.onTriviaTap});

  @override
  Widget build(BuildContext context) {
    final games = [
      _ExploreGame(
        title: 'Trivia',
        description: 'Pon a prueba lo que sabes.',
        icon: Icons.quiz_rounded,
      ),
      _ExploreGame(
        title: '¿Quién soy?',
        description: 'Adivina el animal por su silueta.',
        icon: Icons.pets_rounded,
      ),
      _ExploreGame(
        title: 'Animaldle',
        description: 'Descubre el animal por intentos.',
        icon: Icons.search_rounded,
      ),
      _ExploreGame(
        title: 'Memoria',
        description: 'Encuentra todos los pares.',
        icon: Icons.grid_view_rounded,
      ),
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final double cellWidth = (screenWidth - 40 - 12) / 2;
    final double gridHeight = 2 * (cellWidth / 1.25) + 14;

    return SizedBox(
      height: gridHeight,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.25,
        ),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          final isAvailable = index == 0;
          return _ExploreGameCard(
            game: game,
            isAvailable: isAvailable,
            onTap: isAvailable ? onTriviaTap : null,
          );
        },
      ),
    );
  }
}

class _ExploreGameCard extends StatelessWidget {
  final _ExploreGame game;
  final bool isAvailable;
  final VoidCallback? onTap;

  const _ExploreGameCard({
    required this.game,
    required this.isAvailable,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: isAvailable ? palette.primarySoft : palette.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.primarySoft.withValues(alpha: isAvailable ? 0.9 : 0.6),
                palette.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: isAvailable
                  ? palette.primary.withValues(alpha: 0.3)
                  : palette.border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(game.icon, color: palette.primary, size: 24),
                    ),
                    const Spacer(),
                    Icon(
                      isAvailable
                          ? Icons.arrow_forward_rounded
                          : Icons.lock_rounded,
                      color: isAvailable
                          ? palette.primary
                          : palette.textSecondary,
                      size: 19,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  game.title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  game.description,
                  style: AppTheme.bodyStyle(context).copyWith(
                    color: palette.textSecondary.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
