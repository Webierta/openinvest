import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../models/fund_data.dart';
import '../providers/fund_provider.dart';
import '../widgets/circle_avatar_fund.dart';
import '../widgets/gradient_background.dart';
import '../widgets/portfolio_appbar.dart';
import '../widgets/error_banner.dart';
import '../widgets/app_drawer.dart';
import '../widgets/updating_indicator.dart';
import 'fund_search_page.dart';
import 'fund_details_page.dart';
import '../utils/route_observer.dart';
import '../utils/financial_calculator.dart';
import 'portfolio_summary_page.dart';

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> with RouteAware {
  bool _alertChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);

    final provider = context.read<FundProvider>();
    if (!_alertChecked && provider.triggeredAlerts.isNotEmpty) {
      _alertChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showTriggeredAlertsDialog(context, provider);
        }
      });
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    context.read<FundProvider>().clearError();
  }

  List<({DateTime date, double value})> _buildPortfolioHistory(
    List<FundData> funds,
    Map<String, double> exchangeRates,
  ) {
    final dates = <DateTime>{};

    for (final fund in funds) {
      for (final point in fund.history) {
        if (point.price > 0 && point.price.isFinite) {
          dates.add(
            DateTime(point.date.year, point.date.month, point.date.day),
          );
        }
      }
    }

    final sortedDates = dates.toList()..sort();
    final result = <({DateTime date, double value})>[];

    for (final date in sortedDates) {
      var portfolioValue = 0.0;

      for (final fund in funds) {
        final units = FinancialCalculator.calculateUnitsAt(fund, date);
        if (units <= 0) continue;

        PricePoint? quote;
        for (final point in fund.history) {
          final pointDate = DateTime(
            point.date.year,
            point.date.month,
            point.date.day,
          );

          if (pointDate.isAfter(date)) break;
          if (point.price > 0 && point.price.isFinite) {
            quote = point;
          }
        }

        if (quote == null) continue;

        final exchangeRate = exchangeRates[fund.currency] ?? 1.0;
        portfolioValue += units * quote.price * exchangeRate;
      }

      if (portfolioValue > 0 && portfolioValue.isFinite) {
        result.add((date: date, value: portfolioValue));
      }
    }

    return result;
  }

  // GETTERS
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  String get locale => Localizations.localeOf(context).toString();
  NumberFormat get priceFormat => NumberFormat('#,##0.0000', locale);
  NumberFormat get percentFormat => NumberFormat('#,##0.00', locale);
  NumberFormat get smartFormat => NumberFormat('#,##0.##', locale);
  DateFormat get dateFormat => DateFormat.yMMMd(locale);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FundProvider>();

    final globalMetrics = FinancialCalculator.calculateGlobalMetrics(
      provider.portfolio,
      provider.exchangeRates,
    );
    final bool showPortfolioSummary = globalMetrics.totalInvested > 0;

    // Variación global entre las dos últimas valoraciones disponibles
    // de cada fondo, convertidas a euros.
    double dailyChangeAbs = 0;
    double previousPortfolioValue = 0;

    for (final fund in provider.portfolio) {
      if (fund.history.length < 2) continue;

      final fundMetrics = FinancialCalculator.calculateFundMetrics(fund);
      final previousPrice = fund.history[fund.history.length - 2].price;
      final exchangeRate = provider.exchangeRates[fund.currency] ?? 1.0;

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

    return Stack(
      children: [
        Scaffold(
          extendBodyBehindAppBar: true,
          appBar: PortfolioAppbar(
            provider: provider,
            onRefresh: provider.updateAllPortfolio,
            onSortSelected: (criteria) {
              context.read<FundProvider>().setSortCriteria(criteria);
            },
            onClearPortfolio: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.clearPortfolioTitle),
                  content: Text(l10n.clearPortfolioConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () {
                        provider.clearPortfolio();
                        Navigator.pop(context);
                      },
                      child: Text(
                        l10n.delete,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          drawer: const AppDrawer(),
          body: GradientBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (provider.error != null || provider.info != null)
                    ErrorBanner(
                      message: provider.info ?? provider.error!,
                      isInfo: provider.info != null,
                      onRetry: provider.info != null
                          ? null
                          : provider.updateAllPortfolio,
                      onDismiss: provider.clearError,
                    ),

                  Expanded(
                    child: provider.hasPortfolioLoadError
                        ? Center(
                            child: Text(
                              l10n.portfolioLoadError,
                              textAlign: .center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          )
                        : provider.portfolio.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: .center,
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 80,
                                  color: Colors.white24,
                                ),
                                const SizedBox(height: 16),
                                Text(l10n.emptyPortfolio),
                                TextButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const FundSearchPage(),
                                    ),
                                  ),
                                  icon: const Icon(Icons.search),
                                  label: Text(l10n.addFirstFund),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: provider.loadPortfolio,
                            child: ListView.builder(
                              padding: const .only(bottom: 100, top: 12),
                              itemCount:
                                  provider.portfolio.length +
                                  (showPortfolioSummary ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (showPortfolioSummary && index == 0) {
                                  return _buildPortfolioHeader(
                                    globalMetrics,
                                    dailyChangeAbs,
                                    dailyChangePercent,
                                    provider,
                                  );
                                }
                                final item =
                                    provider.portfolio[index -
                                        (showPortfolioSummary ? 1 : 0)];

                                final metrics =
                                    FinancialCalculator.calculateFundMetrics(
                                      item,
                                    );

                                double? dailyVariation;
                                Color? dailyVarColor;
                                if (item.history.length > 1) {
                                  final prev = item
                                      .history[item.history.length - 2]
                                      .price;
                                  if (prev != 0) {
                                    dailyVariation =
                                        ((item.lastValue - prev) / prev) * 100;
                                    if (dailyVariation > 0) {
                                      dailyVarColor = Colors.greenAccent[400];
                                    } else if (dailyVariation < 0) {
                                      dailyVarColor = Colors.redAccent[200];
                                    }
                                  }
                                }

                                return _buildFundCard(
                                  item,
                                  metrics,
                                  dailyVariation,
                                  dailyVarColor,
                                  provider,
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FundSearchPage()),
            ),
            backgroundColor: Colors.amber,
            child: const Icon(
              Icons.add_chart_rounded,
              color: Colors.black87,
              size: 32,
            ),
          ),
        ),
        if (provider.isUpdatingPortfolio) ...UpdatingIndicator.show(),
      ],
    );
  }

  // ENCABEZADO CARTERA
  Widget _buildPortfolioHeader(
    GlobalMetrics metrics,
    double dailyChangeAbs,
    double? dailyChangePercent,
    FundProvider provider,
  ) {
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

    final portfolioHistory = _buildPortfolioHistory(
      context.read<FundProvider>().portfolio,
      context.read<FundProvider>().exchangeRates,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF263750), Color(0xFF172337)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // VALOR Y VARIACIÓN DIARIA
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: .circular(16)),
              //color: dailyColor.withValues(alpha: 0.12),
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
                            ?.copyWith(fontWeight: FontWeight.w700),
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
                          fontWeight: FontWeight.w600,
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
                  painter: _HistoryChartPainter(
                    portfolioHistory.map((point) => point.value).toList(),
                    strokeWidth: 2,
                  ),
                ),
              ),
            ],
            // MÉTRICAS
            ...[
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
                        FittedBox(child: MetricLabel(l10n.invested)),
                        FittedBox(
                          child: MetricValue(
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
                        MetricLabel(l10n.performanceLabel),
                        FittedBox(
                          child: Row(
                            children: [
                              MetricValue(
                                '${metrics.profitAbs > 0 ? '+' : ''}'
                                '${currencyFormat.format(metrics.profitAbs)}',
                                color: profitColor,
                              ),
                              const SizedBox(width: 4),
                              MetricRelative(
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
                    margin: const EdgeInsets.symmetric(horizontal: 9),
                  ),
                  // MWR
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        MetricLabel('MWR'),
                        FittedBox(
                          child: Container(
                            padding: const .symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
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
                                fontWeight: FontWeight.bold,
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

            // Marquesina
            const SizedBox(height: 10),
            const Divider(height: 1, color: Colors.white12),
            //const SizedBox(height: 9),
            MarqueeTicker(
              funds: provider.portfolio,
              priceFormat: priceFormat,
              percentFormat: percentFormat,
              velocity: 60.0,
            ),

            // PIE
            //const SizedBox(height: 10),
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(Icons.assessment, color: Colors.white70, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.countFunds(provider.portfolio.length),
                    //'${provider.portfolio.length} fondos',
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

  // TARJETA FONDO
  Widget _buildFundCard(
    FundData fund,
    FundMetrics metrics,
    double? dailyVariation,
    Color? dailyVarColor,
    FundProvider provider,
  ) {
    final hasOps = fund.operations.isNotEmpty;
    //final hasPrices30Days = item.history.length > 30;
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
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
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
      padding: const .fromLTRB(12, 9, 12, 9),
      child: Container(
        decoration: cardDecoration,
        child: Material(
          color: Colors.transparent,
          borderRadius: .circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
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
                                          fontWeight: FontWeight.w400,
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
                                    ?.copyWith(fontWeight: FontWeight.w700),
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
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // GRÁFICO DEL FONDO
                  if (chartValues.length >= 2) ...[
                    SizedBox(
                      height: 65,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _HistoryChartPainter(
                          chartValues,
                          lineColor: chartColor,
                          fillColor: chartColor.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  ],

                  // MÉTRICAS DE LA POSICIÓN
                  if (hasOps) ...[
                    const SizedBox(height: 9),
                    const Divider(height: 1, color: Colors.white12),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Valor de posición
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              MetricLabel(l10n.valueLabel),
                              FittedBox(
                                child: MetricValue(
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
                              MetricLabel(l10n.performanceLabel),
                              FittedBox(
                                child: Row(
                                  children: [
                                    MetricValue(
                                      '${metrics.profitAbs > 0 ? '+' : ''}'
                                      '${smartFormat.format(metrics.profitAbs)} $symbolCurrency',
                                      color: profitColor,
                                    ),
                                    const SizedBox(width: 4),
                                    MetricRelative(
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
                                MetricLabel('TWR'),
                                FittedBox(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
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
                                      //'${metrics.tae > 0 ? '+' : ''}'
                                      //'${percentFormat.format(metrics.tae)}%',
                                      '${(metrics.twrAnnualized != null && metrics.twrAnnualized! > 0) ? '+' : ''}'
                                      '${(metrics.twrAnnualized != null) ? '${percentFormat.format(metrics.twrAnnualized! * 100)}%' : ''}',
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: profitColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
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
                          dateFormat.format(fund.date),
                          //'${l10n.valuationDate}: ${dateFormat.format(fund.date)}',
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

  void _showTriggeredAlertsDialog(BuildContext context, FundProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.amber),
            const SizedBox(width: 10),
            Text(l10n.portfolioAlertsTitle),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: .start,
            children: [
              Text(
                l10n.portfolioAlertsDesc,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.triggeredAlerts.length,
                  itemBuilder: (context, index) {
                    final alert = provider.triggeredAlerts[index];
                    final message = alert.isMinAlert
                        ? l10n.alertMinReached(
                            alert.fund.name,
                            priceFormat.format(alert.currentValue),
                            priceFormat.format(alert.limitValue),
                          )
                        : l10n.alertMaxReached(
                            alert.fund.name,
                            priceFormat.format(alert.currentValue),
                            priceFormat.format(alert.limitValue),
                          );
                    return Padding(
                      padding: const .only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: .start,
                        children: [
                          Icon(
                            alert.isMinAlert
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: alert.isMinAlert
                                ? Colors.redAccent
                                : Colors.greenAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: .start,
                              children: [
                                Text(
                                  alert.fund.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  message,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              provider.clearTriggeredAlerts();
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}

class _HistoryChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final double strokeWidth;

  _HistoryChartPainter(
    this.values, {
    this.lineColor = const Color(0xFF64C8F5),
    this.fillColor = const Color(0x554FC3F7),
    this.strokeWidth = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }

    final sampled = <double>[];
    final step = (values.length - 1) / 49;

    for (var i = 0; i < 50; i++) {
      sampled.add(values[(i * step).round()]);
    }

    final minValue = sampled.reduce((a, b) => a < b ? a : b);
    final maxValue = sampled.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;

    final points = <Offset>[];

    for (var i = 0; i < sampled.length; i++) {
      final x = size.width * i / (sampled.length - 1);
      final normalized = range == 0 ? 0.5 : (sampled[i] - minValue) / range;
      final y = size.height - 5 - normalized * (size.height - 10);

      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillColor, fillColor.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HistoryChartPainter oldDelegate) {
    if (oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.values.length != values.length) {
      return true;
    }

    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }

    return false;
  }
}

class MetricLabel extends StatelessWidget {
  final String value;
  const MetricLabel(this.value, {super.key});

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

class MetricValue extends StatelessWidget {
  final String value;
  final Color? color;
  final bool? bold;
  final double? size;
  const MetricValue(
    this.value, {
    this.color = Colors.white,
    this.bold = true,
    this.size = 14,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: .ellipsis,
      style: TextStyle(
        fontSize: size,
        fontWeight: bold == true ? .bold : .w500,
        color: color,
      ),
    );
  }
}

class MetricRelative extends StatelessWidget {
  final String value;
  final Color color;
  const MetricRelative(this.value, this.color, {super.key});

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

class MarqueeTicker extends StatefulWidget {
  final List<FundData> funds;
  final NumberFormat priceFormat;
  final NumberFormat percentFormat;
  final double velocity; // Píxeles por segundo

  const MarqueeTicker({
    super.key,
    required this.funds,
    required this.priceFormat,
    required this.percentFormat,
    this.velocity = 50.0,
  });

  @override
  State<MarqueeTicker> createState() => _MarqueeTickerState();
}

class _MarqueeTickerState extends State<MarqueeTicker> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Espera a que el widget se renderice para iniciar la animación
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() {
    if (!_scrollController.hasClients) return;

    // Calculamos el tiempo basado en el desplazamiento máximo y la velocidad deseada
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final durationInMs = ((maxScrollExtent / widget.velocity) * 1000).toInt();

    _scrollController
        .animateTo(
          maxScrollExtent,
          duration: Duration(milliseconds: durationInMs),
          curve: Curves.linear, // Movimiento fluido y lineal sin aceleraciones
        )
        .then((_) {
          if (mounted) {
            // Al llegar al final, salta instantáneamente al inicio sin que el usuario lo note y repite
            _scrollController.jumpTo(0.0);
            _startScrolling();
          }
        });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              final prev = fund.history[fund.history.length - 2].price;
              if (prev != 0) {
                dailyVariation = ((fund.lastValue - prev) / prev) * 100;
                if (dailyVariation > 0) {
                  dailyVarColor = Colors.greenAccent[400];
                } else if (dailyVariation < 0) {
                  dailyVarColor = Colors.redAccent[200];
                } else {
                  dailyVarColor = Colors.blueGrey.shade200;
                }
              }
            }
            String variacion = '';
            if (dailyVariation != null) {
              variacion = '${dailyVariation > 0 ? '\u25B2' : '\u25BC'} ';
            }

            return Row(
              children: [
                const SizedBox(width: 12),
                Text(
                  variacion,
                  style: TextStyle(
                    color: dailyVarColor ?? Colors.blueGrey.shade200,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                Text(
                  fund.name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.priceFormat.format(fund.lastValue)} ${fund.currency}',
                  style: TextStyle(
                    fontWeight: .bold,
                    shadows: [
                      Shadow(
                        blurRadius: 8.0,
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
                      style: TextStyle(color: Colors.white),
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
