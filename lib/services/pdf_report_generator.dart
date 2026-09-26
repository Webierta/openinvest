import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/app_localizations.dart';
import '../utils/financial_calculator.dart';
import 'fund_scraper.dart';

class PdfReportGenerator {
  /// Genera un PDF con el resumen anual de la cartera
  static Future<Uint8List> generateAnnualReport(
    BuildContext context, {
    required List<FundData> portfolio,
    required int year,
    Map<String, double>? exchangeRates,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final pdf = pw.Document();
    final dateFormat = DateFormat.yMd(locale);
    final percentFormat = NumberFormat.decimalPercentPattern(
      locale: locale,
      decimalDigits: 2,
    );

    // Calcular métricas globales
    final globalMetrics = FinancialCalculator.calculateGlobalMetrics(
      portfolio,
      exchangeRates ?? {'EUR': 1.0},
    );

    final fontDataRegular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final fontDataBold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

    final ttfRegular = pw.Font.ttf(fontDataRegular);
    final ttfBold = pw.Font.ttf(fontDataBold);

    // Construir el documento PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: ttfRegular,
          bold: ttfBold,
        ),
        build: (pw.Context context) => [
          // === CABECERA ===
          _buildHeader(l10n, year),
          pw.SizedBox(height: 20),

          // === RESUMEN EJECUTIVO ===
          _buildExecutiveSummary(
            l10n,
            locale,
            globalMetrics,
            percentFormat,
          ),
          pw.SizedBox(height: 20),

          // === TABLA DE FONDOS ===
          _buildFundsTable(
            l10n,
            locale,
            portfolio,
            percentFormat,
            exchangeRates,
          ),
          pw.SizedBox(height: 20),

          // === DISCLAIMER ===
          _buildDisclaimer(l10n, dateFormat),
        ],
        footer: (pw.Context context) => _buildFooter(l10n, context, year),
      ),
    );

    return pdf.save();
  }

  static String _formatCurrency(double value, String locale) {
    final formatter = NumberFormat('#,##0.00', locale);
    return '${formatter.format(value)} €';
  }

  /// Cabecera del documento
  static pw.Widget _buildHeader(AppLocalizations l10n, int year) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'OpenInvest',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  l10n.annualPortfolioReport,
                  style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                '$year',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
          ],
        ),
        pw.Divider(color: PdfColors.blue900, thickness: 2),
      ],
    );
  }

  /// Resumen ejecutivo con métricas globales
  static pw.Widget _buildExecutiveSummary(
    AppLocalizations l10n,
    String locale,
    GlobalMetrics metrics,
    NumberFormat percentFormat,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            l10n.executiveSummary,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricBox(
                l10n.netInvestmentLabel,
                _formatCurrency(metrics.totalInvested, locale),
              ),
              _buildMetricBox(
                l10n.currentValueLabel,
                _formatCurrency(metrics.totalValue, locale),
              ),
              _buildMetricBox(
                l10n.totalGain,
                _formatCurrency(metrics.profitAbs, locale),
                color: metrics.profitAbs >= 0
                    ? PdfColors.green800
                    : PdfColors.red800,
              ),
              _buildMetricBox(
                l10n.sortByPerformance,
                percentFormat.format(metrics.profitRel / 100),
                color: metrics.profitRel >= 0
                    ? PdfColors.green800
                    : PdfColors.red800,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricBox(
    String label,
    String value, {
    PdfColor? color,
  }) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color ?? PdfColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tabla detallada por fondo
  static pw.Widget _buildFundsTable(
    AppLocalizations l10n,
    String locale,
    List<FundData> portfolio,
    NumberFormat percentFormat,
    Map<String, double>? exchangeRates,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          l10n.fundDetail,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(2.5), // ISIN
            1: pw.FlexColumnWidth(4), // Nombre
            2: pw.FlexColumnWidth(2), // Valor
            3: pw.FlexColumnWidth(1.5), // Rent.
            4: pw.FlexColumnWidth(1.5), // TWR
            5: pw.FlexColumnWidth(1.5), // MWR
          },
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            // Cabecera de la tabla
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue50),
              children: [
                _tableHeader(l10n.csvHeaderIsin),
                _tableHeader(l10n.csvHeaderFundName),
                _tableHeader(l10n.currentValueLabel),
                _tableHeader(l10n.returnPercentLabel),
                _tableHeader('TWR'),
                _tableHeader('MWR'),
              ],
            ),
            // Filas de datos
            ...portfolio.map((fund) {
              final metrics = FinancialCalculator.calculateFundMetrics(fund);
              final rate = exchangeRates?[fund.currency] ?? 1.0;
              final valueConverted = metrics.currentValue * rate;
              final profitPercent = metrics.profitRel;
              final twr = metrics.twrTotal ?? 0.0;
              final mwr = metrics.mwrAnnualized ?? 0.0;

              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      fund.isin,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      fund.name,
                      style: const pw.TextStyle(fontSize: 8),
                      maxLines: 2,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      _formatCurrency(valueConverted, locale),
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      percentFormat.format(profitPercent / 100),
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: profitPercent >= 0
                            ? PdfColors.green800
                            : PdfColors.red800,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      percentFormat.format(twr),
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: twr >= 0 ? PdfColors.green800 : PdfColors.red800,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      percentFormat.format(mwr),
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: mwr >= 0 ? PdfColors.green800 : PdfColors.red800,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
    );
  }

  /// Disclaimer legal
  static pw.Widget _buildDisclaimer(
    AppLocalizations l10n,
    DateFormat dateFormat,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            l10n.legalNotice,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            l10n.legalNoticeText(dateFormat.format(DateTime.now())),
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  /// Pie de página con numeración
  static pw.Widget _buildFooter(
    AppLocalizations l10n,
    pw.Context context,
    int year,
  ) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 0),
      child: pw.Text(
        l10n.pdfFooter(
          year.toString(),
          context.pageNumber.toString(),
          context.pagesCount.toString(),
        ),
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  /// Guarda el PDF en el dispositivo
  static Future<String?> savePdfToDevice(
    BuildContext context,
    Uint8List pdfBytes,
    String fileName,
  ) async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final String safeFileName = fileName.toLowerCase().endsWith('.pdf')
          ? fileName
          : '$fileName.pdf';

      final dynamic result = await FilePicker.saveFile(
        dialogTitle: l10n.saveAnnualReportTitle,
        fileName: safeFileName,
        bytes: pdfBytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null) return null;
      var pathStr = result.toString();
      if (pathStr.startsWith('file://')) {
        try {
          pathStr = Uri.parse(pathStr).toFilePath();
        } catch (_) {}
      }
      return pathStr;
    } catch (e) {
      debugPrint('❌ Error al guardar el PDF: $e');
      return null;
    }
  }

  /// Previsualiza e imprime el PDF (funciona en Linux, Android, iOS, Windows, macOS)
  static Future<void> previewAndPrint(
    Uint8List pdfBytes,
    String documentName,
  ) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: documentName,
    );
  }
}
