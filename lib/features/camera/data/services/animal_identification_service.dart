import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

import 'mega_detector_service.dart';
import 'local_classifier_service.dart';

class AnimalIdentificationService {
  final MegaDetectorService _megaDetectorService;
  final LocalClassifierService _localClassifierService;

  AnimalIdentificationService({
    required MegaDetectorService megaDetectorService,
    required LocalClassifierService localClassifierService,
    // ignore: prefer_initializing_formals
  }) : _megaDetectorService = megaDetectorService,
       // ignore: prefer_initializing_formals
       _localClassifierService = localClassifierService;

  bool get isDetectorLoaded => _megaDetectorService.isModelLoaded;

  /// Inicializa MegaDetector, que se usa en cada análisis.
  Future<void> initializeDetector() async {
    await _megaDetectorService.initialize();
  }

  Future<void> _initializeClassifier() async {
    if (_localClassifierService.isModelLoaded) return;

    debugPrint('AnimalIdentification: inicializando clasificador SpeciesNet');
    try {
      await _localClassifierService.initialize();
      debugPrint('AnimalIdentification: clasificador SpeciesNet listo');
    } catch (error) {
      debugPrint(
        'AnimalIdentification: error inicializando SpeciesNet: $error',
      );
      rethrow;
    }
  }

  /// Libera los recursos de ambos modelos.
  Future<void> dispose() async {
    try {
      await _megaDetectorService.dispose();
    } finally {
      await _localClassifierService.dispose();
    }
  }

  /// Ejecuta el proceso completo de identificación:
  /// 1. Detecta el animal con MegaDetector.
  /// 2. Recorta la región detectada.
  /// 3. Clasifica el recorte con SpeciesNet.
  /// 4. Devuelve un resultado unificado.
  Future<Map<String, dynamic>> identifyAnimal(img.Image image) async {
    if (!isDetectorLoaded) {
      throw Exception('MegaDetector no está inicializado');
    }

    if (image.width <= 0 || image.height <= 0) {
      throw ArgumentError('La imagen tiene dimensiones inválidas');
    }

    // --------------------------------------------------
    // 1. DETECCIÓN DEL ANIMAL
    // --------------------------------------------------

    final MegaDetection? detection;
    try {
      detection = await _megaDetectorService.detectAnimal(image);
    } catch (error) {
      debugPrint('AnimalIdentification: error ejecutando MegaDetector: $error');
      rethrow;
    }

    if (detection == null) {
      debugPrint('AnimalIdentification: MegaDetector no encontró un animal');
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

    final left = detection.left.round().clamp(0, image.width - 1).toInt();

    final top = detection.top.round().clamp(0, image.height - 1).toInt();

    final right = detection.right.round().clamp(left + 1, image.width).toInt();

    final bottom = detection.bottom
        .round()
        .clamp(top + 1, image.height)
        .toInt();

    final cropWidth = right - left;
    final cropHeight = bottom - top;

    if (cropWidth <= 0 || cropHeight <= 0) {
      throw Exception('MegaDetector produjo un recorte inválido');
    }

    final animalCrop = img.copyCrop(
      image,
      x: left,
      y: top,
      width: cropWidth,
      height: cropHeight,
    );

    await _initializeClassifier();

    // --------------------------------------------------
    // 3. CLASIFICACIÓN CON SPECIESNET
    // --------------------------------------------------

    final Map<String, dynamic> classification;
    try {
      classification = await _localClassifierService.analyzeImage(
        animalCrop,
        detectionConfidence: detection.confidence,
      );
    } catch (error) {
      debugPrint('AnimalIdentification: error ejecutando SpeciesNet: $error');
      rethrow;
    }
    debugPrint(
      'AnimalIdentification: detección=${detection.confidence}, '
      'resultado=${classification['label']}, '
      'estado=${classification['status']}',
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
