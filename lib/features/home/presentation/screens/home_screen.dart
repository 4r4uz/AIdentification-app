import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/core/theme/app_theme.dart';
import '/core/theme/colors.dart';
import '/core/constants/app_texts.dart';
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
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final SpeciesService _speciesService = SpeciesService();
  String? _imageUrl;
  late Future<List<SpeciesFactModel>> _factsFuture;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authService.authStateChanges.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.signedOut ||
          _authService.currentUser == null) {
        setState(() => _imageUrl = null);
      } else if (state.event == AuthChangeEvent.signedIn) {
        _loadProfileImage();
      }
    });
    _factsFuture = _speciesService.getAllSpeciesFacts();
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
    });
    await Future.wait([_loadProfileImage(), _factsFuture]);
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppTexts.exploreSectionTitle,
          style: AppTheme.headingStyle(context)
              .copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
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
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 8),
                          _FactsCarousel(factsFuture: _factsFuture),
                          const SizedBox(height: 32),
                          _buildExploreSectionHeader(context),
                          const SizedBox(height: 16),
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
              width: 48,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: palette.primarySoft,
                shape: BoxShape.circle,
              ),
              child: imageUrl == null
                  ? Icon(Icons.person_rounded, color: palette.primary, size: 27)
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      cacheWidth: (48 * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                      cacheHeight: (48 * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person_rounded,
                        color: palette.primary,
                        size: 27,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        ElevatedButton(
          onPressed: onAchievementsTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.background,
            foregroundColor: palette.textPrimary,
            overlayColor: Colors.transparent,
            side: BorderSide(color: palette.border, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40))
          ),
          child:
            const Text("Logros"),
        ),
        const Spacer(),
        IconButton(
          onPressed: onSettingsTap,
          tooltip: 'Configuración',
          icon: Icon(Icons.settings_outlined, color: palette.textSecondary),
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
    _rotationTimer = Timer.periodic(const Duration(seconds: 6), (_) {
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
    final pool = available.isEmpty ? List<SpeciesFactModel>.from(_facts) : available;
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
        height: 142,
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
          height: 142,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {},
            itemBuilder: (context, index) {
              final fact = _factForPage(index);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: palette.primary,
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Flexible(
                                  child: Text(
                                    fact.speciesName ?? 'Dato curioso',
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: palette.cameraForeground,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                if (fact.scientificName != null &&
                                    fact.scientificName!.trim().isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      fact.scientificName!,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.bodyStyle(context)
                                          .copyWith(
                                            color: palette.cameraForeground
                                                .withValues(alpha: 0.62),
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              fact.fact,
                              style: AppTheme.bodyStyle(context).copyWith(
                                color: palette.cameraForeground.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _FactsMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _FactsMessage({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
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
    final double cellWidth = (screenWidth - 44 - 14) / 2;
    final double gridHeight = 2 * (cellWidth / 0.88) + 14;

    return SizedBox(
      height: gridHeight,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.88,
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
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: isAvailable
                  ? palette.primary.withValues(alpha: 0.3)
                  : palette.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isAvailable ? palette.primary : palette.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  game.icon,
                  color: isAvailable
                      ? palette.cameraForeground
                      : palette.primary.withValues(alpha: 0.5),
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                game.title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                game.description,
                style: AppTheme.bodyStyle(
                  context,
                ).copyWith(color: palette.textSecondary.withValues(alpha: 0.8)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isAvailable)
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: palette.primary,
                      size: 20,
                    )
                  else
                    Icon(
                      Icons.lock_rounded,
                      color: palette.textSecondary,
                      size: 20,
                    ),
                  const SizedBox(width: 8),
                  if (!isAvailable)
                    Text(
                      AppTexts.exploreSectionLocked,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
