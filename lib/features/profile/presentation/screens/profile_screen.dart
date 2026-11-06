import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/shared/widgets/common_widgets.dart';
import '/features/auth/data/services/auth_service.dart';
import '/features/camera/data/services/detection_service.dart';
import '/features/profile/data/services/profile_refresh_notifier.dart';
import '/features/profile/data/services/profile_service.dart';
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
  final AuthService _authService = AuthService();
  final DetectionService _detectionService = DetectionService();
  final ProfileService _profileService = ProfileService();
  final ImagePicker _imagePicker = ImagePicker();

  User? _currentUser;
  int _totalDetections = 0;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isFetching = false;
  bool _hasLoaded = false;
  String? _avatarUrl;
  File? _localAvatarFile;
  String? _loadError;

  @override
  void initState() {
    super.initState();
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
    ProfileRefreshNotifier.detectionSaved.removeListener(
      _onSuccessfulDetectionSaved,
    );
    super.dispose();
  }

  void _onSuccessfulDetectionSaved() {
    if (widget.isAuthenticated && _currentUser != null) {
      setState(() => _totalDetections++);
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

      final metadataAvatar = user.userMetadata?['avatar_url'];
      setState(() {
        _currentUser = user;
        _totalDetections = results[0] as int;
        _avatarUrl =
            results[1] as String? ??
            (metadataAvatar is String ? metadataAvatar : null);
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileSettingsScreen()),
    );
  }

  void _openLogin() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
  }

  void _openRegister() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
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
        actions: [
          IconButton(
            tooltip: 'Configuración',
            onPressed: _openSettings,
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: widget.isAuthenticated
          ? _buildAuthenticatedProfile(context)
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
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.primarySoft, palette.surface],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              ProfileAvatar(
                imageUrl: _avatarUrl,
                localImageFile: _localAvatarFile,
                onTap: _pickAndUploadImage,
                isUploading: _isUploadingImage,
              ),
              const SizedBox(height: 18),
              Text(
                username,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Text('Tu actividad', style: AppTheme.headingStyle(context)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(context),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(Icons.camera_alt_rounded, color: palette.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Identificaciones guardadas',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalDetections',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
