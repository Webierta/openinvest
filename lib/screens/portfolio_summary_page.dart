import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:investing/models/fund_data.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/fund_provider.dart';
import '../screens/correlation_matrix_page.dart';
import '../screens/compara_page.dart';
import '../utils/financial_calculator.dart';
import '../widgets/circle_avatar_fund.dart';
import '../widgets/gradient_background.dart';
import 'fund_details_page.dart';
import 'fund_search_page.dart';

// Importa aquí tu página de añadir fondo o informes si las tienes separadas

class PortfolioSummaryPage extends StatelessWidget {
  const PortfolioSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<FundProvider>();
    final funds = provider.portfolio;

    final locale = Localizations.localeOf(context).toString();
    //final priceFormat = NumberFormat('#,##0.0000', locale);
    final percentFormat = NumberFormat('#,##0.00', locale);
    final smartFormat = NumberFormat('#,##0.##', locale);

    final globalMetrics = FinancialCalculator.calculateGlobalMetrics(
      provider.portfolio,
      provider.exchangeRates,
    );
    final Color globalProfitColor = globalMetrics.profitAbs >= 0
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cartera'), // Ajusta a tu clave de localización
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          /* IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar datos',
            onPressed: () => provider.refreshPortfolio(), // Tu método de actualización
          ), */
        ],
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
              ? _buildEmptyState(context, l10n) // NO HAY FONDOS
              : RefreshIndicator(
                  onRefresh: provider.loadPortfolio,
                  child: CustomScrollView(
                    slivers: [
                      // 1. TARJETA DE RESUMEN GLOBAL (HERO)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildSummaryCard(
                            context,
                            provider,
                            l10n,
                            globalMetrics,
                            smartFormat,
                            percentFormat,
                            globalProfitColor,
                          ),
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
                    ],
                  ),
                ),
        ),
      ),
      // Tu Floating Action Button existente para añadir fondo
      /* floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navega a tu página de añadir fondo
        },
        icon: const Icon(Icons.add),
        label: const Text('Añadir Fondo'),
        backgroundColor: const Color(0xFF3B82F6),
      ), */
    );
  }

  // --- WIDGETS AUXILIARES DE DISEÑO ---

  Widget _buildSummaryCard(
    BuildContext context,
    FundProvider provider,
    AppLocalizations l10n,
    GlobalMetrics globalMetrics,
    NumberFormat smartFormat,
    NumberFormat percentFormat,
    Color globalProfitColor,
  ) {
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
                  'Rendimiento',
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
                  globalMetrics.isAnnualized
                      ? l10n.sortByPerformance
                      : l10n.gain,
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
          icon: Icons.description,
          title: 'Informes',
          subtitle: 'PDF / CSV',
          color: Colors.teal,
          onTap: () {
            // TODO: Crear y Navegar a ReportsPage
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, dynamic l10n) {
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
