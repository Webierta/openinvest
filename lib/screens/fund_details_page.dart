import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/fund_provider.dart';
import '../services/export_service.dart';
import '../services/fund_scraper.dart';
import '../widgets/error_banner.dart';
import '../widgets/gradient_background.dart';
import 'fund_details_tabs/fund_balance_tab.dart';
import 'fund_details_tabs/fund_history_chart.dart';
import 'fund_details_tabs/fund_operations_list.dart';
import 'fund_details_tabs/price_history_table.dart';
import 'fund_details_tabs/fund_summary_tab.dart';
import 'fund_details_tabs/monthly_returns_tab.dart';
import '../utils/route_observer.dart';

class FundDetailsPage extends StatefulWidget {
  const FundDetailsPage({super.key});

  @override
  State<FundDetailsPage> createState() => _FundDetailsPageState();
}

class _FundDetailsPageState extends State<FundDetailsPage> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
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
  void didPop() {
    context.read<FundProvider>().clearError();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<FundProvider>();
    final fund = provider.currentFund;
    if (fund == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.noDataAvailable)),
      );
    }

    final locale = Localizations.localeOf(context).toString();
    final priceFormat = NumberFormat('#,##0.0000', locale);
    final percentFormat = NumberFormat('#,##0.00', locale);
    final dateFormat = DateFormat.yMd(locale).add_Hm();

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Row(
            children: [
              Hero(
                tag: 'avatar_${fund.isin}',
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: _getFundColor(fund.isin)
                      .withValues(alpha: 0.2),
                  child: Text(
                    fund.name.isNotEmpty ? fund.name[0].toUpperCase() : 'F',
                    style: TextStyle(
                      color: _getFundColor(fund.isin),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'name_${fund.isin}',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          fund.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Text(
                      fund.isin,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: provider.isBusy
                  ? null
                  : () => provider.searchFund(fund.isin),
              tooltip: l10n.updateDataTooltip,
            ),
            IconButton(
              icon: const Icon(Icons.date_range, color: Colors.white),
              onPressed: provider.isBusy
                  ? null
                  : () => _selectDateRange(context, provider, fund),
              tooltip: l10n.downloadRangeTooltip,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: l10n.moreOptionsTooltip,
              onSelected: (value) =>
                  _handleMenuAction(context, provider, fund, value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.file_upload_outlined,
                        size: 20,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.exportFundAction),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.layers_clear_outlined,
                        size: 20,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.clearDataAction),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.deleteFromPortfolioAction,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: const Icon(Icons.info_outline), text: l10n.statusTab),
              Tab(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                text: l10n.balanceTab,
              ),
              Tab(icon: const Icon(Icons.show_chart), text: l10n.chartTab),
              Tab(icon: const Icon(Icons.calendar_month_outlined), text: l10n.monthsTab),
              Tab(icon: const Icon(Icons.table_rows), text: l10n.tableTab),
              Tab(icon: const Icon(Icons.account_balance), text: l10n.marketTab),
            ],
          ),
        ),
        body: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                if (provider.error != null || provider.info != null)
                  ErrorBanner(
                    message: provider.info ?? provider.error!,
                    isInfo: provider.info != null,
                    onRetry: provider.info != null
                        ? null
                        : () => provider.searchFund(fund.isin),
                    onDismiss: provider.clearError,
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      RefreshIndicator(
                        onRefresh: () => provider.searchFund(fund.isin),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: FundSummaryTab(
                            fund: fund,
                            priceFormat: priceFormat,
                            percentFormat: percentFormat,
                            dateFormat: dateFormat,
                          ),
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: () => provider.searchFund(fund.isin),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: fund.operations.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.noOperationsRegistered,
                                    style: const TextStyle(color: Colors.white38),
                                  ),
                                )
                              : FundBalanceTab(
                                  fund: fund,
                                  priceFormat: priceFormat,
                                  percentFormat: percentFormat,
                                ),
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: () => provider.searchFund(fund.isin),
                        child: fund.lastValue == 0 && fund.history.isEmpty
                            ? Center(
                                child: Text(l10n.noDataAvailable),
                              )
                            : SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                child: FundHistoryChart(
                                  fund: fund,
                                  priceFormat: priceFormat,
                                ),
                              ),
                      ),
                      RefreshIndicator(
                        onRefresh: () => provider.searchFund(fund.isin),
                        child: fund.lastValue == 0 && fund.history.isEmpty
                            ? Center(
                                child: Text(l10n.noDataAvailable),
                              )
                            : SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                child: MonthlyReturnsTab(
                                  fund: fund,
                                  percentFormat: percentFormat,
                                ),
                              ),
                      ),
                      RefreshIndicator(
                        onRefresh: () => provider.searchFund(fund.isin),
                        child: fund.lastValue == 0 && fund.history.isEmpty
                            ? Center(
                                child: Text(l10n.noDataAvailable),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: PriceHistoryTable(
                                  fund: fund,
                                  priceFormat: priceFormat,
                                  percentFormat: percentFormat,
                                  onExported: () => setState(() {}),
                                ),
                              ),
                      ),
                      FundOperationsList(fund: fund, priceFormat: priceFormat),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, _) {
                if (tabController.index != 0) {
                  return const SizedBox.shrink();
                }
                return FloatingActionButton(
                  onPressed: () => _showAlertDialog(context, provider, fund),
                  backgroundColor: Colors.amber,
                  child: const Icon(
                    Icons.add_alert_rounded,
                    color: Colors.black87,
                    size: 32,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _selectDateRange(
    BuildContext context,
    FundProvider provider,
    FundData fund,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.input,
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
    );
    if (picked != null) {
      await provider.searchFundByRange(fund.isin, picked);
    }
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    FundProvider provider,
    FundData fund,
    String value,
  ) async {
    switch (value) {
      case 'export':
        await ExportService.exportFund(context, fund);
        if (mounted) setState(() {});
        break;
      case 'clear':
        _showClearDataDialog(context, provider);
        break;
      case 'delete':
        _showDeleteFundDialog(context, provider, fund);
        break;
    }
  }

  void _showClearDataDialog(BuildContext context, FundProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clearDataTitle),
        content: Text(l10n.clearDataConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              provider.clearCurrentFundData();
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.clearDataAction.split(' ').last), // Use "Limpiar" / "Clear"
          ),
        ],
      ),
    );
  }

  void _showDeleteFundDialog(
    BuildContext context,
    FundProvider provider,
    FundData fund,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteFromPortfolioTitle),
        content: Text(l10n.deleteFromPortfolioConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              await provider.removeFromPortfolio(fund.isin);
              if (context.mounted) {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              }
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAlertDialog(
    BuildContext context,
    FundProvider provider,
    FundData fund,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final minController = TextEditingController(
      text: fund.alertMin?.toString().replaceAll('.', ',') ?? '',
    );
    final maxController = TextEditingController(
      text: fund.alertMax?.toString().replaceAll('.', ',') ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.amber),
            const SizedBox(width: 10),
            Text(l10n.configureAlertsTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.configureAlertsDesc,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: minController,
              decoration: InputDecoration(
                labelText: l10n.minLabel,
                suffixText: fund.currency,
                prefixIcon: const Icon(
                  Icons.arrow_downward,
                  color: Colors.redAccent,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: maxController,
              decoration: InputDecoration(
                labelText: l10n.maxLabel,
                suffixText: fund.currency,
                prefixIcon: const Icon(
                  Icons.arrow_upward,
                  color: Colors.greenAccent,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.setAlerts(fund.isin, null, null);
              Navigator.pop(dialogContext);
            },
            child: Text(
              l10n.deleteAlertsAction,
              style: const TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final min = double.tryParse(
                minController.text.replaceAll(',', '.'),
              );
              final max = double.tryParse(
                maxController.text.replaceAll(',', '.'),
              );
              provider.setAlerts(fund.isin, min, max);
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

Color _getFundColor(String isin) {
  final hash = isin.hashCode;
  final colors = [
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
