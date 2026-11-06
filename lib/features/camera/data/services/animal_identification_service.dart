import 'package:image/image.dart' as img;

import 'mega_detector_service.dart';
import 'local_classifier_service.dart';

class AnimalIdentificationService {
  final MegaDetectorService _megaDetectorService;
  final LocalClassifierService _localClassifierService;

  AnimalIdentificationService({
    required MegaDetectorService megaDetectorService,
    required LocalClassifierService localClassifierService,
  // ignore: prefer_initializing_formals
  })  : _megaDetectorService = megaDetectorService,
        // ignore: prefer_initializing_formals
        _localClassifierService = localClassifierService;

  bool get isModelLoaded =>
      _megaDetectorService.isModelLoaded &&
      _localClassifierService.isModelLoaded;

  /// Inicializa ambos modelos de IA.
  Future<void> initialize() async {
    await _megaDetectorService.initialize();
    await _localClassifierService.initialize();
  }

  /// Libera los recursos de ambos modelos.
  Future<void> dispose() async {
    await _megaDetectorService.dispose();
    await _localClassifierService.dispose();
  }

  /// Ejecuta el proceso completo de identificación:
  /// 1. Detecta el animal con MegaDetector.
  /// 2. Recorta la región detectada.
  /// 3. Clasifica el recorte con SpeciesNet.
  /// 4. Devuelve un resultado unificado.
  Future<Map<String, dynamic>> identifyAnimal(
    img.Image image,
  ) async {
    if (!isModelLoaded) {
      throw Exception(
        'Los modelos de identificación no están inicializados',
      );
    }

    if (image.width <= 0 || image.height <= 0) {
      throw ArgumentError('La imagen tiene dimensiones inválidas');
    }

    // --------------------------------------------------
    // 1. DETECCIÓN DEL ANIMAL
    // --------------------------------------------------

    final detection =
        await _megaDetectorService.detectAnimal(image);

    if (detection == null) {
      return {
        'status': 'not_detected',
        'label': 'No se detectaron animales',
        'confidence': 0.0,
        'prediction': '',
        'prediction_source': 'none',
        'prediction_score': 0.0,
        'detection_confidence': 0.0,
        'bounding_box': null,
        'category': '',
        'api_response': {'detections': <dynamic>[]},
      };
    }

    // --------------------------------------------------
    // 2. VALIDACIÓN Y RECORTE DEL ANIMAL
    // --------------------------------------------------

    final left = detection.left
        .round()
        .clamp(0, image.width - 1)
        .toInt();

    final top = detection.top
        .round()
        .clamp(0, image.height - 1)
        .toInt();

    final right = detection.right
        .round()
        .clamp(left + 1, image.width)
        .toInt();

    final bottom = detection.bottom
        .round()
        .clamp(top + 1, image.height)
        .toInt();

    final cropWidth = right - left;
    final cropHeight = bottom - top;

    if (cropWidth <= 0 || cropHeight <= 0) {
      throw Exception(
        'MegaDetector produjo un recorte inválido',
      );
    }

    final animalCrop = img.copyCrop(
      image,
      x: left,
      y: top,
      width: cropWidth,
      height: cropHeight,
    );

    // --------------------------------------------------
    // 3. CLASIFICACIÓN CON SPECIESNET
    // --------------------------------------------------

    final classification =
        await _localClassifierService.analyzeImage(
      animalCrop,
      detectionConfidence: detection.confidence,
    );

    // --------------------------------------------------
    // 4. RESULTADO UNIFICADO
    // --------------------------------------------------

    final normalizedBoundingBox = {
      'x': left / image.width,
      'y': top / image.height,
      'width': cropWidth / image.width,
      'height': cropHeight / image.height,
    };

    return {
      ...classification,

      // Confianza independiente del detector.
      'detection_confidence': detection.confidence,

      // Coordenadas del animal en la imagen original.
      'bounding_box': {
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
        'width': cropWidth,
        'height': cropHeight,
      },
      'category': 'animal',
      'api_response': {
        'detections': [
          {
            'category': 'animal',
            'confidence': detection.confidence,
            'bbox': normalizedBoundingBox,
          },
        ],
        'prediction': classification['prediction'],
      },
    };
  }
}
