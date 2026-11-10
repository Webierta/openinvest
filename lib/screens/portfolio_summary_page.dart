import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/fund_data.dart';

import '../l10n/app_localizations.dart';
import '../models/historical_investment.dart';
import '../providers/fund_provider.dart';
import '../screens/correlation_matrix_page.dart';
import '../screens/compara_page.dart';
import '../tools/files_generator.dart';
import '../utils/financial_calculator.dart';
import '../widgets/circle_avatar_fund.dart';
import '../widgets/gradient_background.dart';
import 'fund_details_page.dart';
import 'fund_search_page.dart';
import 'historical_investment_form_page.dart';

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
      historicalInvestments: provider.historicalInvestments,
      historicalOperations: provider.historicalOperations,
    );

    final portfolioMetrics = FinancialCalculator.calculateGlobalMetrics(
      provider.portfolio,
      provider.exchangeRates,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.portfolioTitle),
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
                      // TOTAL VALUE Y PESOS
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: .all(16.0),
                          child: _buildTotalValue(provider, portfolioMetrics),
                        ),
                      ),

                      // MÉTRICAS CARTERA + TRAYECTORIA INVERSORA
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const .all(16),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cards = [
                                _buildSummaryCard(
                                  title: 'Cartera actual',
                                  provider: provider,
                                  metrics: portfolioMetrics,
                                ),
                                _buildSummaryCard(
                                  title: 'Trayectoria inversora',
                                  provider: provider,
                                  metrics: globalMetrics,
                                  isPortfolio: false,
                                ),
                              ];
                              if (constraints.maxWidth >= 650) {
                                return Row(
                                  crossAxisAlignment: .start,
                                  children: [
                                    Expanded(child: cards[0]),
                                    const SizedBox(width: 16),
                                    Expanded(child: cards[1]),
                                  ],
                                );
                              }
                              return Column(
                                children: [
                                  cards[0],
                                  const SizedBox(height: 16),
                                  cards[1],
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      // CUADRÍCULA DE ACCIONES RÁPIDAS
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const .symmetric(horizontal: 16.0),
                          child: Text(
                            l10n.actionsLabel,
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
                          padding: const .fromLTRB(16, 8, 16, 16),
                          child: _buildActionGrid(context, provider),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),

                      // 3. LISTADO DE FONDOS
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const .symmetric(horizontal: 16.0),
                          child: Text(
                            l10n.yourFundsTitle('${funds.length}'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: .bold,
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
                          padding: .fromLTRB(8, 0, 8, 16),
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
                          padding: const .symmetric(horizontal: 8),
                          child: _buildRecentOperations(
                            context,
                            provider.portfolio,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // Listado inversiones históricas
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const .symmetric(horizontal: 8),
                          child: _buildHistoricalInvestments(
                            context,
                            provider.historicalInvestments,
                          ),
                        ),
                      ),
                      // Espacio final para que el FAB no tape el último elemento
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES DE DISEÑO ---

  Widget _buildTotalValue(
    FundProvider provider,
    GlobalMetrics portfolioMetrics,
  ) {
    final portfolioProfitColor = portfolioMetrics.profitAbs >= 0
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: .all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            l10n.currentPortfolioValue,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                portfolioMetrics.profitAbs >= 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: portfolioProfitColor,
                size: 40,
              ),
              const SizedBox(width: 8),
              Text(
                '${smartFormat.format(portfolioMetrics.totalValue)} €',
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
          const SizedBox(height: 8),
          _buildPesos(provider, portfolioMetrics),
        ],
      ),
    );
  }

  Widget _buildPesos(FundProvider provider, GlobalMetrics metrics) {
    if (metrics.totalValue <= 0) {
      return SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: .all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            l10n.weightsLabel,
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
                  final calculateFundMetrics =
                      FinancialCalculator.calculateFundMetrics(item);
                  final double rate =
                      provider.exchangeRates[item.currency] ?? 1.0;
                  final fundValue = calculateFundMetrics.currentValue * rate;
                  final weight = fundValue / metrics.totalValue;
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
                        margin: const .symmetric(horizontal: 0.5),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required FundProvider provider,
    required GlobalMetrics metrics,
    bool? isPortfolio = true,
  }) {
    if (isPortfolio == false && provider.historicalInvestments.isEmpty) {
      return SizedBox.shrink();
    }

    final bool hayInversionCartera = metrics.totalInvested > 0;

    double inversion = metrics.totalInvested;
    double rendimientoAbsoluto = metrics.profitAbs;
    //double rentabilidadSimple = metrics.profitRel;
    double accumulatedReturn = inversion > 0
        ? rendimientoAbsoluto / inversion * 100
        : 0.0;
    double? mwr = metrics.mwrAnnualized;
    Color profitColor = metrics.profitAbs >= 0
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;

    if (isPortfolio == false) {
      inversion = metrics.totalInvestedGlobal;
      rendimientoAbsoluto = metrics.profitAbsGlobal;
      //rentabilidadSimple = metrics.profitRelGlobal;
      accumulatedReturn = inversion > 0
          ? rendimientoAbsoluto / inversion * 100
          : 0.0;
      mwr = metrics.mwrAnnualizedGlobal;
      profitColor = metrics.profitAbsGlobal >= 0
          ? Colors.greenAccent[400]!
          : Colors.redAccent[200]!;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: .circular(20),
        border: .all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(title, style: TextStyle(fontSize: 16)),
          if (hayInversionCartera) ...[
            const SizedBox(height: 10),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),

            // TOTAL INVERTIDO
            Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  l10n.invested,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${smartFormat.format(inversion)} €',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: .bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // RENDIMIENTO ABSOLUTO
            Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  l10n.absoluteReturnLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${rendimientoAbsoluto > 0 ? '+' : ''}${smartFormat.format(rendimientoAbsoluto)} €',
                  style: TextStyle(
                    color: profitColor,
                    fontSize: 18,
                    fontWeight: .bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // RENTABILIDAD SIMPLE ACUMULADA
            Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  'Rentabilidad simple acumulada',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${accumulatedReturn > 0 ? '+' : ''}${percentFormat.format(accumulatedReturn)} %',
                  style: TextStyle(
                    color: profitColor,
                    fontSize: 18,
                    fontWeight: .bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // MWR ANUALIZADO
            if (metrics.mwrAnnualized != null)
              Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    'MWR anualizado',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${mwr! > 0 ? '+' : ''}'
                    '${smartFormat.format(mwr * 100)} %',
                    style: TextStyle(
                      color: profitColor,
                      fontSize: 18,
                      fontWeight: .bold,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, FundProvider provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Responsive: 2 columnas en móvil, 4 en escritorio (Linux/Windows)
    //final int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;
    final int crossAxisCount = screenWidth > 1000 ? 6 : 3;
    // En pantallas muy pequeñas (<360px), hacemos las tarjetas un poco más altas
    //(aspectRatio < 1.0) para evitar que el texto se desborde si ocupa 2 líneas.
    final double aspectRatio = screenWidth > 1000
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
          title: l10n.addAction,
          subtitle: l10n.newFundSubtitle,
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
          title: l10n.compareLabel,
          subtitle: l10n.twoFundsSubtitle,
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
          title: l10n.correlationAction,
          subtitle: l10n.riskMatrixSubtitle,
          color: Colors.orange,
          onTap: () async {
            if (provider.portfolio.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.needAtLeastTwoFundsForCorrelation)),
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
          icon: Icons.history,
          title: 'Histórico',
          subtitle: 'Trayectoria inversora',
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HistoricalInvestmentFormPage(),
              ),
            );
          },
        ),

        _buildActionCard(
          context,
          provider,
          icon: Icons.picture_as_pdf,
          title: 'Informe anual',
          subtitle: 'PDF',
          color: Colors.teal,
          onTap: () {
            final filesGenerator = FilesGenerator(
              context: context,
              l10n: l10n,
              provider: provider,
            );
            filesGenerator.initReportPdf();
          },
        ),

        _buildActionCard(
          context,
          provider,
          icon: Icons.table_view,
          title: 'Operaciones',
          subtitle: 'Hoja CSV',
          color: Colors.teal,
          onTap: () {
            final filesGenerator = FilesGenerator(
              context: context,
              l10n: l10n,
              provider: provider,
            );
            filesGenerator.initExportCsv();
          },
        ),
      ],
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
        borderRadius: .circular(16),
        child: Container(
          padding: const .all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: .circular(16),
            border: .all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: FittedBox(
            fit: .scaleDown,
            child: Column(
              mainAxisAlignment: .center,
              mainAxisSize: .min, // Clave: no forzar altura extra
              children: [
                Container(
                  padding: const .all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: .circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: .ellipsis,
                  textAlign: .center,
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
                  overflow: .ellipsis,
                  textAlign: .center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
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
      margin: const .symmetric(horizontal: 12, vertical: 6),
      color: Colors.white.withValues(alpha: 0.03),
      child: InkWell(
        borderRadius: .circular(16),
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
                      crossAxisAlignment: .start,
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
                                    overflow: .ellipsis,
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
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 16.0),
          child: Text(
            l10n.recentOperationsTitle,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          margin: const .symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: .circular(16),
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
    // En compra el dinero sale (-), en venta entra (+)

    Color color = Colors.greenAccent;
    IconData icon = Icons.add_box_outlined;
    //add_circle_outline;
    String tooltip = l10n.subscription;
    if (op.type == OperationType.sell) {
      color = Colors.redAccent;
      icon = Icons.indeterminate_check_box_outlined;
      //remove_circle_outline;
      tooltip = l10n.redemption;
    } else if (op.type == OperationType.outTransfer) {
      color = Colors.redAccent.shade100;
      icon = Icons.output_outlined;
      tooltip = l10n.outTransfer;
    } else if (op.type == OperationType.inTransfer) {
      color = Colors.greenAccent.shade100;
      icon = Icons.input_outlined;
      tooltip = l10n.inTransfer;
    }

    //final fund = funds.firstWhere((fund) => fund.isin == op.isin);
    final fundIsin = funds.where((fund) => fund.isin == op.isin).toList();
    if (fundIsin.isEmpty) return SizedBox.shrink();
    final fund = fundIsin.first;

    return ListTile(
      contentPadding: const .symmetric(horizontal: 16, vertical: 8),
      leading: Tooltip(
        message: tooltip,
        child: Container(
          padding: const .all(8),
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
        overflow: .ellipsis,
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
          mainAxisAlignment: .center,
          crossAxisAlignment: .end,
          children: [
            Text(
              '${smartFormat.format(op.amount)} ${fund.currency}',
              style: TextStyle(color: color, fontWeight: .bold, fontSize: 14),
            ),
            Text(
              //'${op.units.toStringAsFixed(3)} partes',
              l10n.unitsPartsFormat(op.units.toStringAsFixed(3)),
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

  Widget _buildHistoricalInvestments(
    BuildContext context,
    List<HistoricalInvestment> allInvestments,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 16.0),
          child: Text(
            'Inversiones históricas',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          margin: const .symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: .circular(16),
            border: .all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < allInvestments.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Colors.white12),
                //_buildOperationTile(recentOps[i], funds),
                ListTile(
                  contentPadding: const .symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(Icons.history),
                  title: Text(allInvestments[i].name),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: .center,
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
              fontWeight: .bold,
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
