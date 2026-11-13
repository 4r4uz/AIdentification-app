import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/core/service_locator.dart';
import '/features/auth/data/services/auth_service.dart';
import '/features/camera/data/services/detection_service.dart';
import '/shared/widgets/common_widgets.dart';
import '/features/profile/data/services/profile_refresh_notifier.dart';
import '/features/profile/data/services/profile_service.dart';
import '/features/gallery/presentation/screens/gallery_screen.dart';
import '/core/theme/app_theme.dart';
import '/core/theme/colors.dart';
import '/features/auth/presentation/screens/login_screen.dart';
import '/features/auth/presentation/screens/register_screen.dart';
import '/features/profile/presentation/screens/profile_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isActive;
  final bool isAuthenticated;

  const ProfileScreen({
    super.key,
    this.isActive = true,
    this.isAuthenticated = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = ServiceLocator.auth;
  final DetectionService _detectionService = ServiceLocator.detection;
  final ProfileService _profileService = ServiceLocator.profile;
  final _speciesService = ServiceLocator.species;
  final ImagePicker _imagePicker = ImagePicker();

  User? _currentUser;
  int _totalDetections = 0;
  int _discoveredSpeciesCount = 0;
  int _totalSpeciesCount = 0;
  bool _hasCollectionStats = false;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isFetching = false;
  bool _hasLoaded = false;
  String? _avatarUrl;
  File? _localAvatarFile;
  String? _loadError;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authService.authStateChanges.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.signedOut ||
          _authService.currentUser == null) {
        setState(() {
          _currentUser = null;
          _totalDetections = 0;
          _discoveredSpeciesCount = 0;
          _totalSpeciesCount = 0;
          _hasCollectionStats = false;
          _avatarUrl = null;
          _localAvatarFile = null;
          _loadError = null;
          _hasLoaded = false;
          _isLoading = false;
        });
      } else if (state.event == AuthChangeEvent.signedIn) {
        _loadUserData();
      }
    });
    ProfileRefreshNotifier.detectionSaved.addListener(
      _onSuccessfulDetectionSaved,
    );
    if (widget.isActive && widget.isAuthenticated) {
      _loadUserData();
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isAuthenticated && oldWidget.isAuthenticated) {
      setState(() {
        _currentUser = null;
        _totalDetections = 0;
        _discoveredSpeciesCount = 0;
        _totalSpeciesCount = 0;
        _hasCollectionStats = false;
        _avatarUrl = null;
        _localAvatarFile = null;
        _loadError = null;
        _hasLoaded = false;
        _isLoading = false;
      });
    } else if (widget.isAuthenticated &&
        !oldWidget.isAuthenticated &&
        widget.isActive) {
      _loadUserData();
    } else if (widget.isAuthenticated &&
        widget.isActive &&
        !oldWidget.isActive &&
        !_hasLoaded) {
      _loadUserData();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    ProfileRefreshNotifier.detectionSaved.removeListener(
      _onSuccessfulDetectionSaved,
    );
    super.dispose();
  }

  void _onSuccessfulDetectionSaved() {
    if (widget.isAuthenticated && _currentUser != null) {
      setState(() => _totalDetections++);
      _loadCollectionStats(_currentUser!.id);
    }
  }

  Future<void> _loadCollectionStats(String userId) async {
    try {
      final results = await Future.wait([
        _speciesService.getAllSpecies(),
        _speciesService.getDiscoveredSpecies(userId),
      ]);
      if (!mounted || _authService.currentUser?.id != userId) return;

      setState(() {
        _totalSpeciesCount = results[0].length;
        _discoveredSpeciesCount = results[1].length;
        _hasCollectionStats = true;
      });
    } catch (error) {
      debugPrint('Error cargando el progreso de colección: $error');
      if (mounted) setState(() => _hasCollectionStats = false);
    }
  }

  Future<void> _loadUserData() async {
    if (_isFetching || !widget.isAuthenticated) return;
    _isFetching = true;
    if (!_hasLoaded && mounted) setState(() => _isLoading = true);
    if (mounted) setState(() => _loadError = null);

    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _currentUser = null;
            _hasLoaded = true;
            _isLoading = false;
          });
        }
        return;
      }

      final results = await Future.wait<Object?>([
        _detectionService.getTotalDetectionsCount(user.id),
        _profileService.getProfilePictureUrl(user.id),
      ]);
      if (!mounted || _authService.currentUser?.id != user.id) return;
      await _loadCollectionStats(user.id);
      if (!mounted || _authService.currentUser?.id != user.id) return;

      final metadataAvatar = user.userMetadata?['avatar_url'];
      setState(() {
        _currentUser = user;
        _totalDetections = results[0] as int;
        _avatarUrl = results[1] as String? ?? metadataAvatar as String?;
        _hasLoaded = true;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error cargando el perfil: $error');
      if (mounted) {
        setState(() {
          _loadError = error.toString();
          _hasLoaded = true;
          _isLoading = false;
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ProfileSettingsScreen()),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openCollection() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GalleryScreen(isAuthenticated: widget.isAuthenticated),
      ),
    );
  }

  Future<void> _openLogin() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const LoginScreen()));

    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openRegister() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const RegisterScreen()),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      final user = _authService.currentUser;
      if (user == null) return;

      final imageFile = File(image.path);
      setState(() {
        _isUploadingImage = true;
        _localAvatarFile = imageFile;
      });
      final imageUrl = await _profileService.uploadProfilePicture(
        user.id,
        imageFile,
      );

      if (mounted) {
        setState(() {
          _avatarUrl = imageUrl;
          _localAvatarFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Foto de perfil actualizada'),
            backgroundColor: context.palette.success,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _localAvatarFile = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar foto: $error'),
            backgroundColor: context.palette.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: context.palette.primarySoft,
        actions: [
          IconButton(
            tooltip: 'Configuración',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: widget.isAuthenticated
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.palette.primarySoft.withValues(alpha: 0.45),
                    context.palette.background,
                    context.palette.background,
                  ],
                  stops: const [0, 0.32, 1],
                ),
              ),
              child: _buildAuthenticatedProfile(context),
            )
          : _buildGuestProfile(context),
    );
  }

  Widget _buildAuthenticatedProfile(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadUserData,
      color: context.palette.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (_isLoading)
            const _ProfileSkeleton()
          else if (_loadError != null && _currentUser == null)
            EmptyStateWidget(
              icon: Icons.cloud_off_outlined,
              title: 'No se pudo cargar el perfil',
              message: _loadError,
              buttonText: 'Reintentar',
              onButtonPressed: _loadUserData,
            )
          else
            _buildProfileContent(context),
        ],
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context) {
    final palette = context.palette;
    final rawUsername = _currentUser?.userMetadata?['username'];
    final username = rawUsername is String && rawUsername.trim().isNotEmpty
        ? rawUsername.trim()
        : 'Explorador';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.primarySoft.withValues(alpha: 0.95),
                palette.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileAvatar(
                imageUrl: _avatarUrl,
                localImageFile: _localAvatarFile,
                onTap: _pickAndUploadImage,
                isUploading: _isUploadingImage,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Explorador de fauna chilena',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _ProfileSectionTitle(
          icon: Icons.bar_chart_rounded,
          title: 'Tus estadísticas',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: AppTheme.cardDecoration(context),
          child: Row(
            children: [
              Expanded(
                child: _ProfileStat(
                  icon: Icons.pets_rounded,
                  value: _hasCollectionStats ? '$_discoveredSpeciesCount' : '—',
                  label: 'Especies descubiertas',
                ),
              ),
              Container(width: 1, height: 76, color: palette.border),
              Expanded(
                child: _ProfileStat(
                  icon: Icons.camera_alt_rounded,
                  value: '$_totalDetections',
                  label: 'Avistamientos registrados',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _ProfileSectionTitle(icon: Icons.star_rounded, title: 'Tu colección'),
        const SizedBox(height: 12),
        Material(
          color: palette.surface,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: _openCollection,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: palette.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: palette.primary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasCollectionStats
                              ? 'Completa tu colección'
                              : 'Tu colección',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _hasCollectionStats
                              ? 'Descubriste $_discoveredSpeciesCount de $_totalSpeciesCount especies'
                              : 'No se pudo cargar el progreso. Toca para reintentar.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (_hasCollectionStats) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _totalSpeciesCount == 0
                                  ? 0
                                  : (_discoveredSpeciesCount /
                                            _totalSpeciesCount)
                                        .clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: palette.surfaceMuted,
                              color: palette.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.primary,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestProfile(BuildContext context) {
    final palette = context.palette;
    return ListView(
      padding: AppTheme.defaultPadding,
      children: [
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
          decoration: AppTheme.cardDecoration(context),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 42,
                  color: palette.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Explora a tu manera',
                textAlign: TextAlign.center,
                style: AppTheme.titleStyle(context),
              ),
              const SizedBox(height: 8),
              Text(
                'Puedes identificar animales sin una cuenta. Inicia sesión o crea una cuenta para guardar tus hallazgos y acceder a la galería.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyStyle(context),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openLogin,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Iniciar sesión'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openRegister,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Crear cuenta'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ProfileSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(icon, color: palette.primary, size: 25),
        const SizedBox(width: 9),
        Text(
          title,
          style: AppTheme.headingStyle(context)
              .copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ProfileStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Icon(icon, color: palette.primary, size: 29),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 18),
        const SkeletonBlock(width: 120, height: 120, radius: 60),
        const SizedBox(height: 18),
        const SkeletonBlock(width: 150, height: 24),
        const SizedBox(height: 8),
        const SkeletonBlock(width: 200, height: 16),
        const SizedBox(height: 34),
        const SkeletonBlock(width: 140, height: 24),
        const SizedBox(height: 14),
        const SkeletonBlock(width: double.infinity, height: 92, radius: 20),
      ],
    );
  }
}
