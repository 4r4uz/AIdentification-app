part of '../admin_dashboard_screen.dart';

class _DashboardTab extends StatelessWidget {
  final Future<DashboardStats> statsFuture;
  final Future<List<Map<String, dynamic>>> allDetectionsFuture;
  final Future<List<Map<String, dynamic>>> recentDetectionsFuture;
  final ValueChanged<Map<String, dynamic>> onViewDetail;
  final VoidCallback onViewAllTap;
  final VoidCallback onRetry;

  const _DashboardTab({
    required this.statsFuture,
    required this.allDetectionsFuture,
    required this.recentDetectionsFuture,
    required this.onViewDetail,
    required this.onViewAllTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<DashboardStats>(
            future: statsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _KpiRowSkeleton();
              }
              if (snapshot.hasError) {
                return _ErrorState(
                  message: 'No se pudieron cargar las estadísticas.',
                  onRetry: onRetry,
                );
              }
              final stats = snapshot.data ?? DashboardStats.empty();
              return _KpiRow(stats: stats);
            },
          ),
          const SizedBox(height: 28),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: allDetectionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              return AnalyticsChartsSection(detections: snapshot.data ?? []);
            },
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Últimos avistamientos', style: AppTheme.headingStyle()),
              TextButton.icon(
                onPressed: onViewAllTap,
                icon: const Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Ver todos',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: recentDetectionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              if (snapshot.hasError) {
                return _ErrorState(
                  message: 'No se pudieron cargar los avistamientos recientes.',
                  onRetry: onRetry,
                );
              }
              final detections = snapshot.data ?? [];
              if (detections.isEmpty) {
                return const _EmptyState(
                  icon: Icons.travel_explore_outlined,
                  message:
                      'Aún no hay avistamientos registrados en la plataforma.',
                );
              }
              return Column(
                children: detections
                    .map(
                      (d) => _RecentDetectionTile(
                        detection: d,
                        onTap: () => onViewDetail(d),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final DashboardStats stats;

  const _KpiRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final confidencePercent = stats.averageConfidence <= 1.0
        ? stats.averageConfidence * 100
        : stats.averageConfidence;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
        final cards = [
          _KpiCard(
            icon: Icons.travel_explore_outlined,
            label: 'Total Detecciones',
            value: stats.totalDetections.toString(),
            color: AppColors.primary,
          ),
          _KpiCard(
            icon: Icons.pets_outlined,
            label: 'Especies en Catálogo',
            value: stats.totalSpecies.toString(),
            color: AppColors.confidenceHigh,
          ),
          _KpiCard(
            icon: Icons.people_alt_outlined,
            label: 'Usuarios Registrados',
            value: stats.totalUsers.toString(),
            color: AppColors.warning,
          ),
          _KpiCard(
            icon: Icons.auto_awesome_outlined,
            label: 'Confianza Promedio IA',
            value: '${confidencePercent.toStringAsFixed(1)}%',
            color: AppColors.confidenceMedium,
          ),
        ];

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.1,
          children: cards,
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTheme.bodyStyle(),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiRowSkeleton extends StatelessWidget {
  const _KpiRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.1,
          children: List.generate(
            4,
            (_) => Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecentDetectionTile extends StatelessWidget {
  final Map<String, dynamic> detection;
  final VoidCallback onTap;

  const _RecentDetectionTile({required this.detection, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final species = detection['species'] as Map<String, dynamic>?;
    final profile = detection['profiles'] as Map<String, dynamic>?;
    final commonName =
        species?['name_common']?.toString() ?? 'Especie desconocida';
    final username = profile?['username']?.toString() ?? 'Usuario anónimo';
    final confidence = _normalizeConfidence(detection['confidence']);
    final createdAt = _formatDate(detection['created_at']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _DetectionThumbnail(
                imagePath: detection['image_path']?.toString(),
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            commonName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reportado por $username · $createdAt',
                      style: AppTheme.bodyStyle(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ConfidenceChip(percent: confidence),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
