import 'dart:convert';
import 'dart:html' as html;

class CsvExporter {
  /// Escapa comillas, comas y saltos de línea según el estándar RFC 4180.
  static String _escape(dynamic value) {
    if (value == null) return '';
    final str = value.toString().replaceAll('"', '""');
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"$str"';
    }
    return str;
  }

  /// Dispara la descarga del archivo CSV en el navegador con BOM UTF-8 para Excel.
  static void _downloadCsv(String filename, List < List < dynamic > > rows) {
    final buffer = StringBuffer();
    // BOM UTF-8 para que Excel abra bien tildes (á, é, í, ó, ú) y ñ
    buffer.write('\uFEFF');

    for (final row in rows) {
      buffer.writeln(row.map(_escape).join(','));
    }

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  /// Exporta la lista de avistamientos (filtrada o completa).
  static void exportDetections(List < Map < String, dynamic > > detections) {
    final rows = < List < dynamic > >[
      [
        'ID',
        'Especie',
        'Rareza',
        'Confianza (%)',
        'Usuario',
        'Fecha',
      ],
    ];

    for (final d in detections) {
      final species = d['species'];
      final profile = d['profiles'];

      final speciesName = (species is Map)
          ? (species['common_name'] ?? species['name'] ?? 'Especie #${d['species_id']}')
          : 'Especie #${d['species_id'] ?? '-'}';

      final rarity = (species is Map ? species['rarity'] : null) ??
          d['rarity'] ??
          'Común';

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
        rarity,
        confidence,
        username,
        d['created_at'] ?? '',
      ]);
    }

    final dateTag = DateTime.now().toIso8601String().split('T').first;
    _downloadCsv('animalpedia_avistamientos_$dateTag.csv', rows);
  }

  /// Exporta el catálogo de especies.
  static void exportSpecies(List < Map < String, dynamic > > speciesList) {
    final rows = < List < dynamic > >[
      [
        'ID',
        'Nombre Común',
        'Nombre Científico',
        'Rareza',
        'Categoría / Hábitat',
      ],
    ];

    for (final s in speciesList) {
      rows.add([
        s['id'] ?? '',
        s['name_common'] ?? s['common_name'] ?? s['name'] ?? '',
        s['name_scientific'] ?? s['scientific_name'] ?? '',
        s['rarity'] ?? '',
        s['habitat'] ?? s['category'] ?? '',
      ]);
    }

    final dateTag = DateTime.now().toIso8601String().split('T').first;
    _downloadCsv('animalpedia_especies_$dateTag.csv', rows);
  }
}