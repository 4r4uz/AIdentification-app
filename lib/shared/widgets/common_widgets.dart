import 'dart:io';

import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '/core/theme/colors.dart';
import '/core/constants/app_texts.dart';

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final Color? color;

  const LoadingIndicator({super.key, this.message, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: color ?? context.palette.primary),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: AppTheme.bodyStyle(context),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const LogoutButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout_rounded),
        label: Text(isLoading ? 'Cerrando sesión...' : 'Cerrar sesión'),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.palette.error,
          side: BorderSide(color: context.palette.error.withValues(alpha: .35)),
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.palette.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: context.palette.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: AppTheme.bodyStyle(context),
                textAlign: TextAlign.center,
              ),
            ],
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onButtonPressed,
                child: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: context.palette.primary),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final File? localImageFile;
  final VoidCallback? onTap;
  final bool isUploading;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.localImageFile,
    this.onTap,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final imageCacheSize = (112 * MediaQuery.devicePixelRatioOf(context))
        .round();
    return Semantics(
      button: true,
      enabled: !isUploading && onTap != null,
      label: 'Cambiar foto de perfil',
      child: GestureDetector(
        onTap: isUploading ? null : onTap,
        child: Stack(
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: palette.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(color: palette.surface, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: .14),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: localImageFile != null
                    ? Image.file(
                        localImageFile!,
                        fit: BoxFit.cover,
                        cacheWidth: imageCacheSize,
                        cacheHeight: imageCacheSize,
                      )
                    : imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        key: ValueKey(imageUrl),
                        fit: BoxFit.cover,
                        cacheWidth: imageCacheSize,
                        cacheHeight: imageCacheSize,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person_rounded,
                          size: 54,
                          color: palette.primary,
                        ),
                      )
                    : Icon(
                        Icons.person_rounded,
                        size: 54,
                        color: palette.primary,
                      ),
              ),
            ),
            if (isUploading)
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: palette.cameraSurface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: palette.cameraForeground,
                    strokeWidth: 2,
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.background, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;

  const CustomAppBar({
    super.key,
    required this.title,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title), centerTitle: centerTitle);
  }
}

class ChangePhotoButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const ChangePhotoButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.photo_camera_outlined),
        label: Text(
          isLoading ? AppTexts.uploadingPhoto : AppTexts.changePhotoButton,
        ),
      ),
    );
  }
}
