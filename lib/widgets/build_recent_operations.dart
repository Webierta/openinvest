import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/fund_data.dart';
import '../providers/fund_provider.dart';

class BuildRecentOperations extends StatelessWidget {
  const BuildRecentOperations({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<FundProvider, _RecentOperationsInputs>(
      selector: (_, provider) => _RecentOperationsInputs.fromProvider(provider),
      shouldRebuild: (previous, next) => !previous.hasSameDataAs(next),
      builder: (context, inputs, _) {
        if (inputs.operations.isEmpty) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context)!;
        final locale = Localizations.localeOf(context).toString();
        final smartFormat = NumberFormat('#,##0.##', locale);
        final dateFormat = DateFormat.yMMMd(locale);

        return Column(
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const .symmetric(horizontal: 24),
              child: Text(
                l10n.recentOperationsTitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: .bold,
                ),
              ),
            ),
            Container(
              margin: const .symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: .circular(16),
                border: .all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < inputs.operations.length;
                    index++
                  ) ...[
                    if (index > 0)
                      const Divider(height: 1, color: Colors.white12),
                    _buildOperationTile(
                      context,
                      inputs.operations[index],
                      l10n,
                      smartFormat,
                      dateFormat,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOperationTile(
    BuildContext context,
    _RecentOperationData operation,
    AppLocalizations l10n,
    NumberFormat smartFormat,
    DateFormat dateFormat,
  ) {
    Color color = Colors.greenAccent;
    IconData icon = Icons.add_box_outlined;
    String tooltip = l10n.subscription;

    if (operation.type == .sell) {
      color = Colors.redAccent;
      icon = Icons.indeterminate_check_box_outlined;
      tooltip = l10n.redemption;
    } else if (operation.type == .outTransfer) {
      color = Colors.redAccent.shade100;
      icon = Icons.output_outlined;
      tooltip = l10n.outTransfer;
    } else if (operation.type == .inTransfer) {
      color = Colors.greenAccent.shade100;
      icon = Icons.input_outlined;
      tooltip = l10n.inTransfer;
    }

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
        operation.fundName,
        maxLines: 1,
        overflow: .ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      subtitle: Text(
        dateFormat.format(operation.date),
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
              '${smartFormat.format(operation.amount)} ${operation.currency}',
              style: TextStyle(color: color, fontWeight: .bold, fontSize: 14),
            ),
            Text(
              l10n.unitsPartsFormat(operation.units.toStringAsFixed(3)),
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
}

class _RecentOperationsInputs {
  final List<_RecentOperationData> operations;

  const _RecentOperationsInputs({required this.operations});

  factory _RecentOperationsInputs.fromProvider(FundProvider provider) {
    final fundDataByIsin = <String, FundData>{};
    for (final fund in provider.portfolio) {
      fundDataByIsin[fund.isin] = fund;
    }

    final operations = <_RecentOperationData>[];
    for (final fund in provider.portfolio) {
      for (final operation in fund.operations) {
        final fundData = fundDataByIsin[operation.isin];
        if (fundData == null) continue;

        operations.add(
          _RecentOperationData(
            fundName: fundData.name,
            currency: fundData.currency,
            date: operation.date,
            type: operation.type,
            units: operation.units,
            amount: operation.amount,
          ),
        );
      }
    }

    operations.sort((first, second) => second.date.compareTo(first.date));

    return _RecentOperationsInputs(
      operations: List<_RecentOperationData>.unmodifiable(operations.take(5)),
    );
  }

  bool hasSameDataAs(_RecentOperationsInputs other) {
    if (operations.length != other.operations.length) return false;

    for (var index = 0; index < operations.length; index++) {
      if (!operations[index].hasSameDataAs(other.operations[index])) {
        return false;
      }
    }

    return true;
  }
}

class _RecentOperationData {
  final String fundName;
  final String currency;
  final DateTime date;
  final OperationType type;
  final double units;
  final double amount;

  const _RecentOperationData({
    required this.fundName,
    required this.currency,
    required this.date,
    required this.type,
    required this.units,
    required this.amount,
  });

  bool hasSameDataAs(_RecentOperationData other) {
    return fundName == other.fundName &&
        currency == other.currency &&
        date == other.date &&
        type == other.type &&
        units == other.units &&
        amount == other.amount;
  }
}
