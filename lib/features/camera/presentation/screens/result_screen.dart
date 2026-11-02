import 'dart:io';
import 'package:flutter/material.dart';
import '/features/camera/domain/entities/species_prediction.dart';
import '/core/theme/colors.dart';
import '/core/theme/app_theme.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final String imagePath;

  const ResultScreen({
    super.key,
    required this.result,
    required this.imagePath,
  });

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
            _buildImage(context),
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

  Widget _buildImage(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullImage(context),
      child: Container(
        height: 250,
        decoration: AppTheme.cardDecoration(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Image.file(File(imagePath), fit: BoxFit.cover),
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
              child: Image.file(File(imagePath), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context) {
    final hasDetection = result['status'] == 'ok' && result['label'] != null;

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
    final label = result['label']?.toString() ?? 'Desconocido';
    final raw = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    final confidencePercent = (raw.isFinite ? raw : 0.0)
        .clamp(0.0, 1.0)
        .toDouble();
    final confidenceValue = (confidencePercent * 100).round();
    final predictionSource = result['prediction_source']?.toString() ?? '';

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
    final label = result['label']?.toString() ?? 'No se detectó ningún animal';
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
          _buildDetailRow(context, 'Estado', result['status'] ?? 'Desconocido'),
          _buildDetailRow(
            context,
            'Categoría',
            result['category'] ?? 'No disponible',
          ),
          _buildDetailRow(
            context,
            'Animal detectado',
            (result['label']?.toString().replaceAll('deteccion: ', '') ??
                'No disponible'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationInfoCard(BuildContext context) {
    final prediction = SpeciesPrediction.parse(
      result['prediction']?.toString() ?? '',
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
