import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/fund_provider.dart';
import '../screens/compara_page.dart';
import '../screens/correlation_matrix_page.dart';
import '../screens/fund_search_page.dart';
import '../screens/historical_investment_form_page.dart';
import '../tools/files_generator.dart';

class BuildActionsGrid extends StatelessWidget {
  const BuildActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<FundProvider, _ActionsGridInputs>(
      selector: (_, provider) => _ActionsGridInputs.fromProvider(provider),
      shouldRebuild: (previous, next) => !previous.hasSameDataAs(next),
      builder: (context, inputs, _) {
        final l10n = AppLocalizations.of(context)!;
        final screenWidth = MediaQuery.of(context).size.width;
        // Responsive: 6, 3, 2 y 1 columnas
        final crossAxisCount = screenWidth > 1000
            ? 6
            : screenWidth > 650
            ? 3
            : screenWidth > 350
            ? 2
            : 1;

        return GridView.count(
          padding: .zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 160,
          children: [
            _buildActionCard(
              icon: Icons.add_chart,
              title: l10n.addAction,
              subtitle: l10n.newFundSubtitle,
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FundSearchPage()),
              ),
            ),
            _buildActionCard(
              icon: Icons.compare_arrows,
              title: l10n.compareLabel,
              subtitle: l10n.twoFundsSubtitle,
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ComparaPage()),
              ),
            ),
            _buildActionCard(
              icon: Icons.grid_4x4,
              title: l10n.correlationAction,
              subtitle: l10n.riskMatrixSubtitle,
              color: Colors.orange,
              onTap: () => _openCorrelationMatrix(context, l10n, inputs),
            ),
            _buildActionCard(
              icon: Icons.history,
              title: l10n.investmentHistoryTitle,
              subtitle: l10n.investmentJourneySubtitle,
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistoricalInvestmentFormPage(),
                ),
              ),
            ),
            _buildActionCard(
              icon: Icons.picture_as_pdf,
              title: l10n.annualReportTitle,
              subtitle: 'PDF',
              color: Colors.teal,
              onTap: () {
                final provider = context.read<FundProvider>();
                FilesGenerator(
                  context: context,
                  l10n: l10n,
                  provider: provider,
                ).initReportPdf();
              },
            ),
            _buildActionCard(
              icon: Icons.table_view,
              title: l10n.operationsTitle,
              subtitle: l10n.csvSpreadsheetSubtitle,
              color: Colors.teal,
              onTap: () {
                final provider = context.read<FundProvider>();
                FilesGenerator(
                  context: context,
                  l10n: l10n,
                  provider: provider,
                ).initExportCsv();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCorrelationMatrix(
    BuildContext context,
    AppLocalizations l10n,
    _ActionsGridInputs inputs,
  ) async {
    if (!inputs.hasEnoughFundsForCorrelation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.needAtLeastTwoFundsForCorrelation)),
      );
      return;
    }

    final provider = context.read<FundProvider>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    var loaded = false;
    try {
      loaded = await provider.loadCorrelationMatrix();
    } catch (error) {
      loaded = false;
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!context.mounted) return;
    if (!loaded) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.correlationLoadError)));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CorrelationMatrixPage()),
    );
  }

  Widget _buildActionCard({
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
            color: color.withValues(alpha: 0.2),
            borderRadius: .circular(16),
            border: .all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisAlignment: .center,
            mainAxisSize: .min,
            children: [
              Container(
                padding: const .all(10),
                decoration: BoxDecoration(color: Colors.white, shape: .circle),
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
}

class _ActionsGridInputs {
  final bool hasEnoughFundsForCorrelation;

  const _ActionsGridInputs({required this.hasEnoughFundsForCorrelation});

  factory _ActionsGridInputs.fromProvider(FundProvider provider) {
    return _ActionsGridInputs(
      hasEnoughFundsForCorrelation: provider.portfolio.length >= 2,
    );
  }

  bool hasSameDataAs(_ActionsGridInputs other) {
    return hasEnoughFundsForCorrelation == other.hasEnoughFundsForCorrelation;
  }
}
