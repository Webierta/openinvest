import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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

    // Cálculos para la cabecera y estadísticas
    double maxVal = -double.infinity;
    double minVal = double.infinity;
    double sum = 0;
    PricePoint? maxPoint;
    PricePoint? minPoint;

    for (var p in fund.history) {
      sum += p.price;
      if (p.price > maxVal) {
        maxVal = p.price;
        maxPoint = p;
      }
      if (p.price < minVal) {
        minVal = p.price;
        minPoint = p;
      }
    }

    final double meanVal = fund.history.isNotEmpty ? sum / fund.history.length : 0;
    final double distToMaxAbs = maxVal > 0 ? fund.lastValue - maxVal : 0;
    final double distToMaxRel = maxVal > 0 ? (distToMaxAbs / maxVal) * 100 : 0;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                //color: Colors.red,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  DateFormat('MM/yy').format(fund.date),
                                ),
                              ),
                              Text(
                                DateFormat('d').format(fund.date),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Valor Liquidativo',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        '${priceFormat.format(fund.lastValue)} ${fund.currency}',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                      ),
                      if (diff != null && percent != null) ...[
                        Row(
                          children: [
                            Text(
                              '${diff > 0 ? '+' : ''}${priceFormat.format(diff)}',
                              style: TextStyle(
                                color: varColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '(${percent > 0 ? '+' : ''}${percentFormat.format(percent)}%)',
                              style: TextStyle(color: varColor, fontSize: 11),
                            ),
                          ],
                        ),
                        if (distToMaxAbs < -0.0001) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.keyboard_double_arrow_up, size: 12, color: Colors.white.withValues(alpha: 0.3)),
                              const SizedBox(width: 4),
                              Text(
                                'A máximos: ${priceFormat.format(distToMaxAbs)} (${percentFormat.format(distToMaxRel)}%)',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
              /* Text(
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
              ), */
              //const SizedBox(height: 8),
              /* Text(
                'Actualizado: ${DateFormat('dd/MM/yyyy').format(fund.date)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Colors.white38),
              ), */
              //const SizedBox(height: 6),
              /* FutureBuilder<DateTime?>(
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
              ), */
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
              _buildStatsGrid(context, meanVal, maxPoint, minPoint),
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
            FutureBuilder<String?>(
              future: _getCnmvUrl(context),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => launchUrl(
                        Uri.parse(snapshot.data!),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          /*color: const Color(0xFF003D7C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF003D7C).withValues(
                              alpha: 0.4,
                            ),
                          ),*/
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA50A37),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'CNMV',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Consulta en el Registro Oficial',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.open_in_new,
                              size: 14,
                              color: Colors.blueAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const Divider(height: 32, color: Colors.white10),
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
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, double meanVal, PricePoint? maxPoint, PricePoint? minPoint) {
    if (fund.history.isEmpty) return const SizedBox.shrink();

    final returns = <double>[];

    for (int i = 0; i < fund.history.length; i++) {
      final point = fund.history[i];
      if (i > 0) {
        final previousPrice = fund.history[i - 1].price;
        if (previousPrice != 0) {
          returns.add((point.price - previousPrice) / previousPrice);
        }
      }
    }

    double annualVolatility = 0;
    if (returns.isNotEmpty) {
      final meanReturn = returns.reduce((a, b) => a + b) / returns.length;
      final varianceSum = returns
          .map((value) => pow(value - meanReturn, 2).toDouble())
          .reduce((a, b) => a + b);
      annualVolatility = sqrt(varianceSum / returns.length) * sqrt(252) * 100;
    }

    // Cálculo de Max Drawdown y Tiempo de Recuperación
    double maxDrawdown = 0;
    double currentPeak = -1.0;
    double peakAtMDD = -1.0;
    DateTime? troughDate;

    for (var point in fund.history) {
      if (point.price > currentPeak) {
        currentPeak = point.price;
      }
      if (currentPeak > 0) {
        final drawdown = (point.price - currentPeak) / currentPeak;
        if (drawdown < maxDrawdown) {
          maxDrawdown = drawdown;
          troughDate = point.date;
          peakAtMDD = currentPeak;
        }
      }
    }

    String recoveryText = '---';
    if (troughDate != null && peakAtMDD > 0) {
      DateTime? recoveryDate;
      for (var point in fund.history) {
        if (point.date.isAfter(troughDate!) && point.price >= peakAtMDD) {
          recoveryDate = point.date;
          break;
        }
      }

      if (recoveryDate != null) {
        recoveryText = '${recoveryDate.difference(troughDate!).inDays} días';
      } else {
        final daysElapsed = DateTime.now().difference(troughDate!).inDays;
        recoveryText = '$daysElapsed días (en curso)';
      }
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
                maxPoint != null ? priceFormat.format(maxPoint.price) : '---',
                maxPoint != null ? format.format(maxPoint.date) : '',
                Colors.greenAccent[400]!,
                Icons.arrow_upward,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoItem(
                context,
                'Mínimo',
                minPoint != null ? priceFormat.format(minPoint.price) : '---',
                minPoint != null ? format.format(minPoint.date) : '',
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
                priceFormat.format(meanVal),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                context,
                'Max Drawdown',
                '${percentFormat.format(maxDrawdown * 100)}%',
                'Máxima Caída',
                Colors.redAccent[400]!,
                Icons.trending_down,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoItem(
                context,
                'Recuperación',
                recoveryText,
                'Desde el Trough',
                Colors.greenAccent[400]!,
                Icons.restore,
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
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
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            date,
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Future<String?> _getCnmvUrl(BuildContext context) async {
    try {
      final String response = await DefaultAssetBundle.of(context)
          .loadString('assets/files/fondos_armonizados.json');
      final List<dynamic> data = json.decode(response);
      for (final item in data) {
        final List<dynamic> isins = item['isins'] ?? [];
        if (isins.contains(fund.isin)) {
          return item['url'];
        }
      }
    } catch (e) {
      debugPrint('Error loading CNMV data: $e');
    }
    return null;
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
