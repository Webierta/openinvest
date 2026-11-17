import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../models/fund_data.dart';
import '../providers/fund_provider.dart';
import '../screens/fund_details_page.dart';
import '../utils/financial_calculator.dart';
import 'circle_avatar_fund.dart';
import 'history_chart_painter.dart';

class BuildFundCard extends StatelessWidget {
  final FundData fund;

  const BuildFundCard({super.key, required this.fund});

  @override
  Widget build(BuildContext context) {
    return Selector<FundProvider, _FundCardInputs?>(
      selector: (_, provider) => _FundCardInputs.fromProvider(provider, fund),
      shouldRebuild: (previous, next) => previous == null || next == null
          ? previous != next
          : !previous.hasSameDataAs(next),
      builder: (context, inputs, _) {
        if (inputs == null) return const SizedBox.shrink();

        final fund = inputs.fund;
        final metrics = FinancialCalculator.calculateFundMetrics(fund);
        final locale = Localizations.localeOf(context).toString();
        final priceFormat = NumberFormat('#,##0.0000', locale);
        final percentFormat = NumberFormat('#,##0.00', locale);
        final smartFormat = NumberFormat('#,##0.##', locale);

        double? dailyVariation;
        Color? dailyVarColor;
        if (fund.history.length > 1) {
          final prev = fund.history[fund.history.length - 2].price;
          if (prev != 0) {
            dailyVariation = ((fund.lastValue - prev) / prev) * 100;
            if (dailyVariation > 0) {
              dailyVarColor = Colors.greenAccent[400];
            } else if (dailyVariation < 0) {
              dailyVarColor = Colors.redAccent[200];
            }
          }
        }

        return Builder(
          builder: (cardContext) => _buildCard(
            cardContext,
            fund,
            metrics,
            dailyVariation,
            dailyVarColor,
            priceFormat,
            percentFormat,
            smartFormat,
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    FundData fund,
    FundMetrics metrics,
    double? dailyVariation,
    Color? dailyVarColor,
    NumberFormat priceFormat,
    NumberFormat percentFormat,
    NumberFormat smartFormat,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final hasOps = fund.operations.isNotEmpty;
    final profitColor = metrics.profitAbs > 0
        ? Colors.greenAccent
        : metrics.profitAbs < 0
        ? Colors.redAccent
        : Colors.blueGrey.shade200;

    final chartValues = fund.history
        .where((point) => point.price > 0 && point.price.isFinite)
        .map((point) => point.price)
        .toList();

    final chartColor =
        chartValues.length < 2 || chartValues.last == chartValues.first
        ? Colors.blueGrey.shade300
        : chartValues.last > chartValues.first
        ? Colors.greenAccent
        : Colors.redAccent;

    final hasAlert =
        (fund.alertMin != null && fund.lastValue <= fund.alertMin!) ||
        (fund.alertMax != null && fund.lastValue >= fund.alertMax!);

    final cardDecoration = BoxDecoration(
      borderRadius: .circular(20),
      gradient: const LinearGradient(
        begin: .topLeft,
        end: .bottomRight,
        colors: [Color(0xFF192A40), Color(0xFF101C30)],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );

    String symbolCurrency = fund.currency;
    if (fund.currency == 'EUR') {
      symbolCurrency = '€';
    } else if (fund.currency == 'USD') {
      symbolCurrency = '\$';
    }

    return Padding(
      padding: const .fromLTRB(16, 9, 16, 9),
      child: Container(
        decoration: cardDecoration,
        child: Material(
          color: Colors.transparent,
          borderRadius: .circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              final provider = context.read<FundProvider>();
              provider.selectFund(fund);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FundDetailsPage(),
                ),
              );
            },
            child: Padding(
              padding: const .fromLTRB(16, 15, 16, 12),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  // CABECERA: identidad
                  FittedBox(
                    child: Row(
                      children: [
                        Hero(
                          tag: 'avatar_${fund.isin}',
                          child: CircleAvatarFund(
                            fund: fund,
                            radius: 40,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: .start,
                          children: [
                            Hero(
                              tag: 'name_${fund.isin}',
                              child: Material(
                                color: Colors.transparent,
                                child: FittedBox(
                                  child: Row(
                                    children: [
                                      Text(
                                        fund.name,
                                        maxLines: 1,
                                        overflow: .ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: .w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              fund.isin,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // COTIZACIÓN
                  if (dailyVariation != null)
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: .circular(16),
                      ),
                      color: (dailyVarColor ?? Colors.blueGrey).withValues(
                        alpha: 0.12,
                      ),
                      child: Padding(
                        padding: const .symmetric(horizontal: 18, vertical: 16),
                        child: Row(
                          children: [
                            if (hasAlert) ...[
                              const Icon(
                                Icons.notifications_active_rounded,
                                color: Colors.amber,
                                size: 27,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                '${priceFormat.format(fund.lastValue)} ${fund.currency}',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: .w700),
                              ),
                            ),
                            Text(
                              '${dailyVariation > 0
                                  ? '\u25B2'
                                  : dailyVariation < 0
                                  ? '\u25BC'
                                  : '='} '
                              '${dailyVariation > 0 ? '+' : ''}'
                              '${percentFormat.format(dailyVariation)} %',
                              style: TextStyle(
                                color:
                                    dailyVarColor ?? Colors.blueGrey.shade200,
                                fontWeight: .w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // GRÁFICO DEL FONDO
                  if (chartValues.length >= 2)
                    SizedBox(
                      height: 65,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: HistoryChartPainter(
                          chartValues,
                          lineColor: chartColor,
                          fillColor: chartColor.withValues(alpha: 0.25),
                        ),
                      ),
                    ),

                  // MÉTRICAS
                  if (hasOps) ...[
                    const SizedBox(height: 9),
                    const Divider(height: 1, color: Colors.white12),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Valor
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              _FundMetricLabel(l10n.valueLabel),
                              FittedBox(
                                child: _FundMetricValue(
                                  '${smartFormat.format(metrics.currentValue)} $symbolCurrency',
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

                        // Rentabilidad acumulada
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              _FundMetricLabel(l10n.performanceLabel),
                              FittedBox(
                                child: Row(
                                  children: [
                                    _FundMetricValue(
                                      '${metrics.profitAbs > 0 ? '+' : ''}'
                                      '${smartFormat.format(metrics.profitAbs)} $symbolCurrency',
                                      color: profitColor,
                                    ),
                                    const SizedBox(width: 4),
                                    _FundMetricRelative(
                                      '${metrics.profitRel > 0 ? '+' : ''}'
                                      '${percentFormat.format(metrics.profitRel)} %',
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

                        // TAE
                        //if (fund.history.length > 30)
                        if (metrics.twrAnnualized != null)
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: .start,
                              children: [
                                const _FundMetricLabel('TWR'),
                                FittedBox(
                                  child: Container(
                                    padding: const .symmetric(
                                      horizontal: 7,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: profitColor.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                      borderRadius: .circular(16),
                                    ),
                                    child: Text(
                                      '${metrics.twrAnnualized! > 0 ? '+' : ''}'
                                      '${percentFormat.format(metrics.twrAnnualized! * 100)}%',
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: profitColor,
                                        fontSize: 11,
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
                  ],

                  // PIE: fecha de cotización y navegación
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: Colors.white70,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat.yMMMd(
                            Localizations.localeOf(context).toString(),
                          ).format(fund.date),
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FundCardInputs {
  final FundData fund;

  const _FundCardInputs(this.fund);

  static _FundCardInputs? fromProvider(FundProvider provider, FundData fund) {
    for (final portfolioFund in provider.portfolio) {
      if (portfolioFund.isin == fund.isin) {
        return _FundCardInputs(portfolioFund);
      }
    }
    return null;
  }

  bool hasSameDataAs(_FundCardInputs other) {
    final first = fund;
    final second = other.fund;
    return first.isin == second.isin &&
        first.name == second.name &&
        first.lastValue == second.lastValue &&
        first.currency == second.currency &&
        first.date == second.date &&
        first.alertMin == second.alertMin &&
        first.alertMax == second.alertMax &&
        _sameHistory(first.history, second.history) &&
        _sameOperations(first.operations, second.operations);
  }

  bool _sameHistory(List<PricePoint> first, List<PricePoint> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].date != second[index].date ||
          first[index].price != second[index].price) {
        return false;
      }
    }
    return true;
  }

  bool _sameOperations(List<FundOperation> first, List<FundOperation> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      final firstOperation = first[index];
      final secondOperation = second[index];
      if (firstOperation.date != secondOperation.date ||
          firstOperation.type != secondOperation.type ||
          firstOperation.units != secondOperation.units ||
          firstOperation.price != secondOperation.price ||
          firstOperation.amount != secondOperation.amount) {
        return false;
      }
    }
    return true;
  }
}

class _FundMetricLabel extends StatelessWidget {
  final String value;

  const _FundMetricLabel(this.value);

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

class _FundMetricValue extends StatelessWidget {
  final String value;
  final Color? color;

  const _FundMetricValue(this.value, {this.color = Colors.white});

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

class _FundMetricRelative extends StatelessWidget {
  final String value;
  final Color color;

  const _FundMetricRelative(this.value, this.color);

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
