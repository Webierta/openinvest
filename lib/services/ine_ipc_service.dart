import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Modelo de datos que representa un punto en la serie histórica del IPC.
class IpcDataPoint {
  final int year;
  final int month;
  final double value;
  final DateTime date;

  IpcDataPoint({
    required this.year,
    required this.month,
    required this.value,
    required this.date,
  });

  factory IpcDataPoint.fromJson(Map<String, dynamic> json) {
    final year = json['Anyo'] as int;
    final month = json['FK_Periodo'] as int;
    final timestamp = json['Fecha'] as int?;

    return IpcDataPoint(
      year: year,
      month: month, // 1 = Enero, 12 = Diciembre
      value: (json['Valor'] as num).toDouble(),
      date: timestamp == null
          ? DateTime(year, month)
          : DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }
}

/// Servicio para consultar el IPC utilizando la API pública del INE.
class IneIpcService {
  // URL de la API del INE para la tabla 50902: IPC general nacional (Base 2021)
  // CORREGIDO la tabla 50902 no está actualizada
  // TABLA 76125 PARA VALORES POSTERIORES A 2002:
  static const String _ipcTableUrlPost2002 =
      'https://servicios.ine.es/wstempus/js/ES/DATOS_TABLA/76125';

  // TABLA 268 PARA VALORES ANTERIORES A 2002:
  static const String _ipcTableUrlPre2002 =
      'https://servicios.ine.es/wstempus/js/ES/DATOS_TABLA/268';

  /// MÉTODO getIpcValue SUSTITUIDO POR getAllIpcHistory MÁS EFICIENTE

  /// Obtiene el valor del IPC para un año y mes específicos.
  ///
  /// [year]: Año de consulta (ej. 2023).
  /// [month]: Mes de consulta (1 = Enero, 12 = Diciembre).
  ///
  /// Devuelve el valor del IPC (double) o `null` si no se encuentran datos
  /// (ej. mes futuro) o si ocurre un error de red.
  //Future<double?> getIpcValue(int year, int month) async {
  /* Future<IpcDataPoint?> getIpcValue(int year, int month) async {
    if (month < 1 || month > 12) {
      throw ArgumentError(
        'El mes debe ser un valor entre 1 (Enero) y 12 (Diciembre).',
      );
    }
    final ipcTableUrl = year < 2002
        ? _ipcTableUrlPre2002
        : _ipcTableUrlPost2002;
    try {
      final response = await http.get(Uri.parse(ipcTableUrl));
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        // La API devuelve un array de series. Buscamos la del "Índice general" nacional.
        final generalIndexSeries = jsonData.firstWhere(
          (item) => item['Nombre'].toString().contains('Índice general'),
          orElse: () => jsonData
              .first, // Fallback por si cambia ligeramente la nomenclatura
        );
        final List<dynamic> dataSeries = generalIndexSeries['Data'] as List;
        // Filtramos el punto de datos que coincida con el año y mes solicitados
        final matchingData = dataSeries.firstWhere(
          (data) => data['Anyo'] == year && data['FK_Periodo'] == month,
          orElse: () => null,
        );
        if (matchingData != null) {
          //return (matchingData['Valor'] as num).toDouble();
          return matchingData;
        }
        return null; // No hay datos publicados aún para esa fecha
      } else {
        throw Exception(
          'Error en la API del INE: Código de estado ${response.statusCode}',
        );
      }
    } catch (e) {
      //print('Error al obtener el dato del IPC: $e');
      return null;
    }
  } */

  /// (Recomendado) Obtiene toda la serie histórica del IPC general nacional.
  /// Es mucho más eficiente llamar a este método una vez y cachear el resultado
  /// en FundProvider o en memoria, en lugar de llamar a getIpcValue()
  /// repetidamente para diferentes fechas.
  Future<List<IpcDataPoint>> getAllIpcHistory() async {
    // El código del "Índice general" en la tabla 76125 es IPC290751
    // El código del "Índice general" en la tabla 268 es IPC2401
    final ipcHistoryPost2002 = await getPartIpcHistory(
      _ipcTableUrlPost2002,
      'IPC290751',
    );
    final ipcHistoryPre2002 = await getPartIpcHistory(
      _ipcTableUrlPre2002,
      'IPC2401',
    );
    return ipcHistoryPost2002 + ipcHistoryPre2002;
  }

  Future<List<IpcDataPoint>> getPartIpcHistory(
    String ipcTableUrl,
    String cod,
  ) async {
    try {
      final response = await http.get(Uri.parse(ipcTableUrl));
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);

        final generalIndexSeries = jsonData.firstWhere(
          (item) => item['COD'] == cod,
          orElse: () => null,
        );

        if (generalIndexSeries == null || generalIndexSeries['Data'] == null) {
          debugPrint('INE API ERROR: No se encontró la serie con COD $cod');
          return [];
        }

        final List<dynamic> dataSeries = generalIndexSeries['Data'] as List;

        // Convertimos y ordenamos de más reciente a más antiguo
        return dataSeries.map((data) => IpcDataPoint.fromJson(data)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      } else {
        debugPrint('INE API ERROR: Código de estado ${response.statusCode}');
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('INE API EXCEPTION: $e');
      debugPrint(stackTrace.toString());
      return [];
    }
  }

  /// MÉTODO INCLUIDO EN FUND PROVIDER

  /// Calcula la variación porcentual del IPC entre dos fechas.
  ///
  /// [startYear], [startMonth]: Fecha inicial (ej. 2021, 3 para Marzo 2021).
  /// [endYear], [endMonth]: Fecha final (ej. 2023, 10 para Octubre 2023).
  ///
  /// Devuelve la variación en porcentaje (ej. 5.5 significa un 5.5% de inflación).
  /// Devuelve `null` si falta el dato de alguna de las dos fechas (ej. mes futuro no publicado).

  /* Future<double?> getIpcVariation(
    int startYear,
    int startMonth,
    int endYear,
    int endMonth,
  ) async {
    if (startMonth < 1 || startMonth > 12 || endMonth < 1 || endMonth > 12) {
      /* throw ArgumentError(
        'Los meses deben estar entre 1 (Enero) y 12 (Diciembre).',
      ); */
      return null;
    }

    try {
      // 1. Obtenemos toda la serie histórica (la API la cacheará a nivel de red,
      // y si está en Provider, es instantáneo).
      final history = await getAllIpcHistory();
      if (history.isEmpty) return null;

      // 2. Buscamos los valores del índice para ambas fechas
      final startData = history.firstWhere(
        (data) => data.year == startYear && data.month == startMonth,
        orElse: () =>
            IpcDataPoint(year: 0, month: 0, value: 0, date: DateTime.now()),
      );
      final endData = history.firstWhere(
        (data) => data.year == endYear && data.month == endMonth,
        orElse: () =>
            IpcDataPoint(year: 0, month: 0, value: 0, date: DateTime.now()),
      );

      // 3. Validamos que ambas fechas tengan datos publicados
      if (startData.year == 0 || endData.year == 0) return null;
      // Una de las fechas no tiene datos (probablemente es un mes futuro)

      // 4. Calculamos la variación porcentual
      //final variation = ((endData.value - startData.value) / startData.value) * 100;
      final variation = ((endData.value / startData.value) - 1) * 100;
      return variation;
    } catch (e) {
      //print('Error al calcular la variación del IPC: $e');
      return null;
    }
  } */
}
