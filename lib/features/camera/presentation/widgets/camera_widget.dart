import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CameraWidget extends StatefulWidget {
  final Function(File image) onImageCaptured;

  const CameraWidget({super.key, required this.onImageCaptured});

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget>
    with WidgetsBindingObserver {
  CameraController? _controller;

  bool _isReady = false;
  bool _hasError = false;
  bool _isTakingPicture = false;
  bool _isInitializing = false;
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
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zoomIndicatorTimer?.cancel();
    _disposeCamera();
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    try {
      await _controller?.dispose();
    } catch (_) {}

    _controller = null;

    if (mounted) {
      setState(() {
        _isReady = false;
        _isTorchEnabled = false;
      });
    }
  }

  Future<void> _initCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      await _disposeCamera();

      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Permiso de cámara requerido';
        });
        return;
      }

      final cameras = await availableCameras();
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

      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _currentZoom = _minZoom;

      if (!mounted) return;

      setState(() {
        _isReady = true;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    } finally {
      _isInitializing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      await _disposeCamera();
    }

    if (state == AppLifecycleState.resumed) {
      if (_controller == null || !_isReady) {
        await _initCamera();
      }
    }
  }

  Future<void> takePicture() async {
    if (_isTakingPicture) return;
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isTakingPicture = true);

    try {
      final XFile image = await _controller!.takePicture();
      await Future.delayed(const Duration(milliseconds: 100));

      final compressedFile = await _compressImage(image);
      debugPrint('Captured compressed path: ${compressedFile.path}');
      widget.onImageCaptured(File(compressedFile.path));
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isTakingPicture = false);
      }
    }
  }

  Future<XFile> _compressImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return image; // fallback a imagen original
    }

    final oriented = img.bakeOrientation(decoded);
    final compressed = img.copyResize(oriented, width: 1280);

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final outFile = File(path);
    await outFile.writeAsBytes(img.encodeJpg(compressed, quality: 85));

    return XFile(path);
  }

  Future<void> _focusAtPoint(TapDownDetails details) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

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
      await _controller!.setFocusPoint(Offset(dx, dy));
      await _controller!.setExposurePoint(Offset(dx, dy));
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
          SnackBar(
            content: Text('No se pudo cambiar la linterna: $error'),
          ),
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
      return _buildLoading();
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

  Widget _buildLoading() => const Center(child: CircularProgressIndicator());

  Widget _buildError() => Center(
    child: Text(_errorMessage, style: const TextStyle(color: Colors.white)),
  );
}
