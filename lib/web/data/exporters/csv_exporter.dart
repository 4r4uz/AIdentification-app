import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'csv_generator.dart';

/// Adaptador de exportación CSV exclusivo para Web.
///
/// La lógica de generación de CSV vive en [CsvGenerator] (pura Dart, sin DOM).
/// Esta clase solo se encarga de disparar la descarga en el navegador.
class CsvExporter {
  /// Dispara la descarga del archivo CSV en el navegador con BOM UTF-8 para Excel.
  static void _downloadCsv(String filename, String csvContent) {
    final bytes = utf8.encode(csvContent);
    final blob = web.Blob(
      <JSUint8Array>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';

    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  /// Exporta la lista de avistamientos (filtrada o completa).
  static void exportDetections(List<Map<String, dynamic>> detections) {
    final csv = CsvGenerator.detections(detections);
    final dateTag = DateTime.now().toIso8601String().split('T').first;
    _downloadCsv('animalpedia_avistamientos_$dateTag.csv', csv);
  }

  /// Exporta el catálogo de especies.
  static void exportSpecies(List<Map<String, dynamic>> speciesList) {
    final csv = CsvGenerator.species(speciesList);
    final dateTag = DateTime.now().toIso8601String().split('T').first;
    _downloadCsv('animalpedia_especies_$dateTag.csv', csv);
  }
}
