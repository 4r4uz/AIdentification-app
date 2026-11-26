import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../supabase/supabase_service.dart';

enum AdminTab {
  dashboard,
  detections,
  species,
  gamification,
  users,
  subscriptions,
}

/// Estado compartido del panel administrativo.
///
/// Centraliza:
/// - Pestaña activa (`_selectedTab`)
/// - Datos de la cuenta del administrador logueado
/// - Estado de carga de pestañas (species, users)
/// - Filtros y paginación de usuarios y detecciones
///
/// Se consume con `Provider.of<AdminDashboardProvider>(context)` o
/// `Consumer<AdminDashboardProvider>`.
class AdminDashboardProvider extends ChangeNotifier {
  final SupabaseClient _client = SupabaseService().client;

  // ---------------------------------------------------------------------
  // Navegación
  // ---------------------------------------------------------------------
  AdminTab _selectedTab = AdminTab.dashboard;

  AdminTab get selectedTab => _selectedTab;

  void selectTab(AdminTab tab) {
    if (_selectedTab == tab) return;
    _selectedTab = tab;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Datos de cuenta
  // ---------------------------------------------------------------------
  String? _accountName;
  String? _accountEmail;
  String? _accountAvatarUrl;
  String? _accountRole;

  String? get accountName => _accountName;
  String? get accountEmail => _accountEmail;
  String? get accountAvatarUrl => _accountAvatarUrl;
  String? get accountRole => _accountRole;

  bool _isAccountPanelOpen = false;

  bool get isAccountPanelOpen => _isAccountPanelOpen;

  void openAccountPanel() {
    if (_isAccountPanelOpen) return;
    _isAccountPanelOpen = true;
    notifyListeners();
  }

  void closeAccountPanel() {
    if (!_isAccountPanelOpen) return;
    _isAccountPanelOpen = false;
    notifyListeners();
  }

  Future<void> loadAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    String? name;
    String? avatarUrl;
    String? role;

    try {
      final profile = await _client
          .from('profiles')
          .select('username, full_name, avatar_url, role')
          .eq('id', user.id)
          .maybeSingle();
      name = profile?['username']?.toString().trim();
      if (name == null || name.isEmpty) {
        name = profile?['full_name']?.toString().trim();
      }
      avatarUrl = profile?['avatar_url']?.toString().trim();
      role = profile?['role']?.toString().trim();
    } catch (_) {}

    _accountName = name?.isNotEmpty == true
        ? name
        : (user.userMetadata?['username']?.toString() ??
              user.userMetadata?['full_name']?.toString() ??
              user.email ??
              'Administrador');
    _accountEmail = user.email;
    _accountAvatarUrl = avatarUrl?.isNotEmpty == true
        ? avatarUrl
        : user.userMetadata?['avatar_url']?.toString();
    _accountRole = role?.isNotEmpty == true ? role : 'admin';

    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Flags de carga por pestaña (evita recargar innecesariamente)
  // ---------------------------------------------------------------------
  bool _speciesLoaded = false;
  bool _usersLoaded = false;

  bool get speciesLoaded => _speciesLoaded;
  bool get usersLoaded => _usersLoaded;

  void markSpeciesLoaded() {
    _speciesLoaded = true;
    notifyListeners();
  }

  void markUsersLoaded() {
    _usersLoaded = true;
    notifyListeners();
  }

  void resetTabLoadFlags() {
    _speciesLoaded = false;
    _usersLoaded = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Filtro de usuarios
  // ---------------------------------------------------------------------
  String _userStatusFilter = 'Todos';

  String get userStatusFilter => _userStatusFilter;

  void setUserStatusFilter(String value) {
    _userStatusFilter = value;
    notifyListeners();
  }
}
