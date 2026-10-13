import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../providers/fund_provider.dart';
import '../tools/portfolio_correlation_matrix.dart';
import '../utils/financial_calculator.dart';
import '../widgets/circle_avatar_fund.dart';
import '../widgets/error_banner.dart';
import '../widgets/gradient_background.dart';
import 'correlation_matrix_page.dart';
import 'fund_search_page.dart';

class PortfolioSummaryPage extends StatefulWidget {
  const new({super.key});

  @override
  State<PortfolioSummaryPage> createState() => _PortfolioSummaryPageState();
}

class _PortfolioSummaryPageState extends State<PortfolioSummaryPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<FundProvider>();
    final locale = Localizations.localeOf(context).toString();
    //final priceFormat = NumberFormat('#,##0.0000', locale);
    final percentFormat = NumberFormat('#,##0.00', locale);
    final smartFormat = NumberFormat('#,##0.##', locale);

    final globalMetrics = FinancialCalculator.calculateGlobalMetrics(
      provider.portfolio,
      provider.exchangeRates,
    );

    //final funds = provider.portfolio;
    //final correlationMatrix = provider.loadCorrelationMatrix(funds);

    final Color globalProfitColor = globalMetrics.profitAbs >= 0
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;

    final bool showPortfolioSummary = globalMetrics.totalInvested > 0;
    return Scaffold(
      appBar: AppBar(title: Text('Cartera')),
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
                    ? Center(
                        child: Text(
                          l10n.portfolioLoadError,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
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
                            Text(l10n.emptyPortfolio),
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FundSearchPage(),
                                ),
                              ),
                              icon: const Icon(Icons.search),
                              label: Text(l10n.addFirstFund),
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
                                      Text(
                                        l10n.portfolioSummary,
                                        style: const TextStyle(
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
                                        '${l10n.invested}: ${smartFormat.format(globalMetrics.totalInvested)} €',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.white70),
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
                                              '${globalMetrics.isAnnualized ? l10n.sortByPerformance : l10n.gain}: ${globalMetrics.profitRel > 0 ? '+' : ''}${percentFormat.format(globalMetrics.profitRel)}%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          // Mostrar indicador de carga si la cartera es grande (>10 fondos)
                                          if (provider.portfolio.length > 10) {
                                            // Muestra un CircularProgressIndicator aquí si lo deseas
                                          }
                                          // Cálculo (puedes usar 'compute' aquí si quieres ser ultra-optimista)
                                          final matrix =
                                              calculatePortfolioCorrelationMatrix(
                                                provider.portfolio,
                                                minDataPoints: 30,
                                              );
                                          if (!mounted) return;
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  CorrelationMatrixPage(
                                                    funds: provider.portfolio,
                                                    matrix: matrix,
                                                  ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.grid_4x4),
                                        label: const Text(
                                          'Matriz de Correlación',
                                        ),
                                      ),
                                      if (globalMetrics.totalValue > 0) ...[
                                        const SizedBox(height: 24),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: SizedBox(
                                            height: 8,
                                            width: double.infinity,
                                            child: Row(
                                              children: provider.portfolio.map((
                                                item,
                                              ) {
                                                final metrics =
                                                    FinancialCalculator.calculateFundMetrics(
                                                      item,
                                                    );
                                                final double rate =
                                                    provider.exchangeRates[item
                                                        .currency] ??
                                                    1.0;
                                                final fundValue =
                                                    metrics.currentValue * rate;
                                                final weight =
                                                    fundValue /
                                                    globalMetrics.totalValue;

                                                if (weight <= 0) {
                                                  return const SizedBox.shrink();
                                                }

                                                return Expanded(
                                                  flex: (weight * 1000).toInt(),
                                                  child: Tooltip(
                                                    message:
                                                        '${item.name}\n${l10n.weightLabel}: ${percentFormat.format(weight * 100)}%',
                                                    triggerMode:
                                                        TooltipTriggerMode.tap,
                                                    preferBelow: false,
                                                    child: Container(
                                                      color: CircleAvatarFund(
                                                        fund: item,
                                                      ).getFundColor,
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 0.5,
                                                          ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }
                            return SizedBox.shrink();
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
