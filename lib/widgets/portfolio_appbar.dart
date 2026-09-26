import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/fund_provider.dart';
import '../services/export_service.dart';
import '../services/pdf_report_generator.dart';
import '../services/report_generator.dart';

class PortfolioAppbar extends StatelessWidget implements PreferredSizeWidget {
  final FundProvider provider;
  final VoidCallback onRefresh;
  final ValueChanged<SortCriteria> onSortSelected;
  //final VoidCallback onClearPortfolio;

  const PortfolioAppbar({
    super.key,
    required this.provider,
    required this.onRefresh,
    required this.onSortSelected,
    //required this.onClearPortfolio,
  });

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



  Future<void> _handleImport(BuildContext context, FundProvider provider) async {
    final l10n = AppLocalizations.of(context)!;
    final fund = await ExportService.importFund(context);
    if (fund != null && context.mounted) {
      final existing = provider.portfolio.any(
        (item) => item.isin == fund.isin,
      );
      var overwrite = false;
      if (existing) {
        final decision = await _confirmOverwrite(
          context,
          fund.name,
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.fundImportedSuccess)),
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _handleExport(
    BuildContext context,
    FundProvider provider,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final filePath = await ReportGenerator.exportOperationsToCsv(
      context,
      provider.portfolio,
    );

    if (context.mounted) Navigator.of(context).pop();

    if (context.mounted) {
      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Informe guardado: ${filePath.split('/').last}'),
            action: SnackBarAction(
              label: 'Abrir',
              onPressed: () => _openFile(filePath),
            ),
            //duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exportación cancelada o fallida.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),

        );
      }
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('El archivo no existe');
      }

      final uri = Uri.file(filePath, windows: Platform.isWindows);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw Exception('No se pudo abrir el archivo');
      }
    } catch (e) {
      debugPrint('Error al abrir el archivo: $e');
    }
  }

  void _showYearPicker(BuildContext context, FundProvider provider) {
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (i) => currentYear - i);

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Selecciona el año del informe'),
        children: years.map((year) => SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context);
            _generateReport(context, year, provider);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(year.toString(), style: const TextStyle(fontSize: 16)),
          ),
        )).toList(),
      ),
    );
  }

  Future<void> _generateReport(BuildContext context, int year, FundProvider provider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfBytes = await PdfReportGenerator.generateAnnualReport(
        context,
        portfolio: provider.portfolio,
        year: year,
      );

      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        _showActionsDialog(context, pdfBytes, year);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar el PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showActionsDialog(BuildContext context, Uint8List pdfBytes, int year) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informe generado'),
        content: Text('El informe anual de $year está listo. ¿Qué deseas hacer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveFile(context, pdfBytes, year);
            },
            child: const Text('Guardar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _previewAndPrint(context, pdfBytes, year);
            },
            child: const Text('Previsualizar / Imprimir'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFile(BuildContext context, Uint8List pdfBytes, int year) async {
    final filePath = await PdfReportGenerator.savePdfToDevice(
      context,
      pdfBytes,
      'OpenInvest_InformeAnual_$year.pdf',
    );

    if (context.mounted) {
      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ PDF guardado: ${filePath.split('/').last}'),
            action: SnackBarAction(
              label: 'Abrir',
              onPressed: () => _openFile2(filePath),
            ),
          ),
        );
      }
    }
  }

  Future<void> _previewAndPrint(BuildContext context, Uint8List pdfBytes, int year) async {
    await PdfReportGenerator.previewAndPrint(pdfBytes, 'OpenInvest_InformeAnual_$year.pdf');
  }

  Future<void> _openFile2(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;
      final uri = Uri.file(filePath, windows: Platform.isWindows);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      debugPrint('Error al abrir el PDF: $e');
    }
  }

  _onClearPortfolio (BuildContext context){
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
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.red),
            ),
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
              case 'operaciones':
                _handleExport(context, provider);
                break;
              case 'informe':
                _showYearPicker(context, provider);
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
                    Icons.file_download_outlined,
                    size: 20,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.importFundJson),
                ],
              ),
            ),
            if (provider.portfolio.isNotEmpty)
              PopupMenuItem(
                value: 'operaciones',
                child: Row(
                  children: [
                    const Icon(
                      Icons.file_download_outlined,
                      size: 20,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.operationsCsv),
                  ],
                ),
              ),
            if (provider.portfolio.isNotEmpty)
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
            if (provider.portfolio.isNotEmpty)
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
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
