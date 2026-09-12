import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/fund_scraper.dart';

class FundBalanceTab extends StatelessWidget {
  final FundData fund;
  final NumberFormat priceFormat;
  final NumberFormat percentFormat;

  const FundBalanceTab({
    super.key,
    required this.fund,
    required this.priceFormat,
    required this.percentFormat,
  });

  @override
  Widget build(BuildContext context) {
    double totalUnits = 0;
    double totalInvested = 0;
    DateTime? firstOperationDate;

    for (final operation in fund.operations) {
      if (operation.type == OperationType.buy) {
        totalUnits += operation.units;
        totalInvested += operation.amount;
      } else {
        totalUnits -= operation.units;
        totalInvested -= operation.amount;
      }
      if (firstOperationDate == null ||
          operation.date.isBefore(firstOperationDate)) {
        firstOperationDate = operation.date;
      }
    }

    final currentValue = totalUnits * fund.lastValue;
    final profit = currentValue - totalInvested;
    final profitPercent = totalInvested > 0
        ? (profit / totalInvested) * 100
        : 0;
    final profitColor = profit >= 0
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;
    final averagePurchasePrice = totalUnits > 0
        ? totalInvested / totalUnits
        : 0;
    final moic = totalInvested > 0 ? currentValue / totalInvested : 0;

    String annualizedReturn = '-';
    String twrTotal = '-';
    String twrAnnualized = '-';
    String mwrTotal = '-';
    String mwrAnnualized = '-';
    int days = 0;

    if (firstOperationDate != null && totalInvested > 0) {
      days = DateTime.now().difference(firstOperationDate).inDays;
      if (days > 0) {
        final years = days / 365.25;
        final annualized =
            (pow(currentValue / totalInvested, 1 / years) - 1) * 100;
        annualizedReturn = '${percentFormat.format(annualized)}%';

        final initialPricePoint = fund.history.cast<PricePoint?>().firstWhere(
          (point) =>
              point!.date.year == firstOperationDate!.year &&
              point.date.month == firstOperationDate.month &&
              point.date.day == firstOperationDate.day,
          orElse: () => fund.history.isNotEmpty ? fund.history.first : null,
        );
        if (initialPricePoint != null && initialPricePoint.price > 0) {
          final twr = (fund.lastValue / initialPricePoint.price) - 1;
          final twrAnnual = (pow(1 + twr, 1 / years) - 1) * 100;
          twrTotal = '${percentFormat.format(twr * 100)}%';
          twrAnnualized = '${percentFormat.format(twrAnnual)}%';
        }

        final flows = fund.operations
            .map(
              (operation) => <String, Object>{
                'amount': operation.type == OperationType.buy
                    ? -operation.amount
                    : operation.amount,
                'date': operation.date,
              },
            )
            .toList();
        flows.add(<String, Object>{
          'amount': currentValue,
          'date': DateTime.now(),
        });

        final irr = _calculateIrr(flows);
        if (!irr.isNaN) {
          mwrAnnualized = '${percentFormat.format(irr * 100)}%';
          final mwr = (pow(1 + irr, years) - 1) * 100;
          mwrTotal = '${percentFormat.format(mwr)}%';
        }
      }
    }

    String age = '-';
    if (days > 0) {
      if (days < 60) {
        age = '$days días';
      } else if (days < 365) {
        age = '${days ~/ 30} meses';
      } else {
        final years = days ~/ 365;
        final months = (days % 365) ~/ 30;
        if (months == 0) {
          age = years == 1 ? '1 año' : '$years años';
        } else {
          age =
              '$years ${years == 1 ? 'año' : 'años'} y $months ${months == 1 ? 'mes' : 'meses'}';
        }
      }
    }

    final smartFormat = NumberFormat('#,##0.####', 'es_ES');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBalanceRow(
          'Participaciones totales',
          totalUnits
              .toStringAsFixed(4)
              .replaceAll('.', ',')
              .replaceAll(RegExp(r',0000$'), ''),
        ),
        _buildBalanceRow(
          'Inversión neta',
          '${smartFormat.format(totalInvested)} ${fund.currency}',
        ),
        _buildBalanceRow(
          'Precio medio compra',
          '${priceFormat.format(averagePurchasePrice)} ${fund.currency}',
        ),
        _buildBalanceRow(
          'Valor actual',
          '${smartFormat.format(currentValue)} ${fund.currency}',
          isBold: true,
        ),
        const Divider(height: 32, color: Colors.white10),
        Row(
          children: [
            const Text(
              'Índices de Rentabilidad',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.white38,
              ),
              onPressed: () => _showIndicesInfo(context),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSimpleStat(
                'Rent. Anualizada',
                annualizedReturn,
                color: profitColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleStat(
                'Multiplicador (MoIC)',
                '${moic.toStringAsFixed(2)}x',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSimpleStat('TWR (Total)', twrTotal)),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleStat(
                'TWR Anualizado',
                twrAnnualized,
                color: profitColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSimpleStat('MWR Acumulado', mwrTotal)),
            const SizedBox(width: 12),
            Expanded(child: _buildSimpleStat('MWR Anualizado', mwrAnnualized)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSimpleStat('Antigüedad', age)),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleStat(
                'Break-even',
                priceFormat.format(averagePurchasePrice),
              ),
            ),
          ],
        ),
        const Divider(height: 32, color: Colors.white10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Plusvalía / Minusvalía',
              style: TextStyle(color: Colors.white70),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${profit > 0 ? '+' : ''}${smartFormat.format(profit)} ${fund.currency}',
                  style: TextStyle(
                    color: profitColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${profitPercent > 0 ? '+' : ''}${percentFormat.format(profitPercent)}%',
                  style: TextStyle(
                    color: profitColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  double _calculateIrr(List<Map<String, Object>> flows) {
    if (flows.isEmpty) return double.nan;

    double npv(double rate) {
      double total = 0;
      final start = flows.first['date'] as DateTime;
      for (final flow in flows) {
        final time =
            (flow['date'] as DateTime).difference(start).inDays / 365.25;
        total += (flow['amount'] as double) / pow(1 + rate, time);
      }
      return total;
    }

    double low = -0.99;
    double high = 2.0;
    for (int i = 0; i < 50; i++) {
      final middle = (low + high) / 2;
      if (npv(middle) > 0) {
        low = middle;
      } else {
        high = middle;
      }
      if ((high - low).abs() < 1e-6) break;
    }
    return (low + high) / 2;
  }

  Widget _buildSimpleStat(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white38,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.white : Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _showIndicesInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text('Índices Financieros'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IndexInfoRow(
                title: 'Rent. Anualizada (TAE)',
                description: 'Rentabilidad simple de TU inversión basándose en el capital total aportado y el tiempo transcurrido.',
              ),
              _IndexInfoRow(
                title: 'TWR (Total / Anualizado)',
                description: 'Time-Weighted Return. Mide el rendimiento del FONDO, eliminando el impacto de tus entradas y salidas de dinero. Es la rentabilidad del activo en sí.',
              ),
              _IndexInfoRow(
                title: 'MWR (Total / Anualizado)',
                description: 'Money-Weighted Return (o TIR). Rentabilidad real de tu bolsillo que tiene en cuenta el momento exacto de cada aportación. Refleja tu éxito como inversor al elegir cuándo entrar y salir.',
              ),
              _IndexInfoRow(
                title: 'Multiplicador (MoIC)',
                description: 'Capital final obtenido por cada euro invertido.',
              ),
              _IndexInfoRow(
                title: 'Antigüedad',
                description: 'Tiempo transcurrido desde la primera operación.',
              ),
              _IndexInfoRow(
                title: 'Break-even',
                description: 'Precio necesario para no tener pérdidas.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _IndexInfoRow extends StatelessWidget {
  final String title;
  final String description;

  const _IndexInfoRow({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.3,
              color: Colors.white70,
            ),
          ),
          const Divider(color: Colors.white10),
        ],
      ),
    );
  }
}
