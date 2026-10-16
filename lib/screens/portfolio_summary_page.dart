import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/fund_data.dart';

import '../l10n/app_localizations.dart';
import '../providers/fund_provider.dart';
import '../screens/correlation_matrix_page.dart';
import '../screens/compara_page.dart';
import '../tools/files_generator.dart';
import '../utils/financial_calculator.dart';
import '../widgets/circle_avatar_fund.dart';
import '../widgets/gradient_background.dart';
import 'fund_details_page.dart';
import 'fund_search_page.dart';

class PortfolioSummaryPage extends StatefulWidget {
  const PortfolioSummaryPage({super.key});

  @override
  State<PortfolioSummaryPage> createState() => _PortfolioSummaryPageState();
}

class _PortfolioSummaryPageState extends State<PortfolioSummaryPage> {
  // GETTERS
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  String get locale => Localizations.localeOf(context).toString();
  //NumberFormat get priceFormat => NumberFormat('#,##0.0000', locale);
  NumberFormat get percentFormat => NumberFormat('#,##0.00', locale);
  NumberFormat get smartFormat => NumberFormat('#,##0.##', locale);
  //DateFormat get smartDateFormat => DateFormat('dd/MM/yy', locale);
  DateFormat get dateFormat => DateFormat.yMMMd(locale);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FundProvider>();
    final funds = provider.portfolio;

    final globalMetrics = FinancialCalculator.calculateGlobalMetrics(
      provider.portfolio,
      provider.exchangeRates,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Cartera'), // Ajusta a tu clave de localización
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: provider.hasPortfolioLoadError
              ? Center(
                  child: Text(
                    l10n.portfolioLoadError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : funds.isEmpty
              ? _buildEmptyState(context) // NO HAY FONDOS
              : RefreshIndicator(
                  onRefresh: provider.loadPortfolio,
                  child: CustomScrollView(
                    slivers: [
                      // 1. TARJETA DE RESUMEN GLOBAL (HERO)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildSummaryCard(provider, globalMetrics),
                        ),
                      ),
                      // 2. CUADRÍCULA DE ACCIONES RÁPIDAS
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Acciones',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            16.0,
                            8.0,
                            16.0,
                            24.0,
                          ),
                          child: _buildActionGrid(context, provider),
                        ),
                      ),
                      // 3. LISTADO DE FONDOS
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Tus Fondos (${funds.length})',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                      if (provider.hasPortfolioLoadError)
                        Center(
                          child: Text(
                            l10n.portfolioLoadError,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        )
                      else if (provider.portfolio.isEmpty)
                        Center(child: Text(l10n.emptyPortfolio))
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            16.0,
                            8.0,
                            16.0,
                            32.0,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final fund = funds[index];
                              return _buildFundListItem(
                                context,
                                provider,
                                fund,
                              );
                            }, childCount: funds.length),
                          ),
                        ),
                      // Listado de Operaciones recientes
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildRecentOperations(
                            context,
                            provider.portfolio,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 32), // Espacio final para que el FAB no tape el último elemento
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES DE DISEÑO ---
  Widget _buildSummaryCard(FundProvider provider, GlobalMetrics globalMetrics) {
    final globalProfitColor = globalMetrics.profitAbs >= 0
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;
    final bool hayInversion = globalMetrics.totalInvested > 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Valor actual de la Cartera',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                globalMetrics.profitAbs >= 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: globalProfitColor,
                size: 40,
              ),
              const SizedBox(width: 8),
              Text(
                '${smartFormat.format(globalMetrics.totalValue)} €',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          if (hayInversion) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.invested,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${smartFormat.format(globalMetrics.totalInvested)} €',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rendimiento absoluto',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${globalMetrics.profitAbs > 0 ? '+' : ''}${smartFormat.format(globalMetrics.profitAbs)} €',
                  style: TextStyle(
                    color: globalProfitColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  /* globalMetrics.isAnnualized
                      ? l10n.sortByPerformance
                      : l10n.gain, */
                  'Rendimiento relativo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${globalMetrics.profitRel > 0 ? '+' : ''}${percentFormat.format(globalMetrics.profitRel)}%',
                  style: TextStyle(
                    color: globalProfitColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (globalMetrics.totalValue > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Pesos',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 18,
                  width: double.infinity,
                  child: Row(
                    children: provider.portfolio.map((item) {
                      final metrics = FinancialCalculator.calculateFundMetrics(
                        item,
                      );
                      final double rate =
                          provider.exchangeRates[item.currency] ?? 1.0;
                      final fundValue = metrics.currentValue * rate;
                      final weight = fundValue / globalMetrics.totalValue;
                      if (weight <= 0) return const SizedBox.shrink();
                      return Expanded(
                        flex: (weight * 1000).toInt(),
                        child: Tooltip(
                          message:
                              '${item.name}\n${l10n.weightLabel}: ${percentFormat.format(weight * 100)}%',
                          triggerMode: TooltipTriggerMode.tap,
                          preferBelow: false,
                          child: Container(
                            color: CircleAvatarFund(fund: item).getFundColor,
                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, FundProvider provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Responsive: 2 columnas en móvil, 4 en escritorio (Linux/Windows)
    //final int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;
    final int crossAxisCount = screenWidth > 600 ? 4 : 2;
    // En pantallas muy pequeñas (<360px), hacemos las tarjetas un poco más altas
    //(aspectRatio < 1.0) para evitar que el texto se desborde si ocupa 2 líneas.
    final double aspectRatio = screenWidth > 600
        ? 1.5
        : screenWidth < 360
        ? 0.95
        : 1.4; //1.1.

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      children: [
        _buildActionCard(
          context,
          provider,
          icon: Icons.add_chart,
          title: 'Añadir',
          subtitle: 'Nuevo Fondo',
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FundSearchPage()),
          ),
        ),
        _buildActionCard(
          context,
          provider,
          icon: Icons.compare_arrows,
          title: 'Comparar',
          subtitle: '2 Fondos',
          color: Colors.purple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComparaPage()),
            );
          },
        ),
        _buildActionCard(
          context,
          provider,
          icon: Icons.grid_4x4,
          title: 'Correlación',
          subtitle: 'Matriz de Riesgo',
          color: Colors.orange,
          onTap: () async {
            if (provider.portfolio.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Necesitas al menos 2 fondos para ver la matriz.',
                  ),
                ),
              );
              return;
            }
            // Mostrar loading
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(child: CircularProgressIndicator()),
            );

            await provider.loadCorrelationMatrix();

            if (!context.mounted) return;
            Navigator.pop(context); // Quitar loading
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CorrelationMatrixPage()),
            );
          },
        ),
        _buildActionCard(
          context,
          provider,
          icon: Icons.description,
          title: 'Informes',
          subtitle: 'PDF / CSV',
          color: Colors.teal,
          onTap: () async {
            final returnDialogInformes = await _showDialogInformes(context);
            if (returnDialogInformes == null || !context.mounted) return;
            final filesGenerator = FilesGenerator(
              context: context,
              l10n: l10n,
              provider: provider,
            );
            if (returnDialogInformes == 'PDF') {
              filesGenerator.initReportPdf();
            }
            if (returnDialogInformes == 'CSV') {
              filesGenerator.initExportCsv();
            }
          },
        ),
      ],
    );
  }

  Future<String?> _showDialogInformes(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          contentPadding: EdgeInsets.all(24),
          //titlePadding: EdgeInsets.all(24),
          title: Center(child: Text('Genera archivos de tu Cartera')),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'CSV');
              },
              child: Text(
                '✔️ Hoja de calculo de las operaciones (formato CSV)',
              ),
            ),
            const SizedBox(height: 12),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'PDF');
              },
              child: Text('✔️ Informe anual en formato PDF'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    FundProvider provider, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Clave: no forzar altura extra
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFundListItem(
    BuildContext context,
    FundProvider provider,
    FundData fund,
  ) {
    final metrics = FinancialCalculator.calculateFundMetrics(fund);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.white.withValues(alpha: 0.03),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          provider.selectFund(fund);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FundDetailsPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'avatar_${fund.isin}',
                    child: CircleAvatarFund(fund: fund),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'name_${fund.isin}',
                          child: Material(
                            color: Colors.transparent,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    fund.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          fund.isin,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  if (fund.operations.isNotEmpty)
                    Text(
                      '${smartFormat.format(metrics.currentValue)} ${fund.currency}',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOperations(BuildContext context, List<FundData> funds) {
    // 1. Aplanar todas las operaciones de todos los fondos
    final List<FundOperation> allOps = [];
    for (final fund in funds) {
      for (final op in fund.operations) {
        allOps.add(op);
      }
    }
    // 2. Ordenar por fecha descendente (las más recientes primero)
    allOps.sort((a, b) => b.date.compareTo(a.date));
    // 3. Tomar solo las últimas 5 operaciones
    final recentOps = allOps.take(5).toList();

    if (recentOps.isEmpty) {
      return const SizedBox.shrink(); // No mostramos nada si no hay operaciones
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Últimas operaciones',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < recentOps.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Colors.white12),
                _buildOperationTile(recentOps[i], funds),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperationTile(FundOperation op, List<FundData> funds) {
    final isBuy = op.type == OperationType.buy;
    final color = isBuy ? Colors.greenAccent : Colors.redAccent;
    final icon = isBuy ? Icons.add_circle_outline : Icons.remove_circle_outline;
    // En compra el dinero sale (-), en venta entra (+)
    //final sign = isBuy ? '-' : '+';
    final tooltip = isBuy ? 'Suscripción' : 'Reembolso';
    //final fund = funds.firstWhere((fund) => fund.isin == op.isin);
    final fundIsin = funds.where((fund) => fund.isin == op.isin).toList();
    if (fundIsin.isEmpty) return SizedBox.shrink();
    final fund = fundIsin.first;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
      title: Text(
        fund.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          //fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        dateFormat.format(op.date),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
      trailing: FittedBox(
        child: Column(
          mainAxisSize: .max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${smartFormat.format(op.amount)} ${fund.currency}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              '${op.units.toStringAsFixed(3)} partes',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.emptyPortfolio,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FundSearchPage()),
            ),
            icon: const Icon(Icons.search),
            label: Text(l10n.addFirstFund),
          ),
        ],
      ),
    );
  }
}
