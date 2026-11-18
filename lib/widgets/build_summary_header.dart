import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/fund_data.dart';
import '../providers/fund_provider.dart';
import '../utils/financial_calculator.dart';
import 'circle_avatar_fund.dart';

class BuildSummaryHeader extends StatelessWidget {
  const BuildSummaryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<FundProvider, _SummaryHeaderInputs>(
      selector: (_, provider) => _SummaryHeaderInputs.fromProvider(provider),
      shouldRebuild: (previous, next) => !previous.hasSameDataAs(next),
      builder: (context, inputs, _) {
        final metrics = FinancialCalculator.calculateGlobalMetrics(
          inputs.portfolio,
          inputs.exchangeRates,
        );
        final locale = Localizations.localeOf(context).toString();
        final smartFormat = NumberFormat('#,##0.##', locale);
        final dateFormat = DateFormat.yMMMd(locale);

        return _buildHeader(context, inputs, metrics, smartFormat, dateFormat);
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    _SummaryHeaderInputs inputs,
    GlobalMetrics metrics,
    NumberFormat smartFormat,
    DateFormat dateFormat,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final portfolioProfitColor = metrics.profitAbs >= 0
        ? Colors.greenAccent[400]!
        : Colors.redAccent[200]!;

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
                  metrics.profitAbs >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: portfolioProfitColor,
                  size: 40,
                ),
                const SizedBox(width: 8),
                Text(
                  '${smartFormat.format(metrics.totalValue)} €',
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: .bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.assessment, color: Colors.white70, size: 24),
                const SizedBox(width: 8),
                Text(l10n.countFunds(inputs.portfolio.length)),
              ],
            ),
            const SizedBox(height: 12),
            _buildWeights(context, inputs, metrics),
            if (inputs.latestQuoteDate case final latestQuoteDate?) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: .end,
                children: [
                  Text(
                    l10n.portfolioDataAsOf(dateFormat.format(latestQuoteDate)),
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

  Widget _buildWeights(
    BuildContext context,
    _SummaryHeaderInputs inputs,
    GlobalMetrics metrics,
  ) {
    if (metrics.totalValue <= 0) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final percentFormat = NumberFormat('#,##0.00', locale);

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
                children: inputs.portfolio.map((fund) {
                  final fundMetrics = FinancialCalculator.calculateFundMetrics(
                    fund,
                  );
                  final exchangeRate =
                      inputs.exchangeRates[fund.currency] ?? 1.0;
                  final fundValue = fundMetrics.currentValue * exchangeRate;
                  final weight = fundValue / metrics.totalValue;
                  if (weight <= 0) return const SizedBox.shrink();
                  return Expanded(
                    flex: (weight * 1000).toInt(),
                    child: Tooltip(
                      message:
                          '${fund.name}\n${l10n.weightLabel}: '
                          '${percentFormat.format(weight * 100)}%',
                      triggerMode: .tap,
                      preferBelow: false,
                      child: Container(
                        color: CircleAvatarFund(fund: fund).getFundColor,
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
}

class _SummaryHeaderInputs {
  final List<FundData> portfolio;
  final Map<String, double> exchangeRates;
  final DateTime? latestQuoteDate;

  _SummaryHeaderInputs({
    required this.portfolio,
    required this.exchangeRates,
    required this.latestQuoteDate,
  });

  factory _SummaryHeaderInputs.fromProvider(FundProvider provider) {
    final portfolio = List<FundData>.unmodifiable(provider.portfolio);
    final quoteDates = portfolio
        .where((fund) => fund.history.isNotEmpty)
        .map((fund) => fund.history.last.date);
    DateTime? latestQuoteDate;
    for (final date in quoteDates) {
      if (latestQuoteDate == null || date.isAfter(latestQuoteDate)) {
        latestQuoteDate = date;
      }
    }

    return _SummaryHeaderInputs(
      portfolio: portfolio,
      exchangeRates: Map<String, double>.unmodifiable(provider.exchangeRates),
      latestQuoteDate: latestQuoteDate,
    );
  }

  bool hasSameDataAs(_SummaryHeaderInputs other) {
    if (!mapEquals(exchangeRates, other.exchangeRates) ||
        latestQuoteDate != other.latestQuoteDate ||
        portfolio.length != other.portfolio.length) {
      return false;
    }

    for (var index = 0; index < portfolio.length; index++) {
      if (!_fundsHaveSameRelevantData(
        portfolio[index],
        other.portfolio[index],
      )) {
        return false;
      }
    }

    return true;
  }

  bool _fundsHaveSameRelevantData(FundData first, FundData second) {
    if (first.isin != second.isin ||
        first.name != second.name ||
        first.lastValue != second.lastValue ||
        first.currency != second.currency ||
        first.date != second.date ||
        first.history.isEmpty != second.history.isEmpty ||
        (first.history.isNotEmpty &&
            first.history.last.date != second.history.last.date) ||
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
}
