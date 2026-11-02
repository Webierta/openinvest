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
                                  //return SizedBox.shrink();
                                  return _buildPortfolioHeader(
                                    globalMetrics,
                                    dailyChangeAbs,
                                    dailyChangePercent,
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

                                final hasOps = item.operations.isNotEmpty;
                                //final hasPrices30Days = item.history.length > 30;
                                final Color profitColor = metrics.profitAbs >= 0
                                    ? Colors.greenAccent[400]!
                                    : Colors.redAccent[200]!;

                                return Padding(
                                  padding: const EdgeInsets.only(top: 15),
                                  child: Badge(
                                    label: Text(dateFormat.format(item.date)),
                                    textColor: Colors.white,
                                    textStyle: TextStyle(fontSize: 12),
                                    alignment: .topRight,
                                    //largeSize: 130,
                                    //alignment: AlignmentDirectional(0.7, -1),
                                    offset: Offset(-120, -6),
                                    padding: const .symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    backgroundColor: Colors.blueGrey,
                                    child: Card(
                                      //clipBehavior: Clip.none,
                                      margin: const .symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      color: Colors.white.withValues(
                                        alpha: 0.03,
                                      ),
                                      child: InkWell(
                                        borderRadius: .circular(16),
                                        onTap: () {
                                          provider.selectFund(item);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const FundDetailsPage(),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            children: [
                                              Row(
                                                crossAxisAlignment: .end,
                                                children: [
                                                  Hero(
                                                    tag: 'avatar_${item.isin}',
                                                    child: CircleAvatarFund(
                                                      fund: item,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          .start,
                                                      children: [
                                                        Hero(
                                                          tag:
                                                              'name_${item.isin}',
                                                          child: Material(
                                                            color: Colors
                                                                .transparent,
                                                            child: Row(
                                                              children: [
                                                                Flexible(
                                                                  child: Text(
                                                                    item.name,
                                                                    overflow:
                                                                        .ellipsis,
                                                                    style: const TextStyle(
                                                                      fontWeight:
                                                                          .bold,
                                                                      fontSize:
                                                                          15,
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                  ),
                                                                ),
                                                                if ((item.alertMin !=
                                                                            null &&
                                                                        item.lastValue <=
                                                                            item.alertMin!) ||
                                                                    (item.alertMax !=
                                                                            null &&
                                                                        item.lastValue >=
                                                                            item.alertMax!)) ...[
                                                                  const SizedBox(
                                                                    width: 6,
                                                                  ),
                                                                  const Icon(
                                                                    Icons
                                                                        .notifications_active_rounded,
                                                                    color: Colors
                                                                        .amber,
                                                                    size: 16,
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          item.isin,
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    fontSize:
                                                                        11,
                                                                    color: Colors
                                                                        .white38,
                                                                  ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment: .end,
                                                    children: [
                                                      Text(
                                                        '${priceFormat.format(item.lastValue)} ${item.currency}',
                                                        style: const TextStyle(
                                                          //fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                          height: 1.1,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      if (dailyVariation !=
                                                          null) ...[
                                                        Text(
                                                          '${dailyVariation > 0 ? '+' : ''}${percentFormat.format(dailyVariation)}%',
                                                          style: TextStyle(
                                                            color:
                                                                dailyVarColor,
                                                            fontSize: 14,
                                                            fontWeight: .bold,
                                                            height: 1.0,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              if (hasOps) ...[
                                                const Divider(
                                                  height: 30,
                                                  color: Colors.white10,
                                                ),
                                                Row(
                                                  mainAxisAlignment:
                                                      .spaceBetween,
                                                  crossAxisAlignment: .end,
                                                  children: [
                                                    Column(
                                                      crossAxisAlignment:
                                                          .start,
                                                      children: [
                                                        Text(
                                                          l10n.valueLabel,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 9,
                                                                color: Colors
                                                                    .white38,
                                                                fontWeight:
                                                                    .bold,
                                                                letterSpacing:
                                                                    0.5,
                                                              ),
                                                        ),
                                                        Text(
                                                          '${smartFormat.format(metrics.currentValue)} ${item.currency}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    .w500,
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                        ),
                                                        // if (item
                                                        //         .history
                                                        //         .length >
                                                        //     30) ...[
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        Text(
                                                          l10n.performanceLabel,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 9,
                                                                color: Colors
                                                                    .white38,
                                                                fontWeight:
                                                                    .bold,
                                                                letterSpacing:
                                                                    0.5,
                                                              ),
                                                        ),
                                                        Text(
                                                          '${metrics.profitAbs > 0 ? '+' : ''}${smartFormat.format(metrics.profitAbs)} ${item.currency}',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: .bold,
                                                            color: profitColor,
                                                          ),
                                                        ),
                                                        //],
                                                      ],
                                                    ),
                                                    if (item.history.length >
                                                        30)
                                                      Column(
                                                        crossAxisAlignment:
                                                            .end,
                                                        children: [
                                                          Text(
                                                            metrics.isAnnualized
                                                                ? l10n.sortByPerformance
                                                                : l10n.totalGain,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 9,
                                                                  color: Colors
                                                                      .white38,
                                                                  fontWeight:
                                                                      .bold,
                                                                  letterSpacing:
                                                                      0.5,
                                                                ),
                                                          ),
                                                          Container(
                                                            padding:
                                                                const .symmetric(
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 4,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: profitColor
                                                                  .withValues(
                                                                    alpha: 0.15,
                                                                  ),
                                                              borderRadius:
                                                                  .circular(6),
                                                              border: .all(
                                                                color: profitColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.3,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              //'${(metrics.isAnnualized ? metrics.tae : metrics.profitRel) > 0 ? '+' : ''}'
                                                              //'${percentFormat.format(metrics.isAnnualized ? metrics.tae : metrics.profitRel)}%',
                                                              '${(metrics.twrAnnualized != null && metrics.twrAnnualized! > 0) ? '+' : ''}'
                                                              '${(metrics.twrAnnualized != null) ? '${percentFormat.format(metrics.twrAnnualized! * 100)}%' : ''}',
                                                              style: TextStyle(
                                                                //fontSize: 14,
                                                                //fontWeight: FontWeight.bold,
                                                                color:
                                                                    profitColor,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
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

  Widget _buildPortfolioHeader(
    GlobalMetrics metrics,
    double dailyChangeAbs,
    double? dailyChangePercent,
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
          crossAxisAlignment: .start,
          children: [
            const Text(
              'Mi Cartera',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                // Logo
                Image.asset(
                  'assets/images/logo_trans.png',
                  width: 64,
                  cacheWidth: 64,
                ),
                const SizedBox(width: 10),
                // Patrimonio y resultado acumulado
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          currencyFormat.format(metrics.totalValue),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      FittedBox(
                        child: Row(
                          children: [
                            Icon(
                              metrics.profitAbs > 0
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              color: profitColor,
                              //size: 28,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${metrics.profitAbs > 0 ? '+' : ''}'
                              '${currencyFormat.format(metrics.profitAbs)} '
                              '(${accumulatedReturn > 0 ? '+' : ''}'
                              '${percentFormat.format(accumulatedReturn)}%)',
                              style: TextStyle(
                                color: profitColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Variación diaria global
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '± Hoy',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (dailyChangePercent != null)
                        Chip(
                          backgroundColor: dailyColor.withValues(alpha: 0.13),
                          side: BorderSide(
                            color: dailyColor.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: .all(4),
                          avatar: Icon(
                            dailyChangePercent > 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: dailyColor,
                            size: 24,
                          ),
                          label: Text(
                            '${dailyChangePercent > 0 ? '+' : ''}'
                            '${percentFormat.format(dailyChangePercent)}%',
                            style: TextStyle(
                              color: dailyColor,
                              fontSize: 12,
                              //fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const Text(
                          '—',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            if (portfolioHistory.length >= 2) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 65,
                width: double.infinity,
                child: CustomPaint(
                  painter: _PortfolioHistoryPainter(
                    portfolioHistory.map((point) => point.value).toList(),
                  ),
                ),
              ),
            ],
          ],
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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

class _PortfolioHistoryPainter extends CustomPainter {
  final List<double> values;

  _PortfolioHistoryPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }

    // Reducimos la cantidad de puntos para mantener una gráfica ligera.
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

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x554FC3F7), Color(0x004FC3F7)],
      ).createShader(Offset.zero & size);

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF64C8F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _PortfolioHistoryPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;

    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }

    return false;
  }
}
