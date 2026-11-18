import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/fund_provider.dart';
import '../screens/correlation_matrix_page.dart';
import '../screens/compara_page.dart';
import '../tools/files_generator.dart';
import '../widgets/build_funds_list.dart';
import '../widgets/build_historical_investments.dart';
import '../widgets/build_recent_operations.dart';
import '../widgets/build_summary_header.dart';
import '../widgets/build_summary_panel.dart';
import '../widgets/gradient_background.dart';
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
                          child: const BuildSummaryHeader(),
                        ),
                      ),

                      // TARJETAS CARTERA + HISTÓRICO + GLOBAL
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const .all(16),
                          child: const BuildSummaryPanel(),
                        ),
                      ),

                      // CUADRÍCULA DE ACCIONES RÁPIDAS
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const .symmetric(horizontal: 32.0),
                          child: Text(
                            l10n.actionsLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: .bold,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const .fromLTRB(20, 8, 20, 8),
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
                            style: const TextStyle(
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
                              return BuildFundsList(
                                key: ValueKey(fund.isin),
                                fund: fund,
                              );
                            }, childCount: funds.length),
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      // Listado de Operaciones recientes
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const .symmetric(horizontal: 8),
                          child: const BuildRecentOperations(),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // Listado inversiones históricas
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const .symmetric(horizontal: 8),
                          /* child: _buildHistoricalInvestments(
                            context,
                            provider.historicalInvestments,
                          ), */
                          child: const BuildHistoricalInvestments(),
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
      padding: .zero,
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
          title: l10n.investmentHistoryTitle,
          subtitle: l10n.investmentJourneySubtitle,
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
          title: l10n.annualReportTitle,
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
          title: l10n.operationsTitle,
          subtitle: l10n.csvSpreadsheetSubtitle,
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

  /* Widget _buildHistoricalInvestments(
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
            l10n.historicalInvestmentsTitle,
            style: const TextStyle(color: Colors.white70, fontWeight: .bold),
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
  } */

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
