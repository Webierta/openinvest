import 'package:material_ui/material_ui.dart';
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

    final fechasCotizacion = provider.portfolio
        .where((fund) => fund.history.isNotEmpty)
        .map((fund) => fund.history.last.date)
        .toList();

    final DateTime? ultimaFecha = fechasCotizacion.isEmpty
        ? null
        : fechasCotizacion.reduce((a, b) => a.isAfter(b) ? a : b);

    final historicalMetrics =
        FinancialCalculator.calculateHistoricalInvestmentsMetrics(
          provider.historicalInvestments,
          provider.historicalOperations,
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
                    textAlign: .center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : funds.isEmpty && provider.historicalInvestments.isEmpty
              // sin fondos vigentes ni inversiones históricas
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  onRefresh: provider.loadPortfolio,
                  child: CustomScrollView(
                    slivers: [
                      // TOTAL VALUE Y PESOS
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: .all(16.0),
                          child: _buildTotalValue(
                            provider,
                            portfolioMetrics,
                            ultimaFecha: ultimaFecha,
                          ),
                        ),
                      ),

                      // MÉTRICAS CARTERA + TRAYECTORIA INVERSORA
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const .all(16),
                          child: _buildSummaryPanel(
                            portfolioMetrics: portfolioMetrics,
                            historicalMetrics: historicalMetrics,
                            globalMetrics: globalMetrics,
                            showHistorical:
                                provider.historicalInvestments.isNotEmpty,
                            provider: provider,
                          ),
                        ),
                      ),

                      // CUADRÍCULA DE ACCIONES RÁPIDAS
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const .symmetric(horizontal: 32.0),
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
                          padding: const .fromLTRB(20, 8, 16, 0),
                          child: _buildActionGrid(context, provider),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // 3. LISTADO DE FONDOS
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const .symmetric(horizontal: 32.0),
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
                        SliverToBoxAdapter(
                          child: Center(
                            child: Text(
                              l10n.portfolioLoadError,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        )
                      else if (provider.portfolio.isEmpty)
                        //Center(child: Text(l10n.emptyPortfolio))
                        SliverToBoxAdapter(
                          child: Center(child: Text(l10n.emptyPortfolio)),
                        )
                      else
                        SliverPadding(
                          //padding: .fromLTRB(8, 0, 8, 16),
                          padding: .symmetric(horizontal: 16, vertical: 4),
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

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
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
                      const SliverToBoxAdapter(child: SizedBox(height: 42)),
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
    GlobalMetrics portfolioMetrics, {
    required DateTime? ultimaFecha,
  }) {
    final portfolioProfitColor = portfolioMetrics.profitAbs >= 0
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;

    return Container(
      padding: const .all(12),
      //padding: .fromLTRB(24, 24, 24, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: .circular(20),
        border: .all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
                  overflow: .ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: .bold,
                    //letterSpacing: -1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.assessment, color: Colors.white70, size: 24),
                const SizedBox(width: 8),
                Text(l10n.countFunds(provider.portfolio.length)),
              ],
            ),
            const SizedBox(height: 12),
            _buildPesos(provider, portfolioMetrics),
            if (ultimaFecha != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: .end,
                children: [
                  Text(
                    'Datos a fecha de ${dateFormat.format(ultimaFecha)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPesos(FundProvider provider, GlobalMetrics metrics) {
    if (metrics.totalValue <= 0) {
      return SizedBox.shrink();
    }

    return Container(
      padding: const .all(24),
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
          Text(
            l10n.weightsLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: .circular(8),
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
                      triggerMode: .tap,
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

  Widget _buildSummaryPanel({
    required GlobalMetrics portfolioMetrics,
    required HistoricalInvestmentMetrics historicalMetrics,
    required GlobalMetrics globalMetrics,
    required bool showHistorical,
    required FundProvider provider,
  }) {
    return Container(
      padding: const .all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: .circular(20),
        border: .all(color: Colors.white.withValues(alpha: 0.12)),
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
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'Resumen de inversiones',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          _buildSummarySection(
            title: 'Cartera',
            subtitle: 'Fondos en seguimiento',
            icon: Icons.assessment_outlined,
            accentColor: Colors.blueAccent,
            inversion: portfolioMetrics.totalInvested,
            rendimientoAbsoluto: portfolioMetrics.profitAbs,
            rentabilidadSimple: portfolioMetrics.profitRel,
            mwr: portfolioMetrics.mwrAnnualized,
            countInv: provider.portfolio.length,
          ),
          if (showHistorical) ...[
            /* Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: Colors.white.withValues(alpha: 0.15),
            ), */
            _buildSummarySection(
              title: 'Histórico',
              subtitle: 'Trayectoria inversora',
              icon: Icons.history_outlined,
              accentColor: Colors.yellowAccent.shade700,
              inversion: historicalMetrics.totalContributions,
              rendimientoAbsoluto: historicalMetrics.profitAbs,
              rentabilidadSimple: historicalMetrics.profitRel ?? 0,
              mwr: historicalMetrics.mwrAnnualized,
              countInv: provider.historicalInvestments.length,
            ),
            /* Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: Colors.white.withValues(alpha: 0.15),
            ), */
            _buildSummarySection(
              title: 'Global',
              subtitle: 'Balance inversor',
              //icon: Icons.language_outlined,
              icon: Icons.account_balance_outlined,
              accentColor: Colors.tealAccent,
              inversion: globalMetrics.totalInvestedGlobal,
              rendimientoAbsoluto: globalMetrics.profitAbsGlobal,
              rentabilidadSimple: globalMetrics.profitRelGlobal * 100,
              mwr: globalMetrics.mwrAnnualizedGlobal,
            ),
          ],
          Divider(
            height: 1,
            indent: 4,
            endIndent: 4,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white38, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'La rentabilidad acumulada no está anualizada ni considera flujos de capital',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required double inversion,
    required double rendimientoAbsoluto,
    required double rentabilidadSimple,
    required double? mwr,
    int? countInv,
  }) {
    final hayInversion = inversion > 0;

    final profitColor = rendimientoAbsoluto >= 0
        ? Colors.greenAccent[400]! //accentColor
        : Colors.redAccent[200]!;

    final profitRelColor = rentabilidadSimple >= 0
        ? Colors.greenAccent[400]! //accentColor
        : Colors.redAccent[200]!;

    final mwrColor = (mwr != null && mwr >= 0)
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;

    final metrics = <Widget>[
      _buildSummaryMetric(
        label: l10n.invested,
        value: '${smartFormat.format(inversion)} €',
        valueColor: Colors.white,
      ),
      _buildSummaryMetric(
        label: l10n.absoluteReturnLabel,
        value:
            '${rendimientoAbsoluto > 0 ? '+' : ''}'
            '${smartFormat.format(rendimientoAbsoluto)} €',
        valueColor: profitColor,
      ),
      _buildSummaryMetric(
        label: 'Rentabilidad acumulada',
        value:
            '${rentabilidadSimple > 0 ? '+' : ''}'
            '${percentFormat.format(rentabilidadSimple)} %',
        valueColor: profitRelColor,
      ),
      if (mwr != null)
        _buildSummaryMetric(
          label: 'MWR anualizado',
          value:
              '${mwr > 0 ? '+' : ''}'
              '${smartFormat.format(mwr * 100)} %',
          valueColor: mwrColor,
        ),
    ];

    return Padding(
      padding: const .symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CABECERA DE LA SECCIÓN
          Container(
            padding: const .symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              //borderRadius: .circular(12),
              borderRadius: .vertical(top: .circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 52, color: accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 20,
                          fontWeight: .bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: accentColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (countInv != null)
                  CircleAvatar(
                    backgroundColor: accentColor,
                    child: Text(
                      countInv.toString(),
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: .bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // MÉTRICAS
          if (hayInversion) ...[
            Container(
              //padding: .all(8),
              padding: const .symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  // Dirección del degradado (puedes ajustarla según necesites)
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accentColor.withValues(alpha: 0.16),
                    Colors.transparent, // Se desvanece a transparente
                  ],
                  // Opcional: puedes controlar en qué punto de la caja ocurre la transición
                  // stops: [0.0, 1.0],
                ),
              ),
              child: Column(
                children: [
                  //const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 760) {
                        return Row(
                          crossAxisAlignment: .start,
                          children: [
                            for (int i = 0; i < metrics.length; i++) ...[
                              if (i > 0)
                                Container(
                                  width: 1,
                                  height: 65,
                                  margin: const .symmetric(horizontal: 12),
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              Expanded(child: metrics[i]),
                            ],
                          ],
                        );
                      }

                      final columns = constraints.maxWidth >= 420 ? 2 : 1;
                      final itemWidth = columns == 2
                          ? (constraints.maxWidth - 8) / 2
                          : constraints.maxWidth;

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final metric in metrics)
                            SizedBox(width: itemWidth, child: metric),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required Color valueColor,
    String? tooltip,
  }) {
    final labelWidget = Text(
      label.toUpperCase(),
      style: TextStyle(color: Colors.white70, fontSize: 10),
      maxLines: 1,
      overflow: .ellipsis,
    );

    return Column(
      crossAxisAlignment: .start,
      children: [
        if (tooltip != null)
          Tooltip(message: tooltip, child: labelWidget)
        else
          labelWidget,
        //const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: .ellipsis,
          style: TextStyle(color: valueColor, fontSize: 18, fontWeight: .bold),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context, FundProvider provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Responsive: 6, 3, 2 y 1 columnas
    final int crossAxisCount = screenWidth > 1000
        ? 6
        : screenWidth > 650
        ? 3
        : screenWidth > 350
        ? 2
        : 1;
    // En pantallas muy pequeñas (<360px), hacemos las tarjetas un poco más altas
    //(aspectRatio < 1.0) para evitar que el texto se desborde si ocupa 2 líneas.
    /* final double aspectRatio = screenWidth > 1000
        ? 0.5 // 1.0
        : screenWidth > 650
        ? 1.0 // 1.5
        : 1.5; //2.0; */
    //final double aspectRatio = 1;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: 160,
      //childAspectRatio: aspectRatio,
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
          padding: const .all(10),
          decoration: BoxDecoration(
            //color: Colors.white.withValues(alpha: 0.05),
            color: color.withValues(alpha: 0.2),
            borderRadius: .circular(16),
            border: .all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisAlignment: .center,
            mainAxisSize: .min, // Clave: no forzar altura extra
            children: [
              Container(
                padding: const .all(10),
                decoration: BoxDecoration(
                  //color: color.withValues(alpha: 0.15),
                  color: Colors.white,
                  shape: .circle,
                ),
                child: Icon(icon, color: color, size: 32),
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
                  fontSize: 16,
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
    );
  }

  Widget _buildFundListItem(
    BuildContext context,
    FundProvider provider,
    FundData fund,
  ) {
    final metrics = FinancialCalculator.calculateFundMetrics(fund);
    return Card(
      //margin: const .symmetric(horizontal: 12, vertical: 6),
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
          padding: const .symmetric(horizontal: 24.0),
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
    if (op.type == .sell) {
      color = Colors.redAccent;
      icon = Icons.indeterminate_check_box_outlined;
      //remove_circle_outline;
      tooltip = l10n.redemption;
    } else if (op.type == .outTransfer) {
      color = Colors.redAccent.shade100;
      icon = Icons.output_outlined;
      tooltip = l10n.outTransfer;
    } else if (op.type == .inTransfer) {
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
            shape: .circle,
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
    if (allInvestments.isEmpty) {
      return const SizedBox.shrink();
      // No mostramos nada si no hay inversiones históricas
    }

    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const .symmetric(horizontal: 24.0),
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
