import 'dart:io';

import 'package:flutter/foundation.dart';

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

      debugPrint(
        '[DetectionService] Iniciando guardado: speciesId=$speciesId, '
        'imagen=${await imageFile.length()} bytes',
      );
      final imagePath = await _uploadImage(imageFile, user.id);
      debugPrint('[DetectionService] Imagen subida a almacenamiento');

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

      debugPrint('[DetectionService] Registro insertado en Supabase');
      final detection = DetectionModel.fromJson(response);
      ProfileRefreshNotifier.notifyDetectionSaved();

      return detection;
    } catch (e) {
      debugPrint('[DetectionService] Falló el guardado: $e');
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

      debugPrint('[DetectionService] Subida de imagen completada');
      return filePath;
    } catch (e) {
      debugPrint('[DetectionService] Falló la subida de imagen: $e');
      throw Exception('Error al subir imagen: ${e.toString()}');
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
          .from('user_species_view')
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
