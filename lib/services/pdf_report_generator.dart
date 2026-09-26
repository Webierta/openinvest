import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../utils/financial_calculator.dart';
import 'fund_scraper.dart';

//import 'package:openinvest/services/fund_scraper.dart'; // Ajusta a tu ruta real
//import 'package:openinvest/utils/financial_calculator.dart';

class PdfReportGenerator {
  /// Genera un PDF con el resumen anual de la cartera
  static Future<Uint8List> generateAnnualReport({
    required List<FundData> portfolio,
    required int year,
    Map<String, double>? exchangeRates,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final percentFormat = NumberFormat.decimalPercentPattern(
      locale: 'es_ES',
      decimalDigits: 2,
    );

    // Calcular métricas globales
    final globalMetrics = FinancialCalculator.calculateGlobalMetrics(
      portfolio,
      exchangeRates ?? {'EUR': 1.0},
    );

    // Construir el documento PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          // === CABECERA ===
          _buildHeader(year),
          pw.SizedBox(height: 20),

          // === RESUMEN EJECUTIVO ===
          _buildExecutiveSummary(globalMetrics, currencyFormat, percentFormat),
          pw.SizedBox(height: 20),

          // === TABLA DE FONDOS ===
          _buildFundsTable(
            portfolio,
            currencyFormat,
            percentFormat,
            exchangeRates,
          ),
          pw.SizedBox(height: 20),

          // === DISCLAIMER ===
          _buildDisclaimer(dateFormat),
        ],
        footer: (pw.Context context) => _buildFooter(context, year),
      ),
    );

    return pdf.save();
  }

  /// Cabecera del documento
  static pw.Widget _buildHeader(int year) {
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
                  'Informe Anual de Cartera',
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
                'Año $year',
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
    GlobalMetrics metrics,
    NumberFormat currencyFormat,
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
            'Resumen Ejecutivo',
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
                'Total Invertido',
                currencyFormat.format(metrics.totalInvested),
              ),
              _buildMetricBox(
                'Valor Actual',
                currencyFormat.format(metrics.totalValue),
              ),
              _buildMetricBox(
                'Plusvalía',
                currencyFormat.format(metrics.profitAbs),
                color: metrics.profitAbs >= 0
                    ? PdfColors.green800
                    : PdfColors.red800,
              ),
              _buildMetricBox(
                'Rentabilidad',
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
    List<FundData> portfolio,
    NumberFormat currencyFormat,
    NumberFormat percentFormat,
    Map<String, double>? exchangeRates,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Detalle por Fondo',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper(
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5), // ISIN
            1: const pw.FlexColumnWidth(4), // Nombre
            2: const pw.FlexColumnWidth(2), // Valor
            3: const pw.FlexColumnWidth(1.5), // Rent.
            4: const pw.FlexColumnWidth(1.5), // TWR
            5: const pw.FlexColumnWidth(1.5), // MWR
          },
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
          headerHeight: 25,
          cellHeight: 30,
          cellPadding: const pw.EdgeInsets.all(4),
          children: [
            // Cabecera de la tabla
            pw.TableRow(
              children: [
                _tableHeader('ISIN'),
                _tableHeader('Nombre'),
                _tableHeader('Valor'),
                _tableHeader('Rent. %'),
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
                  pw.Text(fund.isin, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    fund.name,
                    style: const pw.TextStyle(fontSize: 8),
                    maxLines: 2,
                    overflow: pw.TextOverflow.ellipsis,
                  ),
                  pw.Text(
                    currencyFormat.format(valueConverted),
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.Text(
                    percentFormat.format(profitPercent / 100),
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: profitPercent >= 0
                          ? PdfColors.green800
                          : PdfColors.red800,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.Text(
                    percentFormat.format(twr),
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: twr >= 0 ? PdfColors.green800 : PdfColors.red800,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.Text(
                    percentFormat.format(mwr),
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: mwr >= 0 ? PdfColors.green800 : PdfColors.red800,
                    ),
                    textAlign: pw.TextAlign.right,
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
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      ),
    );
  }

  /// Disclaimer legal
  static pw.Widget _buildDisclaimer(DateFormat dateFormat) {
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
            'Aviso Legal',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Este informe ha sido generado automáticamente por OpenInvest el '
            '${dateFormat.format(DateTime.now())}. Los datos se han obtenido de fuentes públicas '
            'y pueden contener imprecisiones. Este documento no constituye asesoramiento financiero. '
            'Verifique siempre los datos con su entidad financiera antes de tomar decisiones.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  /// Pie de página con numeración
  static pw.Widget _buildFooter(pw.Context context, int year) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'OpenInvest - Informe Anual $year • Página ${context.pageNumber} de ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  /// Guarda el PDF en el dispositivo
  static Future<String?> savePdfToDevice(
    Uint8List pdfBytes,
    String fileName,
  ) async {
    try {
      /* final String? filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar informe anual',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      ); */

      final filePath = await FilePicker.saveFile(
        dialogTitle: 'Guardar informe anual',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: utf8.encode(pdfBytes.toString()),
      );

      /* if (filePath != null) {
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);
        return filePath;
      } */

      if (filePath != null) {
        final File file = File(filePath.path);
        await file.writeAsString(
          pdfBytes.toString(),
          //encoding: Utf8Codec(),
        ); // UTF-8 para acentos y eñes
        return filePath.path;
      }

      return null;
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
