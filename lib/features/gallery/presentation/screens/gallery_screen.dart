import 'package:flutter/material.dart';

import '/core/service_locator.dart';
import '/shared/widgets/common_widgets.dart';
import '/features/gallery/data/models/species_model.dart';
import '/core/theme/app_theme.dart';
import '/core/theme/colors.dart';

class GalleryScreen extends StatefulWidget {
  final bool isActive;
  final bool isAuthenticated;

  const GalleryScreen({
    super.key,
    this.isActive = true,
    this.isAuthenticated = true,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _authService = ServiceLocator.auth;
  final _speciesService = ServiceLocator.species;

  List<SpeciesModel> _species = [];
  Set<int> _discoveredSpeciesIds = <int>{};
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isFetching = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _loadSpecies();
    }
  }

  @override
  void didUpdateWidget(covariant GalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldReload =
        widget.isActive &&
        (!oldWidget.isActive ||
            oldWidget.isAuthenticated != widget.isAuthenticated);

    if (shouldReload) {
      if (!widget.isAuthenticated && mounted) {
        setState(() {
          _discoveredSpeciesIds = <int>{};
          _loadError = null;
        });
      }
      _loadSpecies();
    }
  }

  Future<void> _loadSpecies() async {
    if (_isFetching) return;
    _isFetching = true;
    if (!_hasLoaded) setState(() => _isLoading = true);
    setState(() => _loadError = null);

    try {
      final userId = widget.isAuthenticated
          ? _authService.currentUser?.id
          : null;
      final results = await Future.wait<List<SpeciesModel>>([
        _speciesService.getAllSpecies(),
        if (userId != null) _speciesService.getDiscoveredSpecies(userId),
      ]);
      final speciesList = results.first;

      final activeUserId = widget.isAuthenticated
          ? _authService.currentUser?.id
          : null;
      if (activeUserId != userId) {
        if (mounted && widget.isActive) {
          _isFetching = false;
          await _loadSpecies();
        }
        return;
      }

      final discoveredIds = results.length > 1
          ? results[1].map((species) => species.id).toSet()
          : <int>{};

      if (!mounted) return;

      setState(() {
        _species = speciesList;
        _discoveredSpeciesIds = discoveredIds;
        _hasLoaded = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading species: $e');
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _hasLoaded = true;
          _isLoading = false;
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  bool _isSpeciesUnlocked(SpeciesModel species) {
    return _discoveredSpeciesIds.contains(species.id);
  }

  void _openSpeciesDetails(SpeciesModel species) {
    final isUnlocked = _isSpeciesUnlocked(species);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.palette.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _SpeciesImage(
                    species: species,
                    width: 52,
                    height: 52,
                    borderRadius: 18,
                    silhouette: !isUnlocked,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          species.nameCommon,
                          style: TextStyle(
                            color: context.palette.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (species.nameScientific != null)
                          Text(
                            species.nameScientific!,
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                isUnlocked ? 'Especie descubierta' : 'Especie bloqueada',
                style: TextStyle(
                  color: isUnlocked
                      ? context.palette.success
                      : context.palette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (species.description != null &&
                  species.description!.trim().isNotEmpty)
                Text(species.description!, style: AppTheme.bodyStyle(context))
              else
                Text(
                  'Aún no hay descripción detallada disponible para esta especie.',
                  style: AppTheme.bodyStyle(context),
                ),
              const SizedBox(height: 18),
              if (species.habitat != null && species.habitat!.trim().isNotEmpty)
                _InfoChip(label: 'Hábitat', value: species.habitat!),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Colección'),
            backgroundColor: context.palette.primarySoft,
          ),
          body: RefreshIndicator(
            onRefresh: _loadSpecies,
            color: context.palette.primary,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.palette.primarySoft.withValues(alpha: 0.42),
                    context.palette.background,
                    context.palette.background,
                  ],
                  stops: const [0, 0.3, 1],
                ),
              ),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (_isLoading)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 230,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 16,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => const _SpeciesCardSkeleton(),
                          childCount: 6,
                        ),
                      ),
                    )
                  else if (_loadError != null && _species.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyStateWidget(
                        icon: Icons.cloud_off_outlined,
                        title: 'No se pudo cargar la galería',
                        message: _loadError,
                        buttonText: 'Reintentar',
                        onButtonPressed: _loadSpecies,
                      ),
                    )
                  else if (_species.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyStateWidget(
                        icon: Icons.forest_outlined,
                        title: 'No se encontraron especies',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 230,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 16,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _SpeciesCard(
                            species: _species[index],
                            isUnlocked: _isSpeciesUnlocked(_species[index]),
                            onTap: () => _openSpeciesDetails(_species[index]),
                          ),
                          childCount: _species.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!widget.isAuthenticated) _buildLockedOverlay(context),
      ],
    );
  }

  Widget _buildLockedOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: context.palette.background.withValues(alpha: 0.18),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 38,
                color: context.palette.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Galería bloqueada',
                textAlign: TextAlign.center,
                style: AppTheme.headingStyle(context),
              ),
              const SizedBox(height: 8),
              Text(
                'Inicia sesión para desbloquear tu colección y guardar tus hallazgos.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyStyle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeciesCardSkeleton extends StatelessWidget {
  const _SpeciesCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.palette.border),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: SkeletonBlock(width: 24, height: 24, radius: 12),
          ),
          const Spacer(),
          const SkeletonBlock(width: 56, height: 20),
          const SizedBox(height: 8),
          const SkeletonBlock(width: 44, height: 12),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.palette.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  final SpeciesModel species;
  final bool isUnlocked;
  final VoidCallback onTap;

  const _SpeciesCard({
    required this.species,
    required this.isUnlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: isUnlocked ? palette.surface : palette.primarySoft,
      elevation: 2,
      shadowColor: palette.textPrimary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Container(
                  height: 134,
                  width: double.infinity,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _SpeciesImage(
                          species: species,
                          width: double.infinity,
                          height: 130,
                          borderRadius: 0,
                          silhouette: !isUnlocked,
                        ),
                        if (isUnlocked)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: palette.surface.withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.eco_rounded,
                                color: palette.primary,
                                size: 17,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        species.nameCommon,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        species.nameScientific ??
                            'Especie sin nombre científico',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
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

class _SpeciesImage extends StatelessWidget {
  final SpeciesModel species;
  final double width;
  final double height;
  final double borderRadius;
  final bool silhouette;

  const _SpeciesImage({
    required this.species,
    required this.width,
    required this.height,
    required this.borderRadius,
    this.silhouette = false,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = species.imageUrl?.trim();
    final fallbackColor = context.palette.primarySoft;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: fallbackColor,
        child: imageUrl == null || imageUrl.isEmpty
            ? const SizedBox.shrink()
            : ColorFiltered(
                colorFilter: silhouette
                    ? const ColorFilter.matrix([
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ])
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: loadingProgress.expectedTotalBytes == null
                              ? null
                              : loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!,
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
