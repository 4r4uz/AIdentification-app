import 'dart:async';
import 'package:flutter/foundation.dart';
import '/core/network/supabase_service.dart';
import '/features/gallery/data/models/species_model.dart';
import '/features/gallery/data/models/species_fact_model.dart';
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
      final response = await _supabaseService.client
          .from('species')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return SpeciesModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<SpeciesModel?> getSpeciesByScientificName(String name) async {
    final scientificName = name.trim();
    if (scientificName.isEmpty) return null;

    try {
      final response = await _supabaseService.client
          .from('species')
          .select()
          .eq('name_scientific', scientificName)
          .maybeSingle();

      if (response == null) return null;
      return SpeciesModel.fromJson(response);
    } catch (e) {
      debugPrint('Error buscando especie por nombre científico: $e');
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
          .from('user_species_view')
          .select('species_id')
          .eq('user_id', userId);

      final speciesIds = (response as List)
          .map((item) => (item['species_id'] as num).toInt())
          .toSet()
          .toList();

      if (speciesIds.isEmpty) return [];

      return await _supabaseService.client.safeListFrom(
        _supabaseService.client
            .from('species')
            .select()
            .inFilter('id', speciesIds)
            .order('name_common'),
        fromJson: SpeciesModel.fromJson,
        errorMessage: 'Error al obtener especies descubiertas',
      );
    } catch (e) {
      throw Exception('Error al obtener especies descubiertas: ${e.toString()}');
    }
  }

  Future<List<SpeciesFactModel>> getAllSpeciesFacts() async {
    try {
      final response = await _supabaseService.client
          .from('species_facts')
          .select('id, species_id, fact, sort_order, source_url')
          .order('sort_order')
          .order('id')
          .timeout(const Duration(seconds: 10));

      final facts = (response as List)
          .map(
            (item) => SpeciesFactModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      debugPrint('Datos curiosos cargados desde Supabase: ${facts.length}');
      if (facts.isEmpty) {
        return [];
      }

      final speciesIds = facts.map((fact) => fact.speciesId).toSet().toList();

      // Ejecutar ambas consultas en paralelo para reducir latencia
      final speciesResponse = await _supabaseService.client
          .from('species')
          .select('id, name_common, name_scientific')
          .inFilter('id', speciesIds)
          .timeout(const Duration(seconds: 10));

      final speciesNames = <int, String>{};
      final speciesScientificNames = <int, String?>{};
      for (final item in speciesResponse as List) {
        final row = Map<String, dynamic>.from(item as Map);
        final id = (row['id'] as num).toInt();
        final name = row['name_common'];
        final scientificName = row['name_scientific'];
        if (name is String && name.trim().isNotEmpty) {
          speciesNames[id] = name;
        }
        speciesScientificNames[id] = scientificName is String
            ? scientificName
            : null;
      }

      return facts
          .map(
            (fact) => SpeciesFactModel(
              id: fact.id,
              speciesId: fact.speciesId,
              fact: fact.fact,
              sortOrder: fact.sortOrder,
              sourceUrl: fact.sourceUrl,
              speciesName: speciesNames[fact.speciesId],
              scientificName: speciesScientificNames[fact.speciesId],
            ),
          )
          .toList();
    } on TimeoutException catch (e) {
      debugPrint('Tiempo de espera agotado consultando species_facts: $e');
      throw Exception('Tiempo de espera agotado al obtener datos curiosos');
    } catch (e) {
      debugPrint('Error consultando species_facts en Supabase: $e');
      throw Exception('Error al obtener datos curiosos: ${e.toString()}');
    }
  }

  Future<SpeciesModel?> resolveDetectedSpecies({
    required String prediction,
    required String predictionSource,
  }) async {
    if (predictionSource != 'classifier') return null;

    final parts = prediction.split(';');
    if (parts.length < 7) return null;

    final genus = parts[4].trim();
    final speciesEpithet = parts[5].trim();

    if (genus.isEmpty || speciesEpithet.isEmpty) return null;

    final scientificName = '$genus $speciesEpithet';
    return getSpeciesByScientificName(scientificName);
  }
}