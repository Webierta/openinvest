import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../models/fund_data.dart';
import '../providers/fund_provider.dart';
import '../widgets/build_portfolio_header.dart';
import '../widgets/circle_avatar_fund.dart';
import '../widgets/gradient_background.dart';
import '../widgets/history_chart_painter.dart';
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
                              itemCount: provider.portfolio.length + 1,
                              itemBuilder: (context, index) {
                                // TARJETA ENCABEZADO CARTERA
                                if (index == 0) {
                                  return const BuildPortfolioHeader();
                                }

                                // TARJETAS FONDOS
                                final item = provider.portfolio[index - 1];
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
                  if (chartValues.length >= 2) ...[
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
                                      //'${metrics.tae > 0 ? '+' : ''}'
                                      //'${percentFormat.format(metrics.tae)}%',
                                      '${(metrics.twrAnnualized != null && metrics.twrAnnualized! > 0) ? '+' : ''}'
                                      '${(metrics.twrAnnualized != null) ? '${percentFormat.format(metrics.twrAnnualized! * 100)}%' : ''}',
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
            mainAxisSize: .min,
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
                                    fontWeight: .bold,
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
