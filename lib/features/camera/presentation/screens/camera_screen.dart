import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;

import '/features/camera/presentation/widgets/camera_widget.dart';
import '/features/auth/data/services/auth_service.dart';
import '/features/camera/data/services/detection_service.dart';
import '/features/camera/data/services/local_classifier_service.dart';
import '/features/camera/data/services/mega_detector_service.dart';
import '/features/camera/data/services/animal_identification_service.dart';
import '/features/gallery/data/services/species_service.dart';
import '/core/theme/colors.dart';
import '/features/camera/presentation/screens/result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final DetectionService _detectionService = DetectionService();
  final AuthService _authService = AuthService();
  final SpeciesService _speciesService = SpeciesService();
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

  void _onCameraReady() {
    debugPrint('CameraScreen: cámara lista; iniciando MegaDetector');
    unawaited(_initializeDetector());
  }

  Future<void> _initializeDetector() async {
    if (_animalIdentificationService.isDetectorLoaded) return;
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
      debugPrint('CameraScreen: MegaDetector listo');
      if (mounted) {
        setState(() => _isDetectorReady = true);
      }
    } catch (error) {
      debugPrint('CameraScreen: error inicializando MegaDetector: $error');
      if (mounted) setState(() => _detectorError = error.toString());
    } finally {
      _isDetectorInitializing = false;
    }
  }

  @override
  void dispose() {
    unawaited(_disposeAI());
    super.dispose();
  }

  Future<void> _disposeAI() async {
    await _detectorInitialization;
    await _animalIdentificationService.dispose();
  }

  Future<void> _onImageCaptured(File imageFile) async {
    if (_isProcessing) return;
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

    try {
      final bytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        throw Exception('No se pudo decodificar la imagen capturada');
      }
      final image = img.bakeOrientation(decodedImage);
      final result = await _animalIdentificationService.identifyAnimal(image);
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
