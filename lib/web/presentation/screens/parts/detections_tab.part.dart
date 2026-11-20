part of '../admin_dashboard_screen.dart';

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}

class _DetectionsTab extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> detectionsFuture;
  final ValueChanged<Map<String, dynamic>> onViewDetail;
  final ValueChanged<int> onDelete;
  final VoidCallback onRetry;

  const _DetectionsTab({
    required this.detectionsFuture,
    required this.onViewDetail,
    required this.onDelete,
    required this.onRetry,
  });

  @override
  State<_DetectionsTab> createState() => _DetectionsTabState();
}

class _DetectionsTabState extends State<_DetectionsTab> {
  String _searchQuery = '';

  void _exportToCSV(List<Map<String, dynamic>> detections) {
    CsvExporter.exportDetections(detections);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.detectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return _ErrorState(
            message: 'No se pudieron cargar las detecciones.',
            onRetry: widget.onRetry,
          );
        }
        final allDetections = snapshot.data ?? [];
        if (allDetections.isEmpty) {
          return const _EmptyState(
            icon: Icons.travel_explore_outlined,
            message: 'No hay detecciones registradas todavía.',
          );
        }

        final filtered = allDetections.where((d) {
          final species = d['species'] as Map<String, dynamic>?;
          final profile = d['profiles'] as Map<String, dynamic>?;
          final commonName = (species?['name_common']?.toString() ?? '')
              .toLowerCase();
          final scientificName = (species?['name_scientific']?.toString() ?? '')
              .toLowerCase();
          final username = (profile?['username']?.toString() ?? '')
              .toLowerCase();

          final matchesQuery =
              _searchQuery.isEmpty ||
              commonName.contains(_searchQuery) ||
              scientificName.contains(_searchQuery) ||
              username.contains(_searchQuery);

          return matchesQuery;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _FilterBar(
                    searchHint:
                        'Buscar por especie, nombre científico o usuario...',
                    onSearchChanged: (q) =>
                        setState(() => _searchQuery = q.toLowerCase().trim()),
                    totalCount: filtered.length,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: filtered.isEmpty
                      ? null
                      : () => _exportToCSV(filtered),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 22,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 19),
                  label: const Text(
                    'Exportar CSV',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyState(
                      icon: Icons.search_off_outlined,
                      message:
                          'No se encontraron avistamientos con esos filtros.',
                    )
                  : Container(
                      width: double.infinity,
                      decoration: AppTheme.cardDecoration(),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppTheme.cardRadius,
                        ),
                        child: Column(
                          children: [
                            // CABECERA DE LA TABLA MODERNA
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceElevated,
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.divider,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 64,
                                    child: _TableHeaderLabel('FOTO'),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: _TableHeaderLabel(
                                      'ESPECIE IDENTIFICADA',
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableHeaderLabel('RAREZA'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableHeaderLabel('EXPLORADOR'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableHeaderLabel('CONFIANZA IA'),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: _TableHeaderLabel('COORDENADAS GPS'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _TableHeaderLabel('FECHA Y HORA'),
                                  ),
                                  SizedBox(
                                    width: 96,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: _TableHeaderLabel('ACCIONES'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // CUERPO DE LA TABLA CON SCROLL Y HOVER
                            Expanded(
                              child: ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => Divider(
                                  color: AppColors.divider.withValues(
                                    alpha: 0.45,
                                  ),
                                  height: 1,
                                ),
                                itemBuilder: (context, index) {
                                  final detection = filtered[index];
                                  return _ModernDetectionRow(
                                    detection: detection,
                                    onViewDetail: () =>
                                        widget.onViewDetail(detection),
                                    onDelete: () {
                                      final id = detection['id'] as int?;
                                      if (id != null) widget.onDelete(id);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TableHeaderLabel extends StatelessWidget {
  final String text;
  const _TableHeaderLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ModernDetectionRow extends StatefulWidget {
  final Map<String, dynamic> detection;
  final VoidCallback onViewDetail;
  final VoidCallback onDelete;

  const _ModernDetectionRow({
    required this.detection,
    required this.onViewDetail,
    required this.onDelete,
  });

  @override
  State<_ModernDetectionRow> createState() => _ModernDetectionRowState();
}

class _ModernDetectionRowState extends State<_ModernDetectionRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final detection = widget.detection;
    final species = detection['species'] as Map<String, dynamic>?;
    final profile = detection['profiles'] as Map<String, dynamic>?;

    final id = detection['id'];
    final commonName = species?['name_common']?.toString() ?? 'Sin clasificar';
    final scientificName = species?['name_scientific']?.toString() ?? '';
    final username = profile?['username']?.toString() ?? 'Anónimo';
    final avatarUrl = profile?['avatar_url']?.toString();
    final confidence = _normalizeConfidence(detection['confidence']);
    final createdAt = _formatDate(detection['created_at']?.toString());

    final lat = detection['location_lat'] as num?;
    final lng = detection['location_lng'] as num?;
    final hasGps = lat != null && lng != null;
    final coords = hasGps
        ? '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}'
        : 'No disponible';

    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onViewDetail,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: _isHovered
              ? AppColors.surfaceElevated.withValues(alpha: 0.65)
              : Colors.transparent,
          child: Row(
            children: [
              // 1. Miniatura con borde sutil
              SizedBox(
                width: 64,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isHovered
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.divider,
                      ),
                    ),
                    child: _DetectionThumbnail(
                      imagePath: detection['image_path']?.toString(),
                      size: 46,
                    ),
                  ),
                ),
              ),

              // 2. Especie + Nombre científico + ID
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              commonName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (id != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '#$id',
                              style: TextStyle(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scientificName.isNotEmpty
                            ? scientificName
                            : 'Especie registrada',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Hábitat
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    species?['habitat']?.toString() ??
                        'Hábitat no especificado',
                    style: AppTheme.bodyStyle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // 4. Usuario con Avatar
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.18,
                      ),
                      backgroundImage:
                          (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(
                              initial,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Confianza IA
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ConfidenceChip(percent: confidence),
                ),
              ),

              // 6. Ubicación GPS en contenedor tipo píldora
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.divider.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasGps
                              ? Icons.my_location_rounded
                              : Icons.location_off_outlined,
                          size: 13,
                          color: hasGps
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            coords,
                            style: TextStyle(
                              color: hasGps
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontFamily: hasGps ? 'monospace' : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 7. Fecha y Hora
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        createdAt,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 8. Botones de Acción estilizados
              SizedBox(
                width: 96,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ActionIconButton(
                      icon: Icons.visibility_outlined,
                      tooltip: 'Moderar / Ver detalle',
                      color: AppColors.primary,
                      onTap: widget.onViewDetail,
                    ),
                    const SizedBox(width: 8),
                    _ActionIconButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Eliminar registro',
                      color: AppColors.error,
                      onTap: widget.onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
