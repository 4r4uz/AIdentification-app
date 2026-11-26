import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// Chip de confianza IA con color según porcentaje.
class ConfidenceChip extends StatelessWidget {
  final double percent;

  const ConfidenceChip({super.key, required this.percent});

  Color get _color {
    if (percent >= 80) return AppColors.confidenceHigh;
    if (percent >= 60) return AppColors.confidenceMedium;
    return AppColors.confidenceLow;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
