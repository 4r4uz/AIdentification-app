import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class LocalClassifierService {
  static const String _modelAsset =
      'assets/models/speciesnet_classifier_v4.0.1a.onnx';
  static const String _labelsAsset = 'assets/models/labels.txt';
  static const int _inputSize = 480;
  static const double _speciesConfidenceThreshold = 0.8;
  static const double _animalConfidenceThreshold = 0.65;
  static const double _rollupConfidenceThreshold = 0.65;
  static const double _minimumDetectionAgreement = 0.2;
  static const double _minimumAnimalDetectionConfidence = 0.5;

  final OnnxRuntime _ort = OnnxRuntime();
  OrtSession? _session;
  List<String>? _labels;
  bool _isInitializing = false;

  bool get isModelLoaded => _session != null;

  /// Carga el modelo ONNX y los labels desde assets.
  Future<void> initialize() async {
    if (_session != null) return;
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      _labels = (await rootBundle.loadString(
        _labelsAsset,
      )).split('\n').where((e) => e.trim().isNotEmpty).toList();

      _session = await _ort.createSessionFromAsset(
        _modelAsset,
        options: OrtSessionOptions(
          intraOpNumThreads: 4,
          providers: [OrtProvider.CPU],
        ),
      );
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> dispose() async {
    await _session?.close();
    _session = null;
  }

  /// Clasifica el recorte de animal que produjo MegaDetector.
  Future<Map<String, dynamic>> analyzeImage(
    img.Image image, {
    required double detectionConfidence,
  }) async {
    if (_session == null) {
      throw Exception('Modelo local no inicializado');
    }

    final resized = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    final input = _imageToFloat32(resized);
    final inputTensor = await OrtValue.fromList(input, [
      1,
      _inputSize,
      _inputSize,
      3,
    ]);
    late final List<dynamic> logits;
    try {
      final outputs = await _session!.run({'input': inputTensor});
      try {
        final logitsValue = outputs['logits'];
        if (logitsValue == null) {
          throw Exception(
            'No se encontró la salida "logits" del modelo SpeciesNet',
          );
        }
        logits = await logitsValue.asFlattenedList();
      } finally {
        for (final output in outputs.values) {
          await output.dispose();
        }
      }
    } finally {
      await inputTensor.dispose();
    }

    if (logits.isEmpty || logits.length != _labels!.length) {
      throw Exception(
        'La salida SpeciesNet (${logits.length} clases) no coincide con '
        'sus etiquetas (${_labels!.length})',
      );
    }

    final scores = _softmax(logits);
    var topIndex = 0;
    for (var index = 1; index < scores.length; index++) {
      if (scores[index] > scores[topIndex]) topIndex = index;
    }

    final topLabelParts = _parseLabel(_labels![topIndex], topIndex);
    final topScore = scores[topIndex];
    if (_isAnimalLabel(topLabelParts) &&
        (topScore > _speciesConfidenceThreshold ||
            (topScore > _animalConfidenceThreshold &&
                detectionConfidence > _minimumDetectionAgreement))) {
      return _buildClassificationResult(
        topLabelParts[6],
        topScore,
        _labels![topIndex],
        'classifier',
      );
    }

    final rollup = _rollUpTaxonomy(scores);
    if (rollup != null) return rollup;

    if (detectionConfidence > _minimumAnimalDetectionConfidence) {
      return {
        'status': 'ok',
        'label': 'Animal detectado',
        'confidence': detectionConfidence,
        'prediction': '',
        'prediction_source': 'detector',
        'prediction_score': detectionConfidence,
      };
    }

    return {
      'status': 'ok',
      'label': 'Animal no identificado',
      'confidence': topScore,
      'prediction': '',
      'prediction_source': 'unknown',
      'prediction_score': topScore,
    };
  }

  List<String> _parseLabel(String label, int index) {
    final parts = label.split(';').map((part) => part.trim()).toList();
    if (parts.length < 7) {
      throw FormatException(
        'Etiqueta SpeciesNet inválida para el índice $index: $label',
      );
    }
    return parts;
  }

  bool _isAnimalLabel(List<String> parts) {
    final commonName = parts[6].toLowerCase();
    return parts
            .sublist(1, 6)
            .any((taxon) => taxon.isNotEmpty && taxon != 'unknown') &&
        commonName != 'blank' &&
        commonName != 'human' &&
        commonName != 'vehicle';
  }

  Map<String, dynamic> _buildClassificationResult(
    String label,
    double score,
    String prediction,
    String source,
  ) {
    return {
      'status': 'ok',
      'label': label.isEmpty ? 'Animal detectado' : label,
      'confidence': score,
      'prediction': prediction,
      'prediction_source': source,
      'prediction_score': score,
    };
  }

  Map<String, dynamic>? _rollUpTaxonomy(List<double> scores) {
    const rollupLevels = [
      ('genus', 4),
      ('family', 3),
      ('order', 2),
      ('class', 1),
      ('kingdom', 0),
    ];

    for (final (level, rankIndex) in rollupLevels) {
      final accumulatedScores = <String, double>{};
      final representatives = <String, List<String>>{};

      for (var index = 0; index < scores.length; index++) {
        final parts = _parseLabel(_labels![index], index);
        if (!_isAnimalLabel(parts)) continue;

        final taxon = rankIndex == 0 ? 'Animalia' : parts[rankIndex];
        if (taxon.isEmpty || taxon.toLowerCase() == 'unknown') continue;

        accumulatedScores.update(
          taxon,
          (score) => score + scores[index],
          ifAbsent: () => scores[index],
        );
        representatives.putIfAbsent(taxon, () => parts);
      }

      if (accumulatedScores.isEmpty) continue;
      final bestTaxon = accumulatedScores.entries.reduce(
        (best, candidate) =>
            candidate.value > best.value ? candidate : best,
      );
      if (bestTaxon.value <= _rollupConfidenceThreshold) continue;

      final predictionParts = List<String>.from(
        representatives[bestTaxon.key]!,
      );
      predictionParts[rankIndex] = bestTaxon.key;
      for (var lowerRank = rankIndex + 1; lowerRank <= 5; lowerRank++) {
        predictionParts[lowerRank] = '';
      }
      predictionParts[6] = bestTaxon.key;

      return _buildClassificationResult(
        bestTaxon.key,
        bestTaxon.value,
        predictionParts.join(';'),
        'classifier+rollup_to_$level',
      );
    }

    return null;
  }

  // ---------------- PREPROCESADO ----------------

  Float32List _imageToFloat32(img.Image image) {
    final buffer = Float32List(_inputSize * _inputSize * 3);
    int idx = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final p = image.getPixel(x, y);
        buffer[idx++] = p.r / 255.0;
        buffer[idx++] = p.g / 255.0;
        buffer[idx++] = p.b / 255.0;
      }
    }
    return buffer;
  }

  // ---------------- SOFTMAX + TOP-1 ----------------

  List<double> _softmax(List<dynamic> logits) {
    double maxVal = -double.infinity;
    for (final v in logits) {
      final d = (v as num).toDouble();
      if (!d.isFinite) {
        throw const FormatException('SpeciesNet produjo logits no finitos');
      }
      if (d > maxVal) maxVal = d;
    }

    final expValues = List<double>.filled(logits.length, 0);
    double sum = 0.0;
    for (int i = 0; i < logits.length; i++) {
      final e = math.exp((logits[i] as num).toDouble() - maxVal);
      expValues[i] = e;
      sum += e;
    }

    return [for (final value in expValues) value / sum];
  }
}
