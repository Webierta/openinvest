import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../models/fund_data.dart';
import '../providers/fund_provider.dart';
import 'history_chart_painter.dart';
import '../utils/financial_calculator.dart';
import '../screens/portfolio_summary_page.dart';

typedef _DatedPricePoint = ({DateTime date, PricePoint point, int index});
typedef _DatedUnitChange = ({DateTime date, double units, int index});

class BuildPortfolioHeader extends StatelessWidget {
  const BuildPortfolioHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<FundProvider, _PortfolioHeaderInputs>(
      selector: (_, provider) => _PortfolioHeaderInputs.fromProvider(provider),
      shouldRebuild: (previous, next) => !previous.hasSameDataAs(next),
      builder: (context, inputs, _) {
        // portfolioMetrics
        final metrics = FinancialCalculator.calculateGlobalMetrics(
          inputs.portfolio,
          inputs.exchangeRates,
        );

        // Variación global entre las dos últimas valoraciones disponibles
        // de cada fondo, convertidas a euros.
        double dailyChangeAbs = 0;
        double previousPortfolioValue = 0;

        for (final fund in inputs.portfolio) {
          if (fund.history.length < 2) continue;

          final fundMetrics = FinancialCalculator.calculateFundMetrics(fund);
          final previousPrice = fund.history[fund.history.length - 2].price;
          final exchangeRate = inputs.exchangeRates[fund.currency] ?? 1.0;

          dailyChangeAbs +=
              fundMetrics.totalUnits *
              (fund.lastValue - previousPrice) *
              exchangeRate;

          previousPortfolioValue +=
              fundMetrics.totalUnits * previousPrice * exchangeRate;
        }

        final dailyChangePercent = previousPortfolioValue > 0
            ? dailyChangeAbs / previousPortfolioValue * 100
            : null;

        final portfolioHistory = _buildPortfolioHistory(
          inputs.portfolio,
          inputs.exchangeRates,
        );

        return Builder(
          builder: (headerContext) => _buildHeader(
            headerContext,
            inputs,
            metrics,
            dailyChangeAbs,
            dailyChangePercent,
            portfolioHistory,
          ),
        );
      },
    );
  }

  List<({DateTime date, double value})> _buildPortfolioHistory(
    List<FundData> funds,
    Map<String, double> exchangeRates,
  ) {
    DateTime dateOnly(DateTime date) =>
        DateTime(date.year, date.month, date.day);

    final dates = <DateTime>{};
    final histories = <List<_DatedPricePoint>>[];
    final unitChanges = <List<_DatedUnitChange>>[];

    for (final fund in funds) {
      final history = <_DatedPricePoint>[];
      for (var index = 0; index < fund.history.length; index++) {
        final point = fund.history[index];
        final date = dateOnly(point.date);
        history.add((date: date, point: point, index: index));
        if (point.price > 0 && point.price.isFinite) {
          dates.add(date);
        }
      }
      history.sort((a, b) {
        final dateComparison = a.date.compareTo(b.date);
        return dateComparison != 0
            ? dateComparison
            : a.index.compareTo(b.index);
      });
      histories.add(history);

      final changes = <_DatedUnitChange>[];
      for (var index = 0; index < fund.operations.length; index++) {
        final operation = fund.operations[index];
        final isInvestment =
            operation.type == .buy || operation.type == .inTransfer;
        changes.add((
          date: dateOnly(operation.date),
          units: isInvestment ? operation.units : -operation.units,
          index: index,
        ));
      }
      changes.sort((a, b) {
        final dateComparison = a.date.compareTo(b.date);
        return dateComparison != 0
            ? dateComparison
            : a.index.compareTo(b.index);
      });
      unitChanges.add(changes);
    }

    final sortedDates = dates.toList()..sort();
    final result = <({DateTime date, double value})>[];
    final historyIndexes = List<int>.filled(funds.length, 0);
    final operationIndexes = List<int>.filled(funds.length, 0);
    final quotes = List<PricePoint?>.filled(funds.length, null);
    final units = List<double>.filled(funds.length, 0);

    for (final date in sortedDates) {
      var portfolioValue = 0.0;

      for (var fundIndex = 0; fundIndex < funds.length; fundIndex++) {
        final history = histories[fundIndex];
        var historyIndex = historyIndexes[fundIndex];
        var quote = quotes[fundIndex];
        while (historyIndex < history.length &&
            !history[historyIndex].date.isAfter(date)) {
          final point = history[historyIndex].point;
          if (point.price > 0 && point.price.isFinite) {
            quote = point;
          }
          historyIndex++;
        }
        historyIndexes[fundIndex] = historyIndex;
        quotes[fundIndex] = quote;

        final changes = unitChanges[fundIndex];
        var operationIndex = operationIndexes[fundIndex];
        var fundUnits = units[fundIndex];
        while (operationIndex < changes.length &&
            !changes[operationIndex].date.isAfter(date)) {
          fundUnits += changes[operationIndex].units;
          operationIndex++;
        }
        operationIndexes[fundIndex] = operationIndex;
        units[fundIndex] = fundUnits;

        if (fundUnits <= 0 || quote == null) continue;

        final exchangeRate = exchangeRates[funds[fundIndex].currency] ?? 1.0;
        portfolioValue += fundUnits * quote.price * exchangeRate;
      }

      if (portfolioValue > 0 && portfolioValue.isFinite) {
        result.add((date: date, value: portfolioValue));
      }
    }

    return result;
  }

  Widget _buildHeader(
    BuildContext context,
    _PortfolioHeaderInputs inputs,
    GlobalMetrics metrics,
    double dailyChangeAbs,
    double? dailyChangePercent,
    List<({DateTime date, double value})> portfolioHistory,
  ) {
    final locale = Localizations.localeOf(context).toString();
    final l10n = AppLocalizations.of(context)!;
    final priceFormat = NumberFormat('#,##0.0000', locale);
    final percentFormat = NumberFormat('#,##0.00', locale);
    final smartFormat = NumberFormat('#,##0.##', locale);
    final currencyFormat = NumberFormat.currency(
      locale: locale,
      symbol: '€',
      decimalDigits: 2,
    );
    final accumulatedReturn = metrics.totalInvested > 0
        ? metrics.profitAbs / metrics.totalInvested * 100
        : 0.0;
    final profitColor = metrics.profitAbs >= 0
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;
    final dailyColor = dailyChangeAbs > 0
        ? Colors.greenAccent[400]!
        : dailyChangeAbs < 0
        ? Colors.redAccent[200]!
        : Colors.white70;

    return Padding(
      padding: const .fromLTRB(16, 12, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const .all(18),
        decoration: BoxDecoration(
          borderRadius: .circular(20),
          gradient: const LinearGradient(
            begin: .topLeft,
            end: .bottomRight,
            colors: [Color(0xFF263750), Color(0xFF172337)],
          ),
          border: .all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // CABECERA
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade900,
                  child: Icon(Icons.business_center, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.myPortfolioTitle,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: .w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // VALOR Y VARIACIÓN DIARIA
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: .circular(16)),
              color: Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: 0.3),
              child: Padding(
                padding: const .symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        currencyFormat.format(metrics.totalValue),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: .w700),
                      ),
                    ),
                    if (dailyChangePercent != null)
                      Text(
                        '${dailyChangePercent > 0
                            ? '\u25B2'
                            : dailyChangePercent < 0
                            ? '\u25BC'
                            : '='} '
                        '${dailyChangePercent > 0 ? '+' : ''}'
                        '${percentFormat.format(dailyChangePercent)} %',
                        style: TextStyle(
                          color: dailyColor,
                          fontWeight: .w600,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // GRAFICO
            if (portfolioHistory.length >= 2) ...[
              SizedBox(
                height: 65,
                width: double.infinity,
                child: CustomPaint(
                  painter: HistoryChartPainter(
                    portfolioHistory.map((point) => point.value).toList(),
                    strokeWidth: 2,
                  ),
                ),
              ),
            ],
            // MÉTRICAS
            const SizedBox(height: 9),
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 12),
            Row(
              children: [
                // Inversión
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      _HeaderMetricLabel(l10n.invested.toUpperCase()),
                      FittedBox(
                        child: _HeaderMetricValue(
                          '${smartFormat.format(metrics.totalInvested)} €',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: Colors.white30,
                  margin: const .symmetric(horizontal: 9),
                ),
                // Rentabilidad
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      _HeaderMetricLabel(l10n.performanceLabel),
                      FittedBox(
                        child: Row(
                          children: [
                            _HeaderMetricValue(
                              '${metrics.profitAbs > 0 ? '+' : ''}'
                              '${currencyFormat.format(metrics.profitAbs)}',
                              color: profitColor,
                            ),
                            const SizedBox(width: 4),
                            _HeaderMetricRelative(
                              '${accumulatedReturn > 0 ? '+' : ''}'
                              '${percentFormat.format(accumulatedReturn)}%',
                              profitColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: Colors.white30,
                  margin: const .symmetric(horizontal: 9),
                ),
                // MWR
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      _HeaderMetricLabel('MWR'),
                      FittedBox(
                        child: Container(
                          padding: const .symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            border: .all(
                              color: profitColor.withValues(alpha: 0.8),
                            ),
                            borderRadius: .circular(16),
                          ),
                          child: Text(
                            '${(metrics.mwrAnnualized != null && metrics.mwrAnnualized! > 0) ? '+' : ''}'
                            '${(metrics.mwrAnnualized != null) ? '${percentFormat.format(metrics.mwrAnnualized! * 100)}%' : ''}',
                            style: TextStyle(
                              color: profitColor,
                              fontSize: 12,
                              fontWeight: .bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // MARQUESINA
            const SizedBox(height: 10),
            const Divider(height: 1, color: Colors.white12),
            _PortfolioMarqueeTicker(
              funds: inputs.portfolio,
              priceFormat: priceFormat,
              percentFormat: percentFormat,
              velocity: 60,
            ),
            // PIE
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(Icons.assessment, color: Colors.white70, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.countFunds(inputs.portfolio.length),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PortfolioSummaryPage(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        l10n.viewDetails,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 21,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioHeaderInputs {
  final List<FundData> portfolio;
  final Map<String, double> exchangeRates;

  _PortfolioHeaderInputs({
    required this.portfolio,
    required this.exchangeRates,
  });

  factory _PortfolioHeaderInputs.fromProvider(FundProvider provider) {
    return _PortfolioHeaderInputs(
      portfolio: List<FundData>.unmodifiable(provider.portfolio),
      exchangeRates: Map<String, double>.unmodifiable(provider.exchangeRates),
    );
  }

  bool hasSameDataAs(_PortfolioHeaderInputs other) {
    return listEquals(portfolio, other.portfolio) &&
        mapEquals(exchangeRates, other.exchangeRates);
  }
}

class _HeaderMetricLabel extends StatelessWidget {
  final String value;

  const _HeaderMetricLabel(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: .ellipsis,
      style: const TextStyle(fontSize: 11, color: Colors.white70),
    );
  }
}

class _HeaderMetricValue extends StatelessWidget {
  final String value;
  final Color? color;

  const _HeaderMetricValue(this.value, {this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: .ellipsis,
      style: TextStyle(fontSize: 14, fontWeight: .bold, color: color),
    );
  }
}

class _HeaderMetricRelative extends StatelessWidget {
  final String value;
  final Color color;

  const _HeaderMetricRelative(this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(value, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _PortfolioMarqueeTicker extends StatefulWidget {
  final List<FundData> funds;
  final NumberFormat priceFormat;
  final NumberFormat percentFormat;
  final double velocity;

  const _PortfolioMarqueeTicker({
    required this.funds,
    required this.priceFormat,
    required this.percentFormat,
    required this.velocity,
  });

  @override
  State<_PortfolioMarqueeTicker> createState() =>
      _PortfolioMarqueeTickerState();
}

class _PortfolioMarqueeTickerState extends State<_PortfolioMarqueeTicker> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Espera a que el widget se renderice para iniciar la animación
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    if (!mounted || !_scrollController.hasClients) return;

    // Calculamos el tiempo basado en el desplazamiento máximo y la velocidad deseada

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (maxScrollExtent <= 0) return;

    final durationInMs = (maxScrollExtent / widget.velocity * 1000).toInt();
    if (durationInMs <= 0) return;

    _scrollController
        .animateTo(
          maxScrollExtent,
          duration: Duration(milliseconds: durationInMs),
          curve: Curves.linear,
          // Movimiento fluido y lineal sin aceleraciones
        )
        .then((_) {
          if (!mounted) return;
          // vuelve al inicio
          _scrollController.jumpTo(0);
          _startScrolling();
        });
  }

  @override
  void dispose() {
    // _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.funds.isEmpty) return const SizedBox(height: 45);

    return SizedBox(
      height: 45,
      child: Container(
        color: Colors.black87,
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          // Multiplicamos la lista para simular un bucle continuo fluido
          itemCount: widget.funds.length * 100,
          itemBuilder: (context, index) {
            // Conseguimos el índice real usando el operador módulo
            final fund = widget.funds[index % widget.funds.length];
            double? dailyVariation;
            Color? dailyVarColor;
            if (fund.history.length > 1) {
              final previousPrice = fund.history[fund.history.length - 2].price;
              if (previousPrice != 0) {
                dailyVariation =
                    ((fund.lastValue - previousPrice) / previousPrice) * 100;
                if (dailyVariation > 0) {
                  dailyVarColor = Colors.greenAccent[400];
                } else if (dailyVariation < 0) {
                  dailyVarColor = Colors.redAccent[200];
                } else {
                  dailyVarColor = Colors.blueGrey.shade200;
                }
              }
            }

            final variationArrow = dailyVariation == null
                ? ''
                : '${dailyVariation > 0 ? '\u25B2' : '\u25BC'} ';

            return Row(
              children: [
                const SizedBox(width: 12),
                Text(
                  variationArrow,
                  style: TextStyle(
                    color: dailyVarColor ?? Colors.blueGrey.shade200,
                    fontWeight: .w600,
                    fontSize: 18,
                  ),
                ),
                Text(
                  fund.name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: .w400,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.priceFormat.format(fund.lastValue)} ${fund.currency}',
                  style: TextStyle(
                    fontWeight: .bold,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: const Color(0xFF39FF14).withAlpha(180),
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (dailyVariation != null)
                  ColoredBox(
                    color:
                        Color.lerp(dailyVarColor, Colors.black, 0.3) ??
                        Colors.blueGrey.shade200,
                    child: Text(
                      ' ${dailyVariation > 0 ? '+' : ''}'
                      '${widget.percentFormat.format(dailyVariation)} % ',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(width: 12),
                // Separador visual entre cotizaciones
                const Text('|', style: TextStyle(color: Colors.white54)),
              ],
            );
          },
        ),
      ),
    );
  }
}
