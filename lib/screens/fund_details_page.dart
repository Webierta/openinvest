import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

class FundDetailsPage extends StatefulWidget {
  const FundDetailsPage({super.key});

  @override
  State<FundDetailsPage> createState() => _FundDetailsPageState();
}

class _FundDetailsPageState extends State<FundDetailsPage> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FundProvider>();
    final fund = provider.currentFund;
    if (fund == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No hay datos disponibles')),
      );
    }

    final priceFormat = NumberFormat('#,##0.0000', 'es_ES');
    final percentFormat = NumberFormat('#,##0.00', 'es_ES');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return DefaultTabController(
      length: 5,
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
              tooltip: 'Actualizar datos',
            ),
            IconButton(
              icon: const Icon(Icons.date_range, color: Colors.white),
              onPressed: provider.isBusy
                  ? null
                  : () => _selectDateRange(context, provider, fund),
              tooltip: 'Descargar rango',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: 'Más opciones',
              onSelected: (value) =>
                  _handleMenuAction(context, provider, fund, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(
                        Icons.file_upload_outlined,
                        size: 20,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 12),
                      Text('Exportar fondo'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(
                        Icons.layers_clear_outlined,
                        size: 20,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 12),
                      Text('Limpiar datos'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Eliminar de cartera',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Resumen'),
              Tab(
                icon: Icon(Icons.account_balance_wallet_outlined),
                text: 'Balance',
              ),
              Tab(icon: Icon(Icons.show_chart), text: 'Gráfico'),
              Tab(icon: Icon(Icons.table_rows), text: 'Tabla'),
              Tab(icon: Icon(Icons.account_balance), text: 'Operaciones'),
            ],
          ),
        ),
        body: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                if (provider.error != null)
                  ErrorBanner(
                    message: provider.error!,
                    onRetry: () => provider.searchFund(fund.isin),
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
                              ? const Center(
                                  child: Text(
                                    'No hay operaciones registradas',
                                    style: TextStyle(color: Colors.white38),
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
                            ? const Center(
                                child: Text('No hay datos disponibles'),
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
                            ? const Center(
                                child: Text('No hay datos disponibles'),
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpiar Datos'),
        content: const Text('¿Quieres limpiar los precios e historial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              provider.clearCurrentFundData();
              Navigator.pop(dialogContext);
            },
            child: const Text('Limpiar'),
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar de Cartera'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este fondo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await provider.removeFromPortfolio(fund.isin);
              if (context.mounted) {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
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
    final minController = TextEditingController(
      text: fund.alertMin?.toString().replaceAll('.', ',') ?? '',
    );
    final maxController = TextEditingController(
      text: fund.alertMax?.toString().replaceAll('.', ',') ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.amber),
            SizedBox(width: 10),
            Text('Configurar Alertas'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Notificar si el Valor Liquidativo alcanza los siguientes límites:',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: minController,
              decoration: InputDecoration(
                labelText: 'Mínimo',
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
                labelText: 'Máximo',
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
            child: const Text(
              'Borrar Alertas',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
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
            child: const Text('Guardar'),
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
