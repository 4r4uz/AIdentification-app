part of '../admin_dashboard_screen.dart';

class _SpeciesTab extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> speciesFuture;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final VoidCallback onCreate;
  final VoidCallback onRetry;

  const _SpeciesTab({
    required this.speciesFuture,
    required this.onEdit,
    required this.onDelete,
    required this.onCreate,
    required this.onRetry,
  });

  @override
  State<_SpeciesTab> createState() => _SpeciesTabState();
}

class _SpeciesTabState extends State<_SpeciesTab> {
  String _searchQuery = '';

  Future<void> _showSpeciesDetails(
    BuildContext context,
    Map<String, dynamic> species,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                species['name_common']?.toString() ?? 'Detalle de especie',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((species['image_url']?.toString() ?? '').isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _DetectionThumbnail(
                      imagePath: species['image_url']?.toString(),
                      size: 220,
                      fullWidth: true,
                      bucketName: 'species',
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _SpeciesDetailField(
                      label: 'Nombre científico',
                      value:
                          species['name_scientific']?.toString() ??
                          'Sin nombre científico',
                    ),
                    _SpeciesDetailField(
                      label: 'Hábitat',
                      value:
                          species['habitat']?.toString() ??
                          'Hábitat no especificado',
                    ),
                    _SpeciesDetailField(
                      label: 'ID',
                      value: species['id']?.toString() ?? '-',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Descripción',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  species['description']?.toString().trim().isNotEmpty == true
                      ? species['description'].toString()
                      : 'Sin descripción registrada.',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onDelete(species);
            },
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            label: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onEdit(species);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modificar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.speciesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return _ErrorState(
            message: 'No se pudo cargar el catálogo de especies.',
            onRetry: widget.onRetry,
          );
        }
        final allSpecies = snapshot.data ?? [];
        if (allSpecies.isEmpty) {
          return const _EmptyState(
            icon: Icons.pets_outlined,
            message: 'El catálogo de especies está vacío. Usa el botón "Nueva Especie" para agregar una.',
          );
        }

        final filtered = allSpecies.where((s) {
          final common = (s['name_common']?.toString() ?? '').toLowerCase();
          final scientific = (s['name_scientific']?.toString() ?? '')
              .toLowerCase();
          final habitat = (s['habitat']?.toString() ?? '').toLowerCase();
          final matchesSearch =
              _searchQuery.isEmpty ||
              common.contains(_searchQuery) ||
              scientific.contains(_searchQuery) ||
              habitat.contains(_searchQuery);

          return matchesSearch;
        }).toList();

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _FilterBar(
                    searchHint: 'Buscar especie por nombre común, científico o hábitat...',
                    onSearchChanged: (q) =>
                        setState(() => _searchQuery = q.toLowerCase().trim()),
                    totalCount: filtered.length,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: widget.onCreate,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar especie'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: filtered.isEmpty
                      ? null
                      : () {
                          CsvExporter.exportSpecies(filtered);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Exportadas ${filtered.length} especies a CSV',
                              ),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
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
            const SizedBox(height: 18),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyState(
                      icon: Icons.search_off_outlined,
                      message: 'Ninguna especie coincide con tu búsqueda.',
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _SpeciesCard(
                          species: item,
                          onTap: () => _showSpeciesDetails(context, item),
                          onEdit: () => widget.onEdit(item),
                          onDelete: () => widget.onDelete(item),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  final Map<String, dynamic> species;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SpeciesCard({
    required this.species,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final commonName = species['name_common']?.toString() ?? 'Sin nombre';
    final scientificName = species['name_scientific']?.toString() ?? '';
    final habitat = species['habitat']?.toString() ?? 'Hábitat no especificado';
    final imageUrl = species['image_url']?.toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: AppTheme.cardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetectionThumbnail(
              imagePath: imageUrl,
              size: 46,
              bucketName: 'species',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    commonName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (scientificName.isNotEmpty)
                    Text(
                      scientificName,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    habitat,
                    style: AppTheme.bodyStyle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SpeciesDetailField extends StatelessWidget {
  final String label;
  final String value;

  const _SpeciesDetailField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
