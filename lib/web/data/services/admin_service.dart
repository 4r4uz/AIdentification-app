import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../supabase/supabase_service.dart';

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

/// Capa de servicio para el panel de administración web.
/// Alineada 100% con el esquema SQL de AnimalPedia.
class AdminService {
  final SupabaseClient _client = SupabaseService().client;

  // ---------------------------------------------------------------------
  // 1. Estadísticas del dashboard
  // ---------------------------------------------------------------------
  Future<DashboardStats> getDashboardStats() async {
    try {
      final detectionsRes = await _client
          .from('detections')
          .select()
          .count(CountOption.exact);

      final speciesRes = await _client
          .from('species')
          .select()
          .count(CountOption.exact);

      final usersRes = await _client
          .from('profiles')
          .select()
          .count(CountOption.exact);

      final List<dynamic> confidenceRows = await _client
          .from('detections')
          .select('confidence');

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
              .select('id, name_common, name_scientific, rarity, image_url')
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

        d['profiles'] = (uid != null ? profilesById[uid] : null) ??
            {
              'username': uid != null
                  ? 'Usuario (${uid.substring(0, uid.length > 6 ? 6 : uid.length)})'
                  : 'Anónimo',
              'avatar_url': null,
            };

        d['species'] = (sid != null ? speciesById[sid] : null) ??
            {
              'id': sid,
              'name_common': sid != null ? 'Especie #$sid' : 'Sin clasificar',
              'name_scientific': 'Pendiente de validación',
              'rarity': 'comun',
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
      debugPrint('[AdminService] Error al eliminar la detección #$detectionId: $e');
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
      debugPrint('[AdminService] Error al reasignar especie en detección #$detectionId: $e');
      rethrow;
    }
  }

  /// Retorna el listado completo de usuarios registrados en el sistema.
  Future<List<Map<String, dynamic>>> getUsersList() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[AdminService] Error en getUsersList: $e');
      return [];
    }
  }

  /// Actualiza la información de un usuario (ej. nombre de usuario)
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
    } catch (e) {
      debugPrint('[AdminService] Error al actualizar perfil de usuario $userId: $e');
      rethrow;
    }
  }

  /// Elimina un perfil de usuario de la plataforma
  Future<void> deleteUserProfile(String userId) async {
    try {
      await _client
          .from('profiles')
          .delete()
          .eq('id', userId);
    } catch (e) {
      debugPrint('[AdminService] Error al eliminar usuario $userId: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------
  // 3. Catálogo de Especies (CRUD completo)
  // ---------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getSpeciesList() async {
    try {
      final response = await _client
          .from('species')
          .select()
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
  Future<List<Map<String, dynamic>>> getTriviasList() async {
    try {
      final response = await _client
          .from('trivias')
          .select()
          .order('id', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[AdminService] Error en getTriviasList: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAchievementsList() async {
    try {
      final response = await _client
          .from('achievements')
          .select()
          .order('id', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[AdminService] Error en getAchievementsList: $e');
      return [];
    }
  }
}