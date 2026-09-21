import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/fund_provider.dart';
import '../../services/fund_scraper.dart';
import '../../utils/financial_calculator.dart';

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
      final newText =
          widget.fund.performanceFee?.toString().replaceAll('.', ',') ?? '';
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
    final metrics = FinancialCalculator.calculateFundMetrics(widget.fund);

    final profitColor =
        metrics.profitAbs >= 0
            ? Colors.greenAccent[400]!
            : Colors.redAccent[200]!;

    String annualizedReturnStr = '-';
    if (metrics.tae != 0 || metrics.days > 0) {
      annualizedReturnStr = '${widget.percentFormat.format(metrics.tae)}%';
    }

    String twrTotalStr =
        metrics.twrTotal != null
            ? '${widget.percentFormat.format(metrics.twrTotal! * 100)}%'
            : '-';
    String twrAnnualizedStr =
        metrics.twrAnnualized != null
            ? '${widget.percentFormat.format(metrics.twrAnnualized! * 100)}%'
            : '-';
    String mwrTotalStr =
        metrics.mwrTotal != null
            ? '${widget.percentFormat.format(metrics.mwrTotal! * 100)}%'
            : '-';
    String mwrAnnualizedStr =
        metrics.mwrAnnualized != null
            ? '${widget.percentFormat.format(metrics.mwrAnnualized! * 100)}%'
            : '-';

    String ageStr = '-';
    if (metrics.days > 0) {
      if (metrics.days < 60) {
        ageStr = '${metrics.days} días';
      } else if (metrics.days < 365) {
        ageStr = '${metrics.days ~/ 30} meses';
      } else {
        final years = metrics.days ~/ 365;
        final months = (metrics.days % 365) ~/ 30;
        if (months == 0) {
          ageStr = years == 1 ? '1 año' : '$years años';
        } else {
          ageStr =
              '$years ${years == 1 ? 'año' : 'años'} y $months ${months == 1 ? 'mes' : 'meses'}';
        }
      }
    }

    final smartFormat = NumberFormat('#,##0.####', 'es_ES');

    // Cálculos de costes de gestión
    final fixedFee = widget.fund.ter ?? 0.0;
    final perfFee = widget.fund.performanceFee ?? 0.0;

    // 1. Costes Fijos (sobre valor actual)
    final estFixedAnnualCost = metrics.currentValue * (fixedFee / 100);

    // 2. Comisión de Resultados (sobre plusvalía bruta si es positiva)
    final estPerfAnnualCost =
        metrics.profitAbs > 0 ? metrics.profitAbs * (perfFee / 100) : 0.0;

    final totalEstAnnualCost = estFixedAnnualCost + estPerfAnnualCost;
    final totalEstMonthlyCost = totalEstAnnualCost / 12;

    // Cálculo de Plusvalía Neta (Estimación histórica acumulada)
    double netProfit = metrics.profitAbs;
    double netProfitPercent = metrics.profitRel;
    double totalAccumulatedCost = 0.0;

    if ((fixedFee > 0 || perfFee > 0) && metrics.days > 0) {
      final double yearsHeld = metrics.days / 365.25;

      // Estimación costes fijos: media entre inversión inicial y actual por tiempo
      final accumulatedFixed =
          ((metrics.currentValue + metrics.totalInvested) / 2) *
          (fixedFee / 100) *
          yearsHeld;

      // Estimación comisión resultados: aplicada sobre la plusvalía actual
      final accumulatedPerf =
          metrics.profitAbs > 0 ? metrics.profitAbs * (perfFee / 100) : 0.0;

      totalAccumulatedCost = accumulatedFixed + accumulatedPerf;
      netProfit = metrics.profitAbs - totalAccumulatedCost;
      netProfitPercent =
          metrics.totalInvested > 0
              ? (netProfit / metrics.totalInvested) * 100
              : 0.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBalanceRow(
          'Participaciones totales',
          metrics.totalUnits
              .toStringAsFixed(4)
              .replaceAll('.', ',')
              .replaceAll(RegExp(r',0000$'), ''),
        ),
        _buildBalanceRow(
          'Inversión neta',
          '${smartFormat.format(metrics.totalInvested)} ${widget.fund.currency}',
        ),
        _buildBalanceRow(
          'Precio medio compra',
          '${widget.priceFormat.format(metrics.avgPurchasePrice)} ${widget.fund.currency}',
        ),
        const Divider(height: 20, color: Colors.white10),
        _buildBalanceRow(
          'Valor actual',
          '${smartFormat.format(metrics.currentValue)} ${widget.fund.currency}',
          isBold: true,
          fontSize: 16,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              metrics.profitAbs > 0 ? 'Plusvalía Bruta' : 'Minusvalía Bruta',
              style: const TextStyle(color: Colors.white70),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${metrics.profitAbs > 0 ? '+' : ''}${smartFormat.format(metrics.profitAbs)} ${widget.fund.currency}',
                  style: TextStyle(
                    color: profitColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${metrics.profitRel > 0 ? '+' : ''}${widget.percentFormat.format(metrics.profitRel)}%',
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
                  final f = double.tryParse(
                    _fixedFeeController.text.replaceAll(',', '.'),
                  );
                  final p = double.tryParse(
                    _perfFeeController.text.replaceAll(',', '.'),
                  );
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
                  final f = double.tryParse(
                    _fixedFeeController.text.replaceAll(',', '.'),
                  );
                  final p = double.tryParse(
                    _perfFeeController.text.replaceAll(',', '.'),
                  );
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
                annualizedReturnStr,
                color: profitColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleStat(
                'Multiplicador (MoIC)',
                '${metrics.moic.toStringAsFixed(2)}x',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSimpleStat('TWR (Total)', twrTotalStr)),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleStat(
                'TWR Anualizado',
                twrAnnualizedStr,
                color: profitColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSimpleStat('MWR Acumulado', mwrTotalStr)),
            const SizedBox(width: 12),
            Expanded(child: _buildSimpleStat('MWR Anualizado', mwrAnnualizedStr)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSimpleStat('Antigüedad', ageStr)),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleStat(
                'Break-even',
                widget.priceFormat.format(metrics.avgPurchasePrice),
              ),
            ),
          ],
        ),
      ],
    );
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
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white38,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: '0,00',
              hintStyle: const TextStyle(color: Colors.white12),
              suffixText: suffix,
              suffixStyle: const TextStyle(color: Colors.white24, fontSize: 9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
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
              Text(
                'Rentabilidades brutas sin consideración de costes ni comisiones.',
              ),
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
