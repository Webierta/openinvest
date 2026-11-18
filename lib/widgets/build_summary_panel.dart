import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/fund_data.dart';
import '../models/historical_investment.dart';
import '../models/historical_operation.dart';
import '../providers/fund_provider.dart';
import '../utils/financial_calculator.dart';

class BuildSummaryPanel extends StatelessWidget {
  const BuildSummaryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const .fromLTRB(0, 12, 0, 12),
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
            padding: const .only(left: 16),
            child: Text(
              l10n.investmentSummaryTitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          _buildPortfolioSection(context),
          _buildHistoricalSection(context),
          _buildGlobalSection(context),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const .only(left: 16, right: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.cumulativeReturnDisclaimer,
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioSection(BuildContext context) {
    return Selector<FundProvider, _PortfolioSummaryInputs>(
      selector: (_, provider) => _PortfolioSummaryInputs.fromProvider(provider),
      shouldRebuild: (previous, next) => !previous.hasSameDataAs(next),
      builder: (context, inputs, _) {
        final metrics = FinancialCalculator.calculateGlobalMetrics(
          inputs.portfolio,
          inputs.exchangeRates,
        );

        return _buildSummarySection(
          context,
          title: AppLocalizations.of(context)!.portfolioTitle,
          subtitle: AppLocalizations.of(context)!.activeFundsSubtitle,
          icon: Icons.assessment_outlined,
          accentColor: Colors.blueAccent,
          inversion: metrics.totalInvested,
          rendimientoAbsoluto: metrics.profitAbs,
          rentabilidadSimple: metrics.profitRel,
          mwr: metrics.mwrAnnualized,
          countInv: inputs.portfolio.length,
        );
      },
    );
  }

  Widget _buildHistoricalSection(BuildContext context) {
    return Selector<FundProvider, _HistoricalSummaryInputs>(
      selector: (_, provider) =>
          _HistoricalSummaryInputs.fromProvider(provider),
      shouldRebuild: (previous, next) => !previous.hasSameDataAs(next),
      builder: (context, inputs, _) {
        if (inputs.investments.isEmpty) return const SizedBox.shrink();

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics(
              inputs.investments,
              inputs.operations,
            );
        final l10n = AppLocalizations.of(context)!;

        return _buildSummarySection(
          context,
          title: l10n.investmentHistoryTitle,
          subtitle: l10n.investmentJourneySubtitle,
          icon: Icons.history_outlined,
          accentColor: Colors.yellowAccent.shade700,
          inversion: metrics.totalContributions,
          rendimientoAbsoluto: metrics.profitAbs,
          rentabilidadSimple: metrics.profitRel ?? 0,
          mwr: metrics.mwrAnnualized,
          countInv: inputs.investments.length,
        );
      },
    );
  }

  Widget _buildGlobalSection(BuildContext context) {
    return Selector<FundProvider, _GlobalSummaryInputs>(
      selector: (_, provider) => _GlobalSummaryInputs.fromProvider(provider),
      shouldRebuild: (previous, next) => !previous.hasSameDataAs(next),
      builder: (context, inputs, _) {
        if (inputs.historical.investments.isEmpty) {
          return const SizedBox.shrink();
        }

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          inputs.portfolio.portfolio,
          inputs.portfolio.exchangeRates,
          historicalInvestments: inputs.historical.investments,
          historicalOperations: inputs.historical.operations,
        );
        final l10n = AppLocalizations.of(context)!;

        return _buildSummarySection(
          context,
          title: l10n.globalSummaryTitle,
          subtitle: l10n.investorBalanceSubtitle,
          icon: Icons.account_balance_outlined,
          accentColor: Colors.tealAccent,
          inversion: metrics.totalInvestedGlobal,
          rendimientoAbsoluto: metrics.profitAbsGlobal,
          rentabilidadSimple: metrics.profitRelGlobal * 100,
          mwr: metrics.mwrAnnualizedGlobal,
        );
      },
    );
  }

  Widget _buildSummarySection(
    BuildContext context, {
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
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final smartFormat = NumberFormat('#,##0.##', locale);
    final percentFormat = NumberFormat('#,##0.00', locale);
    final hayInversion = inversion > 0;

    final profitColor = rendimientoAbsoluto >= 0
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;
    final profitRelColor = rentabilidadSimple >= 0
        ? Colors.greenAccent[400]!
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
        label: l10n.cumulativeReturnLabel,
        value:
            '${rentabilidadSimple > 0 ? '+' : ''}'
            '${percentFormat.format(rentabilidadSimple)} %',
        valueColor: profitRelColor,
      ),
      if (mwr != null)
        _buildSummaryMetric(
          label: l10n.annualizedMwrLabel,
          value: '${mwr > 0 ? '+' : ''}${smartFormat.format(mwr * 100)} %',
          valueColor: mwrColor,
        ),
    ];

    return Padding(
      padding: const .symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          // CABECERA DE LA SECCIÓN
          Container(
            padding: const .symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
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
          if (hayInversion)
            Container(
              padding: const .symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: .topCenter,
                  end: .bottomCenter,
                  colors: [
                    accentColor.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 760) {
                        return Row(
                          crossAxisAlignment: .start,
                          children: [
                            for (
                              var index = 0;
                              index < metrics.length;
                              index++
                            ) ...[
                              if (index > 0)
                                Container(
                                  width: 1,
                                  height: 65,
                                  margin: const .symmetric(horizontal: 12),
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              Expanded(child: metrics[index]),
                            ],
                          ],
                        );
                      }

                      final columns = constraints.maxWidth >= 340 ? 2 : 1;
                      final itemWidth = columns == 2
                          ? (constraints.maxWidth - 8) / 2
                          : constraints.maxWidth;

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final metric in metrics)
                            SizedBox(
                              width: itemWidth,
                              child: FittedBox(
                                fit: .scaleDown,
                                alignment: .centerLeft,
                                child: metric,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(color: Colors.white70, fontSize: 10),
          maxLines: 1,
          overflow: .ellipsis,
        ),
        Text(
          value,
          maxLines: 1,
          overflow: .ellipsis,
          style: TextStyle(color: valueColor, fontSize: 16, fontWeight: .bold),
        ),
      ],
    );
  }
}

class _PortfolioSummaryInputs {
  final List<FundData> portfolio;
  final Map<String, double> exchangeRates;

  _PortfolioSummaryInputs({
    required this.portfolio,
    required this.exchangeRates,
  });

  factory _PortfolioSummaryInputs.fromProvider(FundProvider provider) {
    return _PortfolioSummaryInputs(
      portfolio: List<FundData>.unmodifiable(provider.portfolio),
      exchangeRates: Map<String, double>.unmodifiable(provider.exchangeRates),
    );
  }

  bool hasSameDataAs(_PortfolioSummaryInputs other) {
    if (!mapEquals(exchangeRates, other.exchangeRates) ||
        portfolio.length != other.portfolio.length) {
      return false;
    }

    for (var index = 0; index < portfolio.length; index++) {
      if (!_fundsHaveSameMetricData(portfolio[index], other.portfolio[index])) {
        return false;
      }
    }

    return true;
  }
}

class _HistoricalSummaryInputs {
  final List<HistoricalInvestment> investments;
  final List<HistoricalOperation> operations;

  _HistoricalSummaryInputs({
    required this.investments,
    required this.operations,
  });

  factory _HistoricalSummaryInputs.fromProvider(FundProvider provider) {
    return _HistoricalSummaryInputs(
      investments: List<HistoricalInvestment>.unmodifiable(
        provider.historicalInvestments,
      ),
      operations: List<HistoricalOperation>.unmodifiable(
        provider.historicalOperations,
      ),
    );
  }

  bool hasSameDataAs(_HistoricalSummaryInputs other) {
    if (investments.length != other.investments.length ||
        operations.length != other.operations.length) {
      return false;
    }

    for (var index = 0; index < investments.length; index++) {
      if (investments[index].uid != other.investments[index].uid) return false;
    }
    for (var index = 0; index < operations.length; index++) {
      if (!_historicalOperationsHaveSameMetricData(
        operations[index],
        other.operations[index],
      )) {
        return false;
      }
    }

    return true;
  }
}

class _GlobalSummaryInputs {
  final _PortfolioSummaryInputs portfolio;
  final _HistoricalSummaryInputs historical;

  const _GlobalSummaryInputs({
    required this.portfolio,
    required this.historical,
  });

  factory _GlobalSummaryInputs.fromProvider(FundProvider provider) {
    return _GlobalSummaryInputs(
      portfolio: _PortfolioSummaryInputs.fromProvider(provider),
      historical: _HistoricalSummaryInputs.fromProvider(provider),
    );
  }

  bool hasSameDataAs(_GlobalSummaryInputs other) {
    return portfolio.hasSameDataAs(other.portfolio) &&
        historical.hasSameDataAs(other.historical);
  }
}

bool _fundsHaveSameMetricData(FundData first, FundData second) {
  if (first.isin != second.isin ||
      first.lastValue != second.lastValue ||
      first.currency != second.currency ||
      first.date != second.date ||
      first.operations.length != second.operations.length) {
    return false;
  }

  for (var index = 0; index < first.operations.length; index++) {
    final firstOperation = first.operations[index];
    final secondOperation = second.operations[index];
    if (firstOperation.date != secondOperation.date ||
        firstOperation.type != secondOperation.type ||
        firstOperation.units != secondOperation.units ||
        firstOperation.amount != secondOperation.amount) {
      return false;
    }
  }

  return true;
}

bool _historicalOperationsHaveSameMetricData(
  HistoricalOperation first,
  HistoricalOperation second,
) {
  return first.uid == second.uid &&
      first.investmentUid == second.investmentUid &&
      first.date == second.date &&
      first.type == second.type &&
      first.amount == second.amount &&
      first.transferUid == second.transferUid;
}
