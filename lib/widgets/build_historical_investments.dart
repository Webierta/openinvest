import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/fund_provider.dart';

class BuildHistoricalInvestments extends StatelessWidget {
  const BuildHistoricalInvestments({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<FundProvider, _HistoricalInvestmentsInputs>(
      selector: (_, provider) =>
          _HistoricalInvestmentsInputs.fromProvider(provider),
      shouldRebuild: (previous, next) => !previous.hasSameDataAs(next),
      builder: (context, inputs, _) {
        if (inputs.investments.isEmpty) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context)!;

        return Column(
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const .symmetric(horizontal: 24),
              child: Text(
                l10n.historicalInvestmentsTitle,
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
                    index < inputs.investments.length;
                    index++
                  ) ...[
                    if (index > 0)
                      const Divider(height: 1, color: Colors.white12),
                    ListTile(
                      contentPadding: const .symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: const Icon(Icons.history),
                      title: Text(
                        inputs.investments[index].name,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
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
}

class _HistoricalInvestmentsInputs {
  final List<_HistoricalInvestmentData> investments;

  const _HistoricalInvestmentsInputs({required this.investments});

  factory _HistoricalInvestmentsInputs.fromProvider(FundProvider provider) {
    final investments = provider.historicalInvestments
        .map(
          (investment) => _HistoricalInvestmentData(
            uid: investment.uid,
            name: investment.name,
          ),
        )
        .toList();

    return _HistoricalInvestmentsInputs(
      investments: List<_HistoricalInvestmentData>.unmodifiable(investments),
    );
  }

  bool hasSameDataAs(_HistoricalInvestmentsInputs other) {
    if (investments.length != other.investments.length) return false;

    for (var index = 0; index < investments.length; index++) {
      if (!investments[index].hasSameDataAs(other.investments[index])) {
        return false;
      }
    }

    return true;
  }
}

class _HistoricalInvestmentData {
  final String uid;
  final String name;

  const _HistoricalInvestmentData({required this.uid, required this.name});

  bool hasSameDataAs(_HistoricalInvestmentData other) {
    return uid == other.uid && name == other.name;
  }
}
