import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/fund_provider.dart';
import '../services/fund_scraper.dart';
import '../widgets/gradient_background.dart';
import '../services/export_service.dart';
import '../services/database_service.dart';
import 'fund_search_page.dart';
import 'fund_details_page.dart';
import 'info_page.dart';
import 'about_page.dart';
import 'support_page.dart';

class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FundProvider>();
    final priceFormat = NumberFormat('#,##0.0000', 'es_ES');
    final percentFormat = NumberFormat('#,##0.00', 'es_ES');
    final smartFormat = NumberFormat('#,##0.##', 'es_ES');

    double globalTotalValue = 0;
    double globalTotalInvested = 0;
    double globalProfitAbs = 0;
    double globalWeightedTaeSum = 0;
    DateTime? globalFirstOpDate;

    for (var item in provider.portfolio) {
      double totalUnits = 0;
      double totalInvested = 0;
      DateTime? fundFirstOpDate;

      for (var op in item.operations) {
        if (op.type == OperationType.buy) {
          totalUnits += op.units;
          totalInvested += op.amount;
        } else {
          totalUnits -= op.units;
          totalInvested -= op.amount;
        }
        if (globalFirstOpDate == null || op.date.isBefore(globalFirstOpDate)) {
          globalFirstOpDate = op.date;
        }
        if (fundFirstOpDate == null || op.date.isBefore(fundFirstOpDate)) {
          fundFirstOpDate = op.date;
        }
      }

      final double rate = provider.exchangeRates[item.currency] ?? 1.0;
      final fundValue = (totalUnits * item.lastValue) * rate;
      final fundProfitAbs = fundValue - (totalInvested * rate);
      
      globalTotalValue += fundValue;
      globalTotalInvested += (totalInvested * rate);
      globalProfitAbs += fundProfitAbs;

      // Cálculo del TAE individual (con respaldo si no hay historial)
      double fundTae = 0;
      if (totalInvested > 0 && fundFirstOpDate != null) {
        final daysDiff = DateTime.now().difference(fundFirstOpDate).inDays;
        
        // 1. Intentar TWR (basado en precios históricos)
        final firstOpPricePoint = item.history.cast<PricePoint?>().lastWhere(
          (p) => p!.date.isBefore(fundFirstOpDate!.add(const Duration(days: 1))),
          orElse: () => null,
        );

        double performanceTotal = 0;
        if (firstOpPricePoint != null && firstOpPricePoint.price > 0) {
          performanceTotal = (item.lastValue / firstOpPricePoint.price) - 1;
        } 
        
        // 2. Respaldo: Si TWR es 0 pero hay beneficio real en €, usar ROI simple
        if (performanceTotal == 0 && fundProfitAbs != 0) {
          performanceTotal = fundProfitAbs / totalInvested;
        }

        if (daysDiff >= 30) {
          final double years = daysDiff / 365.25;
          fundTae = (pow(1 + performanceTotal, 1 / years) - 1) * 100;
        } else {
          fundTae = performanceTotal * 100;
        }
      }
      
      // Acumulamos para la media ponderada global
      if (fundValue > 0) {
        globalWeightedTaeSum += fundTae * fundValue;
      }
    }

    double globalProfitRel = globalTotalValue > 0 ? globalWeightedTaeSum / globalTotalValue : 0;
    
    // Si el TAE ponderado sigue siendo 0 pero hay beneficio global, calculamos ROI global
    if (globalProfitRel == 0 && globalProfitAbs != 0 && globalTotalInvested > 0) {
      globalProfitRel = (globalProfitAbs / globalTotalInvested) * 100;
    }

    bool isGlobalAnnualized = false;
    if (globalFirstOpDate != null) {
      isGlobalAnnualized = DateTime.now().difference(globalFirstOpDate).inDays >= 30;
    }
    final Color globalProfitColor = globalProfitAbs >= 0 ? Colors.greenAccent[400]! : Colors.redAccent[200]!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('OpenInvest'),
        actions: [
          if (provider.portfolio.isNotEmpty) ...[
            IconButton(
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh),
              onPressed: provider.isLoading ? null : provider.updateAllPortfolio,
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
                      Icon(Icons.sort_by_alpha,
                          size: 20,
                          color: provider.sortCriteria == SortCriteria.name
                              ? Colors.blueAccent
                              : Colors.white70),
                      const SizedBox(width: 12),
                      const Text('Nombre del Fondo'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortCriteria.value,
                  child: Row(
                    children: [
                      Icon(Icons.euro_symbol,
                          size: 20,
                          color: provider.sortCriteria == SortCriteria.value
                              ? Colors.blueAccent
                              : Colors.white70),
                      const SizedBox(width: 12),
                      const Text('Valor Total'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortCriteria.performance,
                  child: Row(
                    children: [
                      Icon(Icons.trending_up,
                          size: 20,
                          color: provider.sortCriteria == SortCriteria.performance
                              ? Colors.blueAccent
                              : Colors.white70),
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
                    context.read<FundProvider>().loadPortfolio();
                  }
                  break;
                case 'clear':
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Vaciar Cartera'),
                      content: const Text(
                          '¿Estás seguro de que quieres eliminar todos los fondos de tu cartera?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar')),
                        TextButton(
                          onPressed: () {
                            provider.clearPortfolio();
                            Navigator.pop(context);
                          },
                          child: const Text('Eliminar',
                              style: TextStyle(color: Colors.red)),
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
                    Icon(Icons.file_download_outlined,
                        size: 20, color: Colors.white70),
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
                      Icon(Icons.delete_sweep, size: 20, color: Colors.redAccent),
                      SizedBox(width: 12),
                      Text('Vaciar cartera',
                          style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
              ),
              child: Center(
                child: Image.asset('assets/images/logo.png', width: 100, height: 100),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white70),
              title: const Text('Info', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const InfoPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.code, color: Colors.white70),
              title: const Text('Acerca de', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_outline, color: Colors.white70),
              title: const Text('Apoyar', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportPage()));
              },
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Salir', style: TextStyle(color: Colors.white)),
              onTap: () async {
                await DatabaseService.close();
                exit(0);
              },
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'v1.0.0',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: provider.portfolio.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('Tu cartera está vacía.'),
                      TextButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FundSearchPage())),
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
                    itemCount: provider.portfolio.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Card(
                          margin: const EdgeInsets.all(12),
                          color: Colors.white.withValues(alpha: 0.05),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text('RESUMEN DE CARTERA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white60)),
                            const SizedBox(height: 16),
                            Text(
                              '${smartFormat.format(globalTotalValue)} €',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Invertido: ${smartFormat.format(globalTotalInvested)} €',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white38,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(globalProfitAbs >= 0 ? Icons.trending_up : Icons.trending_down, color: globalProfitColor, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '${globalProfitAbs > 0 ? '+' : ''}${smartFormat.format(globalProfitAbs)} €',
                                  style: TextStyle(color: globalProfitColor, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: globalProfitColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${isGlobalAnnualized ? 'TAE' : 'GANANCIA'}: ${globalProfitRel > 0 ? '+' : ''}${percentFormat.format(globalProfitRel)}%',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                      
                      final item = provider.portfolio[index - 1];
                      
                      double? dailyVariation;
                      Color? dailyVarColor;
                      if (item.history.length > 1) {
                        final prev = item.history[item.history.length - 2].price;
                        if (prev != 0) {
                          dailyVariation = ((item.lastValue - prev) / prev) * 100;
                          if (dailyVariation > 0) {
                            dailyVarColor = Colors.greenAccent[400];
                          } else if (dailyVariation < 0) {
                            dailyVarColor = Colors.redAccent[200];
                          }
                        }
                      }
    
                      double totalUnits = 0;
                      double totalInvested = 0;
                      DateTime? firstOpDate;
                      for (var op in item.operations) {
                        if (op.type == OperationType.buy) {
                          totalUnits += op.units;
                          totalInvested += op.amount;
                        } else {
                          totalUnits -= op.units;
                          totalInvested -= op.amount;
                        }
                        if (firstOpDate == null || op.date.isBefore(firstOpDate)) {
                          firstOpDate = op.date;
                        }
                      }
                      final hasOps = item.operations.isNotEmpty;
                      final double currentValue = totalUnits * item.lastValue;
                      final double fundWeight = globalTotalValue > 0 ? (currentValue / globalTotalValue) * 100 : 0;
                      final double profitAbs = currentValue - totalInvested;
                      
                      double displayPercentage = 0;
                      bool isAnnualized = false;
                      if (totalInvested > 0 && firstOpDate != null) {
                        final daysDiff = DateTime.now().difference(firstOpDate).inDays;
                        // Buscamos el precio inicial para el TWR
                        final firstOpPricePoint = item.history.cast<PricePoint?>().firstWhere(
                          (p) => p!.date.year == firstOpDate!.year && p.date.month == firstOpDate.month && p.date.day == firstOpDate.day,
                          orElse: () => item.history.isNotEmpty ? item.history.first : null,
                        );

                        if (daysDiff >= 30 && firstOpPricePoint != null && firstOpPricePoint.price > 0) {
                          final double years = daysDiff / 365.25;
                          final double twrTotal = (item.lastValue / firstOpPricePoint.price) - 1;
                          displayPercentage = (pow(1 + twrTotal, 1 / years) - 1) * 100;
                          isAnnualized = true;
                        } else {
                          displayPercentage = (profitAbs / totalInvested) * 100;
                        }
                      }

                      final Color profitColor = profitAbs >= 0 ? Colors.greenAccent[400]! : Colors.redAccent[200]!;
    
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: Colors.white.withValues(alpha: 0.03),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            provider.selectFund(item);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const FundDetailsPage()));
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
                                        backgroundColor: _getFundColor(item.isin).withValues(alpha: 0.2),
                                        child: Text(
                                          item.name.isNotEmpty ? item.name[0].toUpperCase() : 'F',
                                          style: TextStyle(
                                            color: _getFundColor(item.isin),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                                      overflow: TextOverflow.ellipsis, 
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)
                                                    ),
                                                  ),
                                                  if ((item.alertMin != null && item.lastValue <= item.alertMin!) || 
                                                      (item.alertMax != null && item.lastValue >= item.alertMax!)) ...[
                                                    const SizedBox(width: 6),
                                                    const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 16),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                          Text(
                                            item.isin, 
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.white38)
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${priceFormat.format(item.lastValue)} ${item.currency}', 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.1, color: Colors.white)
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (dailyVariation != null) ...[
                                              Text(
                                                '${dailyVariation > 0 ? '+' : ''}${percentFormat.format(dailyVariation)}%',
                                                style: TextStyle(
                                                  color: dailyVarColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.0,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Text(
                                              DateFormat('dd/MM/yyyy').format(item.date),
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.0, fontSize: 10, color: Colors.white38),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (hasOps) ...[
                                  const Divider(height: 32, color: Colors.white10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('VALOR TOTAL', style: TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                          Text(
                                            '${priceFormat.format(currentValue)} ${item.currency}', 
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70)
                                          ),
                                          const SizedBox(height: 10),
                                          const Text('RENDIMIENTO', style: TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                          Text(
                                            '${profitAbs > 0 ? '+' : ''}${smartFormat.format(profitAbs)} ${item.currency}',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: profitColor),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('PESO', style: TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                          Text(
                                            '${percentFormat.format(fundWeight)}%',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70)
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            isAnnualized ? 'TAE' : 'GANANCIA TOTAL', 
                                            style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: profitColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: profitColor.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              '${displayPercentage > 0 ? '+' : ''}${percentFormat.format(displayPercentage)}%',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: profitColor),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FundSearchPage())),
        icon: const Icon(Icons.search, color: Colors.white),
        label: const Text('Buscar Fondo', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
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
