import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/fund_data.dart';
import '../providers/fund_provider.dart';
import '../screens/fund_details_page.dart';
import '../utils/financial_calculator.dart';
import 'circle_avatar_fund.dart';

class BuildFundsList extends StatelessWidget {
  final FundData fund;

  const BuildFundsList({super.key, required this.fund});

  @override
  Widget build(BuildContext context) {
    return Selector<FundProvider, _FundListInputs?>(
      selector: (_, provider) => _FundListInputs.fromProvider(provider, fund),
      shouldRebuild: (previous, next) => previous == null || next == null
          ? previous != next
          : !previous.hasSameDataAs(next),
      builder: (context, inputs, _) {
        if (inputs == null) return const SizedBox.shrink();

        final locale = Localizations.localeOf(context).toString();
        final smartFormat = NumberFormat('#,##0.##', locale);

        return _buildFundItem(
          context,
          context.read<FundProvider>(),
          inputs.fund,
          smartFormat,
        );
      },
    );
  }

  Widget _buildFundItem(
    BuildContext context,
    FundProvider provider,
    FundData fund,
    NumberFormat smartFormat,
  ) {
    final metrics = FinancialCalculator.calculateFundMetrics(fund);

    return Card(
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
                                      fontWeight: .bold,
                                      fontSize: 14,
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
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (fund.operations.isNotEmpty)
                    Text(
                      '${smartFormat.format(metrics.currentValue)} ${fund.currency}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
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
}

class _FundListInputs {
  final FundData fund;

  const _FundListInputs(this.fund);

  static _FundListInputs? fromProvider(FundProvider provider, FundData fund) {
    for (final portfolioFund in provider.portfolio) {
      if (portfolioFund.isin == fund.isin) {
        return _FundListInputs(portfolioFund);
      }
    }
    return null;
  }

  bool hasSameDataAs(_FundListInputs other) {
    final first = fund;
    final second = other.fund;

    if (first.isin != second.isin ||
        first.name != second.name ||
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
          firstOperation.price != secondOperation.price ||
          firstOperation.amount != secondOperation.amount) {
        return false;
      }
    }

    return true;
  }
}
