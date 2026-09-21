import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/fund_provider.dart';
import '../widgets/gradient_background.dart';
import '../services/export_service.dart';
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

  Future<bool?> _confirmOverwrite(BuildContext context, String fundName) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fondo ya existente'),
        content: Text(
          '$fundName ya está en tu cartera. ¿Quieres sobrescribirlo? Se eliminarán sus datos actuales, incluido el historial y las operaciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Sobrescribir',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FundProvider>();
    final priceFormat = NumberFormat('#,##0.0000', 'es_ES');
    final percentFormat = NumberFormat('#,##0.00', 'es_ES');
    final smartFormat = NumberFormat('#,##0.##', 'es_ES');

    final globalMetrics = FinancialCalculator.calculateGlobalMetrics(
      provider.portfolio,
      provider.exchangeRates,
    );

    final Color globalProfitColor =
        globalMetrics.profitAbs >= 0
            ? Colors.greenAccent[400]!
            : Colors.redAccent[200]!;

    final bool showPortfolioSummary = globalMetrics.totalInvested > 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text.rich(
          TextSpan(
            text: 'Open',
            style: const TextStyle(color: Colors.white),
            children: [
              TextSpan(
                text: 'Invest',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (provider.portfolio.isNotEmpty) ...[
            IconButton(
              icon: provider.isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh),
              onPressed: provider.isBusy ? null : provider.updateAllPortfolio,
              tooltip: 'Actualizar toda la cartera',
            ),
          ],
          if (provider.portfolio.isNotEmpty)
            PopupMenuButton<SortCriteria>(
              icon: const Icon(Icons.sort, color: Colors.white),
              tooltip: 'Ordenar cartera',
              onSelected: (criteria) {
                context.read<FundProvider>().setSortCriteria(criteria);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: SortCriteria.name,
                  child: Row(
                    children: [
                      Icon(
                        Icons.sort_by_alpha,
                        size: 20,
                        color: provider.sortCriteria == SortCriteria.name
                            ? Colors.blueAccent
                            : Colors.white70,
                      ),
                      const SizedBox(width: 12),
                      const Text('Nombre del Fondo'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortCriteria.value,
                  child: Row(
                    children: [
                      Icon(
                        Icons.euro_symbol,
                        size: 20,
                        color: provider.sortCriteria == SortCriteria.value
                            ? Colors.blueAccent
                            : Colors.white70,
                      ),
                      const SizedBox(width: 12),
                      const Text('Valor Total'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortCriteria.performance,
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 20,
                        color: provider.sortCriteria == SortCriteria.performance
                            ? Colors.blueAccent
                            : Colors.white70,
                      ),
                      const SizedBox(width: 12),
                      const Text('Rendimiento (TAE)'),
                    ],
                  ),
                ),
              ],
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Más opciones',
            onSelected: (value) async {
              switch (value) {
                case 'import':
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
                      if (decision != true || !context.mounted) break;
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
                          const SnackBar(
                            content: Text('Fondo importado correctamente'),
                          ),
                        );
                      }
                    } catch (_) {
                      // El proveedor expone el error en la interfaz principal.
                    }
                  }
                  break;
                case 'clear':
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Vaciar Cartera'),
                      content: const Text(
                        '¿Estás seguro de que quieres eliminar todos los fondos de tu cartera?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () {
                            provider.clearPortfolio();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Eliminar',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(
                      Icons.file_download_outlined,
                      size: 20,
                      color: Colors.white70,
                    ),
                    SizedBox(width: 12),
                    Text('Importar fondo (JSON)'),
                  ],
                ),
              ),
              if (provider.portfolio.isNotEmpty)
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_sweep,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Vaciar cartera',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
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
                    ? const Center(
                        child: Text(
                          'No se pudieron cargar los datos de la cartera.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
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
                            const Text('Tu cartera está vacía.'),
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FundSearchPage(),
                                ),
                              ),
                              icon: const Icon(Icons.search),
                              label: const Text('Añadir mi primer fondo'),
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
                                      const Text(
                                        'RESUMEN DE CARTERA',
                                        style: TextStyle(
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
                                        'Invertido: ${smartFormat.format(globalMetrics.totalInvested)} €',
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
                                              '${globalMetrics.isAnnualized ? 'TAE' : 'GANANCIA'}: ${globalMetrics.profitRel > 0 ? '+' : ''}${percentFormat.format(globalMetrics.profitRel)}%',
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
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: SizedBox(
                                            height: 8,
                                            width: double.infinity,
                                            child: Row(
                                              children: provider.portfolio
                                                  .map((item) {
                                                    final metrics =
                                                        FinancialCalculator
                                                            .calculateFundMetrics(
                                                              item,
                                                            );
                                                    final double rate =
                                                        provider.exchangeRates[
                                                              item.currency
                                                            ] ??
                                                            1.0;
                                                    final fundValue =
                                                        metrics.currentValue *
                                                        rate;
                                                    final weight =
                                                        fundValue /
                                                        globalMetrics
                                                            .totalValue;

                                                    if (weight <= 0) {
                                                      return const SizedBox
                                                          .shrink();
                                                    }

                                                    return Expanded(
                                                      flex: (weight * 1000)
                                                          .toInt(),
                                                      child: Tooltip(
                                                        message:
                                                            '${item.name}\nPeso: ${percentFormat.format(weight * 100)}%',
                                                        triggerMode:
                                                            TooltipTriggerMode
                                                                .tap,
                                                        preferBelow: false,
                                                        child: Container(
                                                          color: _getFundColor(
                                                            item.isin,
                                                          ),
                                                          margin:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                horizontal: 0.5,
                                                              ),
                                                        ),
                                                      ),
                                                    );
                                                  })
                                                  .toList(),
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
                            final Color profitColor =
                                metrics.profitAbs >= 0
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
                                                    DateFormat('dd/MM/yy')
                                                        .format(item.date),
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
                                                const Text(
                                                  'VALOR TOTAL',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.white38,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                Text(
                                                  '${priceFormat.format(metrics.currentValue)} ${item.currency}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                const Text(
                                                  'RENDIMIENTO',
                                                  style: TextStyle(
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
                                                      ? 'TAE'
                                                      : 'GANANCIA TOTAL',
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
