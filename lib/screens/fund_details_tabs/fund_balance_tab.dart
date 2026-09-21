import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/fund_provider.dart';
import '../../services/fund_scraper.dart';

class FundBalanceTab extends StatefulWidget {
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
  State<FundBalanceTab> createState() => _FundBalanceTabState();
}

class _FundBalanceTabState extends State<FundBalanceTab> {
  late TextEditingController _fixedFeeController;
  late TextEditingController _perfFeeController;

  @override
  void initState() {
    super.initState();
    _fixedFeeController = TextEditingController(
      text: widget.fund.ter?.toString().replaceAll('.', ',') ?? '',
    );
    _perfFeeController = TextEditingController(
      text: widget.fund.performanceFee?.toString().replaceAll('.', ',') ?? '',
    );
  }

  @override
  void didUpdateWidget(FundBalanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fund.ter != widget.fund.ter) {
      final newText = widget.fund.ter?.toString().replaceAll('.', ',') ?? '';
      if (_fixedFeeController.text != newText) {
        _fixedFeeController.text = newText;
      }
    }
    if (oldWidget.fund.performanceFee != widget.fund.performanceFee) {
      final newText = widget.fund.performanceFee?.toString().replaceAll('.', ',') ?? '';
      if (_perfFeeController.text != newText) {
        _perfFeeController.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _fixedFeeController.dispose();
    _perfFeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double totalUnits = 0;
    double totalInvested = 0;
    DateTime? firstOperationDate;

    for (final operation in widget.fund.operations) {
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

    final currentValue = totalUnits * widget.fund.lastValue;
    final profit = currentValue - totalInvested;
    final profitPercent =
        totalInvested > 0 ? (profit / totalInvested) * 100 : 0.0;
    final profitColor =
        profit >= 0 ? Colors.greenAccent[400]! : Colors.redAccent[200]!;
    final averagePurchasePrice = totalUnits > 0 ? totalInvested / totalUnits : 0;
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
        annualizedReturn = '${widget.percentFormat.format(annualized)}%';

        final initialPricePoint = widget.fund.history.cast<PricePoint?>().firstWhere(
          (point) =>
              point!.date.year == firstOperationDate!.year &&
              point.date.month == firstOperationDate.month &&
              point.date.day == firstOperationDate.day,
          orElse:
              () =>
                  widget.fund.history.isNotEmpty
                      ? widget.fund.history.first
                      : null,
        );
        if (initialPricePoint != null && initialPricePoint.price > 0) {
          final twr = (widget.fund.lastValue / initialPricePoint.price) - 1;
          final twrAnnual = (pow(1 + twr, 1 / years) - 1) * 100;
          twrTotal = '${widget.percentFormat.format(twr * 100)}%';
          twrAnnualized = '${widget.percentFormat.format(twrAnnual)}%';
        }

        final flows = widget.fund.operations
            .map(
              (operation) => <String, Object>{
                'amount':
                    operation.type == OperationType.buy
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
          mwrAnnualized = '${widget.percentFormat.format(irr * 100)}%';
          final mwr = (pow(1 + irr, years) - 1) * 100;
          mwrTotal = '${widget.percentFormat.format(mwr)}%';
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

    // Cálculos de costes de gestión
    final fixedFee = widget.fund.ter ?? 0.0;
    final perfFee = widget.fund.performanceFee ?? 0.0;
    
    // 1. Costes Fijos (sobre valor actual)
    final estFixedAnnualCost = currentValue * (fixedFee / 100);
    
    // 2. Comisión de Resultados (sobre plusvalía bruta si es positiva)
    final estPerfAnnualCost = profit > 0 ? profit * (perfFee / 100) : 0.0;
    
    final totalEstAnnualCost = estFixedAnnualCost + estPerfAnnualCost;
    final totalEstMonthlyCost = totalEstAnnualCost / 12;

    // Cálculo de Plusvalía Neta (Estimación histórica acumulada)
    double netProfit = profit;
    double netProfitPercent = profitPercent;
    double totalAccumulatedCost = 0.0;

    if ((fixedFee > 0 || perfFee > 0) && days > 0) {
      final double yearsHeld = days / 365.25;
      
      // Estimación costes fijos: media entre inversión inicial y actual por tiempo
      final accumulatedFixed = ((currentValue + totalInvested) / 2) * (fixedFee / 100) * yearsHeld;
      
      // Estimación comisión resultados: aplicada sobre la plusvalía actual
      final accumulatedPerf = profit > 0 ? profit * (perfFee / 100) : 0.0;
      
      totalAccumulatedCost = accumulatedFixed + accumulatedPerf;
      netProfit = profit - totalAccumulatedCost;
      netProfitPercent =
          totalInvested > 0 ? (netProfit / totalInvested) * 100 : 0.0;
    }

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
          '${smartFormat.format(totalInvested)} ${widget.fund.currency}',
        ),
        _buildBalanceRow(
          'Precio medio compra',
          '${widget.priceFormat.format(averagePurchasePrice)} ${widget.fund.currency}',
        ),
        const Divider(height: 20, color: Colors.white10),
        _buildBalanceRow(
          'Valor actual',
          '${smartFormat.format(currentValue)} ${widget.fund.currency}',
          isBold: true,
          fontSize: 16,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Plusvalía Bruta',
              style: TextStyle(color: Colors.white70),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${profit > 0 ? '+' : ''}${smartFormat.format(profit)} ${widget.fund.currency}',
                  style: TextStyle(
                    color: profitColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${profitPercent > 0 ? '+' : ''}${widget.percentFormat.format(profitPercent)}%',
                  style: TextStyle(
                    color: profitColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (totalAccumulatedCost > 0) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ganancia Real',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '(Plusvalía Neta est.)',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${netProfit > 0 ? '+' : ''}${smartFormat.format(netProfit)} ${widget.fund.currency}',
                    style: TextStyle(
                      color:
                          netProfit >= 0
                              ? Colors.greenAccent[400]
                              : Colors.redAccent[200],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${netProfitPercent > 0 ? '+' : ''}${widget.percentFormat.format(netProfitPercent)}%',
                    style: TextStyle(
                      color:
                          netProfit >= 0
                              ? Colors.greenAccent[400]
                              : Colors.redAccent[200],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
        const Divider(height: 32, color: Colors.white10),
        
        // SECCIÓN COSTES DE GESTIÓN
        const Text(
          'Costes de Gestión',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFeeInput(
                label: 'Gastos Corrientes',
                hint: 'Fijos',
                suffix: '% TER',
                controller: _fixedFeeController,
                onSave: () {
                  final f = double.tryParse(_fixedFeeController.text.replaceAll(',', '.'));
                  final p = double.tryParse(_perfFeeController.text.replaceAll(',', '.'));
                  context.read<FundProvider>().setFees(widget.fund.isin, f, p);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeeInput(
                label: 'Com. Resultados',
                hint: 'Sobre éxito',
                suffix: '% Var',
                controller: _perfFeeController,
                onSave: () {
                  final f = double.tryParse(_fixedFeeController.text.replaceAll(',', '.'));
                  final p = double.tryParse(_perfFeeController.text.replaceAll(',', '.'));
                  context.read<FundProvider>().setFees(widget.fund.isin, f, p);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSimpleStat(
                'Coste Anual Est.',
                '${smartFormat.format(totalEstAnnualCost)} ${widget.fund.currency}',
                color: Colors.orangeAccent.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleStat(
                'Coste Mensual Est.',
                '${smartFormat.format(totalEstMonthlyCost)} ${widget.fund.currency}',
                color: Colors.orangeAccent.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        
        const Divider(height: 40, color: Colors.white10),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              'Índices de Rentabilidad',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 15,
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
                widget.priceFormat.format(averagePurchasePrice),
              ),
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

  Widget _buildFeeInput({
    required String label,
    required String hint,
    required String suffix,
    required TextEditingController controller,
    required VoidCallback onSave,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '0,00',
              hintStyle: const TextStyle(color: Colors.white12),
              suffixText: suffix,
              suffixStyle: const TextStyle(color: Colors.white24, fontSize: 9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
              ),
            ),
            onSubmitted: (_) => onSave(),
            onTapOutside: (_) {
              onSave();
              FocusManager.instance.primaryFocus?.unfocus();
            },
          ),
        ),
      ],
    );
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
              fontSize: 11,
              color: Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 13,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.white : Colors.white70,
              fontSize: fontSize,
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
              const Text('Rentabilidades brutas sin consideración de costes ni comisiones.'),
              _IndexInfoRow(
                title: 'Rent. Anualizada (TAE)',
                description:
                    'Rentabilidad simple de TU inversión basándose en el capital total aportado y el tiempo transcurrido.',
              ),
              _IndexInfoRow(
                title: 'TWR (Total / Anualizado)',
                description:
                    'Time-Weighted Return. Mide el rendimiento del FONDO, eliminando el impacto de tus entradas y salidas de dinero. Es la rentabilidad del activo en sí.',
              ),
              _IndexInfoRow(
                title: 'MWR (Total / Anualizado)',
                description:
                    'Money-Weighted Return (o TIR). Rentabilidad real de tu bolsillo que tiene en cuenta el momento exacto de cada aportación. Refleja tu éxito como inversor al elegir cuándo entrar y salir.',
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
