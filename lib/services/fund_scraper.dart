import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../utils/app_error.dart';

class PricePoint {
  final DateTime date;
  final double price;

  PricePoint(this.date, this.price);

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'price': price,
  };

  factory PricePoint.fromJson(Map<String, dynamic> json) =>
      PricePoint(DateTime.parse(json['date']), json['price'].toDouble());
}

enum OperationType { buy, sell }

class FundOperation {
  final int? id;
  final String isin;
  final DateTime date;
  final OperationType type;
  final double units;
  final double price;
  final double amount;

  FundOperation({
    this.id,
    required this.isin,
    required this.date,
    required this.type,
    required this.units,
    required this.price,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    'isin': isin,
    'date': date.toIso8601String(),
    'type': type.name,
    'units': units,
    'price': price,
    'amount': amount,
  };

  factory FundOperation.fromJson(Map<String, dynamic> json) => FundOperation(
    isin: json['isin'],
    date: DateTime.parse(json['date']),
    type: json['type'] == 'buy' ? OperationType.buy : OperationType.sell,
    units: json['units'].toDouble(),
    price: json['price'].toDouble(),
    amount:
        json['amount']?.toDouble() ??
        (json['units'] * json['price']).toDouble(),
  );
}

class FundData {
  final String isin;
  final String symbol;
  final String name;
  final double lastValue;
  final String currency;
  final DateTime date;
  final List<PricePoint> history;
  final List<FundOperation> operations;
  final double? alertMin;
  final double? alertMax;

  FundData({
    required this.isin,
    required this.symbol,
    required this.name,
    required this.lastValue,
    required this.currency,
    required this.date,
    required List<PricePoint> history,
    this.operations = const [],
    this.alertMin,
    this.alertMax,
  }) : history = _syncHistory(history, lastValue, date);

  // Asegura que lastValue esté en history y sea el punto más reciente para esa fecha
  static List<PricePoint> _syncHistory(
    List<PricePoint> history,
    double lastValue,
    DateTime date,
  ) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    final List<PricePoint> synced = List.from(history);

    if (lastValue <= 0) {
      synced.sort((a, b) => a.date.compareTo(b.date));
      return synced;
    }

    final int existingIdx = synced.indexWhere(
      (p) =>
          p.date.year == normalizedDate.year &&
          p.date.month == normalizedDate.month &&
          p.date.day == normalizedDate.day,
    );

    if (existingIdx != -1) {
      // Reemplazamos el punto del día con el lastValue más preciso
      synced[existingIdx] = PricePoint(normalizedDate, lastValue);
    } else {
      // Si no existe el día en el historial (ej: es hoy), lo añadimos
      synced.add(PricePoint(normalizedDate, lastValue));
    }

    synced.sort((a, b) => a.date.compareTo(b.date));
    return synced;
  }

  Map<String, dynamic> toJson() => {
    'isin': isin,
    'symbol': symbol,
    'name': name,
    'lastValue': lastValue,
    'currency': currency,
    'date': date.toIso8601String(),
    'history': history.map((e) => e.toJson()).toList(),
    'operations': operations.map((e) => e.toJson()).toList(),
    'alertMin': alertMin,
    'alertMax': alertMax,
  };

  factory FundData.fromJson(Map<String, dynamic> json) => FundData(
    isin: json['isin'],
    symbol: json['symbol'],
    name: json['name'],
    lastValue: json['lastValue'],
    currency: json['currency'],
    date: DateTime.parse(json['date']),
    history:
        (json['history'] as List?)
            ?.map((e) => PricePoint.fromJson(e))
            .toList() ??
        [],
    operations:
        (json['operations'] as List?)
            ?.map((e) => FundOperation.fromJson(e))
            .toList() ??
        [],
    alertMin: json['alertMin']?.toDouble(),
    alertMax: json['alertMax']?.toDouble(),
  );
}

class ScrapeResult {
  final FundData? data;
  final AppError? error;

  ScrapeResult({this.data, this.error});

  String? get errorMessage => error?.message;
}

class FundScraper {
  static const String _searchUrl =
      'https://query1.finance.yahoo.com/v1/finance/search?q=';
  static const String _chartUrl =
      'https://query1.finance.yahoo.com/v8/finance/chart/';

  static final Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  static Future<http.Response> _getWithRetry(Uri uri) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        return await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 15));
      } on SocketException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      } on TimeoutException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      } on http.ClientException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }

      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }

    throw AppError.network(cause: lastError, stackTrace: lastStackTrace);
  }

  static ScrapeResult parseChartPayload({
    required String isin,
    required String symbol,
    required String name,
    required Map<String, dynamic> payload,
  }) {
    final chart = payload['chart'];
    if (chart is! Map<String, dynamic>) {
      return ScrapeResult(
        error: AppError.data(
          'La respuesta de cotizaciones no tiene un formato válido.',
        ),
      );
    }

    final results = chart['result'];
    if (results is! List ||
        results.isEmpty ||
        results.first is! Map<String, dynamic>) {
      return ScrapeResult(
        error: AppError.notFound('No hay cotizaciones disponibles.'),
      );
    }

    final result = results.first as Map<String, dynamic>;
    final meta = result['meta'];
    if (meta != null && meta is! Map<String, dynamic>) {
      return ScrapeResult(
        error: AppError.data(
          'Los metadatos de cotización no tienen un formato válido.',
        ),
      );
    }

    final metaMap = meta is Map<String, dynamic> ? meta : <String, dynamic>{};
    final price = _asDouble(metaMap['regularMarketPrice']);
    final currency = metaMap['currency'] is String
        ? metaMap['currency'] as String
        : '';
    final timestamp = _asInt(metaMap['regularMarketTime']);
    final timestamps = result['timestamp'];
    final indicators = result['indicators'];
    final quote = indicators is Map<String, dynamic>
        ? indicators['quote']
        : null;
    final closePrices =
        quote is List && quote.isNotEmpty && quote.first is Map<String, dynamic>
        ? (quote.first as Map<String, dynamic>)['close']
        : null;

    final historyResult = _parseHistory(timestamps, closePrices);
    if (historyResult.error != null) {
      return ScrapeResult(error: historyResult.error);
    }

    final history = historyResult.data!;
    if (price == null && history.isEmpty) {
      return ScrapeResult(error: AppError.data('Precio no disponible.'));
    }

    final effectivePrice = price ?? history.last.price;
    final effectiveDate = timestamp == null
        ? (history.isNotEmpty ? history.last.date : DateTime.now())
        : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

    return ScrapeResult(
      data: FundData(
        isin: isin,
        symbol: symbol,
        name: name,
        lastValue: effectivePrice,
        currency: currency,
        date: DateTime(
          effectiveDate.year,
          effectiveDate.month,
          effectiveDate.day,
        ),
        history: history,
      ),
    );
  }

  static ({List<PricePoint>? data, AppError? error}) _parseHistory(
    Object? timestampsValue,
    Object? closePricesValue,
  ) {
    if (timestampsValue == null && closePricesValue == null) {
      return (data: <PricePoint>[], error: null);
    }
    if (timestampsValue is! List || closePricesValue is! List) {
      return (
        data: null,
        error: AppError.data('El historial de cotizaciones está incompleto.'),
      );
    }
    if (timestampsValue.length != closePricesValue.length) {
      return (
        data: null,
        error: AppError.data('El historial de cotizaciones está incompleto.'),
      );
    }

    final history = <PricePoint>[];
    for (int i = 0; i < timestampsValue.length; i++) {
      final closePrice = _asDouble(closePricesValue[i]);
      if (closePrice == null) continue;
      final timestamp = _asInt(timestampsValue[i]);
      if (timestamp == null) {
        return (
          data: null,
          error: AppError.data(
            'El historial de cotizaciones contiene datos inválidos.',
          ),
        );
      }
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      history.add(
        PricePoint(DateTime(date.year, date.month, date.day), closePrice),
      );
    }
    return (data: history, error: null);
  }

  static double? _asDouble(Object? value) =>
      value is num ? value.toDouble() : null;

  static int? _asInt(Object? value) => value is num ? value.toInt() : null;

  static Future<ScrapeResult> getFundByIsin(
    String isin, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final searchResponse = await _getWithRetry(Uri.parse('$_searchUrl$isin'));
      if (searchResponse.statusCode != 200) {
        return ScrapeResult(
          error: AppError.remote('El servicio de búsqueda no está disponible.'),
        );
      }

      final searchData = json.decode(searchResponse.body);
      if (searchData is! Map<String, dynamic> ||
          searchData['quotes'] is! List) {
        return ScrapeResult(
          error: AppError.data(
            'La respuesta de búsqueda no tiene un formato válido.',
          ),
        );
      }
      final quotes = searchData['quotes'] as List;
      if (quotes.isEmpty || quotes.first is! Map<String, dynamic>) {
        return ScrapeResult(error: AppError.notFound('ISIN no encontrado.'));
      }

      final firstResult = quotes.first as Map<String, dynamic>;
      final symbol = firstResult['symbol'];
      if (symbol is! String || symbol.isEmpty) {
        return ScrapeResult(
          error: AppError.data('El fondo no tiene un símbolo válido.'),
        );
      }
      final String name =
          (firstResult['longname'] is String
              ? firstResult['longname']
              : null) ??
          (firstResult['shortname'] is String
              ? firstResult['shortname']
              : null) ??
          'Fondo desconocido';

      // Build chart URL
      String url = '$_chartUrl$symbol';
      if (startDate != null && endDate != null) {
        final start = startDate.millisecondsSinceEpoch ~/ 1000;
        final end = endDate.millisecondsSinceEpoch ~/ 1000;
        url += '?period1=$start&period2=$end&interval=1d';
      } else {
        url += '?range=1mo&interval=1d';
      }

      final chartResponse = await _getWithRetry(Uri.parse(url));

      if (chartResponse.statusCode != 200) {
        return ScrapeResult(
          error: AppError.remote(
            'El servicio de cotizaciones no está disponible.',
          ),
        );
      }

      final chartData = json.decode(chartResponse.body);
      if (chartData is! Map<String, dynamic>) {
        return ScrapeResult(
          error: AppError.data(
            'La respuesta de cotizaciones no tiene un formato válido.',
          ),
        );
      }
      return parseChartPayload(
        isin: isin,
        symbol: symbol,
        name: name,
        payload: chartData,
      );
    } on AppError catch (error) {
      return ScrapeResult(error: error);
    } catch (error, stackTrace) {
      return ScrapeResult(
        error: AppError.fromException(
          error,
          stackTrace,
          type: AppErrorType.data,
        ),
      );
    }
  }

  static Future<double> getExchangeRate(String from, String to) async {
    if (from == to) return 1.0;
    try {
      final String symbol = '$from$to=X';
      final response = await _getWithRetry(
        Uri.parse('$_chartUrl$symbol?range=1d&interval=1d'),
      );
      if (response.statusCode != 200) {
        throw AppError.remote('No se pudo obtener el tipo de cambio.');
      }

      final data = json.decode(response.body);
      final result = data['chart']?['result']?[0];
      final double? rate = result?['meta']?['regularMarketPrice']?.toDouble();

      if (rate == null) {
        throw AppError.data('Tipo de cambio no disponible.');
      }
      return rate;
    } on AppError {
      rethrow;
    } catch (error, stackTrace) {
      throw AppError.fromException(error, stackTrace, type: AppErrorType.data);
    }
  }
}
