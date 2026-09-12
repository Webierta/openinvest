import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/fund_scraper.dart';

class FundHistoryChart extends StatefulWidget {
  final FundData fund;
  final NumberFormat priceFormat;

  const FundHistoryChart({
    super.key,
    required this.fund,
    required this.priceFormat,
  });

  @override
  State<FundHistoryChart> createState() => _FundHistoryChartState();
}

class _FundHistoryChartState extends State<FundHistoryChart> {
  String _range = 'ALL';

  @override
  Widget build(BuildContext context) {
    if (widget.fund.history.isEmpty) return const SizedBox.shrink();
    final filtered = _filteredHistory();
    if (filtered.isEmpty) {
      return Column(
        children: [
          _buildRangeSelector(),
          const SizedBox(height: 100),
          const Center(
            child: Text(
              'No hay datos en este rango',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ],
      );
    }

    final labelFormat = NumberFormat('#,##0.00', 'es_ES');
    final prices = filtered.map((point) => point.price).toList();
    final maxPrice = prices.reduce(max);
    final minPrice = prices.reduce(min);
    final meanPrice = prices.reduce((a, b) => a + b) / prices.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Evolución (${filtered.length} pts)',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildRangeSelector(),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 350,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: 0.05),
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: 0.05),
                  strokeWidth: 1,
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: meanPrice,
                    color: Colors.blue.withValues(alpha: 0.4),
                    strokeWidth: 1.5,
                    dashArray: [5, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      labelResolver: (line) =>
                          'Media: ${labelFormat.format(line.y)}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: max(1, filtered.length / 5).toDouble(),
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < 0 || index >= filtered.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('dd/MM').format(filtered[index].date),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white38,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, _) => Text(
                      labelFormat.format(value),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1E293B),
                  getTooltipItems: (spots) => spots.map((spot) {
                    final date = filtered[spot.x.toInt()].date;
                    return LineTooltipItem(
                      '${DateFormat('dd/MM/yyyy').format(date)}\n',
                      const TextStyle(color: Colors.white38, fontSize: 10),
                      children: [
                        TextSpan(
                          text: widget.priceFormat.format(spot.y),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: filtered
                      .asMap()
                      .entries
                      .map(
                        (entry) =>
                            FlSpot(entry.key.toDouble(), entry.value.price),
                      )
                      .toList(),
                  isCurved: true,
                  color: const Color(0xFF38BDF8),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, _, _) {
                      if (spot.y == maxPrice) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.greenAccent[400]!,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      }
                      if (spot.y == minPrice) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.redAccent[200]!,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      }
                      return FlDotCirclePainter(radius: 0);
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<PricePoint> _filteredHistory() {
    if (_range == 'ALL') return widget.fund.history;
    final now = DateTime.now();
    final cutoff = switch (_range) {
      '1M' => now.subtract(const Duration(days: 30)),
      '6M' => now.subtract(const Duration(days: 182)),
      'YTD' => DateTime(now.year),
      '1Y' => now.subtract(const Duration(days: 365)),
      _ => DateTime(2000),
    };
    return widget.fund.history
        .where((point) => point.date.isAfter(cutoff))
        .toList();
  }

  Widget _buildRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['1M', '6M', 'YTD', '1Y', 'ALL'].map((range) {
          final selected = _range == range;
          return GestureDetector(
            onTap: () => setState(() => _range = range),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF38BDF8) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                range,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.white38,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
