import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/fund_data.dart';
import '../../providers/fund_provider.dart';
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
  late FundMetrics metrics;
  String twrAnnualizedIpcStr = '-';
  String mwrAnnualizedIpcStr = '-';
  String ineIpcVariationStr = 'ND';
  bool _isIpcLoading = false;

  @override
  void initState() {
    metrics = FinancialCalculator.calculateFundMetrics(widget.fund);
    _loadIpcData();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant FundBalanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el fondo cambia (ej. el usuario selecciona otro fondo en el TabBar)
    if (oldWidget.fund.isin != widget.fund.isin) {
      metrics = FinancialCalculator.calculateFundMetrics(widget.fund);
      twrAnnualizedIpcStr = '-';
      mwrAnnualizedIpcStr = '-';
      _isIpcLoading = false;
      _loadIpcData();
    }
  }

  Future<void> _loadIpcData() async {
    if (widget.fund.operations.isEmpty) return;

    setState(() {
      _isIpcLoading = true;
    });

    final provider = context.read<FundProvider>();
    if (provider.ipcHistory == null) {
      await provider.loadIpcHistory();
    }
    final ipcHistory = provider.ipcHistory;
    if (ipcHistory == null) return;

    // Protección: asegurar que haya historial de precios
    if (widget.fund.history.isEmpty) {
      if (mounted) {
        setState(() {
          _isIpcLoading = false;
          metrics = FinancialCalculator.calculateFundMetrics(widget.fund);
        });
      }
      return;
    }

    // Obtener fecha de primera operación
    // Ordenar las operaciones para asegurar que .first sea realmente el más antiguo
    final sortedOp = List.of(widget.fund.operations)
      ..sort((a, b) => a.date.compareTo(b.date));
    final dateFirstOp = sortedOp.first.date;

    // Obtener fecha de último precio
    // Ordenar el historial para asegurar que .last sea realmente el más reciente
    final sortedHistory = List.of(widget.fund.history)
      ..sort((a, b) => a.date.compareTo(b.date));
    final dateLastPrice = sortedHistory.last.date;

    // restar un mes para obtener el último ipc publicado
    final ipcVariation = FinancialCalculator.calculateIpcVariation(
      dateFirstOp.year,
      dateFirstOp.month,
      dateLastPrice.year,
      dateLastPrice.month - 1,
      ipcHistory,
    );

    /* // restar un mes para obtener el último ipc publicado
    final ipcVariation = await provider.getIpcVariation(
      dateFirstOp.year,
      dateFirstOp.month,
      dateLastPrice.year,
      dateLastPrice.month - 1,
    ); */

    if (mounted) {
      setState(() {
        _isIpcLoading = false;
        if (ipcVariation != null) {
          metrics = FinancialCalculator.calculateFundMetrics(
            widget.fund,
            inflationPercent: ipcVariation,
          );

          ineIpcVariationStr = '${widget.percentFormat.format(ipcVariation)}%';

          twrAnnualizedIpcStr = metrics.twrAnnualizedIpc != null
              ? '${widget.percentFormat.format(metrics.twrAnnualizedIpc!)}%'
              : '-';

          mwrAnnualizedIpcStr = metrics.mwrAnnualizedIpc != null
              ? '${widget.percentFormat.format(metrics.mwrAnnualizedIpc!)}%'
              : '-';
        } else {
          // Si no hay datos de IPC, mostramos las métricas normales
          metrics = FinancialCalculator.calculateFundMetrics(widget.fund);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    context.watch<FundProvider>();
    //final provider = context.watch<FundProvider>();
    final locale = Localizations.localeOf(context).toString();
    final smartFormat = NumberFormat('#,##0.##', locale);
    final unitsFormat = NumberFormat('#,##0.####', locale);
    //final metrics = FinancialCalculator.calculateFundMetrics(widget.fund);

    final profitColor = metrics.profitAbs >= 0
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;

    String annualizedReturnStr = '-';
    if (metrics.tae != 0 || metrics.days > 0) {
      annualizedReturnStr = '${widget.percentFormat.format(metrics.tae)}%';
    }

    String twrTotalStr = metrics.twrTotal != null
        ? '${widget.percentFormat.format(metrics.twrTotal! * 100)}%'
        : '-';
    String twrAnnualizedStr = metrics.twrAnnualized != null
        ? '${widget.percentFormat.format(metrics.twrAnnualized! * 100)}%'
        : '-';
    String mwrTotalStr = metrics.mwrTotal != null
        ? '${widget.percentFormat.format(metrics.mwrTotal! * 100)}%'
        : '-';
    String mwrAnnualizedStr = metrics.mwrAnnualized != null
        ? '${widget.percentFormat.format(metrics.mwrAnnualized! * 100)}%'
        : '-';

    String ageStr = '-';
    if (metrics.days > 0) {
      if (metrics.days < 60) {
        ageStr = l10n.daysCount(metrics.days);
      } else if (metrics.days < 365) {
        ageStr = l10n.monthsCount(metrics.days ~/ 30);
      } else {
        final years = metrics.days ~/ 365;
        final months = (metrics.days % 365) ~/ 30;
        if (months == 0) {
          ageStr = l10n.yearsCount(years);
        } else {
          ageStr =
              '${l10n.yearsCount(years)} ${l10n.andLabel} ${l10n.monthsCount(months)}';
        }
      }
    }

    final netProfit = metrics.netProfit;
    final netProfitPercent = metrics.netProfitRel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBalanceRow(
          l10n.totalUnitsLabel,
          unitsFormat.format(metrics.totalUnits),
        ),
        _buildBalanceRow(
          l10n.netInvestmentLabel,
          '${smartFormat.format(metrics.totalInvested)} ${widget.fund.currency}',
        ),
        _buildBalanceRow(
          l10n.avgPurchasePriceLabel,
          '${widget.priceFormat.format(metrics.avgPurchasePrice)} ${widget.fund.currency}',
        ),
        const Divider(height: 20, color: Colors.white10),
        _buildBalanceRow(
          l10n.currentValueLabel,
          '${smartFormat.format(metrics.currentValue)} ${widget.fund.currency}',
          isBold: true,
          fontSize: 16,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              metrics.profitAbs > 0
                  ? l10n.grossProfitLabel
                  : l10n.grossLossLabel,
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
        if (metrics.recordedExternalCosts > 0) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.realGainLabel,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    l10n.netProfitRecordedLabel,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${netProfit > 0 ? '+' : ''}${smartFormat.format(netProfit)} ${widget.fund.currency}',
                    style: TextStyle(
                      color: netProfit >= 0
                          ? Colors.greenAccent[400]
                          : Colors.redAccent[200],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${netProfitPercent > 0 ? '+' : ''}${widget.percentFormat.format(netProfitPercent)}%',
                    style: TextStyle(
                      color: netProfit >= 0
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
        const Divider(height: 40, color: Colors.white10),
        Row(
          children: [
            Text(
              l10n.profitabilityIndicesTitle,
              style: const TextStyle(
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
                l10n.annualizedReturnLabel,
                annualizedReturnStr,
                color: profitColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleStat(
                l10n.moicLabel,
                '${metrics.moic.toStringAsFixed(2)}x',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSimpleStat(l10n.twrTotalLabel, twrTotalStr)),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleStat(
                l10n.twrAnnualizedLabel,
                twrAnnualizedStr,
                color: profitColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSimpleStat(l10n.mwrHistoricalLabel, mwrTotalStr),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleStat(
                l10n.mwrAnnualizedLabel,
                mwrAnnualizedStr,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSimpleStat(
                'TWR Real (vs IPC: $ineIpcVariationStr)',
                _isIpcLoading ? '...' : twrAnnualizedIpcStr,
                color: _getIpcColor(metrics.twrAnnualizedIpc),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleStat(
                'MWR Real (vs IPC: $ineIpcVariationStr)',
                _isIpcLoading ? '...' : mwrAnnualizedIpcStr,
                color: _getIpcColor(metrics.mwrAnnualizedIpc),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSimpleStat(l10n.ageLabel, ageStr)),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSimpleStat(
                l10n.breakEvenLabel,
                widget.priceFormat.format(metrics.avgPurchasePrice),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper para colorear la rentabilidad real (Verde si supera al IPC, Rojo si no)
  Color? _getIpcColor(double? realReturn) {
    if (realReturn == null) return Colors.white70;
    return realReturn > 0 ? Colors.greenAccent[400] : Colors.redAccent[200];
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.financialIndicesTitle,
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                    _IndexInfoRow(
                      title: l10n.annualizedReturnLabel,
                      description: l10n.aprTaeDesc,
                    ),
                    _IndexInfoRow(
                      title: l10n.twrInfoTitle,
                      description: l10n.twrDesc,
                    ),
                    _IndexInfoRow(
                      title: l10n.mwrInfoTitle,
                      description: l10n.mwrIrrDesc,
                    ),
                    _IndexInfoRow(
                      title: 'TWR y MWR reales (vs IPC)',
                      description:
                          'Rentabilidades anualizadas considerando la inflacción (IPC de España) en base a la ecuación de Fisher. '
                          'TWR-IPC representa el rendimiento efectivo del fondo y MWR-IPC el rendimiento real del dinero invertido. '
                          'La aplicación calcula la variación del IPC desde la fecha de la primera suscripción hasta un mes antes del último precio liquidativo, '
                          'sin tener en cuenta posteriores suscripciones o reembolsos.',
                    ),
                    _IndexInfoRow(
                      title: l10n.moicLabel,
                      description: l10n.moicDesc,
                    ),
                    _IndexInfoRow(
                      title: l10n.ageLabel,
                      description: l10n.ageDesc,
                    ),
                    _IndexInfoRow(
                      title: l10n.breakEvenLabel,
                      description: l10n.breakEvenDesc,
                    ),
                    Text(
                      l10n.bruteReturnsNote,
                      style: TextStyle(fontSize: 12, color: Colors.white30),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: CircleAvatar(
                  child: CloseButton(
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      /* builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF38BDF8)),
            const SizedBox(width: 10),
            Text(l10n.financialIndicesTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.bruteReturnsNote),
              _IndexInfoRow(
                title: l10n.annualizedReturnLabel,
                description: l10n.aprTaeDesc,
              ),
              _IndexInfoRow(
                title: l10n.twrInfoTitle,
                description: l10n.twrDesc,
              ),
              _IndexInfoRow(
                title: l10n.mwrInfoTitle,
                description: l10n.mwrIrrDesc,
              ),
              _IndexInfoRow(title: l10n.moicLabel, description: l10n.moicDesc),
              _IndexInfoRow(title: l10n.ageLabel, description: l10n.ageDesc),
              _IndexInfoRow(
                title: l10n.breakEvenLabel,
                description: l10n.breakEvenDesc,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ), */
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
