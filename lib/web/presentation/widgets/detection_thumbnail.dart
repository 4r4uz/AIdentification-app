import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/colors.dart';

/// Miniatura de imagen con resolución de URL desde Supabase Storage.
///
/// Por defecto usa el bucket `detections`, pero se puede configurar con
/// `bucketName` para otros buckets (ej. `species`).
class DetectionThumbnail extends StatelessWidget {
  final String? imagePath;
  final double size;
  final bool fullWidth;
  final String bucketName;

  const DetectionThumbnail({
    super.key,
    required this.imagePath,
    required this.size,
    this.fullWidth = false,
    this.bucketName = 'detections',
  });

  String? _resolveImageUrl(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty) return null;
    final clean = rawPath.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    try {
      return Supabase.instance.client.storage
          .from(bucketName)
          .getPublicUrl(clean);
    } catch (_) {
      return clean;
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolveImageUrl(imagePath);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: fullWidth ? double.infinity : size,
        height: size,
        color: AppColors.surfaceElevated,
        child: resolvedUrl != null
            ? Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.pets_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              )
            : const Icon(
                Icons.pets_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
      ),
    );
  }
}
