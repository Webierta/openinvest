import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/fund_provider.dart';
import '../widgets/build_actions_grid.dart';
import '../widgets/build_funds_list.dart';
import '../widgets/build_historical_investments.dart';
import '../widgets/build_recent_operations.dart';
import '../widgets/build_summary_header.dart';
import '../widgets/build_summary_panel.dart';
import '../widgets/gradient_background.dart';
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
                          child: const BuildActionsGrid(),
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
                        SliverToBoxAdapter(
                          child: Center(child: Text(l10n.emptyPortfolio)),
                        )
                      else
                        SliverPadding(
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
