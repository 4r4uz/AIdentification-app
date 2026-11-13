import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '/features/camera/domain/entities/species_prediction.dart';
import '/features/gallery/data/models/species_fact_model.dart';
import '/features/gallery/data/models/species_model.dart';
import '/core/service_locator.dart';
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
  final _speciesService = ServiceLocator.species;
  late final Future<Size> _imageSize;
  Future<({SpeciesModel? species, List<SpeciesFactModel> facts})>?
  _speciesContentCache;

  Future<({SpeciesModel? species, List<SpeciesFactModel> facts})>
  get _speciesContent => _speciesContentCache ??= _loadSpeciesContent();

  bool get _hasDetection =>
      widget.result['status'] == 'ok' && widget.result['label'] != null;

  SpeciesPrediction get _prediction =>
      SpeciesPrediction.parse(widget.result['prediction']?.toString() ?? '');

  List<({String name, String scientificName, double score})>
  get _alternativePredictions {
    final rawAlternatives = widget.result['alternative_predictions'];
    if (rawAlternatives is! List) return const [];

    final alternatives =
        <({String name, String scientificName, double score})>[];
    for (final item in rawAlternatives) {
      if (item is! Map) continue;
      final name = item['name'];
      final scientificName = item['scientific_name'];
      final rawScore = item['score'];
      if (name is! String || rawScore is! num || !rawScore.isFinite) continue;

      final cleanName = name.trim();
      if (cleanName.isEmpty) continue;
      alternatives.add((
        name: cleanName,
        scientificName: scientificName is String ? scientificName.trim() : '',
        score: rawScore.toDouble().clamp(0.0, 1.0),
      ));
      if (alternatives.length == 3) break;
    }
    return alternatives;
  }

  String get _displayName {
    final prediction = _prediction;
    final commonName = prediction.commonName.trim();
    if (commonName.isNotEmpty) return commonName;
    if (prediction.species.trim().isNotEmpty) return prediction.species.trim();
    if (prediction.genus.trim().isNotEmpty) return prediction.genus.trim();
    if (prediction.family.trim().isNotEmpty) return prediction.family.trim();
    return widget.result['label']?.toString() ?? 'Animal detectado';
  }

  String get _scientificName => [
    _prediction.genus.trim(),
    _prediction.species.trim(),
  ].where((part) => part.isNotEmpty).join(' ');

  @override
  void initState() {
    super.initState();
    _imageSize = _loadImageSize();
  }

  Future<({SpeciesModel? species, List<SpeciesFactModel> facts})>
  _loadSpeciesContent() async {
    final predictionSource =
        widget.result['prediction_source']?.toString() ?? '';
    final prediction = widget.result['prediction']?.toString() ?? '';
    if (!predictionSource.contains('classifier') || prediction.isEmpty) {
      debugPrint(
        '[ResultScreen] Contenido Supabase omitido: '
        'source="$predictionSource", prediction="$prediction"',
      );
      return (species: null, facts: <SpeciesFactModel>[]);
    }

    final species = await _speciesService.resolveDetectedSpecies(
      prediction: prediction,
      predictionSource: predictionSource,
    );
    if (species == null) {
      debugPrint(
        '[ResultScreen] No se resolvió una especie para Supabase: '
        'source="$predictionSource", prediction="$prediction"',
      );
      return (species: null, facts: <SpeciesFactModel>[]);
    }

    final facts = await _speciesService.getSpeciesFactsById(species.id);
    debugPrint(
      '[ResultScreen] Contenido Supabase: speciesId=${species.id}, '
      'description=${species.description?.trim().isNotEmpty ?? false}, '
      'facts=${facts.length}',
    );
    return (species: species, facts: facts);
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
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(context),
              Transform.translate(
                offset: const Offset(0, -30),
                child: _buildSummaryCard(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_prediction.hasUsableClassification) ...[
                      _buildClassificationCard(context),
                      const SizedBox(height: 16),
                    ],
                    _buildKeyDataCard(context),
                    const SizedBox(height: 16),
                    _buildResponsibleObservationCard(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = (screenHeight * 0.59).clamp(400.0, 590.0);

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => _showFullImage(context),
            child: FutureBuilder<Size>(
              future: _imageSize,
              builder: (context, snapshot) {
                final image = Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: context.palette.surfaceMuted,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: context.palette.textSecondary,
                      size: 48,
                    ),
                  ),
                );
                final boundingBox = _normalizedBoundingBox;
                if (!snapshot.hasData || boundingBox == null || !_hasDetection) {
                  return image;
                }

                return CustomPaint(
                  foregroundPainter: _BoundingBoxPainter(
                    boundingBox: boundingBox,
                    imageSize: snapshot.data!,
                    color: Colors.white,
                    confidence: _predictionConfidence,
                  ),
                  child: image,
                );
              },
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Colors.transparent,
                  Color(0xCC000000),
                ],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _heroButton(
                  context,
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Volver',
                ),
                Text(
                  'RESULTADO',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                _heroButton(
                  context,
                  icon: Icons.fullscreen_rounded,
                  onPressed: () => _showFullImage(context),
                  tooltip: 'Ver imagen completa',
                ),
              ],
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasDetection ? _displayName : 'No se encontró un animal',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(blurRadius: 12, color: Colors.black54)],
                  ),
                ),
                if (_hasDetection && _scientificName.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    _scientificName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FutureBuilder(
          future: _speciesContent,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text(
                'Cargando información...',
                style: AppTheme.bodyStyle(context),
              );
            }
            if (snapshot.hasError) {
              return Text(
                'No se pudo cargar la información de la especie.',
                style: AppTheme.bodyStyle(context),
              );
            }
            final description = snapshot.data?.species?.description?.trim();
            return Text(
              description == null || description.isEmpty
                  ? 'Sin información disponible'
                  : description,
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 15,
                height: 1.45,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildKeyDataCard(BuildContext context) {
    final predictionSource =
        widget.result['prediction_source']?.toString() ?? '';
    final detectionConfidence = _numberValue(
      widget.result['detection_confidence'] ??
          _firstDetection?['confidence'] ??
          (predictionSource == 'detector' ? widget.result['confidence'] : null),
    );
    final predictionConfidence = _predictionConfidence;

    final sourceLabel = switch (predictionSource) {
      'classifier' => 'Clasificador',
      final source when source.contains('rollup') => 'Taxonomía parcial',
      'detector' => 'Detector',
      '' => 'Sin información',
      _ => 'IA local',
    };

    return _sectionCard(
      context,
      title: 'Datos clave',
      icon: Icons.insights_rounded,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _dataTile(
              context,
              icon: Icons.auto_awesome_rounded,
              label: 'Confianza IA',
              value: predictionConfidence == null
                  ? 'Sin información'
                  : '${(predictionConfidence * 100).round()}%',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dataTile(
              context,
              icon: Icons.center_focus_strong_rounded,
              label: 'Detección',
              value: detectionConfidence == null
                  ? 'Sin información'
                  : '${(detectionConfidence * 100).round()}%',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dataTile(
              context,
              icon: Icons.account_tree_rounded,
              label: 'Fuente',
              value: sourceLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      height: 126,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.palette.primary, size: 19),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationCard(BuildContext context) {
    final prediction = _prediction;
    if (!prediction.hasUsableClassification) return const SizedBox.shrink();

    final lineage = <(String, String)>[
      ('Clase', prediction.className),
      ('Orden', prediction.order),
      ('Familia', prediction.family),
      ('Género', prediction.genus),
      ('Especie', prediction.species),
      ('Nombre común', prediction.commonName),
    ].where((entry) => entry.$2.trim().isNotEmpty).toList();
    final alternatives = _alternativePredictions;

    return _sectionCard(
      context,
      title: 'Clasificación taxonómica',
      icon: Icons.account_tree_rounded,
      child: Column(
        children: [
          for (var index = 0; index < lineage.length; index++) ...[
            if (index > 0) Divider(height: 18, color: context.palette.border),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    lineage[index].$1,
                    style: AppTheme.bodyStyle(context),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    lineage[index].$2,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: context.palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (alternatives.isNotEmpty) ...[
            Divider(height: 24, color: context.palette.border),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Otras posibles especies',
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final alternative in alternatives)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alternative.name,
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (alternative.scientificName.isNotEmpty)
                            Text(
                              alternative.scientificName,
                              style: TextStyle(
                                color: context.palette.textSecondary.withValues(
                                  alpha: 0.75,
                                ),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(alternative.score * 100).round()}%',
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponsibleObservationCard(BuildContext context) {
    return _sectionCard(
      context,
      title: 'Datos curiosos',
      icon: Icons.lightbulb_outline_rounded,
      child: FutureBuilder(
        future: _speciesContent,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Text(
              'Cargando información...',
              style: AppTheme.bodyStyle(context),
            );
          }
          if (snapshot.hasError) {
            return Text(
              'No se pudieron cargar los datos curiosos.',
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 14,
                height: 1.45,
              ),
            );
          }
          final facts = snapshot.data?.facts ?? const <SpeciesFactModel>[];
          if (facts.isEmpty) {
            return Text(
              'Sin información disponible',
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 14,
                height: 1.45,
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < facts.length; index++) ...[
                if (index > 0) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: context.palette.border),
                  const SizedBox(height: 12),
                ],
                Text(
                  facts[index].fact,
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.palette.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.headingStyle(context).copyWith(fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  double? get _predictionConfidence {
    final predictionSource =
        widget.result['prediction_source']?.toString() ?? '';
    if (!predictionSource.contains('classifier')) return null;
    final raw = _numberValue(
      widget.result['prediction_score'] ?? widget.result['confidence'],
    );
    return raw?.clamp(0.0, 1.0).toDouble();
  }

  Map? get _firstDetection {
    final response = widget.result['api_response'];
    if (response is! Map) return null;
    final detections = response['detections'];
    if (detections is! List || detections.isEmpty) return null;
    final detection = detections.first;
    return detection is Map ? detection : null;
  }

  double? _numberValue(Object? value) {
    if (value is! num || !value.toDouble().isFinite) return null;
    return value.toDouble();
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
}

class _BoundingBoxPainter extends CustomPainter {
  final Map<String, double> boundingBox;
  final Size imageSize;
  final Color color;
  final double? confidence;

  const _BoundingBoxPainter({
    required this.boundingBox,
    required this.imageSize,
    required this.color,
    required this.confidence,
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

    if (confidence != null) {
      final label = TextPainter(
        text: TextSpan(
          text: 'IA ${(confidence! * 100).round()}%',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const horizontalPadding = 8.0;
      const verticalPadding = 5.0;
      final labelWidth = label.width + horizontalPadding * 2;
      final labelHeight = label.height + verticalPadding * 2;
      final labelLeft = rect.left
          .clamp(4.0, math.max(4.0, size.width - labelWidth - 4))
          .toDouble();
      final labelTop = (rect.top - labelHeight - 4)
          .clamp(4.0, math.max(4.0, size.height - labelHeight - 4))
          .toDouble();
      final labelRect = Rect.fromLTWH(
        labelLeft,
        labelTop,
        labelWidth,
        labelHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      label.paint(
        canvas,
        Offset(labelLeft + horizontalPadding, labelTop + verticalPadding),
      );
    }
  }

  @override
  bool shouldRepaint(_BoundingBoxPainter oldDelegate) =>
      oldDelegate.boundingBox != boundingBox ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.color != color ||
      oldDelegate.confidence != confidence;
}
