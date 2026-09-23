import 'package:flutter/material.dart';
import 'package:investing/l10n/app_localizations.dart';
import '../widgets/gradient_background.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.info),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _InfoSection(
                icon: Icons.search,
                title: l10n.searchFundsTitle,
                description: l10n.searchFundsDesc,
              ),
              _InfoSection(
                icon: Icons.history,
                title: l10n.priceHistoryTitle,
                description: l10n.priceHistoryDesc,
              ),
              _InfoSection(
                icon: Icons.account_balance_wallet,
                title: l10n.operationsMgmtTitle,
                description: l10n.operationsMgmtDesc,
              ),
              _InfoSection(
                icon: Icons.trending_up,
                title: l10n.profitabilityAnalysisTitle,
                description: l10n.profitabilityAnalysisDesc,
              ),
              _InfoSection(
                icon: Icons.receipt_long_outlined,
                title: l10n.costsAuditTitle,
                description: l10n.costsAuditDesc,
              ),
              _InfoSection(
                icon: Icons.show_chart,
                title: l10n.interactiveChartsTitle,
                description: l10n.interactiveChartsDesc,
              ),
              _InfoSection(
                icon: Icons.calendar_month_outlined,
                title: l10n.monthlyHeatmapTitle,
                description: l10n.monthlyHeatmapDesc,
              ),
              _InfoSection(
                icon: Icons.compare_arrows,
                title: l10n.benchmarkComparisonTitle,
                description: l10n.benchmarkComparisonDesc,
              ),
              _InfoSection(
                icon: Icons.warning_amber_outlined,
                title: l10n.riskAnalysisTitle,
                description: l10n.riskAnalysisDesc,
              ),
              _InfoSection(
                icon: Icons.save_alt,
                title: l10n.exportImportTitle,
                description: l10n.exportImportDesc,
              ),
              _InfoSection(
                icon: Icons.attach_money,
                title: l10n.multicurrencySupportTitle,
                description: l10n.multicurrencySupportDesc,
              ),
              _InfoSection(
                icon: Icons.notifications,
                title: l10n.notificationsTitle,
                description: l10n.notificationsDesc,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
