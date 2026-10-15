import 'dart:convert';

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
    return IpcDataPoint(
      year: json['Anyo'] as int,
      month: json['FK_Periodo'] as int, // 1 = Enero, 12 = Diciembre
      value: (json['Valor'] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(json['Fecha'] as int),
    );
  }
}

/// Servicio para consultar el IPC utilizando la API pública del INE.
class IneIpcService {
  // URL de la API del INE para la tabla 50902: IPC general nacional (Base 2021)
  static const String _ipcTableUrl =
      'https://servicios.ine.es/wstempus/js/ES/DATOS_TABLA/50902';

  /// Obtiene el valor del IPC para un año y mes específicos.
  ///
  /// [year]: Año de consulta (ej. 2023).
  /// [month]: Mes de consulta (1 = Enero, 12 = Diciembre).
  ///
  /// Devuelve el valor del IPC (double) o `null` si no se encuentran datos
  /// (ej. mes futuro) o si ocurre un error de red.
  //Future<double?> getIpcValue(int year, int month) async {
  Future<IpcDataPoint?> getIpcValue(int year, int month) async {
    if (month < 1 || month > 12) {
      throw ArgumentError(
        'El mes debe ser un valor entre 1 (Enero) y 12 (Diciembre).',
      );
    }

    try {
      final response = await http.get(Uri.parse(_ipcTableUrl));

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
  }

  /// (Recomendado) Obtiene toda la serie histórica del IPC general nacional.
  ///
  /// Es mucho más eficiente llamar a este método una vez y cachear el resultado
  /// en tu FundProvider o en memoria, en lugar de llamar a getIpcValue()
  /// repetidamente para diferentes fechas.
  Future<List<IpcDataPoint>> getAllIpcHistory() async {
    try {
      final response = await http.get(Uri.parse(_ipcTableUrl));
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        final generalIndexSeries = jsonData.firstWhere(
          (item) => item['Nombre'].toString().contains('Índice general'),
          orElse: () => jsonData.first,
        );
        final List<dynamic> dataSeries = generalIndexSeries['Data'] as List;

        // Convertimos y ordenamos de más reciente a más antiguo
        return dataSeries.map((data) => IpcDataPoint.fromJson(data)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      } else {
        throw Exception(
          'Error en la API del INE: Código de estado ${response.statusCode}',
        );
      }
    } catch (e) {
      //print('Error al obtener el historial del IPC: $e');
      return [];
    }
  }

  /// Calcula la variación porcentual del IPC entre dos fechas.
  ///
  /// [startYear], [startMonth]: Fecha inicial (ej. 2021, 3 para Marzo 2021).
  /// [endYear], [endMonth]: Fecha final (ej. 2023, 10 para Octubre 2023).
  ///
  /// Devuelve la variación en porcentaje (ej. 5.5 significa un 5.5% de inflación).
  /// Devuelve `null` si falta el dato de alguna de las dos fechas (ej. mes futuro no publicado).
  Future<double?> getIpcVariation(
    int startYear,
    int startMonth,
    int endYear,
    int endMonth,
  ) async {
    if (startMonth < 1 || startMonth > 12 || endMonth < 1 || endMonth > 12) {
      throw ArgumentError(
        'Los meses deben estar entre 1 (Enero) y 12 (Diciembre).',
      );
    }

    try {
      // 1. Obtenemos toda la serie histórica (la API la cacheará a nivel de red,
      // y si ya la tienes en tu Provider, es instantáneo).
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
      if (startData.year == 0 || endData.year == 0) {
        return null; // Una de las fechas no tiene datos (probablemente es un mes futuro)
      }

      // 4. Calculamos la variación porcentual
      final variation =
          ((endData.value - startData.value) / startData.value) * 100;
      return variation;
    } catch (e) {
      //print('Error al calcular la variación del IPC: $e');
      return null;
    }
  }
}
