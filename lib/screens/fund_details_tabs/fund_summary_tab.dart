import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/export_service.dart';
import '../../services/fund_scraper.dart';

class FundSummaryTab extends StatelessWidget {
  final FundData fund;
  final NumberFormat priceFormat;
  final NumberFormat percentFormat;
  final DateFormat dateFormat;

  const FundSummaryTab({
    super.key,
    required this.fund,
    required this.priceFormat,
    required this.percentFormat,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    double? diff;
    double? percent;
    Color? varColor;
    double? totalDiff;
    double? totalPercent;
    Color? totalVarColor;
    DateTime? oldestDate;

    if (fund.history.length > 1) {
      final previousValue = fund.history[fund.history.length - 2].price;
      if (previousValue != 0) {
        diff = fund.lastValue - previousValue;
        percent = (diff / previousValue) * 100;
        if (diff > 0) {
          varColor = Colors.greenAccent[400];
        } else if (diff < 0) {
          varColor = Colors.redAccent[200];
        }
      }

      final oldestValue = fund.history.first.price;
      oldestDate = fund.history.first.date;
      if (oldestValue != 0) {
        totalDiff = fund.lastValue - oldestValue;
        totalPercent = (totalDiff / oldestValue) * 100;
        if (totalDiff > 0) {
          totalVarColor = Colors.greenAccent[400];
        } else if (totalDiff < 0) {
          totalVarColor = Colors.redAccent[200];
        }
      }
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fund.lastValue == 0 && fund.history.isEmpty)
              const Center(child: Text('Sin datos de cotización.'))
            else ...[
              Text(
                'Valor Liquidativo',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${priceFormat.format(fund.lastValue)} ${fund.currency}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  if (diff != null && percent != null) ...[
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${diff > 0 ? '+' : ''}${priceFormat.format(diff)}',
                          style: TextStyle(
                            color: varColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '(${percent > 0 ? '+' : ''}${percentFormat.format(percent)}%)',
                          style: TextStyle(color: varColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Actualizado: ${DateFormat('dd/MM/yyyy').format(fund.date)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Colors.white38),
              ),
              const SizedBox(height: 6),
              FutureBuilder<DateTime?>(
                future: ExportService.getLastExportDate(fund.isin),
                builder: (context, snapshot) {
                  final lastExport = snapshot.data;
                  final backupPending =
                      lastExport == null ||
                      lastExport.isBefore(
                        DateTime.now().subtract(const Duration(days: 30)),
                      );
                  return Row(
                    children: [
                      Icon(
                        backupPending
                            ? Icons.warning_amber_outlined
                            : Icons.cloud_done_outlined,
                        size: 14,
                        color: backupPending
                            ? Colors.amberAccent
                            : Colors.greenAccent[400],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          backupPending
                              ? lastExport == null
                                    ? 'No hay backup. Se recomienda exportar este fondo.'
                                    : 'El último backup tiene más de un mes. Se recomienda exportar este fondo.'
                              : 'Último backup: ${DateFormat('dd/MM/yyyy HH:mm').format(lastExport)}',
                          style: TextStyle(
                            color: backupPending
                                ? Colors.amberAccent
                                : Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (totalDiff != null &&
                  totalPercent != null &&
                  oldestDate != null) ...[
                const Divider(height: 32, color: Colors.white10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Variación Total',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          'Desde ${DateFormat('dd/MM/yyyy').format(oldestDate)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white38),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${totalDiff > 0 ? '+' : ''}${priceFormat.format(totalDiff)} ${fund.currency}',
                          style: TextStyle(
                            color: totalVarColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${totalPercent > 0 ? '+' : ''}${percentFormat.format(totalPercent)}%',
                          style: TextStyle(
                            color: totalVarColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              _buildStatsGrid(context),
            ],
            if (fund.alertMin != null || fund.alertMax != null) ...[
              const Divider(height: 32, color: Colors.white10),
              Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    size: 16,
                    color: Colors.amberAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Alertas configuradas',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (fund.alertMin != null)
                _buildAlertValue(
                  context,
                  'Mínimo',
                  fund.alertMin!,
                  Icons.arrow_downward,
                  Colors.redAccent[200]!,
                ),
              if (fund.alertMax != null)
                _buildAlertValue(
                  context,
                  'Máximo',
                  fund.alertMax!,
                  Icons.arrow_upward,
                  Colors.greenAccent[400]!,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    if (fund.history.isEmpty) return const SizedBox.shrink();

    double sum = 0;
    PricePoint maxPoint = fund.history.first;
    PricePoint minPoint = fund.history.first;
    final returns = <double>[];

    for (int i = 0; i < fund.history.length; i++) {
      final point = fund.history[i];
      sum += point.price;
      if (point.price > maxPoint.price) maxPoint = point;
      if (point.price < minPoint.price) minPoint = point;
      if (i > 0) {
        final previousPrice = fund.history[i - 1].price;
        if (previousPrice != 0) {
          returns.add((point.price - previousPrice) / previousPrice);
        }
      }
    }

    final meanPrice = sum / fund.history.length;
    double annualVolatility = 0;
    if (returns.isNotEmpty) {
      final meanReturn = returns.reduce((a, b) => a + b) / returns.length;
      final varianceSum = returns
          .map((value) => pow(value - meanReturn, 2).toDouble())
          .reduce((a, b) => a + b);
      annualVolatility = sqrt(varianceSum / returns.length) * sqrt(252) * 100;
    }

    final format = DateFormat('dd/MM/yyyy');
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                context,
                'Máximo',
                priceFormat.format(maxPoint.price),
                format.format(maxPoint.date),
                Colors.greenAccent[400]!,
                Icons.arrow_upward,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoItem(
                context,
                'Mínimo',
                priceFormat.format(minPoint.price),
                format.format(minPoint.date),
                Colors.redAccent[200]!,
                Icons.arrow_downward,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                context,
                'Media',
                priceFormat.format(meanPrice),
                'Histórico',
                Colors.blueAccent,
                Icons.functions,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoItem(
                context,
                'Volatilidad',
                '${percentFormat.format(annualVolatility)}%',
                'Anualizada',
                Colors.orangeAccent,
                Icons.vibration,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    String title,
    String value,
    String date,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            date,
            style: const TextStyle(fontSize: 9, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertValue(
    BuildContext context,
    String label,
    double value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
          Text(
            '${priceFormat.format(value)} ${fund.currency}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
