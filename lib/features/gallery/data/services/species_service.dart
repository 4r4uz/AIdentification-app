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
      throw Exception(
        'Error al obtener especies descubiertas: ${e.toString()}',
      );
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

  Future<List<SpeciesFactModel>> getSpeciesFactsById(int speciesId) async {
    try {
      final response = await _supabaseService.client
          .from('species_facts')
          .select('id, species_id, fact, sort_order, source_url')
          .eq('species_id', speciesId)
          .order('sort_order')
          .order('id')
          .timeout(const Duration(seconds: 10));

      return (response as List)
          .map(
            (item) => SpeciesFactModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on TimeoutException catch (error) {
      debugPrint(
        'Tiempo de espera agotado consultando datos de especie '
        '$speciesId: $error',
      );
      rethrow;
    } catch (error) {
      debugPrint('Error consultando datos de especie $speciesId: $error');
      rethrow;
    }
  }

  Future<SpeciesModel?> resolveDetectedSpecies({
    required String prediction,
    required String predictionSource,
  }) async {
    if (!predictionSource.contains('classifier')) return null;

    final parts = prediction.split(';');
    if (parts.length < 7) return null;

    final genus = parts[4].trim();
    final speciesEpithet = parts[5].trim();
    final commonName = parts[6].trim();

    if (genus.isEmpty && commonName.isEmpty) return null;

    final scientificName = [genus, speciesEpithet]
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (scientificName.isNotEmpty) {
      final exactMatch = await getSpeciesByScientificName(scientificName);
      if (exactMatch != null) return exactMatch;
    }

    final speciesList = await getAllSpecies();

    if (genus.isNotEmpty && speciesEpithet.isNotEmpty) {
      final normalizedPrediction = _normalizeScientificName(scientificName);
      final exactNormalizedMatch = speciesList.where((species) {
        final databaseName = species.nameScientific;
        return databaseName != null &&
            _normalizeScientificName(databaseName) == normalizedPrediction;
      });
      if (exactNormalizedMatch.isNotEmpty) {
        final species = exactNormalizedMatch.first;
        debugPrint(
          'Especie de clasificador resuelta por nombre científico '
          'normalizado: "$scientificName" -> "${species.nameScientific}"',
        );
        return species;
      }

      final binomialMatch = speciesList.where((species) {
        final databaseName = species.nameScientific;
        return databaseName != null &&
            _scientificBinomial(databaseName) == normalizedPrediction;
      });
      if (binomialMatch.isNotEmpty) {
        final species = binomialMatch.first;
        debugPrint(
          'Especie de clasificador resuelta por binomio científico: '
          '"$scientificName" -> "${species.nameScientific}"',
        );
        return species;
      }

      final subspeciesMatch = speciesList.where((species) {
        final databaseName = species.nameScientific;
        return databaseName != null &&
            _matchesScientificName(
              databaseName,
              genus: genus,
              speciesEpithet: speciesEpithet,
            );
      });
      if (subspeciesMatch.isNotEmpty) {
        final species = subspeciesMatch.first;
        debugPrint(
          'Especie de clasificador resuelta por género y epíteto: '
          '"$scientificName" -> "${species.nameScientific}"',
        );
        return species;
      }
    }

    if (commonName.isNotEmpty) {
      final commonNameAliases = _commonNameAliases(commonName);
      for (final species in speciesList) {
        final databaseNames = species.nameCommon
            .split('/')
            .map(_normalizeTaxon)
            .toSet();
        if (databaseNames.intersection(commonNameAliases).isNotEmpty) {
          debugPrint(
            'Especie de clasificador resuelta por nombre común: '
            '"$commonName" -> "${species.nameCommon}"',
          );
          return species;
        }
      }
    }

    debugPrint(
      'No se encontró en Supabase la especie del clasificador: '
      'científico="$genus $speciesEpithet", común="$commonName"',
    );
    return null;
  }

  Set<String> _commonNameAliases(String value) {
    final normalized = _normalizeTaxon(value);
    return switch (normalized) {
      'domestic dog' || 'dog' => {
        'domestic dog',
        'dog',
        'perro domestico',
        'perro',
      },
      'perro domestico' || 'perro' => {
        'domestic dog',
        'dog',
        'perro domestico',
        'perro',
      },
      _ => {normalized},
    };
  }

  String _scientificBinomial(String value) {
    final parts = _normalizeScientificName(value).split(' ');
    return parts.length < 2 ? parts.join(' ') : parts.take(2).join(' ');
  }

  String _normalizeScientificName(String value) {
    final parts = _normalizeTaxon(value).split(' ');
    if (parts.length < 2) return parts.join(' ');
    return parts.take(2).join(' ');
  }

  bool _matchesScientificName(
    String databaseName, {
    required String genus,
    required String speciesEpithet,
  }) {
    final normalizedDatabaseName = _normalizeTaxon(databaseName);
    final databaseParts = normalizedDatabaseName.split(' ');
    final normalizedGenus = _normalizeTaxon(genus);
    final normalizedSpecies = _normalizeTaxon(speciesEpithet);
    if (databaseParts.length < 2 || databaseParts.first != normalizedGenus) {
      return false;
    }

    return databaseParts[1] == normalizedSpecies ||
        databaseParts.skip(2).contains(normalizedSpecies);
  }

  String _normalizeTaxon(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r"""['’]"""), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
