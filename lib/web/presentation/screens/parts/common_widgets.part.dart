part of '../admin_dashboard_screen.dart';

class _FilterBar extends StatelessWidget {
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final int totalCount;

  const _FilterBar({
    required this.searchHint,
    required this.onSearchChanged,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.cardDecoration(),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 340,
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
              ),
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$totalCount resultados',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetectionThumbnail extends StatelessWidget {
  final String? imagePath;
  final double size;
  final bool fullWidth;
  final String bucketName;

  const _DetectionThumbnail({
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

class _ConfidenceChip extends StatelessWidget {
  final double percent;

  const _ConfidenceChip({required this.percent});

  Color get _color {
    if (percent >= 80) return AppColors.confidenceHigh;
    if (percent >= 60) return AppColors.confidenceMedium;
    return AppColors.confidenceLow;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AdminTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _AdminTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 42,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTheme.bodyStyle(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// HELPERS
// ===========================================================================

double _normalizeConfidence(dynamic rawConfidence) {
  final raw = (rawConfidence as num?)?.toDouble() ?? 0.0;
  return raw <= 1.0 ? raw * 100 : raw;
}

String _formatDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return 'Sin fecha';
  try {
    final date = DateTime.parse(isoDate).toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  } catch (_) {
    return isoDate;
  }
}

// ===========================================================================
// TAB 4: GAMIFICACIÓN (TRIVIAS Y LOGROS)
// ===========================================================================
