import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;

import '/core/service_locator.dart';
import '/features/camera/presentation/widgets/camera_widget.dart';
import '/features/camera/data/services/local_classifier_service.dart';
import '/features/camera/data/services/mega_detector_service.dart';
import '/features/camera/data/services/animal_identification_service.dart';
import '/core/theme/colors.dart';
import '/features/camera/presentation/screens/result_screen.dart';

/// Pantalla principal de la cámara con detección e identificación de animales.
///
/// Gestiona el ciclo de vida de la cámara, la inicialización de los modelos de IA,
/// el procesamiento de imágenes capturadas y la navegación a la pantalla de resultados.
///
/// La pantalla maneja estados de inicialización, procesamiento y errores de manera
/// segura, evitando operaciones concurrentes y fugas de recursos.
class CameraScreen extends StatefulWidget {
  final bool isActive;

  const CameraScreen({super.key, required this.isActive});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _detectionService = ServiceLocator.detection;
  final _authService = ServiceLocator.auth;
  final _speciesService = ServiceLocator.species;
  final megaDetectorService = MegaDetectorService();
  final localClassifierService = LocalClassifierService();
  late final AnimalIdentificationService _animalIdentificationService =
      AnimalIdentificationService(
        megaDetectorService: megaDetectorService,
        localClassifierService: localClassifierService,
      );

  bool _isProcessing = false;
  bool _isDetectorReady = false;
  bool _isDetectorInitializing = false;
  String? _detectorError;
  Future<void>? _detectorInitialization;
  Future<void>? _aiDisposal;
  Completer<void>? _inferenceCompletion;

  // Bloqueo para evitar doble liberación de modelos de IA.
  bool _isReleasingAI = false;

  // Bloqueo para evitar procesamiento concurrente de la IA
  bool _isProcessingWithAI = false;

  @override
  void didUpdateWidget(covariant CameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _isReleasingAI = true;
      unawaited(_releaseAIWhenIdle());
    }
  }

  void _onCameraReady() {
    if (!mounted || !widget.isActive) return;
    debugPrint('CameraScreen: cámara lista; iniciando MegaDetector');
    unawaited(_initializeDetector());
  }

  Future<void> _initializeDetector() async {
    final disposal = _aiDisposal;
    if (disposal != null) await disposal;
    if (!mounted || !widget.isActive) return;
    if (_animalIdentificationService.isDetectorLoaded) {
      if (!_isDetectorReady) {
        setState(() => _isDetectorReady = true);
      }
      return;
    }
    final initialization = _detectorInitialization;
    if (initialization != null) {
      await initialization;
      return;
    }

    final future = _initializeDetectorInternal();
    _detectorInitialization = future;
    try {
      await future;
    } finally {
      if (identical(_detectorInitialization, future)) {
        _detectorInitialization = null;
      }
    }
  }

  Future<void> _initializeDetectorInternal() async {
    if (!mounted || !widget.isActive) return;
    _isDetectorInitializing = true;
    if (mounted) {
      setState(() {
        _detectorError = null;
        _isDetectorReady = false;
      });
    }

    try {
      debugPrint('CameraScreen: inicializando MegaDetector');
      await _animalIdentificationService.initializeDetector();
      if (!mounted || !widget.isActive) return;
      debugPrint('CameraScreen: MegaDetector listo');
      setState(() => _isDetectorReady = true);
    } catch (error) {
      debugPrint('CameraScreen: error inicializando MegaDetector: $error');
      if (mounted) setState(() => _detectorError = error.toString());
    } finally {
      _isDetectorInitializing = false;
    }
  }

  @override
  void dispose() {
    // ✅ Solo liberar IA una vez
    if (!_isReleasingAI) {
      _isReleasingAI = true;
      unawaited(_releaseAIWhenIdle());
    }
    super.dispose();
  }

  Future<void> _releaseAIWhenIdle() async {
    final existingDisposal = _aiDisposal;
    if (existingDisposal != null) {
      await existingDisposal;
      return;
    }

    final disposal = _releaseAIInternal().catchError((Object error) {
      debugPrint('CameraScreen: error liberando modelos IA: $error');
    });
    _aiDisposal = disposal;
    try {
      await disposal;
    } finally {
      if (identical(_aiDisposal, disposal)) _aiDisposal = null;
    }
  }

  Future<void> _releaseAIInternal() async {
    final inference = _inferenceCompletion;
    if (inference != null) await inference.future;
    await _detectorInitialization;

    if (mounted && widget.isActive) return;

    await _animalIdentificationService.dispose();
    if (mounted && !widget.isActive) {
      setState(() {
        _isDetectorReady = false;
        _detectorError = null;
      });
      debugPrint('CameraScreen: modelos IA liberados al ocultar la pestaña');
    }
  }

  Future<void> _onImageCaptured(File imageFile) async {
    // ✅ Bloqueo para evitar re-entrada durante procesamiento
    if (_isProcessing || _isProcessingWithAI) return;
    if (!_isDetectorReady) {
      _showError(
        _detectorError ??
            (_isDetectorInitializing
                ? 'MegaDetector todavía se está cargando.'
                : 'MegaDetector no está disponible.'),
      );
      return;
    }

    setState(() => _isProcessing = true);
    _isProcessingWithAI = true;

    try {
      final bytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        throw Exception('No se pudo decodificar la imagen capturada');
      }
      final image = img.bakeOrientation(decodedImage);
      final inference = Completer<void>();
      _inferenceCompletion = inference;
      final Map<String, dynamic> result;
      try {
        result = await _animalIdentificationService.identifyAnimal(image);
      } finally {
        inference.complete();
        if (identical(_inferenceCompletion, inference)) {
          _inferenceCompletion = null;
        }
      }
      debugPrint(
        'CameraScreen: resultado IA '
        'status=${result['status']}, label=${result['label']}, '
        'prediction=${result['prediction']}',
      );

      if (!mounted) return;

      if (result['status'] == 'ok') {
        final prediction = result['prediction']?.toString() ?? '';
        final predictionSource = result['prediction_source']?.toString() ?? '';
        final species = await _speciesService.resolveDetectedSpecies(
          prediction: prediction,
          predictionSource: predictionSource,
        );

        if (species == null) {
          debugPrint(
            'Detección no válida: no existe coincidencia exacta para '
            'name_scientific en species.',
          );
        } else {
          try {
            Position? position;
            try {
              position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                ),
              ).timeout(const Duration(seconds: 5));
            } catch (error) {
              debugPrint('No se pudo obtener ubicación: $error');
            }

            final user = _authService.currentUser;
            if (user != null) {
              await _detectionService.saveDetection(
                imageFile: imageFile,
                speciesId: species.id,
                confidence: (result['confidence'] as num?)?.toDouble(),
                latitude: position?.latitude,
                longitude: position?.longitude,
              );
            }
          } catch (error) {
            debugPrint('Error guardando detección: $error');
          }
        }
      }

      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultScreen(result: result, imagePath: imageFile.path),
        ),
      );
    } catch (error) {
      debugPrint('Error en análisis local: $error');
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
      _isProcessingWithAI = false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error: $message')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraWidget(
              isActive: widget.isActive,
              onImageCaptured: _onImageCaptured,
              onCameraReady: _onCameraReady,
            ),
          ),
          if (_isProcessing) _buildProcessingDialog(),
        ],
      ),
    );
  }

  Widget _buildProcessingDialog() {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: context.palette.cameraSurface,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: context.palette.cameraForeground,
              ),
              SizedBox(height: 16),
              Text(
                'Detectando y clasificando...',
                style: TextStyle(
                  color: context.palette.cameraForeground,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
