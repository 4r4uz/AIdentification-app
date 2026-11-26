/// Generador puro de CSV (sin dependencia del navegador).
///
/// Todas las funciones devuelven un `String` listo para ser escrito en archivo
/// o descargado mediante la plataforma correspondiente (web, móvil, desktop).
///
/// El escape sigue el estándar RFC 4180.
class CsvGenerator {
  /// Escapa comillas, comas y saltos de línea según RFC 4180.
  static String escape(dynamic value) {
    if (value == null) return '';
    final str = value.toString().replaceAll('"', '""');
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"$str"';
    }
    return str;
  }

  /// Convierte una lista de filas en un String CSV con BOM UTF-8.
  ///
  /// El BOM (`\uFEFF`) permite que Excel abra correctamente tildes, ñ, etc.
  static String generate(List<List<dynamic>> rows) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    for (final row in rows) {
      buffer.writeln(row.map(escape).join(','));
    }

    return buffer.toString();
  }

  /// Genera el CSV de avistamientos (detecciones).
  static String detections(List<Map<String, dynamic>> detections) {
    final rows = <List<dynamic>>[
      ['ID', 'Especie', 'Confianza (%)', 'Usuario', 'Fecha'],
    ];

    for (final d in detections) {
      final species = d['species'];
      final profile = d['profiles'];

      final speciesName = (species is Map)
          ? (species['name_common'] ??
                species['name'] ??
                'Especie #${d['species_id']}')
          : 'Especie #${d['species_id'] ?? '-'}';

      final rawConf = d['confidence'];
      String confidence = '-';
      if (rawConf is num) {
        final pct = rawConf <= 1 ? rawConf * 100 : rawConf;
        confidence = pct.toStringAsFixed(1);
      }

      final username = (profile is Map)
          ? (profile['username'] ?? profile['full_name'] ?? 'Desconocido')
          : 'Desconocido';

      rows.add([
        d['id'] ?? '',
        speciesName,
        confidence,
        username,
        d['created_at'] ?? '',
      ]);
    }

    return generate(rows);
  }

  /// Genera el CSV del catálogo de especies.
  static String species(List<Map<String, dynamic>> speciesList) {
    final rows = <List<dynamic>>[
      ['ID', 'Nombre Común', 'Nombre Científico', 'Categoría / Hábitat'],
    ];

    for (final s in speciesList) {
      rows.add([
        s['id'] ?? '',
        s['name_common'] ?? s['common_name'] ?? s['name'] ?? '',
        s['name_scientific'] ?? s['scientific_name'] ?? '',
        s['habitat'] ?? s['category'] ?? '',
      ]);
    }

    return generate(rows);
  }
}