import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/fund_provider.dart';
import '../services/pdf_report_generator.dart';
import '../services/report_generator.dart';

class FilesGenerator {
  final BuildContext context;
  final AppLocalizations l10n;
  final FundProvider provider;

  FilesGenerator({
    required this.context,
    required this.l10n,
    required this.provider,
  });

  // EXPORTA OPERACIONES EN CSV
  Future<void> initExportCsv() async {
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
        _showSnackBar(
          context,
          l10n.reportSavedSuccess(filePath.split('/').last),
          action: SnackBarAction(
            label: l10n.openAction,
            onPressed: () => _openFile(filePath),
          ),
        );
      } else {
        _showSnackBar(context, l10n.exportCancelledOrFailed, error: true);
      }
    }
  }

  // GENERA INFORME ANUAL EN PDF
  void initReportPdf() {
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (i) => currentYear - i);

    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.selectReportYear),
        children: years
            .map(
              (year) => SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _generateReport(year);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    year.toString(),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _generateReport(int year) async {
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
        _showActionsDialog(pdfBytes, year);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _showSnackBar(
          context,
          l10n.pdfGenerationError(e.toString()),
          error: true,
        );
      }
    }
  }

  void _showActionsDialog(Uint8List pdfBytes, int year) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reportGeneratedTitle),
        content: Text(l10n.annualReportReadyMessage(year.toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _saveFile(pdfBytes, year);
            },
            child: Text(l10n.save),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _previewAndPrint(context, pdfBytes, year);
            },
            child: Text(l10n.previewAndPrint),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFile(Uint8List pdfBytes, int year) async {
    final filePath = await PdfReportGenerator.savePdfToDevice(
      context,
      pdfBytes,
      'OpenInvest_InformeAnual_$year.pdf',
    );

    if (context.mounted) {
      if (filePath != null) {
        _showSnackBar(
          context,
          l10n.reportSavedSuccess(filePath.split('/').last),
          action: SnackBarAction(
            label: l10n.openAction,
            onPressed: () => _openFile(filePath),
          ),
        );
      }
    }
  }

  Future<void> _previewAndPrint(
    BuildContext context,
    Uint8List pdfBytes,
    int year,
  ) async {
    await PdfReportGenerator.previewAndPrint(
      pdfBytes,
      'OpenInvest_InformeAnual_$year.pdf',
    );
  }

  Future<void> _openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;
      final uri = Uri.file(filePath, windows: Platform.isWindows);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      debugPrint('Error al abrir el archivo: $e');
    }
  }

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
}
