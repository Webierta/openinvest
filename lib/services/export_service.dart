import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/fund_data.dart';
import '../utils/app_error.dart';

class ExportService {
  static String _lastExportKey(String isin) => 'last_export_$isin';

  static Future<DateTime?> getLastExportDate(String isin) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_lastExportKey(isin));
    return value == null ? null : DateTime.tryParse(value);
  }

  static Future<bool> exportFund(BuildContext context, FundData fund) async {
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

      if (result == null) return false;

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _lastExportKey(fund.isin),
        DateTime.now().toIso8601String(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fondo exportado correctamente')),
        );
      }
      return true;
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
      return false;
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

  static Future<bool> exportPortfolio(
    BuildContext context,
    List<FundData> portfolio,
  ) async {
    try {
      final String fileName =
          "OpenInvest_Cartera_${DateTime.now().toIso8601String().split('T').first.replaceAll('-', '')}.json";
      final Map<String, dynamic> backupData = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'funds': portfolio.map((f) => f.toJson()).toList(),
      };
      final String jsonString = json.encode(backupData);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));

      final result = await FilePicker.saveFile(
        dialogTitle: 'Guardar copia de seguridad de la cartera',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) return false;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cartera exportada correctamente')),
        );
      }
      return true;
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
      return false;
    }
  }

  static Future<List<FundData>?> importPortfolio(BuildContext context) async {
    try {
      final List<PlatformFile> result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result.isEmpty || result.first.path == null) return null;

      final File file = File(result.first.path!);
      final String jsonString = await file.readAsString();
      final dynamic decodedData = json.decode(jsonString);

      List<dynamic> fundsJson;
      if (decodedData is List) {
        fundsJson = decodedData;
      } else if (decodedData is Map && decodedData.containsKey('funds')) {
        fundsJson = decodedData['funds'] as List;
      } else {
        throw Exception('Formato de archivo de cartera no válido');
      }

      final List<FundData> funds = fundsJson
          .map((item) => FundData.fromJson(item as Map<String, dynamic>))
          .toList();

      return funds;
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
