import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import 'fund_scraper.dart';

class ReportGenerator {
  /// Genera un CSV con todas las operaciones ordenadas cronológicamente.
  /// Ideal para importar en Excel o calcular plusvalías FIFO/LIFO.
  static Future<String?> exportOperationsToCsv(
    BuildContext context,
    List<FundData> portfolio,
  ) async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final locale = Localizations.localeOf(context).toString();

      // 1. Aplanar todas las operaciones de todos los fondos en una sola lista
      final List<Map<String, dynamic>> allOperations = [];

      for (final fund in portfolio) {
        for (final op in fund.operations) {
          allOperations.add({
            'fecha': op.date,
            'isin': fund.isin,
            'nombre_fondo': fund.name,
            'tipo': op.type == OperationType.buy ? l10n.buy : l10n.sell,
            'unidades': op.units,
            'precio_unitario': op.price,
            'importe_total': op.amount,
            'divisa': fund.currency,
          });
        }
      }

      // 2. Ordenar cronológicamente (ESENCIAL para cálculos fiscales FIFO)
      allOperations.sort((a, b) => a['fecha'].compareTo(b['fecha']));

      // 3. Definir las cabeceras del CSV con internacionalización
      final List<String> headers = [
        l10n.csvHeaderDate,
        l10n.csvHeaderIsin,
        l10n.csvHeaderFundName,
        l10n.csvHeaderOperationType,
        l10n.csvHeaderUnits,
        l10n.csvHeaderUnitPrice,
        l10n.csvHeaderTotalAmount,
        l10n.csvHeaderCurrency,
      ];

      // 4. Convertir los datos a formato CSV
      final List<List<dynamic>> csvData = [headers];
      final dateFormat = DateFormat.yMd(locale);

      for (final op in allOperations) {
        csvData.add([
          dateFormat.format(op['fecha']),
          op['isin'],
          op['nombre_fondo'],
          op['tipo'],
          op['unidades'].toStringAsFixed(6), // 6 decimales para precisión en fondos
          op['precio_unitario'].toStringAsFixed(4),
          op['importe_total'].toStringAsFixed(2),
          op['divisa'],
        ]);
      }

      final String csvString = _convertToCsv(csvData);

      return await _saveFileToDevice(
        l10n.saveOperationsReportTitle,
        'OpenInvest_Operaciones_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
        csvString,
      );
    } catch (e) {
      debugPrint('❌ Error al generar el informe CSV: $e');
      return null;
    }
  }

  static String _convertToCsv(List<List<dynamic>> rows) {
    return rows.map((row) => row.map((cell) {
      final val = cell.toString();
      if (val.contains(',') || val.contains('"') || val.contains('\n')) {
        return '"${val.replaceAll('"', '""')}"';
      }
      return val;
    }).join(',')).join('\n');
  }

  /// Método auxiliar para guardar el archivo usando FilePicker
  static Future<String?> _saveFileToDevice(
    String dialogTitle,
    String fileName,
    String content,
  ) async {
    try {
      final dynamic filePath = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: utf8.encode(content),
      );

      if (filePath != null) {
        var pathStr = filePath.toString();
        if (pathStr.startsWith('file://')) {
          try {
            pathStr = Uri.parse(pathStr).toFilePath();
          } catch (_) {}
        }
        final File file = File(pathStr);
        await file.writeAsString(
          content,
          encoding: utf8,
        ); // UTF-8 para acentos y eñes
        return pathStr;
      }
      return null; // El usuario canceló el diálogo
    } catch (e) {
      debugPrint('❌ Error al guardar el archivo: $e');
      return null;
    }
  }
}
