import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';

class AnalyticsChartsSection extends StatelessWidget {
  final List<Map<String, dynamic>> detections;

  const AnalyticsChartsSection({super.key, required this.detections});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _DetectionsByDayChart(detections: detections),
              ),
            ],
          );
        }
        return Column(
          children: [_DetectionsByDayChart(detections: detections)],
        );
      },
    );
  }
}

// ===========================================================================
// GRÁFICO 1: AVISTAMIENTOS DE LOS ÚLTIMOS 7 DÍAS (BARRAS)
// ===========================================================================

class _DetectionsByDayChart extends StatefulWidget {
  final List<Map<String, dynamic>> detections;
  const _DetectionsByDayChart({required this.detections});

  @override
  State<_DetectionsByDayChart> createState() => _DetectionsByDayChartState();
}

class _DetectionsByDayChartState extends State<_DetectionsByDayChart> {
  int _selectedDays = 7;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final List<DateTime> days = List.generate(
      _selectedDays,
      (i) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: (_selectedDays - 1) - i)),
    );

    final Map<String, int> countsByDay = {for (final d in days) _dateKey(d): 0};

    for (final det in widget.detections) {
      final rawDate = det['created_at']?.toString();
      if (rawDate == null) continue;
      try {
        final localDate = DateTime.parse(rawDate).toLocal();
        final key = _dateKey(localDate);
        if (countsByDay.containsKey(key)) {
          countsByDay[key] = (countsByDay[key] ?? 0) + 1;
        }
      } catch (_) {}
    }

    final values = days.map((d) => countsByDay[_dateKey(d)] ?? 0).toList();
    final maxVal = values.fold<int>(0, (prev, el) => el > prev ? el : prev);
    final double maxY = (maxVal < 5 ? 5 : maxVal + 2).toDouble();
    final bool is30Days = _selectedDays == 30;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Actividad de Avistamientos (Últimos $_selectedDays días)',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RangeChip(
                    label: '7D',
                    selected: _selectedDays == 7,
                    onTap: () => setState(() => _selectedDays = 7),
                  ),
                  const SizedBox(width: 6),
                  _RangeChip(
                    label: '30D',
                    selected: _selectedDays == 30,
                    onTap: () => setState(() => _selectedDays = 30),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceElevated,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = days[group.x.toInt()];
                      return BarTooltipItem(
                        '${day.day}/${day.month}\n',
                        const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toInt()} registros',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= days.length) {
                          return const SizedBox.shrink();
                        }
                        if (is30Days &&
                            idx % 5 != 0 &&
                            idx != days.length - 1) {
                          return const SizedBox.shrink();
                        }
                        final d = days[idx];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${d.day}/${d.month}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (maxY / 4).ceilToDouble(),
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.divider.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(days.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i].toDouble(),
                        color: AppColors.primary,
                        width: is30Days ? 7 : 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: AppColors.surfaceElevated.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.divider.withValues(alpha: 0.7),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
