
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class LocalClassifierService {
  static const String _modelAsset =
      'assets/models/speciesnet_fp32.onnx';

  static const String _labelsAsset =
      'assets/models/labels.txt';

  static const int _inputSize = 480;

  static const double _speciesConfidenceThreshold = 0.8;
  static const double _animalConfidenceThreshold = 0.65;
  static const double _rollupConfidenceThreshold = 0.65;
  static const double _minimumDetectionAgreement = 0.2;
  static const double _minimumAnimalDetectionConfidence = 0.5;

  final OnnxRuntime _ort = OnnxRuntime();

  OrtSession? _session;
  List<String>? _labels;

  Future<void>? _initializationFuture;

  bool get isModelLoaded => _session != null;

  /// Carga el modelo ONNX y sus etiquetas.
  Future<void> initialize() async {
    if (_session != null) return;

    // Si ya existe una inicialización en curso,
    // espera a que termine en lugar de continuar prematuramente.
    if (_initializationFuture != null) {
      await _initializationFuture;
      return;
    }

    final future = _initializeInternal();
    _initializationFuture = future;

    try {
      await future;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _initializeInternal() async {
    try {
      final labelsContent =
          await rootBundle.loadString(_labelsAsset);

      _labels = labelsContent
          .split('\n')
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();

      _session = await _ort.createSessionFromAsset(
        _modelAsset,
        options: OrtSessionOptions(
          intraOpNumThreads: 4,
          providers: [OrtProvider.CPU],
        ),
      );

      if (_labels!.length != 2498) {
        throw FormatException(
          'Se esperaban 2498 etiquetas de SpeciesNet, '
          'pero se encontraron ${_labels!.length}. '
          'Verifica que labels.txt corresponda al modelo.',
        );
      }
    } catch (e) {
      await _session?.close();
      _session = null;
      _labels = null;

      rethrow;
    }
  }

  /// Libera los recursos del modelo.
  Future<void> dispose() async {
    await _session?.close();

    _session = null;
    _labels = null;
  }

  /// Clasifica el recorte del animal producido por MegaDetector.
  Future<Map<String, dynamic>> analyzeImage(
    img.Image image, {
    required double detectionConfidence,
  }) async {
    if (_session == null || _labels == null) {
      throw Exception('Modelo local no inicializado');
    }

    // Redimensionamiento de la imagen a 480x480.
    final resized = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Conversión RGB NHWC a Float32 [0, 1].
    final input = _imageToFloat32(resized);

    final inputTensor = await OrtValue.fromList(
      input,
      [
        1,
        _inputSize,
        _inputSize,
        3,
      ],
    );

    late final List<dynamic> logits;

    try {
      final outputs = await _session!.run({
        'input': inputTensor,
      });

      try {
        // No asumir que la salida se llama "logits".
        final outputName = _session!.outputNames.first;
        final logitsValue = outputs[outputName];

        if (logitsValue == null) {
          throw Exception(
            'No se encontró la salida ONNX: $outputName',
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
        'La salida SpeciesNet (${logits.length} clases) '
        'no coincide con sus etiquetas (${_labels!.length})',
      );
    }

    // Convertir logits a probabilidades.
    final scores = _softmax(logits);

    // Obtener la clase con mayor puntuación.
    var topIndex = 0;

    for (var index = 1; index < scores.length; index++) {
      if (scores[index] > scores[topIndex]) {
        topIndex = index;
      }
    }

    final topLabelParts = _parseLabel(
      _labels![topIndex],
      topIndex,
    );

    final topScore = scores[topIndex];

    // Clasificación directa de especie.
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

    // Intentar identificar un nivel taxonómico superior.
    final rollup = _rollUpTaxonomy(scores);

    if (rollup != null) {
      return rollup;
    }

    // El detector encontró un animal, pero SpeciesNet
    // no pudo identificarlo con suficiente confianza.
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

  // --------------------------------------------------
  // TAXONOMÍA
  // --------------------------------------------------

  List<String> _parseLabel(String label, int index) {
    final parts = label
        .split(';')
        .map((part) => part.trim())
        .toList();

    if (parts.length < 7) {
      throw FormatException(
        'Etiqueta SpeciesNet inválida para el índice '
        '$index: $label',
      );
    }

    return parts;
  }

  bool _isAnimalLabel(List<String> parts) {
    final commonName = parts[6].toLowerCase();

    return parts
            .sublist(1, 6)
            .any(
              (taxon) =>
                  taxon.isNotEmpty &&
                  taxon.toLowerCase() != 'unknown',
            ) &&
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

  /// Acumula las probabilidades de las especies
  /// que pertenecen a un mismo grupo taxonómico.
  Map<String, dynamic>? _rollUpTaxonomy(
    List<double> scores,
  ) {
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

        final taxon = rankIndex == 0
            ? 'Animalia'
            : parts[rankIndex];

        if (taxon.isEmpty ||
            taxon.toLowerCase() == 'unknown') {
          continue;
        }

        accumulatedScores.update(
          taxon,
          (score) => score + scores[index],
          ifAbsent: () => scores[index],
        );

        representatives.putIfAbsent(
          taxon,
          () => parts,
        );
      }

      if (accumulatedScores.isEmpty) continue;

      final bestTaxon = accumulatedScores.entries.reduce(
        (best, candidate) =>
            candidate.value > best.value
                ? candidate
                : best,
      );

      if (bestTaxon.value <= _rollupConfidenceThreshold) {
        continue;
      }

      final predictionParts = List<String>.from(
        representatives[bestTaxon.key]!,
      );

      predictionParts[rankIndex] = bestTaxon.key;

      // Vaciar los niveles taxonómicos inferiores.
      for (
        var lowerRank = rankIndex + 1;
        lowerRank <= 5;
        lowerRank++
      ) {
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

  // --------------------------------------------------
  // PREPROCESAMIENTO
  // --------------------------------------------------

  /// Convierte la imagen RGB a Float32 NHWC [0, 1].
  Float32List _imageToFloat32(img.Image image) {
    final buffer = Float32List(
      _inputSize * _inputSize * 3,
    );

    var index = 0;

    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);

        buffer[index++] = pixel.r / 255.0;
        buffer[index++] = pixel.g / 255.0;
        buffer[index++] = pixel.b / 255.0;
      }
    }

    return buffer;
  }

  // --------------------------------------------------
  // SOFTMAX
  // --------------------------------------------------

  List<double> _softmax(List<dynamic> logits) {
    var maxVal = -double.infinity;

    for (final value in logits) {
      final number = (value as num).toDouble();

      if (!number.isFinite) {
        throw const FormatException(
          'SpeciesNet produjo logits no finitos',
        );
      }

      if (number > maxVal) {
        maxVal = number;
      }
    }

    final expValues = List<double>.filled(
      logits.length,
      0,
    );

    var sum = 0.0;

    for (var index = 0; index < logits.length; index++) {
      final exponent = math.exp(
        (logits[index] as num).toDouble() - maxVal,
      );

      expValues[index] = exponent;
      sum += exponent;
    }

    if (sum == 0 || !sum.isFinite) {
      throw const FormatException(
        'No se pudo calcular Softmax de SpeciesNet',
      );
    }

    return [
      for (final value in expValues)
        value / sum,
    ];
  }
}
