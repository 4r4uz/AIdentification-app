import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Widget que gestiona la cámara del dispositivo y la captura de imágenes.

/// Cuando isActive es true, inicializa la cámara y espera a que esté lista.
/// Cuando isActive cambia a false, libera los recursos de la cámara.
class CameraWidget extends StatefulWidget {
  final bool isActive;
  final Future<void> Function(File image) onImageCaptured;
  final VoidCallback onCameraReady;

  const CameraWidget({
    super.key,
    required this.isActive,
    required this.onImageCaptured,
    required this.onCameraReady,
  });

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget>
    with WidgetsBindingObserver {
  CameraController? _controller;

  bool _isReady = false;
  bool _hasError = false;
  bool _isTakingPicture = false;
  bool _isProcessingImage = false;
  bool _isInitializing = false;
  bool _isAppActive = true;
  bool _isDisposed = false;
  bool _restartWhenInitializationFinishes = false;
  bool _isTorchEnabled = false;
  bool _isZoomIndicatorVisible = false;

  String _errorMessage = '';
  Timer? _zoomIndicatorTimer;

  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _startDragY = 0;

  Offset? _focusPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) unawaited(_initCamera());
  }

  @override
  void didUpdateWidget(covariant CameraWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;

    if (widget.isActive) {
      if (!_isAppActive) return;
      if (_isInitializing) {
        _restartWhenInitializationFinishes = true;
      } else {
        unawaited(_initCamera());
      }
    } else {
      _restartWhenInitializationFinishes = false;
      _cameraGeneration++;
      unawaited(_disposeCamera());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isAppActive = false;
    _cameraGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _zoomIndicatorTimer?.cancel();
    final controller = _controller;
    _controller = null;
    _isReady = false;
    _isTorchEnabled = false;
    unawaited(_disposeController(controller));
    super.dispose();
  }

  int _cameraGeneration = 0;

  Future<void> _disposeCamera() async {
    final controller = _controller;
    _controller = null;
    _isReady = false;
    _isTorchEnabled = false;

    if (mounted && !_isDisposed) {
      setState(() {});
    }

    await _disposeController(controller);
  }

  Future<void> _disposeController(CameraController? controller) async {
    try {
      if (controller != null) await controller.dispose();
    } catch (error) {
      debugPrint('CameraWidget: error liberando la cámara: $error');
    }
  }

  /// Inicializa la cámara del dispositivo.
  ///
  /// Flujo:
  /// 1. Verifica que no haya una inicialización en curso.
  /// 2. Solicita permiso de cámara al usuario.
  /// 3. Obtiene las cámaras disponibles y selecciona la trasera.
  /// 4. Crea el CameraController con la resolución alta.
  /// 5. Espera a que la cámara se establezca.
  /// 6. Configura el zoom mínimo y máximo.
  ///
  /// Si ya existía un controlador anterior, se descarta antes de crear el nuevo.
  Future<void> _initCamera() async {
    if (!widget.isActive || !_isAppActive || _isProcessingImage) return;
    if (_isInitializing) {
      _restartWhenInitializationFinishes = true;
      return;
    }

    _isInitializing = true;
    final generation = ++_cameraGeneration;

    try {
      await _disposeCamera();
      if (!_isCurrentGeneration(generation)) return;

      final status = await Permission.camera.request();
      if (!_isCurrentGeneration(generation)) return;
      if (!status.isGranted) {
        debugPrint('CameraWidget: permiso de cámara denegado');
        setState(() {
          _hasError = true;
          _errorMessage = 'Permiso de cámara requerido';
        });
        return;
      }

      final cameras = await availableCameras();
      if (!_isCurrentGeneration(generation)) return;
      if (cameras.isEmpty) {
        throw Exception('No se encontró ninguna cámara disponible');
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _controller = controller;

      await controller.initialize();

      if (!_isCurrentGeneration(generation)) {
        if (_controller == controller) {
          _controller = null;
          _isReady = false;
        }
        await _disposeController(controller);
        return;
      }

      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _currentZoom = _minZoom;

      if (!_isCurrentGeneration(generation) || _controller != controller) {
        if (_controller == controller) {
          _controller = null;
          _isReady = false;
        }
        await _disposeController(controller);
        return;
      }

      setState(() {
        _isReady = true;
        _hasError = false;
      });
      debugPrint('CameraWidget: cámara inicializada correctamente');
      widget.onCameraReady();
    } catch (e) {
      debugPrint('CameraWidget: error inicializando la cámara: $e');
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isReady = false;
      });
    } finally {
      _isInitializing = false;
      if (mounted &&
          widget.isActive &&
          _isAppActive &&
          !_isDisposed &&
          _restartWhenInitializationFinishes) {
        _restartWhenInitializationFinishes = false;
        unawaited(_initCamera());
      }
    }
  }

  bool _isCurrentGeneration(int generation) =>
      mounted &&
      !_isDisposed &&
      widget.isActive &&
      _isAppActive &&
      generation == _cameraGeneration;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _isAppActive = false;
      _cameraGeneration++;
      await _disposeCamera();
    }

    if (state == AppLifecycleState.resumed) {
      _isAppActive = true;
      if (!widget.isActive || _isProcessingImage) return;
      if (_isInitializing) {
        _restartWhenInitializationFinishes = true;
        return;
      }
      if (_controller == null || !_isReady) {
        await _initCamera();
      }
    }
  }

  /// Captura una imagen de la cámara y la pasa al callback sin modificarla.
  ///
  /// El método:
  /// 1. Verifica que no este tomando una foto ya.
  /// 2. Crea una foto con el controlador de cámara.
  /// 3. Llama al callback onImageCaptured con la imagen original.
  /// 5. Libera el controlador de cámara para liberar recursos.
  /// 6. Si se configuro reinicio automatico, inicializa la cámara nuevamente.
  Future<void> takePicture() async {
    if (_isTakingPicture) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || !mounted) {
      return;
    }

    setState(() => _isTakingPicture = true);
    var shouldRestartCamera = false;

    try {
      final image = await controller.takePicture();
      debugPrint(
        '[Camera] Foto tomada: ${image.path}, '
        'archivo=${await image.length()} bytes',
      );
      debugPrint('[Camera] Imagen original enviada a análisis: ${image.path}');
      if (mounted && !_isDisposed && _controller == controller) {
        _isProcessingImage = true;
        shouldRestartCamera = true;
        await _disposeCamera();
        if (mounted && !_isDisposed) {
          await widget.onImageCaptured(File(image.path));
        }
      }
    } catch (error) {
      debugPrint('CameraWidget: error capturando la foto: $error');
    } finally {
      if (mounted) {
        setState(() => _isTakingPicture = false);
      }
      _isProcessingImage = false;
      if (shouldRestartCamera &&
          mounted &&
          !_isDisposed &&
          widget.isActive &&
          _isAppActive) {
        await _initCamera();
      }
    }
  }

  Future<void> _focusAtPoint(TapDownDetails details) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || !mounted) {
      return;
    }

    final size = MediaQuery.of(context).size;

    final dx = details.localPosition.dx / size.width;
    final dy = details.localPosition.dy / size.height;

    setState(() {
      _focusPoint = details.localPosition;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _focusPoint = null;
        });
      }
    });

    try {
      await controller.setFocusPoint(Offset(dx, dy));
      await controller.setExposurePoint(Offset(dx, dy));
    } catch (_) {}
  }

  Future<void> _handleZoom(DragUpdateDetails details) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    double sensitivity = 0.01;
    double delta = (_startDragY - details.localPosition.dy) * sensitivity;

    double newZoom = (_currentZoom + delta).clamp(_minZoom, _maxZoom);

    try {
      await _controller!.setZoomLevel(newZoom);
      if (!mounted) return;
      setState(() {
        _currentZoom = newZoom;
        _isZoomIndicatorVisible = true;
      });
      _startDragY = details.localPosition.dy;
      _scheduleZoomIndicatorHide();
    } catch (error) {
      debugPrint('Error ajustando el zoom de la cámara: $error');
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final enableTorch = !_isTorchEnabled;
    try {
      await controller.setFlashMode(
        enableTorch ? FlashMode.torch : FlashMode.off,
      );
      if (mounted) setState(() => _isTorchEnabled = enableTorch);
    } catch (error) {
      debugPrint('Error cambiando la linterna: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cambiar la linterna: $error')),
        );
      }
    }
  }

  void _scheduleZoomIndicatorHide() {
    _zoomIndicatorTimer?.cancel();
    _zoomIndicatorTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _isZoomIndicatorVisible = false);
    });
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    final previewSize = _controller!.value.previewSize!;
    final previewRatio = previewSize.height / previewSize.width;

    return GestureDetector(
      onTapDown: _focusAtPoint,
      onVerticalDragStart: (details) {
        _startDragY = details.localPosition.dy;
      },
      onVerticalDragUpdate: _handleZoom,
      onVerticalDragEnd: (_) => _scheduleZoomIndicatorHide(),
      onVerticalDragCancel: _scheduleZoomIndicatorHide,
      child: Stack(
        children: [
          Center(
            child: Transform.scale(
              scale: previewRatio / deviceRatio,
              child: AspectRatio(
                aspectRatio: previewRatio,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          if (_focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 20,
              top: _focusPoint!.dy - 20,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildError();
    if (!_isReady || _controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.expand();
    }

    return Stack(
      children: [
        _buildCameraPreview(),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: takePicture,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 4),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(34)),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 16,
          right: 20,
          child: Tooltip(
            message: _isTorchEnabled ? 'Apagar linterna' : 'Encender linterna',
            child: Material(
              color: Colors.black.withValues(alpha: 0.4),
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: _toggleTorch,
                color: Colors.white,
                icon: Icon(
                  _isTorchEnabled
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                ),
              ),
            ),
          ),
        ),
        if (_isZoomIndicatorVisible)
          Positioned(
            right: 20,
            top: MediaQuery.sizeOf(context).height * 0.42,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _isZoomIndicatorVisible ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    '${_currentZoom.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _initCamera, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
