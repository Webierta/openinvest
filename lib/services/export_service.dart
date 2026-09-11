import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'fund_scraper.dart';
import 'database_service.dart';
import '../utils/app_error.dart';

class ExportService {
  static Future<void> exportFund(BuildContext context, FundData fund) async {
    try {
      final String fileName = "investi_export_${fund.isin}.json";
      final String jsonString = json.encode(fund.toJson());
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));

      // En esta versión, saveFile requiere los bytes y se encarga de escribir el archivo
      final result = await FilePicker.saveFile(
        dialogTitle: 'Guardar exportación de fondo',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fondo exportado correctamente')),
        );
      }
    } catch (error, stackTrace) {
      final appError = AppError.fromException(
        error,
        stackTrace,
        type: AppErrorType.database,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appError.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<FundData?> importFund(BuildContext context) async {
    try {
      // En esta versión, pickFiles devuelve directamente una lista de PlatformFile
      final List<PlatformFile> result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result.isEmpty || result.first.path == null) return null;

      final File file = File(result.first.path!);
      final String jsonString = await file.readAsString();
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      final FundData fund = FundData.fromJson(jsonData);

      // Save to database
      await DatabaseService.saveFund(fund);
      for (var op in fund.operations) {
        await DatabaseService.saveOperation(op);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fondo importado correctamente')),
        );
      }
      return fund;
    } catch (error, stackTrace) {
      final appError = AppError.fromException(
        error,
        stackTrace,
        type: AppErrorType.database,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appError.message),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }
}
