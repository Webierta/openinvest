import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../providers/fund_provider.dart';
import '../widgets/circle_avatar_fund.dart';
import '../widgets/gradient_background.dart';
import '../widgets/portfolio_appbar.dart';
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

    return Scaffold(
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
                          padding: const .only(bottom: 100, top: 12),
                          itemCount:
                              provider.portfolio.length +
                              (showPortfolioSummary ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (showPortfolioSummary && index == 0) {
                              return SizedBox.shrink();
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
                                  color: Colors.white.withValues(alpha: 0.03),
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
                                                  crossAxisAlignment: .start,
                                                  children: [
                                                    Hero(
                                                      tag: 'name_${item.isin}',
                                                      child: Material(
                                                        color:
                                                            Colors.transparent,
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
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            fontSize: 11,
                                                            color:
                                                                Colors.white38,
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
                                                        color: dailyVarColor,
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
                                              mainAxisAlignment: .spaceBetween,
                                              crossAxisAlignment: .end,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: .start,
                                                  children: [
                                                    Text(
                                                      l10n.valueLabel,
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        color: Colors.white38,
                                                        fontWeight: .bold,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${smartFormat.format(metrics.currentValue)} ${item.currency}',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: .w500,
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                    if (item.history.length >
                                                        30) ...[
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Text(
                                                        l10n.performanceLabel,
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          color: Colors.white38,
                                                          fontWeight: .bold,
                                                          letterSpacing: 0.5,
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
                                                    ],
                                                  ],
                                                ),
                                                if (item.history.length > 30)
                                                  Column(
                                                    crossAxisAlignment: .end,
                                                    children: [
                                                      Text(
                                                        metrics.isAnnualized
                                                            ? l10n.sortByPerformance
                                                            : l10n.totalGain,
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          color: Colors.white38,
                                                          fontWeight: .bold,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const .symmetric(
                                                              horizontal: 10,
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
                                                                  alpha: 0.3,
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
