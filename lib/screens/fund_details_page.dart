import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/fund_provider.dart';
import '../services/fund_scraper.dart';
import '../widgets/gradient_background.dart';
import '../services/export_service.dart';

class FundDetailsPage extends StatefulWidget {
  const FundDetailsPage({super.key});

  @override
  State<FundDetailsPage> createState() => _FundDetailsPageState();
}

class _FundDetailsPageState extends State<FundDetailsPage> {
  int _sortColumnIndex = 1; // Fecha por defecto
  bool _isAscending = false;
  String _selectedChartRange = 'ALL';

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _isAscending = !_isAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _isAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FundProvider>();
    final fund = provider.currentFund;
    if (fund == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('No hay datos disponibles')));
    final priceFormat = NumberFormat('#,##0.0000', 'es_ES');
    final percentFormat = NumberFormat('#,##0.00', 'es_ES');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // Variación diaria para el Hero Avatar (consistencia visual)
    double? dailyVariation;
    Color? dailyVarColor;
    if (fund.history.length > 1) {
      final last = fund.history.last.price;
      final prev = fund.history[fund.history.length - 2].price;
      if (prev != 0) {
        dailyVariation = ((last - prev) / prev) * 100;
        if (dailyVariation > 0) {
          dailyVarColor = Colors.greenAccent[400];
        } else if (dailyVariation < 0) dailyVarColor = Colors.redAccent[200];
      }
    }

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
                  backgroundColor: (dailyVarColor ?? Colors.blue).withValues(alpha: 0.1),
                  child: Icon(
                    dailyVariation != null && dailyVariation < 0 ? Icons.trending_down : Icons.trending_up, 
                    color: dailyVarColor ?? Colors.blue, 
                    size: 16
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
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white), 
                          overflow: TextOverflow.ellipsis
                        ),
                      ),
                    ),
                    Text(fund.isin, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: provider.isLoading ? null : () => provider.searchFund(fund.isin), tooltip: 'Actualizar datos'),
            IconButton(
              icon: const Icon(Icons.date_range, color: Colors.white),
              onPressed: provider.isLoading ? null : () async {
                final DateTimeRange? picked = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now(), initialEntryMode: DatePickerEntryMode.input, initialDateRange: DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()));
                if (picked != null) provider.searchFundByRange(fund.isin, picked);
              },
              tooltip: 'Descargar rango',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: 'Más opciones',
              onSelected: (value) async {
                switch (value) {
                  case 'export':
                    ExportService.exportFund(context, fund);
                    break;
                  case 'clear':
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Limpiar Datos'),
                        content: const Text('¿Quieres limpiar los precios e historial?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                          TextButton(
                            onPressed: () {
                              provider.clearCurrentFundData();
                              Navigator.pop(context);
                            },
                            child: const Text('Limpiar'),
                          ),
                        ],
                      ),
                    );
                    break;
                  case 'delete':
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Eliminar de Cartera'),
                        content: const Text('¿Estás seguro de que quieres eliminar este fondo?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                          TextButton(
                            onPressed: () async {
                              await provider.removeFromPortfolio(fund.isin);
                              if (context.mounted) {
                                Navigator.pop(context);
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_upload_outlined, size: 20, color: Colors.white70),
                      SizedBox(width: 12),
                      Text('Exportar fondo'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.layers_clear_outlined, size: 20, color: Colors.white70),
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
                      Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                      SizedBox(width: 12),
                      Text('Eliminar de cartera', style: TextStyle(color: Colors.redAccent)),
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
              Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Balance'),
              Tab(icon: Icon(Icons.show_chart), text: 'Gráfico'),
              Tab(icon: Icon(Icons.table_rows), text: 'Tabla'),
              Tab(icon: Icon(Icons.account_balance), text: 'Operaciones'),
            ],
          ),
        ),
        body: GradientBackground(
          child: SafeArea(
            child: TabBarView(
              children: [
                RefreshIndicator(onRefresh: () => provider.searchFund(fund.isin), child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), child: _buildSummaryCard(context, fund, priceFormat, percentFormat, dateFormat))),
                RefreshIndicator(onRefresh: () => provider.searchFund(fund.isin), child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), child: fund.operations.isEmpty ? const Center(child: Text('No hay operaciones registradas', style: TextStyle(color: Colors.white38))) : _buildBalanceSection(context, fund, priceFormat, percentFormat))),
                RefreshIndicator(onRefresh: () => provider.searchFund(fund.isin), child: fund.lastValue == 0 && fund.history.isEmpty ? const Center(child: Text('No hay datos disponibles')) : SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), child: _buildGraphSection(context, fund, priceFormat, percentFormat, dateFormat))),
                RefreshIndicator(onRefresh: () => provider.searchFund(fund.isin), child: fund.lastValue == 0 && fund.history.isEmpty ? const Center(child: Text('No hay datos disponibles')) : SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), child: _buildTableSection(context, fund, priceFormat, percentFormat))),
                _buildOperationsSection(context, provider, fund, priceFormat, dateFormat),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, FundData fund, NumberFormat priceFormat, NumberFormat percentFormat, DateFormat dateFormat) {
    double? diff, percent; Color? varColor; double? totalDiff, totalPercent; Color? totalVarColor; DateTime? oldestDate;
    if (fund.history.length > 1) {
      final prevVal = fund.history[fund.history.length - 2].price;
      if (prevVal != 0) { diff = fund.lastValue - prevVal; percent = (diff / prevVal) * 100; if (diff > 0) {
        varColor = Colors.greenAccent[400];
      } else if (diff < 0) varColor = Colors.redAccent[200]; }
      final oldestVal = fund.history.first.price; oldestDate = fund.history.first.date;
      if (oldestVal != 0) { totalDiff = fund.lastValue - oldestVal; totalPercent = (totalDiff / oldestVal) * 100; if (totalDiff > 0) {
        totalVarColor = Colors.greenAccent[400];
      } else if (totalDiff < 0) totalVarColor = Colors.redAccent[200]; }
    }
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fund.lastValue == 0 && fund.history.isEmpty) const Center(child: Text('Sin datos de cotización.'))
            else ...[
              Text('Valor Liquidativo', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${priceFormat.format(fund.lastValue)} ${fund.currency}', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                  if (diff != null && percent != null) ...[
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${diff > 0 ? '+' : ''}${priceFormat.format(diff)}', style: TextStyle(color: varColor, fontWeight: FontWeight.bold, fontSize: 13)), Text('(${percent > 0 ? '+' : ''}${percentFormat.format(percent)}%)', style: TextStyle(color: varColor, fontSize: 11))]),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text('Actualizado: ${dateFormat.format(fund.date)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38)),
              if (totalDiff != null && totalPercent != null && oldestDate != null) ...[
                const Divider(height: 32, color: Colors.white10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Variación Total', style: Theme.of(context).textTheme.labelLarge), Text('Desde ${DateFormat('dd/MM/yyyy').format(oldestDate)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38))]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${totalDiff > 0 ? '+' : ''}${priceFormat.format(totalDiff)} ${fund.currency}', style: TextStyle(color: totalVarColor, fontWeight: FontWeight.bold, fontSize: 15)), Text('${totalPercent > 0 ? '+' : ''}${percentFormat.format(totalPercent)}%', style: TextStyle(color: totalVarColor, fontWeight: FontWeight.bold, fontSize: 13))]),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              _buildStatsGrid(context, fund, priceFormat, percentFormat, dateFormat),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceSection(BuildContext context, FundData fund, NumberFormat priceFormat, NumberFormat percentFormat) {
    double totalUnits = 0; double totalInvested = 0; DateTime? firstOpDate;
    for (var op in fund.operations) {
      if (op.type == OperationType.buy) { totalUnits += op.units; totalInvested += op.amount; } else { totalUnits -= op.units; totalInvested -= op.amount; }
      if (firstOpDate == null || op.date.isBefore(firstOpDate)) firstOpDate = op.date;
    }
    final double currentValue = totalUnits * fund.lastValue;
    final double profitAbs = currentValue - totalInvested;
    final double profitRel = totalInvested > 0 ? (profitAbs / totalInvested) * 100 : 0;
    final Color profitColor = profitAbs >= 0 ? Colors.greenAccent[400]! : Colors.redAccent[200]!;
    final double avgPurchasePrice = totalUnits > 0 ? totalInvested / totalUnits : 0;
    final double moic = totalInvested > 0 ? currentValue / totalInvested : 0;
    String annualizedReturnStr = "-"; 
    String twrTotalStr = "-";
    String twrAnnualizedStr = "-";
    String mwrTotalStr = "-";
    String mwrAnnualizedStr = "-";
    int daysDiff = 0;

    if (firstOpDate != null && totalInvested > 0) {
      daysDiff = DateTime.now().difference(firstOpDate).inDays;
      if (daysDiff > 0) {
        final double years = daysDiff / 365.25;
        
        // 1. Rentabilidad Simple (Money-Weighted Aproximada)
        final double annualizedReturn = (pow(currentValue / totalInvested, 1 / years) - 1) * 100;
        annualizedReturnStr = "${percentFormat.format(annualizedReturn)}%";

        // 2. TWR (Time-Weighted Return)
        final firstOpPricePoint = fund.history.cast<PricePoint?>().firstWhere(
          (p) => p!.date.year == firstOpDate!.year && p.date.month == firstOpDate.month && p.date.day == firstOpDate.day,
          orElse: () => fund.history.isNotEmpty ? fund.history.first : null,
        );
        if (firstOpPricePoint != null && firstOpPricePoint.price > 0) {
          final double twrTotal = (fund.lastValue / firstOpPricePoint.price) - 1;
          final double twrAnnualized = (pow(1 + twrTotal, 1 / years) - 1) * 100;
          twrTotalStr = "${percentFormat.format(twrTotal * 100)}%";
          twrAnnualizedStr = "${percentFormat.format(twrAnnualized)}%";
        }

        // 3. MWR (Money-Weighted Return / IRR)
        // Flujos: Compras (negativos), Ventas (positivos), Valor Actual (positivo final)
        List<Map<String, Object>> flows = fund.operations.map((op) => {
          'amount': op.type == OperationType.buy ? -op.amount : op.amount,
          'date': op.date,
        }).toList();
        flows.add({'amount': currentValue, 'date': DateTime.now()});

        final double irr = _calculateIRR(flows);
        if (!irr.isNaN) {
          mwrAnnualizedStr = "${percentFormat.format(irr * 100)}%";
          // MWR Acumulado equivalente
          final double mwrTotal = (pow(1 + irr, years) - 1) * 100;
          mwrTotalStr = "${percentFormat.format(mwrTotal)}%";
        }
      }
    }

    String antiguedadStr = "-";
    if (daysDiff > 0) {
      if (daysDiff < 60) {
        antiguedadStr = "$daysDiff días";
      } else if (daysDiff < 365) {
        antiguedadStr = "${daysDiff ~/ 30} meses";
      } else {
        int years = daysDiff ~/ 365;
        int months = (daysDiff % 365) ~/ 30;
        if (months == 0) {
          antiguedadStr = years == 1 ? "1 año" : "$years años";
        } else {
          antiguedadStr = "$years ${years == 1 ? 'año' : 'años'} y $months ${months == 1 ? 'mes' : 'meses'}";
        }
      }
    }

    final smartFormat = NumberFormat('#,##0.####', 'es_ES');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildBalanceRow('Participaciones totales', totalUnits.toStringAsFixed(4).replaceAll('.', ',').replaceAll(RegExp(r',0000$'), '')),
      _buildBalanceRow('Inversión neta', '${smartFormat.format(totalInvested)} ${fund.currency}'),
      _buildBalanceRow('Precio medio compra', '${priceFormat.format(avgPurchasePrice)} ${fund.currency}'),
      _buildBalanceRow('Valor actual', '${smartFormat.format(currentValue)} ${fund.currency}', isBold: true),
      const Divider(height: 32, color: Colors.white10),
      Row(children: [
        const Text('Índices de Rentabilidad', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(width: 4),
        IconButton(icon: const Icon(Icons.info_outline, size: 16, color: Colors.white38), onPressed: () => _showIndicesInfo(context), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _buildSimpleStat('Rent. Anualizada', annualizedReturnStr, color: profitColor)),
        const SizedBox(width: 12),
        Expanded(child: _buildSimpleStat('Multiplicador (MoIC)', '${moic.toStringAsFixed(2)}x')),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _buildSimpleStat('TWR (Total)', twrTotalStr)),
        const SizedBox(width: 12),
        Expanded(child: _buildSimpleStat('TWR Anualizado', twrAnnualizedStr)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _buildSimpleStat('MWR Acumulado', mwrTotalStr)),
        const SizedBox(width: 12),
        Expanded(child: _buildSimpleStat('MWR Anualizado', mwrAnnualizedStr)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _buildSimpleStat('Antigüedad', antiguedadStr)),
        const SizedBox(width: 12),
        Expanded(child: _buildSimpleStat('Break-even', priceFormat.format(avgPurchasePrice))),
      ]),
      const Divider(height: 32, color: Colors.white10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Plusvalía / Minusvalía', style: TextStyle(color: Colors.white70)),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${profitAbs > 0 ? '+' : ''}${smartFormat.format(profitAbs)} ${fund.currency}', style: TextStyle(color: profitColor, fontWeight: FontWeight.bold, fontSize: 16)), Text('${profitRel > 0 ? '+' : ''}${percentFormat.format(profitRel)}%', style: TextStyle(color: profitColor, fontWeight: FontWeight.bold))]),
      ]),
    ]);
  }

  Widget _buildSimpleStat(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? Colors.white70)),
      ]),
    );
  }

  Widget _buildBalanceRow(String label, String value, {bool isBold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
      Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? Colors.white : Colors.white70, fontSize: 13)),
    ]));
  }

  Widget _buildGraphSection(BuildContext context, FundData fund, NumberFormat priceFormat, NumberFormat percentFormat, DateFormat dateFormat) {
    if (fund.history.isEmpty) return const SizedBox.shrink();

    // 1. Filtrar historial según rango seleccionado
    List<PricePoint> filteredHistory = fund.history;
    if (_selectedChartRange != 'ALL') {
      DateTime cutoff;
      final now = DateTime.now();
      switch (_selectedChartRange) {
        case '1M': cutoff = now.subtract(const Duration(days: 30)); break;
        case '6M': cutoff = now.subtract(const Duration(days: 182)); break; // ~6 meses
        case 'YTD': cutoff = DateTime(now.year, 1, 1); break;
        case '1Y': cutoff = now.subtract(const Duration(days: 365)); break;
        default: cutoff = DateTime(2000);
      }
      filteredHistory = fund.history.where((p) => p.date.isAfter(cutoff)).toList();
    }

    if (filteredHistory.isEmpty) {
      return Column(
        children: [
          _buildRangeSelector(),
          const SizedBox(height: 100),
          const Center(child: Text('No hay datos en este rango', style: TextStyle(color: Colors.white38))),
        ],
      );
    }

    final labelFormat = NumberFormat('#,##0.00', 'es_ES');
    final prices = filteredHistory.map((e) => e.price).toList();
    final maxPrice = prices.reduce(max), minPrice = prices.reduce(min), meanPrice = prices.reduce((a, b) => a + b) / prices.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(padding: const EdgeInsets.only(left: 8.0), child: Text('Evolución (${filteredHistory.length} pts)', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
          _buildRangeSelector(),
        ],
      ),
      const SizedBox(height: 24),
      SizedBox(height: 350, child: LineChart(LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1), getDrawingVerticalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1)),
        extraLinesData: ExtraLinesData(horizontalLines: [HorizontalLine(y: meanPrice, color: Colors.blue.withValues(alpha: 0.4), strokeWidth: 1.5, dashArray: [5, 5], label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, labelResolver: (line) => 'Media: ${labelFormat.format(line.y)}', style: const TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)))]),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: max(1, filteredHistory.length / 5).toDouble(), getTitlesWidget: (v, m) {
            final i = v.toInt(); if (i < 0 || i >= filteredHistory.length) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(DateFormat('dd/MM').format(filteredHistory[i].date), style: const TextStyle(fontSize: 9, color: Colors.white38)));
          })),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45, getTitlesWidget: (v, m) => Text(labelFormat.format(v), style: const TextStyle(fontSize: 9, color: Colors.white38)))),
        ),
        lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (s) => const Color(0xFF1E293B), getTooltipItems: (spots) => spots.map((s) {
          final d = filteredHistory[s.x.toInt()].date;
          return LineTooltipItem('${DateFormat('dd/MM/yyyy').format(d)}\n', const TextStyle(color: Colors.white38, fontSize: 10), children: [TextSpan(text: priceFormat.format(s.y), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))]);
        }).toList())),
        borderData: FlBorderData(show: false),
        lineBarsData: [LineChartBarData(spots: filteredHistory.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.price)).toList(), isCurved: true, color: const Color(0xFF38BDF8), barWidth: 3, isStrokeCapRound: true, dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
          if (spot.y == maxPrice) return FlDotCirclePainter(radius: 4, color: Colors.greenAccent[400]!, strokeWidth: 2, strokeColor: Colors.white);
          if (spot.y == minPrice) return FlDotCirclePainter(radius: 4, color: Colors.redAccent[200]!, strokeWidth: 2, strokeColor: Colors.white);
          return FlDotCirclePainter(radius: 0);
        }), belowBarData: BarAreaData(show: true, color: const Color(0xFF38BDF8).withValues(alpha: 0.1)))],
      ))),
    ]);
  }

  Widget _buildRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['1M', '6M', 'YTD', '1Y', 'ALL'].map((r) => _buildRangeButton(r)).toList(),
      ),
    );
  }

  Widget _buildRangeButton(String range) {
    final bool isSelected = _selectedChartRange == range;
    return GestureDetector(
      onTap: () => setState(() => _selectedChartRange = range),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          range,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.white38,
          ),
        ),
      ),
    );
  }

  Widget _buildTableSection(BuildContext context, FundData fund, NumberFormat priceFormat, NumberFormat percentFormat) {
    List<Map<String, dynamic>> tableData = [];
    for (int i = 0; i < fund.history.length; i++) {
      final point = fund.history[i]; double? absVar, variation;
      if (i > 0) { final prev = fund.history[i - 1].price; absVar = point.price - prev; if (prev != 0) variation = (absVar / prev) * 100; }
      tableData.add({'index': i + 1, 'date': point.date, 'price': point.price, 'absVar': absVar, 'variation': variation});
    }
    tableData.sort((a, b) {
      int cmp; switch (_sortColumnIndex) {
        case 0: cmp = (a['index'] as int).compareTo(b['index'] as int); break;
        case 1: cmp = (a['date'] as DateTime).compareTo(b['date'] as DateTime); break;
        case 2: cmp = (a['price'] as double).compareTo(b['price'] as double); break;
        case 3: cmp = (a['absVar'] as double? ?? 0).compareTo(b['absVar'] as double? ?? 0); break;
        case 4: cmp = (a['variation'] as double? ?? 0).compareTo(b['variation'] as double? ?? 0); break;
        default: cmp = 0;
      }
      return _isAscending ? cmp : -cmp;
    });
    return Table(
      border: TableBorder.all(color: Colors.white10, width: 0.5, borderRadius: BorderRadius.circular(8)),
      columnWidths: const { 
        0: FlexColumnWidth(0.8), 
        1: FlexColumnWidth(2), 
        2: FlexColumnWidth(1.8), 
        3: FlexColumnWidth(1.5), 
        4: FlexColumnWidth(1.2),
        5: FixedColumnWidth(40), // Columna para eliminar
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Colors.white10), 
          children: [
            _buildSortableHeader('No.', 0), 
            _buildSortableHeader('Fecha', 1), 
            _buildSortableHeader('Precio', 2), 
            _buildSortableHeader('Diff.', 3), 
            _buildSortableHeader('Var.', 4),
            const SizedBox.shrink(), // Header vacío para eliminar
          ]
        ),
        ...tableData.map((row) {
          final absVar = row['absVar'] as double?, variation = row['variation'] as double?;
          Color? vColor; if (absVar != null) { vColor = absVar > 0 ? Colors.greenAccent[400] : (absVar < 0 ? Colors.redAccent[200] : null); }
          return TableRow(children: [
            Padding(padding: const EdgeInsets.all(8.0), child: Text(row['index'].toString(), style: const TextStyle(fontSize: 10, color: Colors.white24))),
            Padding(padding: const EdgeInsets.all(8.0), child: Text(DateFormat('dd/MM/yyyy').format(row['date']), style: const TextStyle(fontSize: 11, color: Colors.white70))),
            Padding(padding: const EdgeInsets.all(8.0), child: Text(priceFormat.format(row['price']), style: const TextStyle(fontSize: 11, color: Colors.white))),
            Padding(padding: const EdgeInsets.all(8.0), child: Text(absVar != null ? '${absVar > 0 ? '+' : ''}${priceFormat.format(absVar)}' : '-', style: TextStyle(color: vColor, fontWeight: FontWeight.bold, fontSize: 10))),
            Padding(padding: const EdgeInsets.all(8.0), child: Text(variation != null ? '${variation > 0 ? '+' : ''}${percentFormat.format(variation)}%' : '-', style: TextStyle(color: vColor, fontWeight: FontWeight.bold, fontSize: 10))),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Eliminar Precio'),
                    content: Text('¿Deseas eliminar el registro del día ${DateFormat('dd/MM/yyyy').format(row['date'])}?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                      TextButton(
                        onPressed: () {
                          context.read<FundProvider>().deletePricePoint(fund.isin, row['date'] as DateTime);
                          Navigator.pop(context);
                        }, 
                        child: const Text('Eliminar', style: TextStyle(color: Colors.red))
                      ),
                    ],
                  ),
                );
              },
            ),
          ]);
        }),
      ],
    );
  }

  Widget _buildSortableHeader(String label, int index) {
    final bool isSorted = _sortColumnIndex == index;
    return InkWell(onTap: () => _onSort(index), child: Padding(padding: const EdgeInsets.all(8.0), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white70)), if (isSorted) Icon(_isAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 14, color: const Color(0xFF38BDF8))])));
  }

  Widget _buildStatsGrid(BuildContext context, FundData fund, NumberFormat priceFormat, NumberFormat percentFormat, DateFormat dateFormat) {
    if (fund.history.isEmpty) return const SizedBox.shrink();
    double sum = 0; PricePoint maxP = fund.history.first, minP = fund.history.first; List<double> returns = [];
    for (int i = 0; i < fund.history.length; i++) {
      final p = fund.history[i]; sum += p.price; if (p.price > maxP.price) maxP = p; if (p.price < minP.price) minP = p;
      if (i > 0) { final prev = fund.history[i - 1].price; if (prev != 0) returns.add((p.price - prev) / prev); }
    }
    final meanPrice = sum / fund.history.length; double volAnual = 0;
    if (returns.isNotEmpty) { double meanRet = returns.reduce((a, b) => a + b) / returns.length; double varSum = returns.map((r) => pow(r - meanRet, 2).toDouble()).reduce((a, b) => a + b); volAnual = sqrt(varSum / returns.length) * sqrt(252) * 100; }
    final df = DateFormat('dd/MM/yyyy');
    return Column(children: [
      Row(children: [Expanded(child: _buildInfoItem(context, 'Máximo', priceFormat.format(maxP.price), df.format(maxP.date), Colors.greenAccent[400]!, Icons.arrow_upward)), const SizedBox(width: 12), Expanded(child: _buildInfoItem(context, 'Mínimo', priceFormat.format(minP.price), df.format(minP.date), Colors.redAccent[200]!, Icons.arrow_downward))]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _buildInfoItem(context, 'Media', priceFormat.format(meanPrice), 'Histórico', Colors.blueAccent, Icons.functions)), const SizedBox(width: 12), Expanded(child: _buildInfoItem(context, 'Volatilidad', '${percentFormat.format(volAnual)}%', 'Anualizada', Colors.orangeAccent, Icons.vibration))]),
    ]);
  }

  Widget _buildInfoItem(BuildContext context, String title, String value, String date, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(title, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(date, style: const TextStyle(fontSize: 9, color: Colors.white38)),
      ]),
    );
  }

  double _calculateIRR(List<Map<String, Object>> flows) {
    if (flows.isEmpty) return double.nan;
    
    // Función NPV (Net Present Value)
    double npv(double rate, List<Map<String, Object>> flows) {
      double total = 0;
      final start = flows.first['date'] as DateTime;
      for (var f in flows) {
        final time = (f['date'] as DateTime).difference(start).inDays / 365.25;
        total += (f['amount'] as double) / pow(1 + rate, time);
      }
      return total;
    }

    // Búsqueda por bisección
    double low = -0.99, high = 2.0; // Rango inicial (-99% a 200%)
    for (int i = 0; i < 50; i++) {
      double mid = (low + high) / 2;
      double v = npv(mid, flows);
      if (v > 0) {
        low = mid;
      } else {
        high = mid;
      }
      if ((high - low).abs() < 1e-6) break;
    }
    
    return (low + high) / 2;
  }

  void _showIndicesInfo(BuildContext context) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Row(children: [Icon(Icons.info_outline, color: Color(0xFF38BDF8)), SizedBox(width: 10), Text('Índices Financieros')]),
      content: const SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _IndexInfoRow(
          title: 'Rent. Anualizada (TAE)', 
          description: 'Rentabilidad simple de TU inversión basándose en el capital total aportado y el tiempo transcurrido.'
        ),
        _IndexInfoRow(
          title: 'TWR (Total / Anualizado)', 
          description: 'Time-Weighted Return. Mide el rendimiento del FONDO, eliminando el impacto de tus entradas y salidas de dinero. Es la rentabilidad del activo en sí.'
        ),
        _IndexInfoRow(
          title: 'MWR (Total / Anualizado)', 
          description: 'Money-Weighted Return (o TIR). Rentabilidad real de tu bolsillo que tiene en cuenta el momento exacto de cada aportación. Refleja tu éxito como inversor al elegir cuándo entrar y salir.'
        ),
        _IndexInfoRow(
          title: 'Multiplicador (MoIC)', 
          description: 'Capital final obtenido por cada euro invertido.'
        ),
        _IndexInfoRow(
          title: 'Antigüedad', 
          description: 'Tiempo transcurrido desde la primera operación.'
        ),
        _IndexInfoRow(
          title: 'Break-even', 
          description: 'Precio necesario para no tener pérdidas.'
        )
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    ));
  }

  Widget _buildOperationsSection(BuildContext context, FundProvider provider, FundData fund, NumberFormat priceFormat, DateFormat dateFormat) {
    final smartFormat = NumberFormat('#,##0.####', 'es_ES');
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16.0), child: ElevatedButton.icon(onPressed: () => _showOperationDialog(context, provider, fund), icon: const Icon(Icons.add), label: const Text('Nueva Operación'), style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)))),
      Expanded(child: fund.operations.isEmpty ? const Center(child: Text('No hay operaciones registradas', style: TextStyle(color: Colors.white38))) : ListView.separated(itemCount: fund.operations.length, separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10), itemBuilder: (context, index) {
        final op = fund.operations[index]; final isBuy = op.type == OperationType.buy;
        return ListTile(
          leading: Icon(isBuy ? Icons.add_circle : Icons.remove_circle, color: isBuy ? Colors.greenAccent[400] : Colors.redAccent[200]),
          title: Text(isBuy ? 'Suscripción' : 'Reembolso', style: const TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: Text(DateFormat('dd/MM/yyyy').format(op.date), style: const TextStyle(color: Colors.white38, fontSize: 12)),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${isBuy ? '' : '-'}${smartFormat.format(op.amount)} ${fund.currency}', style: TextStyle(fontWeight: FontWeight.bold, color: isBuy ? Colors.greenAccent[400] : Colors.redAccent[200], fontSize: 14)),
            Text('${smartFormat.format(op.units)} part. @ ${smartFormat.format(op.price)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
          onTap: () => _showOperationDialog(context, provider, fund, operation: op),
          onLongPress: () { showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Eliminar Operación'), content: const Text('¿Estás seguro?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), TextButton(onPressed: () { provider.deleteOperation(op.id!); Navigator.pop(context); }, child: const Text('Eliminar', style: TextStyle(color: Colors.red)))])); },
        );
      })),
    ]);
  }

  void _showOperationDialog(BuildContext context, FundProvider provider, FundData fund, {FundOperation? operation}) async {
    DateTime selectedDate = operation?.date ?? DateTime.now(); OperationType selectedType = operation?.type ?? OperationType.buy;
    final unitsController = TextEditingController(), priceController = TextEditingController(), amountController = TextEditingController();
    if (operation != null) { unitsController.text = operation.units.toString().replaceAll('.', ','); priceController.text = operation.price.toString().replaceAll('.', ','); amountController.text = operation.amount.toString().replaceAll('.', ','); } else { priceController.text = fund.lastValue.toString().replaceAll('.', ','); }
    void updateAmount() { final u = double.tryParse(unitsController.text.replaceAll(',', '.')) ?? 0; final p = double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0; if (u > 0 && p > 0) amountController.text = (u * p).toString().replaceAll('.', ','); }
    void updateUnits() { final a = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0; final p = double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0; if (a > 0 && p > 0) unitsController.text = (a / p).toStringAsFixed(6).replaceAll('.', ','); }
    await showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: Text(operation == null ? 'Nueva Operación' : 'Editar Operación'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<OperationType>(segments: const [ButtonSegment(value: OperationType.buy, label: Text('Compra')), ButtonSegment(value: OperationType.sell, label: Text('Venta'))], selected: {selectedType}, onSelectionChanged: (newS) => setState(() => selectedType = newS.first)),
        const SizedBox(height: 16),
        ListTile(title: const Text('Fecha'), subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)), trailing: const Icon(Icons.calendar_today), onTap: () async {
          final p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
          if (p != null) setState(() { selectedDate = p; if (operation == null) { final hp = fund.history.cast<PricePoint?>().firstWhere((x) => x!.date.year == p.year && x.date.month == p.month && x.date.day == p.day, orElse: () => null); if (hp != null) { priceController.text = hp.price.toString().replaceAll('.', ','); updateAmount(); } } });
        }),
        TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Precio (VL)'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => updateAmount()),
        TextField(controller: unitsController, decoration: const InputDecoration(labelText: 'Participaciones'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => updateAmount()),
        TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Importe Total'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => updateUnits()),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), ElevatedButton(onPressed: () { final u = double.tryParse(unitsController.text.replaceAll(',', '.')) ?? 0; final p = double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0; final a = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0; if (u > 0 && p > 0 && a > 0) { provider.addOperation(FundOperation(id: operation?.id, isin: fund.isin, date: selectedDate, type: selectedType, units: u, price: p, amount: a)); Navigator.pop(context); } }, child: const Text('Guardar'))],
    )));
  }
}

class _IndexInfoRow extends StatelessWidget {
  final String title, description;
  const _IndexInfoRow({required this.title, required this.description});
  @override
  Widget build(BuildContext context) { return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF38BDF8))), const SizedBox(height: 4), Text(description, style: const TextStyle(fontSize: 13, height: 1.3, color: Colors.white70)), const Divider(color: Colors.white10)])); }
}
