import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../providers/fund_provider.dart';
import '../widgets/build_fund_card.dart';
import '../widgets/build_portfolio_header.dart';
import '../widgets/gradient_background.dart';
import '../widgets/portfolio_appbar.dart';
import '../widgets/error_banner.dart';
import '../widgets/app_drawer.dart';
import '../widgets/updating_indicator.dart';
import 'fund_search_page.dart';
import '../utils/route_observer.dart';

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
  //NumberFormat get percentFormat => NumberFormat('#,##0.00', locale);
  //NumberFormat get smartFormat => NumberFormat('#,##0.##', locale);
  //DateFormat get dateFormat => DateFormat.yMMMd(locale);

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
                                return BuildFundCard(
                                  key: ValueKey(item.isin),
                                  fund: item,
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
