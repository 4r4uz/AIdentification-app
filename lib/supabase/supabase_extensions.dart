import 'package:supabase_flutter/supabase_flutter.dart';

extension SupabaseClientExtensions on SupabaseClient {
  Future<List<T>> safeListFrom<T>(
    PostgrestTransformBuilder<PostgrestList> query, {
    required T Function(Map<String, dynamic>) fromJson,
    String errorMessage = 'Error en consulta',
  }) async {
    try {
      final response = await query;
      final list = response as List;
      return list.map((json) => fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('$errorMessage: ${e.toString()}');
    }
  }

  Future<T?> safeMaybeSingle<T>(
    PostgrestTransformBuilder<PostgrestResponse> query, {
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final response = await query;
      if (response.data == null) return null;
      return fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }
}
