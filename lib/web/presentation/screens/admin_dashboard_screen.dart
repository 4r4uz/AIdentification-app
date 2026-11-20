import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/admin_service.dart';
import '../widgets/analytics_charts.dart';
import 'admin_login_screen.dart';
import '../../data/exporters/csv_exporter.dart';

enum _AdminTab { dashboard, detections, species, gamification, users }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();

  _AdminTab _selectedTab = _AdminTab.dashboard;

  late Future<DashboardStats> _statsFuture;
  late Future<List<Map<String, dynamic>>> _recentDetectionsFuture;
  late Future<List<Map<String, dynamic>>> _allDetectionsFuture;
  late Future<List<Map<String, dynamic>>> _speciesFuture;
  late Future<List<Map<String, dynamic>>> _usersFuture;

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    setState(() {
      _statsFuture = _adminService.getDashboardStats();
      _recentDetectionsFuture = _adminService.getRecentDetections(limit: 6);
      _allDetectionsFuture = _adminService.getRecentDetections(limit: 100);
      _speciesFuture = _adminService.getSpeciesList();
      _usersFuture = _adminService.getUsersList();
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 10),
            Text(
              'Cerrar sesión',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          '¿Seguro que deseas salir del panel de administración?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    

    if (confirm != true) return;

    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    _loadAll();
    try {
      await _statsFuture;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Acciones de Detecciones
  // ---------------------------------------------------------------------------

  Future<void> _handleDeleteDetection(int detectionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: const Text(
          'Eliminar detección',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este registro? Esta acción no se puede deshacer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _adminService.deleteDetection(detectionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Detección eliminada correctamente'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showDetectionDetailsDialog(Map<String, dynamic> detection) async {
    final detectionId = detection['id'] as int?;
    final species = detection['species'] as Map<String, dynamic>?;
    final profile = detection['profiles'] as Map<String, dynamic>?;
    final commonName = species?['name_common']?.toString() ?? 'Especie desconocida';
    final scientificName = species?['name_scientific']?.toString() ?? 'Sin nombre científico';
    final rarity = species?['rarity']?.toString() ?? 'comun';
    final username = profile?['username']?.toString() ?? 'Usuario anónimo';
    final confidence = _normalizeConfidence(detection['confidence']);
    final createdAt = _formatDate(detection['created_at']?.toString());
    final lat = detection['location_lat'];
    final lng = detection['location_lng'];
    final coords = (lat != null && lng != null)
        ? '${(lat as num).toStringAsFixed(5)}, ${(lng as num).toStringAsFixed(5)}'
        : 'Sin coordenadas GPS';

    List<Map<String, dynamic>> speciesCatalog = [];
    try {
      speciesCatalog = await _speciesFuture;
    } catch (_) {}

    int? selectedSpeciesId = (detection['species_id'] as int?) ?? (species?['id'] as int?);
    bool isSaving = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Moderación de Avistamiento #${detectionId ?? ''}',
                            style: AppTheme.headingStyle(),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.divider, height: 24),
                    Center(
                      child: _DetectionThumbnail(
                        imagePath: detection['image_path']?.toString(),
                        size: 200,
                        fullWidth: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                commonName,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                scientificName,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _RarityBadge(rarity: rarity),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailInfoRow(icon: Icons.person_outline, label: 'Reportado por', value: username),
                    const SizedBox(height: 8),
                    _DetailInfoRow(
                      icon: Icons.auto_awesome_outlined,
                      label: 'Confianza IA',
                      value: '${confidence.toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 8),
                    _DetailInfoRow(icon: Icons.location_on_outlined, label: 'Coordenadas', value: coords),
                    const SizedBox(height: 8),
                    _DetailInfoRow(icon: Icons.calendar_today_outlined, label: 'Fecha y hora', value: createdAt),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified_user_outlined, size: 16, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text(
                                'Acción de Moderación (Corregir Especie)',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            initialValue: speciesCatalog.any((s) => s['id'] == selectedSpeciesId)
                                ? selectedSpeciesId
                                : null,
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Especie asignada',
                              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.divider),
                              ),
                            ),
                            items: speciesCatalog.map((s) {
                              final id = s['id'] as int;
                              final name = s['name_common']?.toString() ?? 'Sin nombre';
                              final sci = s['name_scientific']?.toString() ?? '';
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(sci.isNotEmpty ? '$name ($sci)' : name),
                              );
                            }).toList(),
                            onChanged: (val) => setModalState(() => selectedSpeciesId = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (detectionId != null)
                          TextButton.icon(
                            onPressed: isSaving
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _handleDeleteDetection(detectionId);
                                  },
                            style: TextButton.styleFrom(foregroundColor: AppColors.error),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Descartar registro'),
                          )
                        else
                          const SizedBox.shrink(),
                        Row(
                          children: [
                            TextButton(
                              onPressed: isSaving ? null : () => Navigator.pop(context),
                              child: const Text('Cerrar', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: (isSaving || detectionId == null || selectedSpeciesId == null)
                                  ? null
                                  : () async {
                                      setModalState(() => isSaving = true);
                                      try {
                                        await _adminService.updateDetectionSpecies(
                                          detectionId,
                                          selectedSpeciesId!,
                                        );
                                        if (!mounted) return;
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Avistamiento moderado y especie actualizada'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                        _loadAll();
                                      } catch (e) {
                                        setModalState(() => isSaving = false);
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error al actualizar: $e'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                              ),
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : const Icon(Icons.check, size: 16),
                              label: const Text(
                                'Validar / Guardar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Acciones de Especies (Crear / Editar / Eliminar)
  // ---------------------------------------------------------------------------

  Future<void> _showSpeciesFormDialog({Map<String, dynamic>? existingSpecies}) async {
    final isEditing = existingSpecies != null;
    final commonCtrl = TextEditingController(text: existingSpecies?['name_common']?.toString() ?? '');
    final scientificCtrl = TextEditingController(text: existingSpecies?['name_scientific']?.toString() ?? '');
    final habitatCtrl = TextEditingController(text: existingSpecies?['habitat']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existingSpecies?['description']?.toString() ?? '');
    final imageCtrl = TextEditingController(text: existingSpecies?['image_url']?.toString() ?? '');

    final validRarities = ['comun', 'raro', 'epico', 'legendario'];
    String selectedRarity = existingSpecies?['rarity']?.toString().toLowerCase() ?? 'comun';
    if (!validRarities.contains(selectedRarity)) selectedRarity = 'comun';

    final rceCategories = [
      {'key': 'Preocupación Menor (LC)', 'label': 'Preocupación Menor (LC)'},
      {'key': 'Casi Amenazada (NT)', 'label': 'Casi Amenazada (NT)'},
      {'key': 'Vulnerable (VU)', 'label': 'Vulnerable (VU)'},
      {'key': 'En Peligro (EN)', 'label': 'En Peligro (EN)'},
      {'key': 'En Peligro Crítico (CR)', 'label': 'En Peligro Crítico (CR)'},
    ];
    
    String selectedRce = rceCategories[0]['key']!;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          title: Text(
            isEditing ? 'Editar Ficha Taxonómica (RCE)' : 'Nueva Especie (RCE)',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AdminTextField(controller: commonCtrl, label: 'Nombre común *', hint: 'Ej: Huemul'),
                  const SizedBox(height: 12),
                  _AdminTextField(controller: scientificCtrl, label: 'Nombre científico', hint: 'Ej: Hippocamelus bisulcus'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedRarity,
                          dropdownColor: AppColors.surfaceElevated,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Rareza del Juego',
                            labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            filled: true,
                            fillColor: AppColors.surfaceElevated,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.divider),
                            ),
                          ),
                          items: validRarities
                              .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedRarity = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRce,
                    dropdownColor: AppColors.surfaceElevated,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Estado de Conservación RCE (MMA)',
                      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                    ),
                    items: rceCategories
                        .map((cat) => DropdownMenuItem(value: cat['key'], child: Text(cat['label']!)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedRce = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  _AdminTextField(controller: habitatCtrl, label: 'Hábitat', hint: 'Ej: Bosques andino-patagónicos'),
                  const SizedBox(height: 12),
                  _AdminTextField(controller: imageCtrl, label: 'URL de imagen de referencia', hint: 'https://...'),
                  const SizedBox(height: 12),
                  _AdminTextField(
                    controller: descCtrl,
                    label: 'Descripción / Antecedentes RCE',
                    hint: 'Detalles ecológicos y normativos...',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (commonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre común es obligatorio'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                final baseDesc = descCtrl.text.trim();
                final finalDesc = '[RCE: $selectedRce] $baseDesc';

                final payload = <String, dynamic>{
                  'name_common': commonCtrl.text.trim(),
                  'name_scientific': scientificCtrl.text.trim().isEmpty ? null : scientificCtrl.text.trim(),
                  'rarity': selectedRarity,
                  'habitat': habitatCtrl.text.trim().isEmpty ? null : habitatCtrl.text.trim(),
                  'description': finalDesc,
                  'image_url': imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim(),
                };

                try {
                  if (isEditing) {
                    await _adminService.updateSpecies(existingSpecies['id'] as int, payload);
                  } else {
                    await _adminService.createSpecies(payload);
                  }
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al guardar: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
              child: Text(isEditing ? 'Guardar cambios' : 'Registrar especie'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catálogo de especies actualizado con éxito'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadAll();
    }
  }

  Future<void> _handleDeleteSpecies(Map<String, dynamic> species) async {
    final id = species['id'] as int?;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: const Text(
          'Eliminar especie',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Deseas eliminar "${species['name_common']}" del catálogo?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _adminService.deleteSpecies(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Especie eliminada correctamente'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar (puede tener detecciones asociadas): $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _titleForTab(_AdminTab tab) {
    switch (tab) {
      case _AdminTab.dashboard:
        return 'Dashboard / KPIs';
      case _AdminTab.detections:
        return 'Avistamientos / Detecciones';
      case _AdminTab.species:
        return 'Catálogo de Especies';
      case _AdminTab.gamification:
        return 'Gamificación y Logros (Educación)';
      case _AdminTab.users:
        return 'Gestión de Usuarios';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _Sidebar(
            onLogout: _handleLogout,
            selectedTab: _selectedTab,
            onSelectTab: (tab) => setState(() => _selectedTab = tab),
            onRefresh: _isRefreshing ? null : _handleRefresh,
            isRefreshing: _isRefreshing,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(
                  title: _titleForTab(_selectedTab),
                  onRefresh: _isRefreshing ? null : _handleRefresh,
                  isRefreshing: _isRefreshing,
                  actionButton: _selectedTab == _AdminTab.species
                      ? ElevatedButton.icon(
                          onPressed: () => _showSpeciesFormDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                            'Nueva Especie',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: _buildTabContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case _AdminTab.dashboard:
        return _DashboardTab(
          statsFuture: _statsFuture,
          allDetectionsFuture: _allDetectionsFuture,
          recentDetectionsFuture: _recentDetectionsFuture,
          onViewDetail: _showDetectionDetailsDialog,
          onViewAllTap: () => setState(() => _selectedTab = _AdminTab.detections),
          onRetry: _loadAll,
        );
      case _AdminTab.detections:
        return _DetectionsTab(
          detectionsFuture: _allDetectionsFuture,
          onViewDetail: _showDetectionDetailsDialog,
          onDelete: _handleDeleteDetection,
          onRetry: _loadAll,
        );
      case _AdminTab.species:
        return _SpeciesTab(
          speciesFuture: _speciesFuture,
          onEdit: (s) => _showSpeciesFormDialog(existingSpecies: s),
          onDelete: _handleDeleteSpecies,
          onRetry: _loadAll,
        );
      case _AdminTab.gamification:
        return _GamificationTab(
          triviasFuture: _adminService.getTriviasList(),
          achievementsFuture: _adminService.getAchievementsList(),
          onRetry: _loadAll,
        );
      case _AdminTab.users:
        return _UsersTab(
          usersFuture: _usersFuture,
          adminService: _adminService,
          onRefresh: _loadAll,
          onRetry: _loadAll,
        );
    }
  }
}

// ===========================================================================
// SIDEBAR & TOPBAR
// ===========================================================================

class _Sidebar extends StatelessWidget {
  final _AdminTab selectedTab;
  final ValueChanged<_AdminTab> onSelectTab;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.selectedTab,
    required this.onSelectTab,
    required this.onRefresh,
    required this.isRefreshing,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLogo(),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
            _SidebarNavItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard / KPIs',
              isSelected: selectedTab == _AdminTab.dashboard,
              onTap: () => onSelectTab(_AdminTab.dashboard),
            ),
            _SidebarNavItem(
              icon: Icons.travel_explore_outlined,
              label: 'Avistamientos',
              isSelected: selectedTab == _AdminTab.detections,
              onTap: () => onSelectTab(_AdminTab.detections),
            ),
            _SidebarNavItem(
              icon: Icons.pets_outlined,
              label: 'Catálogo de Especies',
              isSelected: selectedTab == _AdminTab.species,
              onTap: () => onSelectTab(_AdminTab.species),
            ),
            _SidebarNavItem(
              icon: Icons.military_tech_outlined,
              label: 'Gamificación & Logros',
              isSelected: selectedTab == _AdminTab.gamification,
              onTap: () => onSelectTab(_AdminTab.gamification),
            ),
            _SidebarNavItem(
              icon: Icons.people_outline,
              label: 'Gestión de Usuarios',
              isSelected: selectedTab == _AdminTab.users,
              onTap: () => onSelectTab(_AdminTab.users),
            ),
            const Spacer(),
            const Divider(color: AppColors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: onRefresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                  ),
                ),
                icon: isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(isRefreshing ? 'Actualizando...' : 'Recargar datos'),
                

              ),
            ),
            Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(
                  color: AppColors.error.withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                ),
              ),
            ),
          ),
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.eco_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'AnimalPedia\nAdmin Panel',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final Widget? actionButton;

  const _TopBar({
    required this.title,
    this.onRefresh,
    this.isRefreshing = false,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Supabase Online (PostGIS)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (actionButton != null) ...[
                actionButton!,
                const SizedBox(width: 12),
              ],
              IconButton(
                onPressed: onRefresh,
                icon: isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.refresh, color: AppColors.textSecondary),
                tooltip: 'Recargar datos',
              ),
              const SizedBox(width: 12),
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  'AD',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// TAB 1: DASHBOARD / KPIs
// ===========================================================================

class _DashboardTab extends StatelessWidget {
  final Future<DashboardStats> statsFuture;
  final Future < List < Map < String, dynamic > > > allDetectionsFuture;
  final Future < List < Map < String, dynamic > > > recentDetectionsFuture;
  final ValueChanged < Map < String, dynamic > > onViewDetail;
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
          FutureBuilder < List < Map < String, dynamic > > > (
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
                icon: const Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
                label: const Text(
                  'Ver todos',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
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
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
                  message: 'Aún no hay avistamientos registrados en la plataforma.',
                );
              }
              return Column(
                children: detections
                    .map((d) => _RecentDetectionTile(
                          detection: d,
                          onTap: () => onViewDetail(d),
                        ))
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
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

  const _RecentDetectionTile({
    required this.detection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final species = detection['species'] as Map<String, dynamic>?;
    final profile = detection['profiles'] as Map<String, dynamic>?;
    final commonName = species?['name_common']?.toString() ?? 'Especie desconocida';
    final rarity = species?['rarity']?.toString() ?? '';
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
              _DetectionThumbnail(imagePath: detection['image_path']?.toString(), size: 48),
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
                        if (rarity.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _RarityBadge(rarity: rarity),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Reportado por $username · $createdAt', style: AppTheme.bodyStyle()),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ConfidenceChip(percent: confidence),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// TAB 2: DETECCIONES (TABLA MODERNA FULL-WIDTH, FILTROS Y EXPORTACIÓN CSV)
// ===========================================================================

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
  String _selectedRarity = 'todos';

  void _exportToCSV(List<Map<String, dynamic>> detections) {
    CsvExporter.exportDetections(detections);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.detectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
          final commonName = (species?['name_common']?.toString() ?? '').toLowerCase();
          final scientificName = (species?['name_scientific']?.toString() ?? '').toLowerCase();
          final rarity = (species?['rarity']?.toString() ?? 'comun').toLowerCase();
          final username = (profile?['username']?.toString() ?? '').toLowerCase();

          final matchesQuery = _searchQuery.isEmpty ||
              commonName.contains(_searchQuery) ||
              scientificName.contains(_searchQuery) ||
              username.contains(_searchQuery);

          final matchesRarity = _selectedRarity == 'todos' || rarity == _selectedRarity;
          return matchesQuery && matchesRarity;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _FilterBar(
                    searchHint: 'Buscar por especie, nombre científico o usuario...',
                    onSearchChanged: (q) => setState(() => _searchQuery = q.toLowerCase().trim()),
                    selectedRarity: _selectedRarity,
                    onRarityChanged: (r) => setState(() => _selectedRarity = r),
                    totalCount: filtered.length,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: filtered.isEmpty ? null : () => _exportToCSV(filtered),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.45), width: 1.2),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 19),
                  label: const Text(
                    'Exportar CSV',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyState(
                      icon: Icons.search_off_outlined,
                      message: 'No se encontraron avistamientos con esos filtros.',
                    )
                  : Container(
                      width: double.infinity,
                      decoration: AppTheme.cardDecoration(),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        child: Column(
                          children: [
                            // CABECERA DE LA TABLA MODERNA
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceElevated,
                                border: Border(
                                  bottom: BorderSide(color: AppColors.divider, width: 1),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(width: 64, child: _TableHeaderLabel('FOTO')),
                                  Expanded(flex: 3, child: _TableHeaderLabel('ESPECIE IDENTIFICADA')),
                                  Expanded(flex: 2, child: _TableHeaderLabel('RAREZA')),
                                  Expanded(flex: 2, child: _TableHeaderLabel('EXPLORADOR')),
                                  Expanded(flex: 2, child: _TableHeaderLabel('CONFIANZA IA')),
                                  Expanded(flex: 3, child: _TableHeaderLabel('COORDENADAS GPS')),
                                  Expanded(flex: 2, child: _TableHeaderLabel('FECHA Y HORA')),
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
                                  color: AppColors.divider.withValues(alpha: 0.45),
                                  height: 1,
                                ),
                                itemBuilder: (context, index) {
                                  final detection = filtered[index];
                                  return _ModernDetectionRow(
                                    detection: detection,
                                    onViewDetail: () => widget.onViewDetail(detection),
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
    final rarity = species?['rarity']?.toString() ?? 'comun';
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
                                color: AppColors.textSecondary.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scientificName.isNotEmpty ? scientificName : 'Especie registrada',
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

              // 3. Rareza
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _RarityBadge(rarity: rarity),
                ),
              ),

              // 4. Usuario con Avatar
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasGps ? Icons.my_location_rounded : Icons.location_off_outlined,
                          size: 13,
                          color: hasGps ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            coords,
                            style: TextStyle(
                              color: hasGps ? AppColors.textPrimary : AppColors.textSecondary,
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
                    const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        createdAt,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
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

// ===========================================================================
// TAB 3: CATÁLOGO DE ESPECIES (CON BUSCADOR, FILTROS Y CRUD)
// ===========================================================================

class _SpeciesTab extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> speciesFuture;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final VoidCallback onRetry;

  const _SpeciesTab({
    required this.speciesFuture,
    required this.onEdit,
    required this.onDelete,
    required this.onRetry,
  });

  @override
  State<_SpeciesTab> createState() => _SpeciesTabState();
}

class _SpeciesTabState extends State<_SpeciesTab> {
  String _searchQuery = '';
  String _selectedRarity = 'todos';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.speciesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
          final scientific = (s['name_scientific']?.toString() ?? '').toLowerCase();
          final habitat = (s['habitat']?.toString() ?? '').toLowerCase();
          final rarity = (s['rarity']?.toString() ?? 'comun').toLowerCase();

          final matchesSearch = _searchQuery.isEmpty ||
              common.contains(_searchQuery) ||
              scientific.contains(_searchQuery) ||
              habitat.contains(_searchQuery);

          final matchesRarity = _selectedRarity == 'todos' || rarity == _selectedRarity;
          return matchesSearch && matchesRarity;
        }).toList();

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _FilterBar(
                    searchHint: 'Buscar especie por nombre común, científico o hábitat...',
                    onSearchChanged: (q) => setState(() => _searchQuery = q.toLowerCase().trim()),
                    selectedRarity: _selectedRarity,
                    onRarityChanged: (r) => setState(() => _selectedRarity = r),
                    totalCount: filtered.length,
                  ),
                ),
                const SizedBox(width: 16),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = (constraints.maxWidth / 310).floor().clamp(1, 4);
                        return GridView.builder(
                          itemCount: filtered.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.35,
                          ),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return _SpeciesCard(
                              species: item,
                              onEdit: () => widget.onEdit(item),
                              onDelete: () => widget.onDelete(item),
                            );
                          },
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SpeciesCard({
    required this.species,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final commonName = species['name_common']?.toString() ?? 'Sin nombre';
    final scientificName = species['name_scientific']?.toString() ?? '';
    final habitat = species['habitat']?.toString() ?? 'Hábitat no especificado';
    final rawDesc = species['description']?.toString() ?? '';
    final rarity = species['rarity']?.toString() ?? 'comun';
    final imageUrl = species['image_url']?.toString();

    String rceBadgeText = 'RCE: LC';
    String displayDesc = rawDesc;
    if (rawDesc.startsWith('[RCE:')) {
      final endIndex = rawDesc.indexOf(']');
      if (endIndex != -1) {
        rceBadgeText = rawDesc.substring(1, endIndex);
        displayDesc = rawDesc.substring(endIndex + 1).trim();
      }
    }

    return Container(
      padding: AppTheme.cardPadding,
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _RarityBadge(rarity: rarity),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      rceBadgeText,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              displayDesc.isEmpty ? 'Sin descripción registrada.' : displayDesc,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(color: AppColors.divider, height: 14),
          Row(
            children: [
              const Icon(Icons.terrain_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  habitat,
                  style: AppTheme.bodyStyle(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: 'Editar especie',
                icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.primary),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Eliminar especie',
                icon: const Icon(Icons.delete_outline, size: 17, color: AppColors.error),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// TAB 5: GESTIÓN DE USUARIOS (REDESIGNED CARDS + CRUD)
// ===========================================================================

class _UsersTab extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> usersFuture;
  final AdminService adminService;
  final VoidCallback onRefresh;
  final VoidCallback onRetry;

  const _UsersTab({
    required this.usersFuture,
    required this.adminService,
    required this.onRefresh,
    required this.onRetry,
  });

  Future<void> _showEditUserDialog(BuildContext context, Map<String, dynamic> user) async {
    final userId = user['id']?.toString();
    final usernameCtrl = TextEditingController(text: user['username']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: const Text(
          'Editar Perfil de Usuario',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nombre de usuario',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (userId == null) return;
              try {
                await adminService.updateUserProfile(userId, {
                  'username': usernameCtrl.text.trim(),
                });
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );

    if (saved == true) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario actualizado correctamente'), backgroundColor: AppColors.success),
      );
      onRefresh();
    }
  }

  Future<void> _handleDeleteUser(BuildContext context, Map<String, dynamic> user) async {
    final userId = user['id']?.toString();
    final username = user['username']?.toString() ?? 'Usuario';
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: const Text(
          'Eliminar Usuario',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de eliminar al usuario "$username"? Esta acción no se puede deshacer.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await adminService.deleteUserProfile(userId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario eliminado correctamente'), backgroundColor: AppColors.success),
      );
      onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar usuario: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return _ErrorState(
            message: 'No se pudieron cargar los usuarios del sistema.',
            onRetry: onRetry,
          );
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline,
            message: 'No hay usuarios registrados en la plataforma.',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = (constraints.maxWidth / 320).floor().clamp(1, 4);
            return GridView.builder(
              itemCount: users.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.6,
              ),
              itemBuilder: (context, index) {
                final user = users[index];
                final username = user['username']?.toString() ?? 'Sin nombre';
                final id = user['id']?.toString() ?? 'N/A';
                final avatarUrl = user['avatar_url']?.toString();
                final createdAt = _formatDate(user['created_at']?.toString());
                final shortId = id.length > 8 ? '${id.substring(0, 8)}...' : id;

                return Container(
                  padding: AppTheme.cardPadding,
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.surfaceElevated,
                            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                            child: (avatarUrl == null || avatarUrl.isEmpty)
                                ? const Icon(Icons.person, color: AppColors.textSecondary, size: 22)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: $shortId',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Divider(color: AppColors.divider, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reg: $createdAt',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _showEditUserDialog(context, user),
                                tooltip: 'Editar usuario',
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: () => _handleDeleteUser(context, user),
                                tooltip: 'Eliminar usuario',
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ===========================================================================
// WIDGETS COMPARTIDOS Y FILTROS
// ===========================================================================

class _FilterBar extends StatelessWidget {
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final String selectedRarity;
  final ValueChanged<String> onRarityChanged;
  final int totalCount;

  const _FilterBar({
    required this.searchHint,
    required this.onSearchChanged,
    required this.selectedRarity,
    required this.onRarityChanged,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final rarities = [
      {'key': 'todos', 'label': 'Todos'},
      {'key': 'comun', 'label': 'Común'},
      {'key': 'raro', 'label': 'Raro'},
      {'key': 'epico', 'label': 'Épico'},
      {'key': 'legendario', 'label': 'Legendario'},
    ];

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
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 18),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
              ...rarities.map((r) {
                final isSelected = selectedRarity == r['key'];
                return ChoiceChip(
                  label: Text(r['label']!),
                  selected: isSelected,
                  onSelected: (_) => onRarityChanged(r['key']!),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                '$totalCount resultados',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  final String rarity;

  const _RarityBadge({required this.rarity});

  Color _colorForRarity(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'común':
      case 'comun':
        return AppColors.confidenceHigh;
      case 'raro':
        return const Color(0xFF38BDF8);
      case 'epico':
      case 'épico':
        return const Color(0xFFD946EF);
      case 'legendario':
        return const Color(0xFFFFB800);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForRarity(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        rarity.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
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
      return Supabase.instance.client.storage.from(bucketName).getPublicUrl(clean);
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.pets_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              )
            : const Icon(Icons.pets_outlined, color: AppColors.textSecondary, size: 20),
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
            style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.bold),
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
        Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
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
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
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
            Icon(icon, size: 42, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(message, style: AppTheme.bodyStyle(), textAlign: TextAlign.center),
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
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
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

class _GamificationTab extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> triviasFuture;
  final Future<List<Map<String, dynamic>>> achievementsFuture;
  final VoidCallback onRetry;

  const _GamificationTab({
    required this.triviasFuture,
    required this.achievementsFuture,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Logros e Insignias del Sistema', style: AppTheme.headingStyle()),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: achievementsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return _ErrorState(message: 'No se pudieron cargar los logros.', onRetry: onRetry);
              }
              final achievements = snapshot.data ?? [];
              if (achievements.isEmpty) {
                return const _EmptyState(icon: Icons.emoji_events_outlined, message: 'No hay logros configurados.');
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = (constraints.maxWidth / 280).floor().clamp(1, 4);
                  return GridView.builder(
                    itemCount: achievements.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 2.2,
                    ),
                    itemBuilder: (context, index) {
                      final ach = achievements[index];
                      return Container(
                        padding: AppTheme.cardPadding,
                        decoration: AppTheme.cardDecoration(),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.military_tech, color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    ach['name']?.toString() ?? 'Logro',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ach['description']?.toString() ?? '',
                                    style: AppTheme.bodyStyle(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
          Text('Preguntas de Trivias Ambientales', style: AppTheme.headingStyle()),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: triviasFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return _ErrorState(message: 'No se pudieron cargar las trivias.', onRetry: onRetry);
              }
              final trivias = snapshot.data ?? [];
              if (trivias.isEmpty) {
                return const _EmptyState(icon: Icons.quiz_outlined, message: 'No hay preguntas de trivia registradas.');
              }
              return Container(
                decoration: AppTheme.cardDecoration(),
                child: ListView.separated(
                  itemCount: trivias.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, _) => const Divider(color: AppColors.divider, height: 1),
                  itemBuilder: (context, index) {
                    final t = trivias[index];
                    return ListTile(
                      title: Text(
                        t['question']?.toString() ?? '',
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Categoría: ${t['category'] ?? 'General'} · Dificultad: ${t['difficulty'] ?? 'facil'} · Puntos: ${t['points'] ?? 10}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          '+${t['points'] ?? 10} pts',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}