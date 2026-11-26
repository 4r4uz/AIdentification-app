import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../supabase/supabase_service.dart';
import '../models/billing_admin_page.dart';

/// Modelo tipado para las estadísticas del dashboard administrativo.
class DashboardStats {
  final int totalDetections;
  final int totalSpecies;
  final int totalUsers;
  final double averageConfidence;

  const DashboardStats({
    required this.totalDetections,
    required this.totalSpecies,
    required this.totalUsers,
    required this.averageConfidence,
  });

  factory DashboardStats.empty() => const DashboardStats(
    totalDetections: 0,
    totalSpecies: 0,
    totalUsers: 0,
    averageConfidence: 0.0,
  );
}

class AdminPageResult {
  final int count;
  final List<Map<String, dynamic>> items;

  const AdminPageResult({required this.count, required this.items});

  const AdminPageResult.empty() : count = 0, items = const [];
}

/// Capa de servicio para el panel de administración web.
/// Alineada 100% con el esquema SQL de AnimalPedia.
class AdminService {
  final SupabaseClient _client = SupabaseService().client;

  // TODO: Add provider-specific checkout and portal methods after selection.
  Future<BillingAdminPage> getBillingAdminPage({
    required String section,
    required int page,
    required String status,
    required String search,
  }) async {
    final response = await _client.functions.invoke(
      'admin-billing',
      body: {
        'section': section,
        'page': page,
        'page_size': 25,
        'status': status,
        'search': search,
      },
    );

    if (response.status >= 400) {
      final data = response.data;
      final message = data is Map
          ? data['error']?.toString()
          : null;
      throw Exception(message ?? 'No se pudo cargar la información de pagos.');
    }

    final data = response.data;
    if (data is! Map) {
      throw Exception('La respuesta de facturación no tiene un formato válido.');
    }
    return BillingAdminPage.fromJson(Map<String, dynamic>.from(data));
  }

  // ---------------------------------------------------------------------
  // 1. Estadísticas del dashboard
  // ---------------------------------------------------------------------
  Future<DashboardStats> getDashboardStats() async {
    try {
      final detectionsRes = await _client
          .from('detections')
          .select('id')
          .count(CountOption.exact);

      final speciesRes = await _client
          .from('species')
          .select('id')
          .count(CountOption.exact);

      final usersRes = await _client
          .from('profiles')
          .select('id')
          .count(CountOption.exact);

      final List<dynamic> confidenceRows = await _client
          .from('detections')
          .select('confidence')
          .limit(100);

      final averageConfidence = _calculateAverageConfidence(confidenceRows);

      return DashboardStats(
        totalDetections: detectionsRes.count,
        totalSpecies: speciesRes.count,
        totalUsers: usersRes.count,
        averageConfidence: averageConfidence,
      );
    } catch (e, stack) {
      debugPrint('[AdminService] Error en getDashboardStats: $e');
      debugPrint('[AdminService] StackTrace: $stack');
      return DashboardStats.empty(); // Retorna vacío en vez de romper la app
    }
  }

  double _calculateAverageConfidence(List<dynamic> rows) {
    if (rows.isEmpty) return 0.0;

    final values = rows
        .map((row) => (row as Map<String, dynamic>)['confidence'])
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList();

    if (values.isEmpty) return 0.0;

    final sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }

  // ---------------------------------------------------------------------
  // 2. Detecciones recientes (Join seguro con species + profiles)
  // ---------------------------------------------------------------------
  // ---------------------------------------------------------------------
  // 2. Detecciones recientes (Cruce blindado con species + profiles)
  // ---------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getRecentDetections({
    int limit = 100,
  }) async {
    try {
      final response = await _client
          .from('detections')
          .select('''
            id,
            user_id,
            species_id,
            image_path,
            confidence,
            location_lat,
            location_lng,
            created_at
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

      final detections = List<Map<String, dynamic>>.from(response);

      // 1. Extraemos IDs únicos de usuarios y de especies
      final userIds = detections
          .map((d) => d['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final speciesIds = detections
          .map((d) => d['species_id'])
          .whereType<int>()
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> profilesById = {};
      final Map<int, Map<String, dynamic>> speciesById = {};

      // 2. Consultamos los perfiles asociados
      if (userIds.isNotEmpty) {
        try {
          final profilesRes = await _client
              .from('profiles')
              .select('id, username, avatar_url')
              .inFilter('id', userIds);

          for (final p in profilesRes) {
            final map = Map<String, dynamic>.from(p);
            final id = map['id']?.toString();
            if (id != null) profilesById[id] = map;
          }
        } catch (e) {
          debugPrint('[AdminService] Aviso al cruzar profiles: $e');
        }
      }

      // 3. Consultamos las especies asociadas
      if (speciesIds.isNotEmpty) {
        try {
          final speciesRes = await _client
              .from('species')
              .select('id, name_common, name_scientific, habitat, image_url')
              .inFilter('id', speciesIds);

          for (final s in speciesRes) {
            final map = Map<String, dynamic>.from(s);
            final id = map['id'] as int?;
            if (id != null) speciesById[id] = map;
          }
        } catch (e) {
          debugPrint('[AdminService] Aviso al cruzar species: $e');
        }
      }

      // 4. Inyectamos 'profiles' y 'species' en cada detección
      for (final d in detections) {
        final uid = d['user_id']?.toString();
        final sid = d['species_id'] as int?;

        d['profiles'] =
            (uid != null ? profilesById[uid] : null) ??
            {
              'username': uid != null
                  ? 'Usuario (${uid.substring(0, uid.length > 6 ? 6 : uid.length)})'
                  : 'Anónimo',
              'avatar_url': null,
            };

        d['species'] =
            (sid != null ? speciesById[sid] : null) ??
            {
              'id': sid,
              'name_common': sid != null ? 'Especie #$sid' : 'Sin clasificar',
              'name_scientific': 'Pendiente de validación',
              'image_url': null,
            };
      }

      return detections;
    } catch (e, stack) {
      debugPrint('[AdminService] Error en getRecentDetections: $e');
      debugPrint('[AdminService] StackTrace: $stack');
      return [];
    }
  }

  /// Elimina un registro de detección por su ID (integer).
  Future<void> deleteDetection(int detectionId) async {
    try {
      await _client.from('detections').delete().eq('id', detectionId);
    } catch (e) {
      debugPrint(
        '[AdminService] Error al eliminar la detección #$detectionId: $e',
      );
      rethrow;
    }
  }

  /// Moderación (HU-15): Corrige o reasigna la especie de un avistamiento.
  Future<void> updateDetectionSpecies(int detectionId, int newSpeciesId) async {
    try {
      await _client
          .from('detections')
          .update({'species_id': newSpeciesId})
          .eq('id', detectionId);
    } catch (e) {
      debugPrint(
        '[AdminService] Error al reasignar especie en detección #$detectionId: $e',
      );
      rethrow;
    }
  }

  /// Retorna el listado completo de usuarios registrados en el sistema.
  Future<List<Map<String, dynamic>>> getUsersList() async {
    try {
      final response = await _client
          .from('profiles')
          .select('id, username, avatar_url, created_at, role, is_active')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[AdminService] Error en getUsersList: $e');
      rethrow;
    }
  }

  /// Crea un usuario de autenticación y su perfil asociado.
  Future<void> createUser({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.functions.invoke(
      'admin-create-user',
      body: {'email': email, 'password': password, 'username': username},
    );

    if (response.status >= 400) {
      throw Exception(
        response.data?['error']?.toString() ?? 'No se pudo crear el usuario.',
      );
    }
  }

  /// Actualiza la información de un usuario (ej. nombre de usuario)
  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _client.from('profiles').update(updates).eq('id', userId);
    } catch (e) {
      debugPrint(
        '[AdminService] Error al actualizar perfil de usuario $userId: $e',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getManagedUser(String userId) async {
    final response = await _client.functions.invoke(
      'admin-get-user',
      body: {'user_id': userId},
    );

    if (response.status >= 400) {
      throw Exception(
        response.data?['error']?.toString() ?? 'No se pudo cargar el usuario.',
      );
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> updateManagedUser({
    required String userId,
    required String username,
    String? email,
    String? password,
  }) async {
    final response = await _client.functions.invoke(
      'admin-update-user',
      body: {
        'user_id': userId,
        'username': username,
        if (email != null && email.isNotEmpty) 'email': email,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );

    if (response.status >= 400) {
      throw Exception(
        response.data?['error']?.toString() ??
            'No se pudo actualizar el usuario.',
      );
    }

  }

  /// Habilita o deshabilita el acceso del usuario sin eliminar su perfil.
  Future<void> setUserStatus(String userId, bool isActive) async {
    final response = await _client.functions.invoke(
      'admin-update-user',
      body: {'user_id': userId, 'is_active': isActive},
    );

    if (response.status >= 400) {
      throw Exception(
        response.data?['error']?.toString() ??
            'No se pudo cambiar el estado del usuario.',
      );
    }
  }

  Future<void> deleteUser(String userId) async {
    final response = await _client.functions.invoke(
      'admin-delete-user',
      body: {'user_id': userId},
    );

    if (response.status >= 400) {
      throw Exception(
        response.data?['error']?.toString() ??
            'No se pudo eliminar el usuario.',
      );
    }
  }

  // ---------------------------------------------------------------------
  // 3. Catálogo de Especies (CRUD completo)
  // ---------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getSpeciesList() async {
    try {
      final response = await _client
          .from('species')
          .select(
            'id, name_common, name_scientific, description, image_url, habitat, created_at',
          )
          .order('name_common', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[AdminService] Error en getSpeciesList: $e');
      return [];
    }
  }

  Future<void> createSpecies(Map<String, dynamic> data) async {
    try {
      await _client.from('species').insert(data);
    } catch (e) {
      debugPrint('[AdminService] Error al crear especie: $e');
      rethrow;
    }
  }

  Future<void> updateSpecies(int id, Map<String, dynamic> data) async {
    try {
      await _client.from('species').update(data).eq('id', id);
    } catch (e) {
      debugPrint('[AdminService] Error al actualizar especie #$id: $e');
      rethrow;
    }
  }

  Future<void> deleteSpecies(int id) async {
    try {
      await _client.from('species').delete().eq('id', id);
    } catch (e) {
      debugPrint('[AdminService] Error al eliminar especie #$id: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------
  // 4. Gestión de Trivias y Logros (Gamificación)
  // ---------------------------------------------------------------------
  Future<AdminPageResult> getTriviasPage({
    required int page,
    int pageSize = 50,
    String search = '',
    String category = '',
    String difficulty = '',
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var countQuery = _client.from('trivias').select('id');
    var dataQuery = _client.from('trivias').select();

    if (search.isNotEmpty) {
      countQuery = countQuery.ilike('question', '%$search%');
      dataQuery = dataQuery.ilike('question', '%$search%');
    }
    if (category.isNotEmpty && category != 'Todas') {
      countQuery = countQuery.eq('category', category);
      dataQuery = dataQuery.eq('category', category);
    }
    if (difficulty.isNotEmpty && difficulty != 'Todas') {
      countQuery = countQuery.eq('difficulty', difficulty);
      dataQuery = dataQuery.eq('difficulty', difficulty);
    }

    final countResponse = await countQuery.count(CountOption.exact);
    final dataResponse = await dataQuery
        .order('id', ascending: false)
        .range(from, to);

    return AdminPageResult(
      count: countResponse.count,
      items: List<Map<String, dynamic>>.from(dataResponse),
    );
  }

  Future<AdminPageResult> getAchievementsPage({
    required int page,
    int pageSize = 50,
    String search = '',
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var countQuery = _client.from('achievements').select('id');
    var dataQuery = _client.from('achievements').select();

    if (search.isNotEmpty) {
      countQuery = countQuery.ilike('name', '%$search%');
      dataQuery = dataQuery.ilike('name', '%$search%');
    }

    final countResponse = await countQuery.count(CountOption.exact);
    final dataResponse = await dataQuery
        .order('id', ascending: true)
        .range(from, to);

    return AdminPageResult(
      count: countResponse.count,
      items: List<Map<String, dynamic>>.from(dataResponse),
    );
  }

  Future<void> createTrivia(Map<String, dynamic> data) async {
    await _client.from('trivias').insert(data);
  }

  Future<void> updateTrivia(int id, Map<String, dynamic> data) async {
    await _client.from('trivias').update(data).eq('id', id);
  }

  Future<void> deleteTrivia(int id) async {
    await _client.from('trivias').delete().eq('id', id);
  }

  Future<void> createAchievement(Map<String, dynamic> data) async {
    await _client.from('achievements').insert(data);
  }

  Future<void> updateAchievement(int id, Map<String, dynamic> data) async {
    await _client.from('achievements').update(data).eq('id', id);
  }

  Future<void> deleteAchievement(int id) async {
    await _client.from('achievements').delete().eq('id', id);
  }
}
