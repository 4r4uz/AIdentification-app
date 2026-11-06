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
  AnimalIdentificationService? _animalIdentificationService;

  bool _isProcessing = false;
  bool _isModelsReady = false;
  bool _isModelsInitializing = false;
  String? _modelError;
  Future<void>? _aiInitialization;

  @override
  void initState() {
    super.initState();
    _aiInitialization = _initializeAI();
  }

  Future<void> _initializeAI() async {
    if (_isModelsInitializing) return;
    _isModelsInitializing = true;
    if (mounted) {
      setState(() {
        _modelError = null;
        _isModelsReady = false;
      });
    }

    try {
      final animalIdentificationService = AnimalIdentificationService(
        megaDetectorService: megaDetectorService,
        localClassifierService: localClassifierService,
      );
      _animalIdentificationService = animalIdentificationService;
      await animalIdentificationService.initialize();
      if (mounted) {
        setState(
          () => _isModelsReady = animalIdentificationService.isModelLoaded,
        );
      }
    } catch (error) {
      debugPrint('Error inicializando los modelos locales: $error');
      if (mounted) setState(() => _modelError = error.toString());
    } finally {
      _isModelsInitializing = false;
    }
  }

  @override
  void dispose() {
    unawaited(_disposeAI());
    super.dispose();
  }

  Future<void> _disposeAI() async {
    await _aiInitialization;
    await _animalIdentificationService?.dispose();
  }

  Future<void> _onImageCaptured(File imageFile) async {
    if (_isProcessing) return;
    if (!_isModelsReady) {
      _showError(
        _modelError ?? 'Los modelos locales todavía se están cargando.',
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
      final animalIdentificationService = _animalIdentificationService;
      if (animalIdentificationService == null) {
        throw Exception('El servicio de identificación no está disponible');
      }

      final result = await animalIdentificationService.identifyAnimal(image);

      if (!mounted) return;

      if (result['status'] == 'ok') {
        final prediction = result['prediction']?.toString() ?? '';
        final predictionSource = result['prediction_source']?.toString() ?? '';
        await _speciesService.registerDetectedSpecies(
          prediction: prediction,
          predictionSource: predictionSource,
        );

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
            final species = await _speciesService.getSpeciesByName(
              result['label']?.toString() ?? '',
            );
            await _detectionService.saveDetection(
              imageFile: imageFile,
              speciesId: species?.id,
              confidence: (result['confidence'] as num?)?.toDouble(),
              latitude: position?.latitude,
              longitude: position?.longitude,
            );
          }
        } catch (error) {
          debugPrint('Error guardando detección: $error');
        }
      }

      if (!mounted) return;
      Navigator.push(
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error: $message')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraWidget(onImageCaptured: _onImageCaptured),
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
