import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/fund_data.dart';
import '../utils/fund_comparison_calculator.dart';

class ComparisonFundChart extends StatefulWidget {
  final FundData first;
  final FundData second;

  const ComparisonFundChart({
    super.key,
    required this.first,
    required this.second,
  });

  @override
  State<ComparisonFundChart> createState() => _ComparisonFundChartState();
}

class _ComparisonFundChartState extends State<ComparisonFundChart> {
  FundComparisonChartRange _range = FundComparisonChartRange.all;

  static const _firstColor = Color(0xFF38BDF8);
  static const _secondColor = Color(0xFFFB923C);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final points = FundComparisonCalculator.buildChartPoints(
      widget.first,
      widget.second,
      range: _range,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.compareChartTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<FundComparisonChartRange>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: FundComparisonChartRange.oneMonth,
                label: Text('1M'),
              ),
              ButtonSegment(
                value: FundComparisonChartRange.sixMonths,
                label: Text('6M'),
              ),
              ButtonSegment(
                value: FundComparisonChartRange.oneYear,
                label: Text('1A'),
              ),
              ButtonSegment(
                value: FundComparisonChartRange.all,
                label: Text('Todo'),
              ),
            ],
            selected: {_range},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                setState(() => _range = selection.first);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        if (points.length < 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                l10n.compareChartNoData,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          )
        else ...[
          _buildChart(points, locale),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildLegendItem(widget.first.name, _firstColor)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLegendItem(widget.second.name, _secondColor),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildChart(List<FundComparisonChartPoint> points, String locale) {
    final startDate = points.first.date;
    final maxX = points.last.date.difference(startDate).inDays.toDouble();
    final firstSpots = points
        .map(
          (point) => FlSpot(
            point.date.difference(startDate).inDays.toDouble(),
            point.firstReturn,
          ),
        )
        .toList(growable: false);
    final secondSpots = points
        .map(
          (point) => FlSpot(
            point.date.difference(startDate).inDays.toDouble(),
            point.secondReturn,
          ),
        )
        .toList(growable: false);
    final returns = [
      ...points.map((point) => point.firstReturn),
      ...points.map((point) => point.secondReturn),
    ];
    final minReturn = returns.reduce(math.min);
    final maxReturn = returns.reduce(math.max);
    final padding = math.max((maxReturn - minReturn) * 0.12, 1.0);
    final minY = math.min(0.0, minReturn - padding).toDouble();
    final maxY = math.max(0.0, maxReturn + padding).toDouble();
    final dayInterval = math.max(maxX / 4, 1).toDouble();
    final dateFormat = DateFormat.MMMd(locale);
    final percentFormat = NumberFormat('#,##0.0', locale);

    return SizedBox(
      key: const ValueKey('comparison-return-chart'),
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: _axisInterval(minY, maxY),
                getTitlesWidget: (value, _) => Text(
                  '${percentFormat.format(value)}%',
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: dayInterval,
                getTitlesWidget: (value, _) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    dateFormat.format(
                      startDate.add(Duration(days: value.round())),
                    ),
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E293B),
              getTooltipItems: (spots) {
                final point = points.firstWhere(
                  (item) =>
                      item.date.difference(startDate).inDays ==
                      spots.first.x.round(),
                  orElse: () => points.first,
                );
                final dateStr = dateFormat.format(point.date);

                return spots.asMap().entries.map((entry) {
                  final index = entry.key;
                  final spot = entry.value;
                  final isSecond = spot.barIndex == 1;
                  final fund = isSecond ? widget.second : widget.first;
                  final color = isSecond ? _secondColor : _firstColor;
                  final dateHeading = index == 0 ? '$dateStr\n' : '';

                  return LineTooltipItem(
                    '$dateHeading${_tooltipFundName(fund.name)}\n'
                    '${percentFormat.format(spot.y)}%',
                    TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: firstSpots,
              isCurved: false,
              color: _firstColor,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: secondSpots,
              isCurved: false,
              color: _secondColor,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String name, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
      ],
    );
  }

  String _tooltipFundName(String name) {
    final singleLine = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 16) return singleLine;
    return '${singleLine.substring(0, 15).trimRight()}…';
  }

  static double _axisInterval(double minY, double maxY) =>
      math.max((maxY - minY) / 4, 1).toDouble();
}
