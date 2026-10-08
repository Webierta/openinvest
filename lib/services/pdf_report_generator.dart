import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/app_localizations.dart';
import '../models/fund_data.dart';

class _PdfLabels {
  final String annualPortfolioReport;
  final String executiveSummary;
  final String fundDetail;
  final String csvHeaderIsin;
  final String csvHeaderFundName;
  final String currentValueLabel;
  final String returnPercentLabel;
  final String legalNotice;
  final String legalNoticeText;
  final String saveAnnualReportTitle;

  const _PdfLabels({
    required this.annualPortfolioReport,
    required this.executiveSummary,
    required this.fundDetail,
    required this.csvHeaderIsin,
    required this.csvHeaderFundName,
    required this.currentValueLabel,
    required this.returnPercentLabel,
    required this.legalNotice,
    required this.legalNoticeText,
    required this.saveAnnualReportTitle,
  });

  String pdfFooter(String year, String page, String total) =>
      'OpenInvest - Informe Anual $year - Página $page de $total';
}

class PdfReportGenerator {
  /// Genera un verdadero informe anual de la cartera.
  ///
  /// Genera un verdadero informe anual.
  ///
  /// Los cálculos y la construcción/serialización del PDF se ejecutan en
  /// isolates para que la interfaz pueda mantener visible el progreso.
  static Future<Uint8List> generateAnnualReport(
    BuildContext context, {
    required List<FundData> portfolio,
    required int year,
    Map<String, double>? exchangeRates,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMd(locale);
    final percentFormat = NumberFormat.decimalPercentPattern(
      locale: locale,
      decimalDigits: 2,
    );

    final rates = <String, double>{'EUR': 1.0, ...?exchangeRates};

    // La generación utiliza directamente el pipeline estándar de
    // pdf/widgets: cálculo anual, construcción del documento y serialización.
    final annualFunds = <_AnnualFundMetrics>[];
    for (final fund in portfolio) {
      annualFunds.add(_calculateAnnualFund(fund, year, rates));
    }

    final global = _calculateGlobalAnnual(annualFunds, year);

    final fontDataRegular = await rootBundle.load(
      'assets/fonts/Roboto-Regular.ttf',
    );
    final fontDataBold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

    final ttfRegular = pw.Font.ttf(fontDataRegular);
    final ttfBold = pw.Font.ttf(fontDataBold);

    final labels = _PdfLabels(
      annualPortfolioReport: l10n.annualPortfolioReport,
      executiveSummary: l10n.executiveSummary,
      fundDetail: l10n.fundDetail,
      csvHeaderIsin: l10n.csvHeaderIsin,
      csvHeaderFundName: l10n.csvHeaderFundName,
      currentValueLabel: l10n.currentValueLabel,
      returnPercentLabel: l10n.returnPercentLabel,
      legalNotice: l10n.legalNotice,
      legalNoticeText: l10n.legalNoticeText(dateFormat.format(DateTime.now())),
      saveAnnualReportTitle: l10n.saveAnnualReportTitle,
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
        build: (pw.Context pdfContext) => [
          _buildHeader(labels, year),
          pw.SizedBox(height: 16),
          _buildPeriodBox(year, global, locale),
          pw.SizedBox(height: 14),
          _buildExecutiveSummary(labels, locale, global, percentFormat),
          pw.SizedBox(height: 20),
          _buildFundsTable(labels, locale, annualFunds, percentFormat),
          pw.SizedBox(height: 20),
          _buildDisclaimer(labels),
        ],
        footer: (pw.Context pdfContext) =>
            _buildFooter(labels, pdfContext, year),
      ),
    );

    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  // Cálculo anual
  // ---------------------------------------------------------------------------

  static _AnnualFundMetrics _calculateAnnualFund(
    FundData fund,
    int year,
    Map<String, double> exchangeRates,
  ) {
    final startDate = DateTime(year, 1, 1);
    final requestedEndDate = DateTime(year, 12, 31, 23, 59, 59, 999);

    // Para el año actual no tiene sentido proyectar hasta el 31 de diciembre.
    // Usamos la fecha de valoración disponible del fondo como cierre real.
    final endDate =
        year == fund.date.year && fund.date.isBefore(requestedEndDate)
        ? fund.date
        : requestedEndDate;

    final sortedOperations = List<FundOperation>.from(fund.operations)
      ..sort((a, b) => a.date.compareTo(b.date));

    double unitsAtStart = 0.0;
    double unitsAtEnd = 0.0;

    double purchases = 0.0;
    double sales = 0.0;

    for (final op in sortedOperations) {
      if (op.date.isBefore(startDate)) {
        unitsAtStart += op.type == OperationType.buy ? op.units : -op.units;
      }

      if (!op.date.isAfter(endDate)) {
        unitsAtEnd += op.type == OperationType.buy ? op.units : -op.units;
      }

      if (!op.date.isBefore(startDate) && !op.date.isAfter(endDate)) {
        if (op.type == OperationType.buy) {
          purchases += op.amount;
        } else {
          sales += op.amount;
        }
      }
    }

    // El valor inicial se obtiene con el último precio disponible hasta
    // el comienzo del año. Si no existe, se utiliza el primer precio
    // disponible del historial.
    final startPrice =
        _priceAtOrBefore(fund.history, startDate) ??
        (fund.history.isNotEmpty ? fund.history.first.price : fund.lastValue);

    // El valor final es el último precio disponible dentro del periodo.
    // Para el año actual se respeta la fecha de valoración del fondo.
    final endPrice =
        _priceAtOrBefore(fund.history, endDate) ??
        (year == fund.date.year ? fund.lastValue : startPrice);

    final startValue = unitsAtStart * startPrice;
    final endValue = unitsAtEnd * endPrice;

    final netInvestment = purchases - sales;

    // Resultado atribuible a la evolución del fondo:
    //
    // valor final = valor inicial + flujos netos + resultado
    final profit = endValue - startValue - netInvestment;

    final returnBase = startValue + purchases;
    final simpleReturn = returnBase > 0 ? profit / returnBase : 0.0;

    final twr = _calculateTwr(
      fund: fund,
      startDate: startDate,
      endDate: endDate,
      initialUnits: unitsAtStart,
      initialValue: startValue,
    );

    final mwr = _calculateMwr(
      fund: fund,
      startDate: startDate,
      endDate: endDate,
      initialValue: startValue,
      finalValue: endValue,
    );

    final rate = exchangeRates[fund.currency] ?? 1.0;

    return _AnnualFundMetrics(
      fund: fund,
      startDate: startDate,
      endDate: endDate,
      unitsAtStart: unitsAtStart,
      unitsAtEnd: unitsAtEnd,
      startValue: startValue,
      endValue: endValue,
      purchases: purchases,
      sales: sales,
      netInvestment: netInvestment,
      profit: profit,
      simpleReturn: simpleReturn,
      twr: twr,
      mwr: mwr,
      exchangeRate: rate,
    );
  }

  static _GlobalAnnualMetrics _calculateGlobalAnnual(
    List<_AnnualFundMetrics> funds,
    int year,
  ) {
    double startValue = 0.0;
    double endValue = 0.0;
    double purchases = 0.0;
    double sales = 0.0;
    double profit = 0.0;

    for (final item in funds) {
      startValue += item.startValueConverted;
      endValue += item.endValueConverted;
      purchases += item.purchasesConverted;
      sales += item.salesConverted;
      profit += item.profitConverted;
    }

    final netInvestment = purchases - sales;
    final base = startValue + purchases;
    final simpleReturn = base > 0 ? profit / base : 0.0;

    return _GlobalAnnualMetrics(
      periodStart: DateTime(year, 1, 1),
      periodEnd: funds.isEmpty
          ? DateTime(year, 12, 31, 23, 59, 59, 999)
          : funds.map((f) => f.endDate).reduce((a, b) => a.isAfter(b) ? a : b),
      startValue: startValue,
      endValue: endValue,
      purchases: purchases,
      sales: sales,
      netInvestment: netInvestment,
      profit: profit,
      simpleReturn: simpleReturn,
    );
  }

  static double? _priceAtOrBefore(List<PricePoint> history, DateTime date) {
    if (history.isEmpty) return null;

    // CNMV/Yahoo histories are normally chronological. Searching backwards
    // makes the common case (recent valuation date) very cheap.
    for (var i = history.length - 1; i >= 0; i--) {
      final point = history[i];
      if (!point.date.isAfter(date)) {
        return point.price;
      }
    }

    return null;
  }

  /// TWR anual vinculado por flujos.
  ///
  /// Se parte del valor de la cartera al inicio del periodo y se segmenta
  /// la rentabilidad cada vez que existe una compra o venta.
  static double? _calculateTwr({
    required FundData fund,
    required DateTime startDate,
    required DateTime endDate,
    required double initialUnits,
    required double initialValue,
  }) {
    if (initialValue <= 0 &&
        fund.operations
            .where(
              (op) => !op.date.isBefore(startDate) && !op.date.isAfter(endDate),
            )
            .isEmpty) {
      return null;
    }

    final operations =
        fund.operations
            .where(
              (op) => !op.date.isBefore(startDate) && !op.date.isAfter(endDate),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    double units = initialUnits;
    double multiplier = 1.0;
    double periodValue = initialValue;

    for (final op in operations) {
      final priceBeforeFlow = _priceAtOrBefore(fund.history, op.date);

      if (priceBeforeFlow != null && periodValue > 0) {
        final valueBeforeFlow = units * priceBeforeFlow;
        final periodReturn = (valueBeforeFlow / periodValue) - 1.0;

        if (periodReturn > -1.0) {
          multiplier *= 1.0 + periodReturn;
        }
      }

      if (priceBeforeFlow == null) {
        // Sin precio histórico en el flujo no podemos segmentar TWR de
        // forma fiable; continuamos con el siguiente flujo.
        continue;
      }

      if (op.type == OperationType.buy) {
        units += op.units;
      } else {
        units -= op.units;
      }

      periodValue = units * priceBeforeFlow;
    }

    final finalPrice =
        _priceAtOrBefore(fund.history, endDate) ?? fund.lastValue;

    if (periodValue > 0 && finalPrice > 0) {
      final finalUnits = units;
      final valueAtEnd = finalUnits * finalPrice;
      final periodReturn = (valueAtEnd / periodValue) - 1.0;

      if (periodReturn > -1.0) {
        multiplier *= 1.0 + periodReturn;
      }
    }

    return multiplier - 1.0;
  }

  /// MWR anual mediante IRR por bisección.
  ///
  /// Solo se utiliza aquí para mostrar la rentabilidad anual del fondo.
  static double? _calculateMwr({
    required FundData fund,
    required DateTime startDate,
    required DateTime endDate,
    required double initialValue,
    required double finalValue,
  }) {
    final flows = <_CashFlow>[];

    if (initialValue > 0) {
      flows.add(_CashFlow(-initialValue, startDate));
    }

    for (final op in fund.operations) {
      if (op.date.isBefore(startDate) || op.date.isAfter(endDate)) {
        continue;
      }

      flows.add(
        _CashFlow(
          op.type == OperationType.buy ? -op.amount : op.amount,
          op.date,
        ),
      );
    }

    if (finalValue > 0) {
      flows.add(_CashFlow(finalValue, endDate));
    }

    if (flows.length < 2) return null;

    final start = flows.first.date;

    double npv(double rate) {
      if (rate <= -1.0) return double.nan;

      double result = 0.0;
      for (final flow in flows) {
        final years = flow.date.difference(start).inDays / 365.25;
        result += flow.amount / _powPositive(1.0 + rate, years);
      }
      return result;
    }

    double low = -0.99;
    double high = 2.0;

    final lowValue = npv(low);
    final highValue = npv(high);

    if (lowValue.isNaN || highValue.isNaN) return null;

    if (lowValue * highValue > 0) {
      return null;
    }

    for (int i = 0; i < 60; i++) {
      final mid = (low + high) / 2.0;
      final value = npv(mid);

      if (value.isNaN) return null;

      if (value > 0) {
        low = mid;
      } else {
        high = mid;
      }

      if ((high - low).abs() < 1e-8) {
        break;
      }
    }

    return (low + high) / 2.0;
  }

  static double _powPositive(double base, double exponent) {
    return math.pow(base, exponent).toDouble();
  }

  // ---------------------------------------------------------------------------
  // PDF
  // ---------------------------------------------------------------------------

  static String _formatCurrency(double value, String locale) {
    final formatter = NumberFormat('#,##0.00', locale);
    return '${formatter.format(value)} €';
  }

  static pw.Widget _buildHeader(_PdfLabels l10n, int year) {
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
                  style: const pw.TextStyle(fontSize: 16),
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

  static pw.Widget _buildPeriodBox(
    int year,
    _GlobalAnnualMetrics metrics,
    String locale,
  ) {
    final formatter = DateFormat.yMd(locale);
    final start = formatter.format(metrics.periodStart);
    final end = formatter.format(metrics.periodEnd);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Periodo del informe: $start - $end',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.Text(
            'Año $year',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildExecutiveSummary(
    _PdfLabels l10n,
    String locale,
    _GlobalAnnualMetrics metrics,
    NumberFormat percentFormat,
  ) {
    return pw.Column(
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
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildMetricBox(
              'Valor inicial',
              _formatCurrency(metrics.startValue, locale),
            ),
            _buildMetricBox(
              'Valor final',
              _formatCurrency(metrics.endValue, locale),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildMetricBox(
              'Compras',
              _formatCurrency(metrics.purchases, locale),
            ),
            _buildMetricBox('Ventas', _formatCurrency(metrics.sales, locale)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildMetricBox(
              'Inversión neta',
              _formatCurrency(metrics.netInvestment, locale),
            ),
            _buildMetricBox(
              'Resultado',
              _formatCurrency(metrics.profit, locale),
              color: metrics.profit >= 0
                  ? PdfColors.green800
                  : PdfColors.red800,
            ),
            _buildMetricBox(
              l10n.returnPercentLabel,
              percentFormat.format(metrics.simpleReturn),
              color: metrics.simpleReturn >= 0
                  ? PdfColors.green800
                  : PdfColors.red800,
            ),
          ],
        ),
      ],
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
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: color ?? PdfColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildFundsTable(
    _PdfLabels l10n,
    String locale,
    List<_AnnualFundMetrics> funds,
    NumberFormat percentFormat,
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
            0: pw.FlexColumnWidth(2.4),
            1: pw.FlexColumnWidth(4.6),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(1.5),
            4: pw.FlexColumnWidth(1.5),
            5: pw.FlexColumnWidth(1.5),
          },
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue50),
              children: [
                _tableHeader(l10n.csvHeaderIsin),
                _tableHeader(l10n.csvHeaderFundName),
                _tableHeader('Valor final'),
                _tableHeader(l10n.returnPercentLabel),
                _tableHeader('TWR'),
                _tableHeader('MWR'),
              ],
            ),
            ...funds.map((item) {
              final returnValue = item.simpleReturn;
              final double? twr = item.twr;
              final double? mwr = item.mwr;

              return pw.TableRow(
                children: [
                  _tableCell(item.fund.isin),
                  _tableCell(item.fund.name, maxLines: 2),
                  _tableCell(
                    _formatCurrency(item.endValueConverted, locale),
                    alignRight: true,
                  ),
                  _tableCell(
                    percentFormat.format(returnValue),
                    alignRight: true,
                    color: returnValue >= 0
                        ? PdfColors.green800
                        : PdfColors.red800,
                  ),
                  _tableCell(
                    twr == null ? '—' : percentFormat.format(twr),
                    alignRight: true,
                    color: twr == null
                        ? null
                        : twr >= 0
                        ? PdfColors.green800
                        : PdfColors.red800,
                  ),
                  _tableCell(
                    mwr == null ? '—' : percentFormat.format(mwr),
                    alignRight: true,
                    color: mwr == null
                        ? null
                        : mwr >= 0
                        ? PdfColors.green800
                        : PdfColors.red800,
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

  static pw.Widget _tableCell(
    String text, {
    int maxLines = 1,
    bool alignRight = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        maxLines: maxLines,
        style: pw.TextStyle(fontSize: 8, color: color ?? PdfColors.black),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _buildDisclaimer(_PdfLabels l10n) {
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
          pw.Text(l10n.legalNoticeText, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(_PdfLabels l10n, pw.Context context, int year) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 0),
      child: pw.Text(
        l10n.pdfFooter(
          year.toString(),
          context.pageNumber.toString(),
          context.pagesCount.toString(),
        ),
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }

  static Future<String?> savePdfToDevice(
    BuildContext context,
    Uint8List pdfBytes,
    String fileName,
  ) async {
    try {
      final l10n = AppLocalizations.of(context)!;

      final safeFileName = fileName.toLowerCase().endsWith('.pdf')
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

// -----------------------------------------------------------------------------
// Modelos internos del informe
// -----------------------------------------------------------------------------

class _AnnualFundMetrics {
  final FundData fund;
  final DateTime startDate;
  final DateTime endDate;
  final double unitsAtStart;
  final double unitsAtEnd;
  final double startValue;
  final double endValue;
  final double purchases;
  final double sales;
  final double netInvestment;
  final double profit;
  final double simpleReturn;
  final double? twr;
  final double? mwr;
  final double exchangeRate;

  const _AnnualFundMetrics({
    required this.fund,
    required this.startDate,
    required this.endDate,
    required this.unitsAtStart,
    required this.unitsAtEnd,
    required this.startValue,
    required this.endValue,
    required this.purchases,
    required this.sales,
    required this.netInvestment,
    required this.profit,
    required this.simpleReturn,
    required this.twr,
    required this.mwr,
    required this.exchangeRate,
  });

  double get startValueConverted => startValue * exchangeRate;
  double get endValueConverted => endValue * exchangeRate;
  double get purchasesConverted => purchases * exchangeRate;
  double get salesConverted => sales * exchangeRate;
  double get profitConverted => profit * exchangeRate;
}

class _CashFlow {
  final double amount;
  final DateTime date;

  const _CashFlow(this.amount, this.date);
}

class _GlobalAnnualMetrics {
  final DateTime periodStart;
  final DateTime periodEnd;
  final double startValue;
  final double endValue;
  final double purchases;
  final double sales;
  final double netInvestment;
  final double profit;
  final double simpleReturn;

  const _GlobalAnnualMetrics({
    required this.periodStart,
    required this.periodEnd,
    required this.startValue,
    required this.endValue,
    required this.purchases,
    required this.sales,
    required this.netInvestment,
    required this.profit,
    required this.simpleReturn,
  });
}
