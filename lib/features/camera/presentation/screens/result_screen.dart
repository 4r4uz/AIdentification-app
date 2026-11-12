import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '/features/camera/domain/entities/species_prediction.dart';
import '/core/theme/colors.dart';
import '/core/theme/app_theme.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final String imagePath;

  const ResultScreen({
    super.key,
    required this.result,
    required this.imagePath,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final Future<Size> _imageSize;

  @override
  void initState() {
    super.initState();
    _imageSize = _loadImageSize();
  }

  Future<Size> _loadImageSize() async {
    final decoded = img.decodeImage(await File(widget.imagePath).readAsBytes());
    if (decoded == null) {
      throw Exception('No se pudo cargar la imagen del resultado');
    }
    return Size(decoded.width.toDouble(), decoded.height.toDouble());
  }

  Map<String, double>? get _normalizedBoundingBox {
    final apiResponse = widget.result['api_response'];
    if (apiResponse is! Map) return null;

    final detections = apiResponse['detections'];
    if (detections is! List || detections.isEmpty) return null;

    final detection = detections.first;
    if (detection is! Map) return null;

    final box = detection['bbox'];
    if (box is! Map) return null;

    double? value(String key) {
      final rawValue = box[key];
      return rawValue is num ? rawValue.toDouble() : null;
    }

    final x = value('x');
    final y = value('y');
    final width = value('width');
    final height = value('height');

    if (x == null || y == null || width == null || height == null) {
      return null;
    }

    return {
      'x': x.clamp(0.0, 1.0).toDouble(),
      'y': y.clamp(0.0, 1.0).toDouble(),
      'width': width.clamp(0.0, 1.0).toDouble(),
      'height': height.clamp(0.0, 1.0).toDouble(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Resultado'),
      ),
      body: SingleChildScrollView(
        padding: AppTheme.defaultPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: _buildImage(context)),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: _buildSpeciesSummary(context)),
              ],
            ),
            const SizedBox(height: 24),
            _buildResultCard(context),
            const SizedBox(height: 24),
            _buildDetailsCard(context),
            const SizedBox(height: 24),
            _buildClassificationInfoCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeciesSummary(BuildContext context) {
    final hasDetection =
        widget.result['status'] == 'ok' && widget.result['label'] != null;
    final prediction = SpeciesPrediction.parse(
      widget.result['prediction']?.toString() ?? '',
    );
    final commonName = prediction.commonName.trim();
    final speciesName = prediction.species.trim();
    final scientificName = [
      prediction.genus.trim(),
      speciesName,
    ].where((part) => part.isNotEmpty).join(' ');
    final identifiedName = commonName.isNotEmpty
        ? commonName
        : speciesName.isNotEmpty
        ? speciesName
        : prediction.genus.isNotEmpty
        ? prediction.genus
        : prediction.family.isNotEmpty
        ? prediction.family
        : widget.result['label']?.toString() ?? 'No identificado';
    final confidence =
        ((widget.result['confidence'] as num?)?.toDouble() ?? 0.0)
            .clamp(0.0, 1.0)
            .toDouble();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasDetection
                ? Icons.auto_awesome_rounded
                : Icons.search_off_rounded,
            color: hasDetection
                ? context.palette.success
                : context.palette.textSecondary,
            size: 22,
          ),
          const Spacer(),
          Text(
            hasDetection ? 'IDENTIFICADO' : 'SIN DETECCIÓN',
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasDetection ? identifiedName : 'No se encontró un animal',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
          ),
          if (hasDetection &&
              commonName.isNotEmpty &&
              scientificName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              scientificName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const Spacer(),
          if (hasDetection) ...[
            Divider(color: context.palette.surfaceMuted),
            Text(
              '${(confidence * 100).round()}% confianza',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.palette.success,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullImage(context),
      child: Container(
        height: 250,
        decoration: AppTheme.cardDecoration(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: FutureBuilder<Size>(
            future: _imageSize,
            builder: (context, snapshot) {
              final image = Image.file(
                File(widget.imagePath),
                fit: BoxFit.cover,
              );
              final boundingBox = _normalizedBoundingBox;

              if (!snapshot.hasData || boundingBox == null) {
                return image;
              }

              return CustomPaint(
                foregroundPainter: _BoundingBoxPainter(
                  boundingBox: boundingBox,
                  imageSize: snapshot.data!,
                  color: context.palette.success,
                ),
                child: image,
              );
            },
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withAlpha(200),
            child: Center(
              child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context) {
    final hasDetection =
        widget.result['status'] == 'ok' && widget.result['label'] != null;

    return Container(
      padding: AppTheme.cardPadding,
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Análisis de IA', style: AppTheme.headingStyle(context)),
          const SizedBox(height: 16),
          hasDetection
              ? _buildDetectionInfo(context)
              : _buildNoDetectionInfo(context),
        ],
      ),
    );
  }

  Widget _buildDetectionInfo(BuildContext context) {
    final label = widget.result['label']?.toString() ?? 'Desconocido';
    final raw = (widget.result['confidence'] as num?)?.toDouble() ?? 0.0;
    final confidencePercent = (raw.isFinite ? raw : 0.0)
        .clamp(0.0, 1.0)
        .toDouble();
    final confidenceValue = (confidencePercent * 100).round();
    final predictionSource =
        widget.result['prediction_source']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: context.palette.success,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Confianza: $confidenceValue%',
          style: AppTheme.bodyStyle(context),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: confidencePercent,
          backgroundColor: context.palette.surfaceMuted,
          color: context.palette.success,
        ),
        if (predictionSource.contains('rollup') &&
            predictionSource != 'classifier')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _rollupMessage(predictionSource),
              style: AppTheme.bodyStyle(context),
            ),
          ),
      ],
    );
  }

  String _rollupMessage(String predictionSource) {
    switch (predictionSource) {
      case 'classifier+rollup_to_family':
        return 'Se identificó la familia, pero no fue posible determinar la especie exacta.';
      case 'classifier+rollup_to_genus':
        return 'Se identificó el género, pero no fue posible determinar la especie exacta.';
      case 'classifier+rollup_to_order':
        return 'Se identificó el orden, pero no fue posible determinar la especie exacta.';
      default:
        return 'La identificación está limitada a un nivel taxonómico superior.';
    }
  }

  Widget _buildNoDetectionInfo(BuildContext context) {
    final label =
        widget.result['label']?.toString() ?? 'No se detectó ningún animal';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: context.palette.error,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Inténtalo de nuevo con una foto más clara o en mejor iluminación.',
          style: TextStyle(color: context.palette.textSecondary, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detalles', style: AppTheme.headingStyle(context)),
          const SizedBox(height: 16),
          _buildDetailRow(
            context,
            'Estado',
            widget.result['status']?.toString() ?? 'Desconocido',
          ),
          _buildDetailRow(
            context,
            'Categoría',
            widget.result['category']?.toString() ?? 'No disponible',
          ),
          _buildDetailRow(
            context,
            'Animal detectado',
            (widget.result['label']?.toString().replaceAll('deteccion: ', '') ??
                'No disponible'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationInfoCard(BuildContext context) {
    final prediction = SpeciesPrediction.parse(
      widget.result['prediction']?.toString() ?? '',
    );

    if (!prediction.hasUsableClassification) return const SizedBox.shrink();

    final lineage = <String>[];
    if (prediction.className.isNotEmpty) {
      lineage.add('Clase: ${prediction.className}');
    }
    if (prediction.order.isNotEmpty) {
      lineage.add('Orden: ${prediction.order}');
    }
    if (prediction.family.isNotEmpty) {
      lineage.add('Familia: ${prediction.family}');
    }
    if (prediction.genus.isNotEmpty) {
      lineage.add('Género: ${prediction.genus}');
    }
    if (prediction.species.isNotEmpty) {
      lineage.add('Especie: ${prediction.species}');
    }
    if (prediction.commonName.isNotEmpty) {
      lineage.add('Nombre común: ${prediction.commonName}');
    }

    return Container(
      padding: AppTheme.cardPadding,
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Clasificación taxonómica',
            style: AppTheme.headingStyle(context),
          ),
          const SizedBox(height: 16),
          ...lineage.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    Icons.biotech_rounded,
                    size: 16,
                    color: context.palette.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item,
                    style: TextStyle(
                      color: context.palette.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyStyle(context)),
          Text(
            value,
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  final Map<String, double> boundingBox;
  final Size imageSize;
  final Color color;

  const _BoundingBoxPainter({
    required this.boundingBox,
    required this.imageSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imageScale = size.width / imageSize.width;
    final heightScale = size.height / imageSize.height;
    final scale = imageScale > heightScale ? imageScale : heightScale;
    final renderedSize = Size(
      imageSize.width * scale,
      imageSize.height * scale,
    );
    final offset = Offset(
      (size.width - renderedSize.width) / 2,
      (size.height - renderedSize.height) / 2,
    );

    final rect = Rect.fromLTWH(
      offset.dx + boundingBox['x']! * renderedSize.width,
      offset.dy + boundingBox['y']! * renderedSize.height,
      boundingBox['width']! * renderedSize.width,
      boundingBox['height']! * renderedSize.height,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_BoundingBoxPainter oldDelegate) =>
      oldDelegate.boundingBox != boundingBox ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.color != color;
}
