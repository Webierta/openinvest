import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'fund_scraper.dart';

//import 'package:openinvest/services/fund_scraper.dart'; // Ajusta a tu ruta real de modelos

class ReportGenerator {
  /// Genera un CSV con todas las operaciones ordenadas cronológicamente.
  /// Ideal para importar en Excel o calcular plusvalías FIFO/LIFO.
  static Future<String?> exportOperationsToCsv(List<FundData> portfolio) async {
    try {
      // 1. Aplanar todas las operaciones de todos los fondos en una sola lista
      final List<Map<String, dynamic>> allOperations = [];

      for (final fund in portfolio) {
        for (final op in fund.operations) {
          allOperations.add({
            'fecha': op.date,
            'isin': fund.isin,
            'nombre_fondo': fund.name,
            'tipo': op.type == OperationType.buy ? 'COMPRA' : 'VENTA',
            'unidades': op.units,
            'precio_unitario': op.price,
            'importe_total': op.amount,
            'divisa': fund.currency,
          });
        }
      }

      // 2. Ordenar cronológicamente (ESSENCIAL para cálculos fiscales FIFO)
      allOperations.sort((a, b) => a['fecha'].compareTo(b['fecha']));

      // 3. Definir las cabeceras del CSV
      const List<String> headers = [
        'Fecha',
        'ISIN',
        'Nombre del Fondo',
        'Tipo de Operación',
        'Unidades',
        'Precio Unitario',
        'Importe Total',
        'Divisa',
      ];

      // 4. Convertir los datos a formato CSV
      final List<List<dynamic>> csvData = [headers];
      final dateFormat = DateFormat('dd/MM/yyyy');

      for (final op in allOperations) {
        csvData.add([
          dateFormat.format(op['fecha']),
          op['isin'],
          op['nombre_fondo'],
          op['tipo'],
          op['unidades'].toStringAsFixed(
            6,
          ), // 6 decimales para precisión en fondos
          op['precio_unitario'].toStringAsFixed(4),
          op['importe_total'].toStringAsFixed(2),
          op['divisa'],
        ]);
      }

      final String csvString = csv.encode(csvData);

      return await _saveFileToDevice(
        'OpenInvest_Operaciones_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
        csvString,
      );
    } catch (e) {
      debugPrint('❌ Error al generar el informe CSV: $e');
      return null;
    }
  }

  /// Método auxiliar para guardar el archivo usando FilePicker
  static Future<String?> _saveFileToDevice(
    String fileName,
    String content,
  ) async {
    try {
      // Usar 'bytes' delega la escritura al plugin nativo,
      // evitando problemas de permisos de dart:io en móviles

      final filePath = await FilePicker.saveFile(
        dialogTitle: 'Guardar informe de operaciones',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: utf8.encode(content),
      );

      if (filePath != null) {
        final File file = File(filePath.path);
        await file.writeAsString(
          // utf8.encode(content)
          content,
          encoding: Utf8Codec(),
        ); // UTF-8 para acentos y eñes
        return filePath.path;
      }
      return null; // El usuario canceló el diálogo
    } catch (e) {
      debugPrint('❌ Error al guardar el archivo: $e');
      return null;
    }
  }
}
