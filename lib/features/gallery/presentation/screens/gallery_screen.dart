import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '/shared/widgets/common_widgets.dart';
import '/features/gallery/data/models/species_model.dart';
import '/features/auth/data/services/auth_service.dart';
import '/features/gallery/data/services/species_service.dart';
import '/core/theme/app_theme.dart';
import '/core/theme/colors.dart';
import '/features/auth/presentation/screens/login_screen.dart';

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
  final AuthService _authService = AuthService();
  final SpeciesService _speciesService = SpeciesService();

  List<SpeciesModel> _species = [];
  List<SpeciesModel> _filteredSpecies = [];
  Set<int> _discoveredSpeciesIds = <int>{};
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isFetching = false;
  String? _loadError;
  String _selectedFilter = 'Todos';

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
    final shouldReload = widget.isActive &&
        (!oldWidget.isActive ||
            oldWidget.isAuthenticated != widget.isAuthenticated);

    if (shouldReload) {
      _loadSpecies();
    }
  }

  Future<void> _loadSpecies() async {
    if (_isFetching) return;
    _isFetching = true;
    if (!_hasLoaded) setState(() => _isLoading = true);
    setState(() => _loadError = null);

    try {
      final speciesList = await _speciesService.getAllSpecies();
      final discoveredIds = <int>{};

      if (widget.isAuthenticated && _authService.currentUser != null) {
        final discoveredSpecies = await _speciesService.getDiscoveredSpecies(
          _authService.currentUser!.id,
        );
        discoveredIds.addAll(discoveredSpecies.map((species) => species.id));
      }

      if (!mounted) return;

      setState(() {
        _species = speciesList;
        _filteredSpecies = _applyFilter(speciesList, _selectedFilter);
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

  List<SpeciesModel> _applyFilter(List<SpeciesModel> list, String filter) {
    if (filter == 'Todos') return list;
    return list.where((species) {
      final rarity = species.rarity.toLowerCase();
      return rarity == filter.toLowerCase();
    }).toList();
  }

  void _filterByRarity(String rarity) {
    setState(() {
      _selectedFilter = rarity;
      _filteredSpecies = _applyFilter(_species, rarity);
    });
  }

  bool _isSpeciesUnlocked(SpeciesModel species) {
    return _discoveredSpeciesIds.contains(species.id);
  }

  void _openSpeciesDetails(SpeciesModel species) {
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
                _isSpeciesUnlocked(species)
                    ? 'Especie descubierta'
                    : 'Especie bloqueada',
                style: TextStyle(
                  color: _isSpeciesUnlocked(species)
                      ? context.palette.success
                      : context.palette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (species.description != null && species.description!.trim().isNotEmpty)
                Text(
                  species.description!,
                  style: AppTheme.bodyStyle(context),
                )
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
            title: const Text('Colección de especies'),
          ),
          body: RefreshIndicator(
            onRefresh: _loadSpecies,
            color: context.palette.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildFilterChips()),
                if (_isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.84,
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
                else if (_filteredSpecies.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateWidget(
                      icon: Icons.forest_outlined,
                      title: 'No se encontraron especies',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _SpeciesCard(
                          species: _filteredSpecies[index],
                          isUnlocked: _isSpeciesUnlocked(_filteredSpecies[index]),
                          onTap: () => _openSpeciesDetails(_filteredSpecies[index]),
                        ),
                        childCount: _filteredSpecies.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!widget.isAuthenticated) _buildLockedOverlay(context),
      ],
    );
  }

  Widget _buildLockedOverlay(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: context.palette.background.withValues(alpha: 0.52),
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
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Iniciar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Todos', 'comun', 'raro', 'epico', 'legendario'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  filter == 'Todos' ? filter : filter.toUpperCase(),
                  style: TextStyle(
                    color: isSelected
                        ? context.palette.primary
                        : context.palette.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) _filterByRarity(filter);
                },
                backgroundColor: context.palette.surface,
                selectedColor: context.palette.primarySoft,
                checkmarkColor: context.palette.primary,
              ),
            );
          }).toList(),
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: SkeletonBlock(width: 28, height: 28, radius: 14),
          ),
          const Spacer(),
          const SkeletonBlock(width: 90, height: 20),
          const SizedBox(height: 8),
          const SkeletonBlock(width: 70, height: 12),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnlocked ? palette.surface : palette.surfaceMuted,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isUnlocked ? palette.primarySoft : palette.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SpeciesImage(
                species: species,
                width: double.infinity,
                height: 120,
                borderRadius: 16,
              ),
              const Spacer(),
              Text(
                species.nameCommon,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                species.nameScientific ?? 'Especie sin nombre científico',
                maxLines: 2,
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
    );
  }
}

class _SpeciesImage extends StatelessWidget {
  final SpeciesModel species;
  final double width;
  final double height;
  final double borderRadius;

  const _SpeciesImage({
    required this.species,
    required this.width,
    required this.height,
    required this.borderRadius,
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
            ? Icon(
                Icons.pets_rounded,
                size: height >= 80 ? 42 : 24,
                color: context.palette.primary,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.pets_rounded,
                  size: height >= 80 ? 42 : 24,
                  color: context.palette.primary,
                ),
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
    );
  }
}
