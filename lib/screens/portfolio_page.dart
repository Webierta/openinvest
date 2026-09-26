import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../providers/fund_provider.dart';
import '../widgets/gradient_background.dart';
import '../widgets/portfolio_appbar.dart';
//import '../services/export_service.dart';
//import '../services/database_service.dart';
import '../widgets/error_banner.dart';
import '../widgets/app_drawer.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<FundProvider>();
    final locale = Localizations.localeOf(context).toString();
    final priceFormat = NumberFormat('#,##0.0000', locale);
    final percentFormat = NumberFormat('#,##0.00', locale);
    final smartFormat = NumberFormat('#,##0.##', locale);
    //final smartDateFormat = DateFormat('dd/MM/yy', locale);

    final globalMetrics = FinancialCalculator.calculateGlobalMetrics(
      provider.portfolio,
      provider.exchangeRates,
    );

    final Color globalProfitColor = globalMetrics.profitAbs >= 0
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;

    final bool showPortfolioSummary = globalMetrics.totalInvested > 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PortfolioAppbar(
        provider: provider,
        onRefresh: provider.updateAllPortfolio,
        onSortSelected: (criteria) {
          context.read<FundProvider>().setSortCriteria(criteria);
        },
        /*onImport: () async {
          final fund = await ExportService.importFund(context);
          if (fund != null && context.mounted) {
            final existing = provider.portfolio.any(
              (item) => item.isin == fund.isin,
            );
            var overwrite = false;
            if (existing) {
              final decision = await _confirmOverwrite(
                context,
                fund.name,
              );
              if (decision != true || !context.mounted) return;
              overwrite = true;
            }
            try {
              if (overwrite) {
                await provider.replaceFund(fund);
              } else {
                await provider.addToPortfolio(fund);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.fundImportedSuccess)),
                );
              }
            } catch (_) {}
          }
        },*/
        /*onClearPortfolio: () {
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
        },*/
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
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    : provider.portfolio.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                                  builder: (context) => const FundSearchPage(),
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
                          padding: const EdgeInsets.only(bottom: 100, top: 12),
                          itemCount:
                              provider.portfolio.length +
                              (showPortfolioSummary ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (showPortfolioSummary && index == 0) {
                              return Card(
                                margin: const EdgeInsets.all(12),
                                color: Colors.white.withValues(alpha: 0.05),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      Text(
                                        l10n.portfolioSummary,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: Colors.white60,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '${smartFormat.format(globalMetrics.totalValue)} €',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${l10n.invested}: ${smartFormat.format(globalMetrics.totalInvested)} €',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.white38),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            globalMetrics.profitAbs >= 0
                                                ? Icons.trending_up
                                                : Icons.trending_down,
                                            color: globalProfitColor,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${globalMetrics.profitAbs > 0 ? '+' : ''}${smartFormat.format(globalMetrics.profitAbs)} €',
                                            style: TextStyle(
                                              color: globalProfitColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: globalProfitColor,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${globalMetrics.isAnnualized ? l10n.sortByPerformance : l10n.gain}: ${globalMetrics.profitRel > 0 ? '+' : ''}${percentFormat.format(globalMetrics.profitRel)}%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (globalMetrics.totalValue > 0) ...[
                                        const SizedBox(height: 24),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: SizedBox(
                                            height: 8,
                                            width: double.infinity,
                                            child: Row(
                                              children: provider.portfolio.map((
                                                item,
                                              ) {
                                                final metrics =
                                                    FinancialCalculator.calculateFundMetrics(
                                                      item,
                                                    );
                                                final double rate =
                                                    provider.exchangeRates[item
                                                        .currency] ??
                                                    1.0;
                                                final fundValue =
                                                    metrics.currentValue * rate;
                                                final weight =
                                                    fundValue /
                                                    globalMetrics.totalValue;

                                                if (weight <= 0) {
                                                  return const SizedBox.shrink();
                                                }

                                                return Expanded(
                                                  flex: (weight * 1000).toInt(),
                                                  child: Tooltip(
                                                    message:
                                                        '${item.name}\n${l10n.weightLabel}: ${percentFormat.format(weight * 100)}%',
                                                    triggerMode:
                                                        TooltipTriggerMode.tap,
                                                    preferBelow: false,
                                                    child: Container(
                                                      color: _getFundColor(
                                                        item.isin,
                                                      ),
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 0.5,
                                                          ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }

                            final item =
                                provider.portfolio[index -
                                    (showPortfolioSummary ? 1 : 0)];

                            final metrics =
                                FinancialCalculator.calculateFundMetrics(item);

                            double? dailyVariation;
                            Color? dailyVarColor;
                            if (item.history.length > 1) {
                              final prev =
                                  item.history[item.history.length - 2].price;
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
                            final Color profitColor = metrics.profitAbs >= 0
                                ? Colors.greenAccent[400]!
                                : Colors.redAccent[200]!;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              color: Colors.white.withValues(alpha: 0.03),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
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
                                        children: [
                                          Hero(
                                            tag: 'avatar_${item.isin}',
                                            child: CircleAvatar(
                                              radius: 20,
                                              backgroundColor: _getFundColor(
                                                item.isin,
                                              ).withValues(alpha: 0.2),
                                              child: Text(
                                                item.name.isNotEmpty
                                                    ? item.name[0].toUpperCase()
                                                    : 'F',
                                                style: TextStyle(
                                                  color: _getFundColor(
                                                    item.isin,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Hero(
                                                  tag: 'name_${item.isin}',
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            item.name,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 15,
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
                                                            color: Colors.amber,
                                                            size: 16,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  item.isin,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        fontSize: 11,
                                                        color: Colors.white38,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${priceFormat.format(item.lastValue)} ${item.currency}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  height: 1.1,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (dailyVariation !=
                                                      null) ...[
                                                    Text(
                                                      '${dailyVariation > 0 ? '+' : ''}${percentFormat.format(dailyVariation)}%',
                                                      style: TextStyle(
                                                        color: dailyVarColor,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                  ],
                                                  Text(
                                                    DateFormat.yMd(locale)
                                                        .format(item.date),
                                                    //SmartDateFormat.format(),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          height: 1.0,
                                                          fontSize: 10,
                                                          color: Colors.white70,
                                                        ),
                                                  ),
                                                ],
                                              ),
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
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  l10n.valueLabel,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.white38,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                Text(
                                                  '${smartFormat.format(metrics.currentValue)} ${item.currency}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  l10n.performanceLabel,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.white38,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                Text(
                                                  '${metrics.profitAbs > 0 ? '+' : ''}${smartFormat.format(metrics.profitAbs)} ${item.currency}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: profitColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  metrics.isAnnualized
                                                      ? l10n.sortByPerformance
                                                      : l10n.totalGain,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.white38,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: profitColor
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: profitColor
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${(metrics.isAnnualized ? metrics.tae : metrics.profitRel) > 0 ? '+' : ''}${percentFormat.format(metrics.isAnnualized ? metrics.tae : metrics.profitRel)}%',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: profitColor,
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
    );
  }

  void _showTriggeredAlertsDialog(BuildContext context, FundProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final priceFormat = NumberFormat('#,##0.0000', locale);

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

  Color _getFundColor(String isin) {
    final int hash = isin.hashCode;
    final List<Color> colors = [
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.tealAccent,
      Colors.pinkAccent,
      Colors.indigoAccent,
      Colors.amberAccent,
      Colors.cyanAccent,
      Colors.lightGreenAccent,
    ];
    return colors[hash.abs() % colors.length];
  }
}
