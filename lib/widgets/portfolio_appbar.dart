import 'package:flutter/material.dart';
import 'package:investing/l10n/app_localizations.dart';

import '../providers/fund_provider.dart';
import '../services/export_service.dart';
import '../tools/files_generator.dart';
import '../utils/fund_data_merger.dart';

class PortfolioAppbar extends StatelessWidget implements PreferredSizeWidget {
  final FundProvider provider;
  final VoidCallback onRefresh;
  final ValueChanged<SortCriteria> onSortSelected;
  final VoidCallback onClearPortfolio;

  const PortfolioAppbar({
    super.key,
    required this.provider,
    required this.onRefresh,
    required this.onSortSelected,
    required this.onClearPortfolio,
  });

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool error = false,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
        duration: duration,
        action: action,
        persist: false,
      ),
    );
  }

  Future<bool?> _confirmOverwrite(BuildContext context, String fundName) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.fundAlreadyInPortfolio),
        content: Text(l10n.overwriteFundDesc(fundName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.overwrite,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImport(
    BuildContext context,
    FundProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final fund = await ExportService.importFund(context);
    if (fund != null && context.mounted) {
      final existing = provider.portfolio.any((item) => item.isin == fund.isin);
      var overwrite = false;
      if (existing) {
        final decision = await _confirmOverwrite(context, fund.name);
        if (decision != true || !context.mounted) return;
        overwrite = true;
      }
      try {
        if (overwrite) {
          await provider.replaceFund(fund);
        } else {
          await provider.addToPortfolio(fund);
        }
        if (context.mounted) {
          _showSnackBar(context, l10n.fundImportedSuccess);
        }
      } catch (_) {}
    }
  }

  Future<void> _handleExportPortfolio(
    BuildContext context,
    FundProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await ExportService.exportPortfolio(
      context,
      provider.portfolio,
    );

    if (context.mounted) Navigator.of(context).pop();

    if (success && context.mounted) {
      _showSnackBar(context, l10n.portfolioExportedSuccess);
    }
  }

  Future<void> _handleImportPortfolio(
    BuildContext context,
    FundProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final importedFunds = await ExportService.importPortfolio(context);
    if (importedFunds != null && importedFunds.isNotEmpty) {
      try {
        for (final importedFund in importedFunds) {
          final existingIndex = provider.portfolio.indexWhere(
            (item) => item.isin == importedFund.isin,
          );
          if (existingIndex == -1) {
            await provider.addToPortfolio(importedFund);
          } else {
            // Fusión inteligente: combinar operaciones sin duplicados
            final existing = provider.portfolio[existingIndex];
            //final merged = _mergeFunds(existing, importedFund);
            final merged = FundDataMerger.merge(existing, importedFund);
            await provider.replaceFund(merged);
          }
        }
        if (context.mounted) {
          _showSnackBar(context, l10n.portfolioImportedSuccess);
        }
      } catch (e) {
        if (context.mounted) {
          _showSnackBar(
            context,
            'Error al fusionar la cartera: $e',
            error: true,
          );
        }
      }
    }
  }

  void _onClearPortfolio(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearPortfolioTitle),
        content: Text(l10n.clearPortfolioConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              provider.clearPortfolio();
              Navigator.pop(context);
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      title: Text.rich(
        TextSpan(
          text: 'Open',
          style: const TextStyle(color: Colors.white),
          children: [
            TextSpan(
              text: 'Invest',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (provider.portfolio.isNotEmpty) ...[
          IconButton(
            icon: provider.isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: provider.isBusy ? null : onRefresh,
            tooltip: l10n.updatePortfolioTooltip,
          ),
        ],
        if (provider.portfolio.isNotEmpty)
          PopupMenuButton<SortCriteria>(
            icon: const Icon(Icons.sort, color: Colors.white),
            tooltip: l10n.sortPortfolioTooltip,
            onSelected: onSortSelected,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SortCriteria.name,
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      size: 20,
                      color: provider.sortCriteria == SortCriteria.name
                          ? Colors.blueAccent
                          : Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.sortByAlpha),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortCriteria.date,
                child: Row(
                  children: [
                    Icon(
                      Icons.date_range,
                      size: 20,
                      color: provider.sortCriteria == SortCriteria.date
                          ? Colors.blueAccent
                          : Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.dateLabel),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortCriteria.value,
                child: Row(
                  children: [
                    Icon(
                      Icons.euro_symbol,
                      size: 20,
                      color: provider.sortCriteria == SortCriteria.value
                          ? Colors.blueAccent
                          : Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.sortByValue),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortCriteria.performance,
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 20,
                      color: provider.sortCriteria == SortCriteria.performance
                          ? Colors.blueAccent
                          : Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.sortByPerformance),
                  ],
                ),
              ),
            ],
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          tooltip: l10n.moreOptionsTooltip,
          onSelected: (value) {
            switch (value) {
              case 'import':
                _handleImport(context, provider);
                break;
              case 'import_portfolio':
                _handleImportPortfolio(context, provider);
                break;
              case 'export_portfolio':
                _handleExportPortfolio(context, provider);
                break;
              case 'operaciones':
                final filesGenerator = FilesGenerator(
                  context: context,
                  l10n: l10n,
                  provider: provider,
                );
                filesGenerator.initExportCsv();
                break;
              case 'informe':
                final filesGenerator = FilesGenerator(
                  context: context,
                  l10n: l10n,
                  provider: provider,
                );
                filesGenerator.initReportPdf();
                break;
              case 'clear':
                _onClearPortfolio(context);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'import',
              child: Row(
                children: [
                  const Icon(
                    //Icons.file_download_outlined,
                    Icons.add_chart,
                    size: 20,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.importFundJson),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'import_portfolio',
              child: Row(
                children: [
                  const Icon(
                    Icons.wallet_travel,
                    size: 20,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.importPortfolioMenu),
                ],
              ),
            ),
            if (provider.portfolio.isNotEmpty)
              PopupMenuItem(
                value: 'export_portfolio',
                child: Row(
                  children: [
                    const Icon(Icons.save, size: 20, color: Colors.white70),
                    const SizedBox(width: 12),
                    Text(l10n.exportPortfolioMenu),
                  ],
                ),
              ),
            if (provider.portfolio.isNotEmpty) ...[
              const PopupMenuDivider(color: Colors.white24),
              PopupMenuItem(
                enabled: false,
                child: Text(l10n.generateFilesLabel),
              ),
              PopupMenuItem(
                value: 'operaciones',
                child: Row(
                  children: [
                    const Icon(
                      Icons.table_chart_outlined,
                      size: 20,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.operationsCsv),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'informe',
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 20,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.pdfReportLabel),
                  ],
                ),
              ),
              const PopupMenuDivider(color: Colors.white24),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_sweep,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.clearPortfolioAction,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
