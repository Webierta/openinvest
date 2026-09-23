import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../../providers/fund_provider.dart';
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

  static const Map<String, String> commonBenchmarks = {
    'S&P 500': '^GSPC',
    'MSCI World': 'URTH',
    'EuroStoxx 50': '^STOXX50E',
    'IBEX 35': '^IBEX',
    'Nasdaq 100': '^NDX',
    'DAX 40': '^GDAXI',
    'CAC 40': '^FCHI',
    'Nikkei 225': '^N225',
  };

  Map<String, String> _getBenchmarkDescriptions(AppLocalizations l10n) => {
        '^GSPC': l10n.sp500Desc,
        'URTH': l10n.msciWorldDesc,
        '^STOXX50E': l10n.euroStoxx50Desc,
        '^IBEX': l10n.ibex35Desc,
        '^NDX': l10n.nasdaq100Desc,
        '^GDAXI': l10n.dax40Desc,
        '^FCHI': l10n.cac40Desc,
        '^N225': l10n.nikkei225Desc,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final provider = context.watch<FundProvider>();
    if (widget.fund.history.isEmpty) return const SizedBox.shrink();
    final filtered = _filteredHistory();
    if (filtered.isEmpty) {
      return Column(
        children: [
          _buildRangeSelector(),
          const SizedBox(height: 100),
          Center(
            child: Text(
              l10n.noDataInRange,
              style: const TextStyle(color: Colors.white38),
            ),
          ),
        ],
      );
    }

    final hasBenchmark = provider.selectedBenchmarkSymbol != null && provider.benchmarkHistory != null;
    final labelFormat = NumberFormat('#,##0.00', locale);

    // Preparar datos para el gráfico
    final fundSpots = _getFundSpots(filtered, hasBenchmark);
    final benchmarkSpots =
        hasBenchmark
            ? _getBenchmarkSpots(filtered, provider.benchmarkHistory!)
            : <FlSpot>[];

    final List<double> allYValues = [
      ...fundSpots.map((s) => s.y),
      ...benchmarkSpots.map((s) => s.y),
    ];
    final maxY = allYValues.isEmpty ? 0.0 : allYValues.reduce(max);
    final minY = allYValues.isEmpty ? 0.0 : allYValues.reduce(min);
    final meanFundPrice =
        filtered.isEmpty
            ? 0.0
            : filtered.map((e) => e.price).reduce((a, b) => a + b) /
                filtered.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _buildRangeSelector(),
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
                  if (!hasBenchmark)
                    HorizontalLine(
                      y: meanFundPrice,
                      color: Colors.blue.withValues(alpha: 0.4),
                      strokeWidth: 1.5,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        labelResolver: (line) =>
                            '${l10n.averageLabelShort}: ${labelFormat.format(line.y)}',
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
                          DateFormat.Md(locale).format(filtered[index].date),
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
                      hasBenchmark
                          ? '${value.toStringAsFixed(1)}%'
                          : labelFormat.format(value),
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
                    final isBenchmark = spot.barIndex == 1;
                    return LineTooltipItem(
                      isBenchmark
                          ? 'Benchmark\n'
                          : '${DateFormat('dd/MM/yyyy').format(date)}\n',
                      TextStyle(
                        color: isBenchmark ? Colors.orangeAccent : Colors.white38,
                        fontSize: 10,
                      ),
                      children: [
                        TextSpan(
                          text: hasBenchmark
                              ? '${spot.y.toStringAsFixed(2)}%'
                              : widget.priceFormat.format(spot.y),
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
                  spots: fundSpots,
                  isCurved: true,
                  color: const Color(0xFF38BDF8),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: !hasBenchmark,
                    getDotPainter: (spot, _, _, _) {
                      if (spot.y == maxY && !hasBenchmark) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.greenAccent[400]!,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      }
                      if (spot.y == minY && !hasBenchmark) {
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
                if (hasBenchmark)
                  LineChartBarData(
                    spots: benchmarkSpots,
                    isCurved: true,
                    color: Colors.orangeAccent.withValues(alpha: 0.6),
                    barWidth: 2,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _buildBenchmarkSelector(provider, filtered),
        ),
        if (hasBenchmark)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8),
            child: Row(
              children: [
                Container(width: 12, height: 12, color: const Color(0xFF38BDF8)),
                const SizedBox(width: 4),
                Text(l10n.fundPercentLabel, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                const SizedBox(width: 16),
                Container(width: 12, height: 12, decoration: BoxDecoration(border: Border.all(color: Colors.orangeAccent), color: Colors.orangeAccent.withValues(alpha: 0.2))),
                const SizedBox(width: 4),
                Text(l10n.benchmarkPercentLabel, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        if (hasBenchmark && provider.selectedBenchmarkSymbol != null)
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 8, right: 8),
            child: Text(
              _getBenchmarkDescriptions(l10n)[provider.selectedBenchmarkSymbol] ?? '',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontStyle: FontStyle.italic,
                height: 1.4,
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

  List<FlSpot> _getFundSpots(List<PricePoint> history, bool normalize) {
    if (history.isEmpty) return [];
    if (!normalize) {
      return history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.price)).toList();
    }
    final basePrice = history.first.price;
    return history.asMap().entries.map((e) {
      final percentage = (e.value.price / basePrice - 1) * 100;
      return FlSpot(e.key.toDouble(), percentage);
    }).toList();
  }

  List<FlSpot> _getBenchmarkSpots(List<PricePoint> fundHistory, List<PricePoint> benchmarkHistory) {
    if (fundHistory.isEmpty || benchmarkHistory.isEmpty) return [];
    
    // Encontrar el punto base del benchmark (fecha más cercana al inicio del fondo filtrado)
    final startDate = fundHistory.first.date;
    final basePoint = benchmarkHistory.firstWhere(
      (p) => !p.date.isBefore(startDate),
      orElse: () => benchmarkHistory.last,
    );
    final basePrice = basePoint.price;

    return fundHistory.asMap().entries.map((e) {
      final date = e.value.date;
      // Buscar el punto del benchmark más cercano a esta fecha
      final benchPoint = benchmarkHistory.lastWhere(
        (p) => !p.date.isAfter(date),
        orElse: () => benchmarkHistory.first,
      );
      final percentage = (benchPoint.price / basePrice - 1) * 100;
      return FlSpot(e.key.toDouble(), percentage);
    }).toList();
  }

  Widget _buildBenchmarkSelector(FundProvider provider, List<PricePoint> filtered) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: provider.selectedBenchmarkSymbol,
          hint: Text(
            l10n.compareWithBenchmark,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          dropdownColor: const Color(0xFF0F172A),
          icon: const Icon(Icons.compare_arrows, size: 16, color: Colors.white38),
          onChanged: (symbol) {
            if (symbol == null) {
              provider.clearBenchmark();
            } else {
              provider.fetchBenchmark(symbol, startDate: filtered.first.date);
            }
          },
          items: [
            if (provider.selectedBenchmarkSymbol != null)
              DropdownMenuItem<String>(
                value: null,
                child: Text(l10n.noneLabel, style: const TextStyle(fontSize: 12)),
              ),
            ...commonBenchmarks.entries.map(
              (e) => DropdownMenuItem(
                value: e.value,
                child: Text(e.key, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
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
            onTap: () {
              setState(() => _range = range);
              // Re-fetch benchmark if visible
              final provider = context.read<FundProvider>();
              if (provider.selectedBenchmarkSymbol != null) {
                 final newFiltered = _filteredHistory();
                 if (newFiltered.isNotEmpty) {
                    provider.fetchBenchmark(provider.selectedBenchmarkSymbol!, startDate: newFiltered.first.date);
                 }
              }
            },
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
