
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

class MegaDetection {
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double confidence;

  const MegaDetection({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.confidence,
  });
}

class MegaDetectorService {
  static const String _modelAsset =
      'assets/models/MDV6-yolov10-e-1280.onnx';

  static const int _inputSize = 1280;

  static const int _classCount = 3;
  static const int _rawFeatureCount = 4 + _classCount;
  static const int _endToEndFeatureCount = 6;

  static const int _animalClassIndex = 0;

  static const double _animalThreshold = 0.2;

  final OnnxRuntime _ort = OnnxRuntime();

  OrtSession? _session;
  List<int>? _outputShape;

  bool _isDisposed = false;

  Future<void>? _initializationFuture;

  bool get isModelLoaded => _session != null;

  /// Inicializa MegaDetector y obtiene las dimensiones de salida del modelo ONNX.
  ///
  /// Verifica que la salida coincida con el formato esperado.
  /// Si no coincide, lanza una excepcion con la forma recibida.
  Future<void> initialize() async {
    if (_session != null) return;

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
    OrtSession? session;

    try {
      session = await _ort.createSessionFromAsset(
        _modelAsset,
        options: OrtSessionOptions(
          intraOpNumThreads: 4,
          providers: [OrtProvider.CPU],
        ),
      );

      final outputInfo = await session.getOutputInfo();

      if (outputInfo.isEmpty ||
          outputInfo.first['shape'] is! List) {
        throw Exception(
          'No se pudo leer la forma de salida de MegaDetector',
        );
      }

      final shape = (outputInfo.first['shape'] as List)
          .map((dimension) => (dimension as num).toInt())
          .toList();

      // El modelo V6 YOLOv10-e exportado debe producir
      // una salida equivalente a [1, 7, 33600].
      final layout = _getFeatureLayout(shape);

      if (layout.$1 != _rawFeatureCount) {
        throw Exception(
          'Salida incompatible con MegaDetector V6. '
          'Forma recibida: ${shape.join('x')}. '
          'Se esperaba una salida de 7 características.',
        );
      }

      _session = session;
      _outputShape = shape;
    } catch (e) {
      await session?.close();
      rethrow;
    }
  }

  /// Libera los recursos de ONNX Runtime.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _session?.close();

    _session = null;
    _outputShape = null;
  }

  /// Detecta animales y devuelve la detección de mayor confianza.
  Future<MegaDetection?> detectAnimal(img.Image image) async {
    final session = _session;
    final outputShape = _outputShape;

    if (session == null || outputShape == null) {
      throw Exception('Modelo MegaDetector no inicializado');
    }

    if (image.width <= 0 || image.height <= 0) {
      throw ArgumentError('La imagen tiene dimensiones inválidas');
    }

    // --------------------------------------------------
    // LETTERBOX
    // --------------------------------------------------

    final scale = math.min(
      _inputSize / image.width,
      _inputSize / image.height,
    );

    final resizedWidth = (image.width * scale).round();
    final resizedHeight = (image.height * scale).round();

    final scaleX = resizedWidth / image.width;
    final scaleY = resizedHeight / image.height;

    final padLeft = (_inputSize - resizedWidth) ~/ 2;
    final padTop = (_inputSize - resizedHeight) ~/ 2;

    final resized = img.copyResize(
      image,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.linear,
    );

    final letterboxed = img.Image(
      width: _inputSize,
      height: _inputSize,
      numChannels: 3,
    );

    img.fill(
      letterboxed,
      color: img.ColorRgb8(114, 114, 114),
    );

    img.compositeImage(
      letterboxed,
      resized,
      dstX: padLeft,
      dstY: padTop,
    );

    // --------------------------------------------------
    // PREPROCESAMIENTO NCHW
    // --------------------------------------------------

    final input = _imageToNchw(letterboxed);

    final inputTensor = await OrtValue.fromList(
      input,
      [
        1,
        3,
        _inputSize,
        _inputSize,
      ],
    );

    late final List<dynamic> output;

    try {
      final outputs = await session.run({
        session.inputNames.first: inputTensor,
      });

      try {
        final outputName = session.outputNames.first;
        final outputValue = outputs[outputName];

        if (outputValue == null) {
          throw Exception(
            'MegaDetector no produjo la salida $outputName',
          );
        }

        output = await outputValue.asFlattenedList();
      } finally {
        for (final value in outputs.values) {
          await value.dispose();
        }
      }
    } finally {
      await inputTensor.dispose();
    }

    // --------------------------------------------------
    // DECODIFICACIÓN DE SALIDA
    // --------------------------------------------------

    final (featureCount, featureAxis) =
        _getFeatureLayout(outputShape);

    if (featureCount == 0 ||
        featureAxis == -1 ||
        output.length % featureCount != 0) {
      throw Exception(
        'Salida de MegaDetector incompatible: '
        'forma ${outputShape.join('x')}',
      );
    }

    final featuresFirst =
        featureAxis == outputShape.length - 2;

    final candidateCount = output.length ~/ featureCount;

    var bestConfidence = -double.infinity;
    var animalCandidateCount = 0;

    double? bestLeft;
    double? bestTop;
    double? bestRight;
    double? bestBottom;

    for (var candidate = 0;
        candidate < candidateCount;
        candidate++) {
      late final double confidence;
      late final double left;
      late final double top;
      late final double right;
      late final double bottom;

      if (featureCount == _rawFeatureCount) {
        // Formato raw YOLO:
        // [cx, cy, width, height, animal, person, vehicle]

        confidence = _valueAt(
          output,
          candidate,
          4 + _animalClassIndex,
          candidateCount,
          featuresFirst,
          featureCount,
        );

        final personConfidence = _valueAt(
          output,
          candidate,
          5,
          candidateCount,
          featuresFirst,
          featureCount,
        );

        final vehicleConfidence = _valueAt(
          output,
          candidate,
          6,
          candidateCount,
          featuresFirst,
          featureCount,
        );

        // Solo conservar detecciones clasificadas como animales.
        if (confidence <= personConfidence ||
            confidence <= vehicleConfidence) {
          continue;
        }
        animalCandidateCount++;

        final centerX = _valueAt(
          output,
          candidate,
          0,
          candidateCount,
          featuresFirst,
          featureCount,
        );

        final centerY = _valueAt(
          output,
          candidate,
          1,
          candidateCount,
          featuresFirst,
          featureCount,
        );

        final width = _valueAt(
          output,
          candidate,
          2,
          candidateCount,
          featuresFirst,
          featureCount,
        );

        final height = _valueAt(
          output,
          candidate,
          3,
          candidateCount,
          featuresFirst,
          featureCount,
        );

        // XYWH -> XYXY
        left = centerX - width / 2;
        top = centerY - height / 2;
        right = centerX + width / 2;
        bottom = centerY + height / 2;
      } else {
        // Formato end-to-end:
        // [x1, y1, x2, y2, confidence, classId]

        confidence = _valueAt(
          output,
          candidate,
          4,
          candidateCount,
          featuresFirst,
          featureCount,
        );

        final classId = _valueAt(
          output,
          candidate,
          5,
          candidateCount,
          featuresFirst,
          featureCount,
        );

        if (classId.round() != _animalClassIndex) {
          continue;
        }
        animalCandidateCount++;

        left = _valueAt(
          output,
          candidate,
          0,
          candidateCount,
          featuresFirst,
          featureCount,
        );

        top = _valueAt(
          output,
          candidate,
          1,
          candidateCount,
          featuresFirst,
          featureCount,
        );

        right = _valueAt(
          output,
          candidate,
          2,
          candidateCount,
          featuresFirst,
          featureCount,
        );

        bottom = _valueAt(
          output,
          candidate,
          3,
          candidateCount,
          featuresFirst,
          featureCount,
        );
      }

      if (!confidence.isFinite ||
          ![
            left,
            top,
            right,
            bottom,
          ].every((value) => value.isFinite) ||
          confidence <= bestConfidence) {
        continue;
      }

      bestConfidence = confidence;

      bestLeft = left;
      bestTop = top;
      bestRight = right;
      bestBottom = bottom;
    }

    if (bestLeft == null ||
        bestTop == null ||
        bestRight == null ||
        bestBottom == null) {
      debugPrint(
        'MegaDetector: no detectado; forma=${outputShape.join('x')}, '
        'candidatos=$candidateCount, candidatosAnimal=$animalCandidateCount, '
        'mejorConfianza=$bestConfidence',
      );
      return null;
    }

    if (bestConfidence < _animalThreshold) {
      debugPrint(
        'MegaDetector: detección descartada por confianza '
        '($bestConfidence < $_animalThreshold)',
      );
      return null;
    }

    debugPrint(
      'MegaDetector: detectado; forma=${outputShape.join('x')}, '
      'candidatos=$candidateCount, candidatosAnimal=$animalCandidateCount, '
      'confianza=$bestConfidence',
    );

    // --------------------------------------------------
    // COORDENADAS NORMALIZADAS O EN PIXELES
    // --------------------------------------------------

    var left = bestLeft;
    var top = bestTop;
    var right = bestRight;
    var bottom = bestBottom;

    if ([
      left,
      top,
      right,
      bottom,
    ].every((value) => value.abs() <= 2)) {
      left *= _inputSize;
      right *= _inputSize;
      top *= _inputSize;
      bottom *= _inputSize;
    }

    // --------------------------------------------------
    // INVERSIÓN DEL LETTERBOX
    // --------------------------------------------------

    left = ((left - padLeft) / scaleX)
        .clamp(0.0, image.width.toDouble());

    right = ((right - padLeft) / scaleX)
        .clamp(0.0, image.width.toDouble());

    top = ((top - padTop) / scaleY)
        .clamp(0.0, image.height.toDouble());

    bottom = ((bottom - padTop) / scaleY)
        .clamp(0.0, image.height.toDouble());

    if (right <= left || bottom <= top) {
      return null;
    }

    return MegaDetection(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      confidence: bestConfidence,
    );
  }

  // --------------------------------------------------
  // FORMATO DE SALIDA
  // --------------------------------------------------

  (int, int) _getFeatureLayout(List<int> shape) {
    if (shape.length < 2) {
      return (0, -1);
    }

    final featureAxis = shape.length - 2;

    if (shape[featureAxis] == _rawFeatureCount) {
      return (_rawFeatureCount, featureAxis);
    }

    if (shape.last == _rawFeatureCount) {
      return (_rawFeatureCount, shape.length - 1);
    }

    if (shape.last == _endToEndFeatureCount) {
      return (
        _endToEndFeatureCount,
        shape.length - 1,
      );
    }

    if (shape[featureAxis] == _endToEndFeatureCount) {
      return (
        _endToEndFeatureCount,
        featureAxis,
      );
    }

    return (0, -1);
  }

  // --------------------------------------------------
  // PREPROCESAMIENTO NCHW
  // --------------------------------------------------

  Float32List _imageToNchw(img.Image image) {
    final planeSize = _inputSize * _inputSize;

    final buffer = Float32List(planeSize * 3);

    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);

        final index = y * _inputSize + x;

        buffer[index] = pixel.r / 255.0;
        buffer[planeSize + index] = pixel.g / 255.0;
        buffer[2 * planeSize + index] = pixel.b / 255.0;
      }
    }

    return buffer;
  }

  // --------------------------------------------------
  // ACCESO A LOS VALORES DE SALIDA
  // --------------------------------------------------

  double _valueAt(
    List<dynamic> output,
    int candidate,
    int feature,
    int candidateCount,
    bool featuresFirst,
    int featureCount,
  ) {
    final index = featuresFirst
        ? feature * candidateCount + candidate
        : candidate * featureCount + feature;

    return (output[index] as num).toDouble();
  }
}
