import 'package:flutter/foundation.dart';
import '/core/network/supabase_service.dart';
import '/features/gallery/data/models/species_model.dart';
import '/core/extensions/supabase_extensions.dart';

class SpeciesService {
  final SupabaseService _supabaseService = SupabaseService();

  Future<List<SpeciesModel>> getAllSpecies() async {
    return _supabaseService.client.safeListFrom(
      _supabaseService.client.from('species').select().order('name_common'),
      fromJson: SpeciesModel.fromJson,
      errorMessage: 'Error al obtener especies',
    );
  }

  Future<SpeciesModel?> getSpeciesById(int id) async {
    try {
      final response = await _supabaseService.client.from('species').select().eq('id', id).single();
      return SpeciesModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<SpeciesModel?> getSpeciesByName(String name) async {
    try {
      final response = await _supabaseService.client
          .from('species')
          .select()
          .ilike('name_common', name)
          .maybeSingle();

      if (response == null) return null;
      return SpeciesModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<SpeciesModel>> getSpeciesByRarity(String rarity) async {
    return _supabaseService.client.safeListFrom(
      _supabaseService.client.from('species').select().eq('rarity', rarity).order('name_common'),
      fromJson: SpeciesModel.fromJson,
      errorMessage: 'Error al obtener especies por rareza',
    );
  }

  Future<List<SpeciesModel>> getDiscoveredSpecies(String userId) async {
    try {
      final response = await _supabaseService.client
          .from('user_species')
          .select('species(*)')
          .eq('user_id', userId);

      return (response as List)
          .map((item) => SpeciesModel.fromJson(item['species'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener especies descubiertas: ${e.toString()}');
    }
  }

  Future<void> registerDetectedSpecies({
    required String prediction,
    required String predictionSource,
  }) async {
    if (predictionSource != 'classifier') return;

    final parts = prediction.split(';');
    if (parts.length < 7) return;

    final genus = parts[4].trim();
    final speciesEpithet = parts[5].trim();
    final commonName = parts[6].trim();

    if (genus.isEmpty || speciesEpithet.isEmpty || commonName.isEmpty) return;

    final scientificName = '$genus $speciesEpithet';

    try {
      final existing = await _supabaseService.client
          .from('species')
          .select('id')
          .eq('name_scientific', scientificName)
          .maybeSingle();

      if (existing != null) return;

      await _supabaseService.client.from('species').insert({
        'name_common': commonName,
        'name_scientific': scientificName,
      });
    } catch (e) {
      debugPrint('Error al registrar especie detectada: $e');
    }
  }
}