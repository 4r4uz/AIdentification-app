import 'dart:io';
import '/core/network/supabase_service.dart';
import '/features/camera/data/models/detection_model.dart';
import '/features/profile/data/services/profile_refresh_notifier.dart';
import '/core/extensions/supabase_extensions.dart';

class DetectionService {
  final SupabaseService _supabaseService = SupabaseService();

  Future<DetectionModel?> saveDetection({
    required File imageFile,
    required int? speciesId,
    required double? confidence,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final imagePath = await _uploadImage(imageFile, user.id);

      final response = await _supabaseService.client
          .from('detections')
          .insert({
            'user_id': user.id,
            'species_id': speciesId,
            'image_path': imagePath,
            'confidence': confidence,
            'location_lat': latitude,
            'location_lng': longitude,
          })
          .select()
          .single();

      final detection = DetectionModel.fromJson(response);
      ProfileRefreshNotifier.notifyDetectionSaved();

      if (speciesId != null) {
        await _addToUserSpecies(user.id, speciesId);
      }

      return detection;
    } catch (e) {
      throw Exception('Error al guardar detección: ${e.toString()}');
    }
  }

  Future<String> _uploadImage(File imageFile, String userId) async {
    try {
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$userId/$fileName';

      await _supabaseService.client.storage
          .from('detection-images')
          .upload(filePath, imageFile);

      return filePath;
    } catch (e) {
      throw Exception('Error al subir imagen: ${e.toString()}');
    }
  }

  Future<void> _addToUserSpecies(String userId, int speciesId) async {
    try {
      final existing = await _supabaseService.client
          .from('user_species')
          .select('total_detections')
          .eq('user_id', userId)
          .eq('species_id', speciesId)
          .maybeSingle();

      if (existing != null) {
        await _supabaseService.client
            .from('user_species')
            .update({
              'total_detections': (existing['total_detections'] as int) + 1,
            })
            .eq('user_id', userId)
            .eq('species_id', speciesId);
      } else {
        await _supabaseService.client.from('user_species').insert({
          'user_id': userId,
          'species_id': speciesId,
          'total_detections': 1,
        });
      }
    } catch (e) {
      throw Exception(
        'Error al actualizar progreso de especie: ${e.toString()}',
      );
    }
  }

  Future<List<DetectionModel>> getUserDetections(String userId) async {
    return _supabaseService.client.safeListFrom(
      _supabaseService.client
          .from('detections')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false),
      fromJson: DetectionModel.fromJson,
      errorMessage: 'Error al obtener historial',
    );
  }

  Future<int> getTotalDetectionsCount(String userId) async {
    try {
      final response = await _supabaseService.client
          .from('detections')
          .select()
          .eq('user_id', userId);

      return (response as List).length;
    } catch (e) {
      throw Exception('Error al obtener el total de detecciones: $e');
    }
  }

  Future<Map<String, int>> getSpeciesStatistics(String userId) async {
    try {
      final response = await _supabaseService.client
          .from('user_species')
          .select('species_id, total_detections')
          .eq('user_id', userId);

      final Map<String, int> stats = {};
      for (var item in response as List) {
        stats[item['species_id'].toString()] = item['total_detections'] as int;
      }
      return stats;
    } catch (e) {
      return {};
    }
  }
}
