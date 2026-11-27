import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/billing_admin_page.dart';
import '../../data/services/admin_service.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/confidence_chip.dart';
import '../widgets/detection_thumbnail.dart';
import '../widgets/filter_bar.dart';
import '../widgets/profile_avatar.dart';
import 'admin_login_screen.dart';
import '../../data/exporters/csv_exporter.dart';
import '../providers/admin_dashboard_provider.dart';

part 'parts/admin_shell.part.dart';
part 'parts/dashboard_tab.part.dart';
part 'parts/detections_tab.part.dart';
part 'parts/species_tab.part.dart';
part 'parts/users_tab.part.dart';
part 'parts/common_widgets.part.dart';
part 'parts/gamification_tab.part.dart';
part 'parts/billing_tab.part.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();

  late Future<DashboardStats> _statsFuture;
  late Future<List<Map<String, dynamic>>> _recentDetectionsFuture;
  late Future<List<Map<String, dynamic>>> _allDetectionsFuture;
  late Future<List<Map<String, dynamic>>> _speciesFuture;
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  void _loadDashboard() {
    setState(() {
      _statsFuture = _adminService.getDashboardStats();
      _recentDetectionsFuture = _adminService.getRecentDetections(limit: 6);
      _allDetectionsFuture = _adminService.getRecentDetections(limit: 100);
    });
  }

  void _loadAll(AdminDashboardProvider provider) {
    switch (provider.selectedTab) {
      case AdminTab.dashboard:
        _loadDashboard();
        break;
      case AdminTab.detections:
        _loadDetections();
        break;
      case AdminTab.species:
        _loadSpecies();
        break;
      case AdminTab.users:
        _loadUsers();
        break;
      case AdminTab.gamification:
        break;
      case AdminTab.subscriptions:
        break;
    }
  }

  void _loadDetections() {
    setState(() {
      _statsFuture = _adminService.getDashboardStats();
      _recentDetectionsFuture = _adminService.getRecentDetections(limit: 6);
      _allDetectionsFuture = _adminService.getRecentDetections(limit: 100);
    });
  }

  void _loadSpecies() {
    setState(() {
      _statsFuture = _adminService.getDashboardStats();
      _speciesFuture = _adminService.getSpeciesList();
    });
  }

  void _loadUsers() {
    setState(() {
      _statsFuture = _adminService.getDashboardStats();
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
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este registro? Esta acción no se puede deshacer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
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
      _loadDetections();
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

  Future<void> _showDetectionDetailsDialog(
    Map<String, dynamic> detection,
  ) async {
    final detectionId = detection['id'] as int?;
    final species = detection['species'] as Map<String, dynamic>?;
    final profile = detection['profiles'] as Map<String, dynamic>?;
    final commonName =
        species?['name_common']?.toString() ?? 'Especie desconocida';
    final scientificName =
        species?['name_scientific']?.toString() ?? 'Sin nombre científico';
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

    int? selectedSpeciesId =
        (detection['species_id'] as int?) ?? (species?['id'] as int?);
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
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.divider, height: 24),
                    Center(
                      child: DetectionThumbnail(
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailInfoRow(
                      icon: Icons.person_outline,
                      label: 'Reportado por',
                      value: username,
                    ),
                    const SizedBox(height: 8),
                    _DetailInfoRow(
                      icon: Icons.auto_awesome_outlined,
                      label: 'Confianza IA',
                      value: '${confidence.toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 8),
                    _DetailInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Coordenadas',
                      value: coords,
                    ),
                    const SizedBox(height: 8),
                    _DetailInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha y hora',
                      value: createdAt,
                    ),
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
                              Icon(
                                Icons.verified_user_outlined,
                                size: 16,
                                color: AppColors.primary,
                              ),
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
                            initialValue:
                                speciesCatalog.any(
                                  (s) => s['id'] == selectedSpeciesId,
                                )
                                ? selectedSpeciesId
                                : null,
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Especie asignada',
                              labelStyle: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.divider,
                                ),
                              ),
                            ),
                            items: speciesCatalog.map((s) {
                              final id = s['id'] as int;
                              final name =
                                  s['name_common']?.toString() ?? 'Sin nombre';
                              final sci =
                                  s['name_scientific']?.toString() ?? '';
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  sci.isNotEmpty ? '$name ($sci)' : name,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setModalState(() => selectedSpeciesId = val),
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
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Descartar registro'),
                          )
                        else
                          const SizedBox.shrink(),
                        Row(
                          children: [
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text(
                                'Cerrar',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed:
                                  (isSaving ||
                                      detectionId == null ||
                                      selectedSpeciesId == null)
                                  ? null
                                  : () async {
                                      setModalState(() => isSaving = true);
                                      try {
                                        await _adminService
                                            .updateDetectionSpecies(
                                              detectionId,
                                              selectedSpeciesId!,
                                            );
                                        if (!mounted || !context.mounted) {
                                          return;
                                        }
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Avistamiento moderado y especie actualizada',
                                            ),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                        _loadDetections();
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        setModalState(() => isSaving = false);
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error al actualizar: $e',
                                            ),
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
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

  Future<void> _showSpeciesFormDialog({
    Map<String, dynamic>? existingSpecies,
  }) async {
    final isEditing = existingSpecies != null;
    final commonCtrl = TextEditingController(
      text: existingSpecies?['name_common']?.toString() ?? '',
    );
    final scientificCtrl = TextEditingController(
      text: existingSpecies?['name_scientific']?.toString() ?? '',
    );
    final habitatCtrl = TextEditingController(
      text: existingSpecies?['habitat']?.toString() ?? '',
    );
    final descCtrl = TextEditingController(
      text: existingSpecies?['description']?.toString() ?? '',
    );
    final imageCtrl = TextEditingController(
      text: existingSpecies?['image_url']?.toString() ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          title: Text(
            isEditing ? 'Editar Especie' : 'Nueva Especie',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AdminTextField(
                    controller: commonCtrl,
                    label: 'Nombre común *',
                    hint: 'Ej: Huemul',
                  ),
                  const SizedBox(height: 12),
                  _AdminTextField(
                    controller: scientificCtrl,
                    label: 'Nombre científico',
                    hint: 'Ej: Hippocamelus bisulcus',
                  ),
                  const SizedBox(height: 12),
                  _AdminTextField(
                    controller: habitatCtrl,
                    label: 'Hábitat',
                    hint: 'Ej: Bosques andino-patagónicos',
                  ),
                  const SizedBox(height: 12),
                  _AdminTextField(
                    controller: imageCtrl,
                    label: 'URL de imagen de referencia',
                    hint: 'https://...',
                  ),
                  const SizedBox(height: 12),
                  _AdminTextField(
                    controller: descCtrl,
                    label: 'Descripción',
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
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
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

                final payload = <String, dynamic>{
                  'name_common': commonCtrl.text.trim(),
                  'name_scientific': scientificCtrl.text.trim().isEmpty
                      ? null
                      : scientificCtrl.text.trim(),
                  'habitat': habitatCtrl.text.trim().isEmpty
                      ? null
                      : habitatCtrl.text.trim(),
                  'description': descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  'image_url': imageCtrl.text.trim().isEmpty
                      ? null
                      : imageCtrl.text.trim(),
                };

                try {
                  if (isEditing) {
                    await _adminService.updateSpecies(
                      existingSpecies['id'] as int,
                      payload,
                    );
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
      _loadSpecies();
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
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Deseas eliminar "${species['name_common']}" del catálogo?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
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
      _loadSpecies();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo eliminar (puede tener detecciones asociadas): $e',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _titleForTab(AdminTab tab) {
    switch (tab) {
      case AdminTab.dashboard:
        return 'Dashboard';
      case AdminTab.detections:
        return 'Avistamientos';
      case AdminTab.species:
        return 'Especies';
      case AdminTab.gamification:
        return 'Gamificación';
      case AdminTab.users:
        return 'Usuarios';
      case AdminTab.subscriptions:
        return 'Suscripciones';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = AdminDashboardProvider();
        provider.loadAccount();
        return provider;
      },
      
      child: Consumer<AdminDashboardProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              children: [
                _Sidebar(
                  selectedTab: provider.selectedTab,
                  onSelectTab: (tab) {
                    provider.selectTab(tab);
                    if (tab == AdminTab.species && !provider.speciesLoaded) {
                      _loadSpecies();
                      provider.markSpeciesLoaded();
                    } else if (tab == AdminTab.users && !provider.usersLoaded) {
                      _loadUsers();
                      provider.markUsersLoaded();
                    }
                  },
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TopBar(
                            title: _titleForTab(provider.selectedTab),
                            accountName: provider.accountName,
                            accountEmail: provider.accountEmail,
                            avatarUrl: provider.accountAvatarUrl,
                            onAccount: provider.openAccountPanel,
                            onLogout: _handleLogout,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                12,
                              ),
                              child: _buildTabContent(provider),
                            ),
                          ),
                        ],
                      ),
                      if (provider.isAccountPanelOpen)
                        Positioned(
                          top: 0,
                          right: 0,
                          bottom: 0,
                          width: 340,
                          child: _AccountPanel(
                            name: provider.accountName,
                            email: provider.accountEmail,
                            avatarUrl: provider.accountAvatarUrl,
                            role: provider.accountRole,
                            onClose: provider.closeAccountPanel,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabContent(AdminDashboardProvider provider) {
    switch (provider.selectedTab) {
      case AdminTab.dashboard:
        return _DashboardTab(
          statsFuture: _statsFuture,
          allDetectionsFuture: _allDetectionsFuture,
          recentDetectionsFuture: _recentDetectionsFuture,
          onViewDetail: _showDetectionDetailsDialog,
          onViewAllTap: () => provider.selectTab(AdminTab.detections),
          onRetry: () => _loadAll(provider),
        );
      case AdminTab.detections:
        return _DetectionsTab(
          detectionsFuture: _allDetectionsFuture,
          onViewDetail: _showDetectionDetailsDialog,
          onDelete: _handleDeleteDetection,
          onRetry: _loadDetections,
        );
      case AdminTab.species:
        return _SpeciesTab(
          speciesFuture: _speciesFuture,
          onCreate: () => _showSpeciesFormDialog(),
          onEdit: (s) => _showSpeciesFormDialog(existingSpecies: s),
          onDelete: _handleDeleteSpecies,
          onRetry: _loadSpecies,
        );
      case AdminTab.gamification:
        return _GamificationTab(adminService: _adminService);
      case AdminTab.users:
        return _UsersTab(
          usersFuture: _usersFuture,
          adminService: _adminService,
          onRefresh: _loadUsers,
          onRetry: _loadUsers,
        );
      case AdminTab.subscriptions:
        return _BillingTab(adminService: _adminService);
    }
  }
}
