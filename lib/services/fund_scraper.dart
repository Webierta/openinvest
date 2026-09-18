import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
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

class FundSearchMatch {
  final String? isin;
  final String symbol;
  final String name;

  const FundSearchMatch({
    required this.isin,
    required this.symbol,
    required this.name,
  });
}

class _FundCatalog {
  final Map<String, List<String>> isinsByName;
  final Map<String, String> names;

  const _FundCatalog({required this.isinsByName, required this.names});
}

class FundScraper {
  static const String _fundCatalogAsset =
      'assets/files/fondos_armonizados.json';
  static const String _searchUrl =
      'https://query1.finance.yahoo.com/v1/finance/search?q=';
  static const String _chartUrl =
      'https://query1.finance.yahoo.com/v8/finance/chart/';

  static final Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };
  static Future<_FundCatalog>? _fundCatalog;
  static final Map<String, String> _fundCatalogNames = {};

  static String _normalizeFundName(String value) {
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    var normalized = value.toLowerCase();
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static Future<_FundCatalog> _loadFundCatalog() {
    return _fundCatalog ??= _readFundCatalog();
  }

  static Future<_FundCatalog> _readFundCatalog() async {
    final content = await rootBundle.loadString(_fundCatalogAsset);
    final entries = json.decode(content);
    if (entries is! List) {
      return const _FundCatalog(isinsByName: {}, names: {});
    }

    final catalog = <String, List<String>>{};
    final names = <String, String>{};
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      final name = entry['nombre'];
      final isins = entry['isins'];
      if (name is String && name.isNotEmpty && isins is List) {
        final normalizedName = _normalizeFundName(name);
        final catalogIsins = catalog.putIfAbsent(normalizedName, () => []);
        for (final isin in isins) {
          if (isin is String &&
              isin.isNotEmpty &&
              !catalogIsins.contains(isin)) {
            catalogIsins.add(isin);
          }
        }
        if (catalogIsins.isNotEmpty) {
          names.putIfAbsent(normalizedName, () => name);
        }
      }
    }
    _fundCatalogNames.addAll(names);
    return _FundCatalog(isinsByName: catalog, names: names);
  }

  static Future<List<FundSearchMatch>> _addCatalogIsins(
    List<FundSearchMatch> matches,
  ) async {
    final catalog = await _loadFundCatalog();
    return matches.expand((match) {
      if (match.isin != null) return [match];
      final isins = _findCatalogIsins(catalog, match.name);
      if (isins.isEmpty) {
        return [
          FundSearchMatch(isin: null, symbol: match.symbol, name: match.name),
        ];
      }
      return isins.map(
        (isin) =>
            FundSearchMatch(isin: isin, symbol: match.symbol, name: match.name),
      );
    }).toList();
  }

  static String? findCatalogIsin(Map<String, String> catalog, String fundName) {
    final normalizedName = _normalizeFundName(fundName);
    return catalog[normalizedName] ??
        _findContainedCatalogIsin(catalog, normalizedName);
  }

  static String? _findContainedCatalogIsin(
    Map<String, String> catalog,
    String normalizedName,
  ) {
    if (normalizedName.length < 8) return null;
    final queryTokens = normalizedName
        .split(' ')
        .where((token) => token.length >= 3)
        .toSet();
    final candidates =
        catalog.entries.where((entry) {
          if (entry.key.length < 8) return false;
          if (normalizedName.contains(entry.key) ||
              entry.key.contains(normalizedName)) {
            return true;
          }
          final catalogTokens = entry.key.split(' ').toSet();
          return queryTokens.isNotEmpty &&
              queryTokens.every(catalogTokens.contains);
        }).toList()..sort(
          (first, second) => second.key.length.compareTo(first.key.length),
        );
    return candidates.isEmpty ? null : candidates.first.value;
  }

  static List<String> _findCatalogIsins(_FundCatalog catalog, String fundName) {
    final normalizedName = _normalizeFundName(fundName);
    final exact = catalog.isinsByName[normalizedName];
    if (exact != null) return exact;

    final queryTokens = normalizedName
        .split(' ')
        .where((token) => token.length >= 3)
        .toSet();
    final candidates =
        catalog.isinsByName.entries.where((entry) {
          if (entry.key.length < 8) return false;
          if (normalizedName.contains(entry.key) ||
              entry.key.contains(normalizedName)) {
            return true;
          }
          final catalogTokens = entry.key.split(' ').toSet();
          return queryTokens.isNotEmpty &&
              queryTokens.every(catalogTokens.contains);
        }).toList()..sort(
          (first, second) => second.key.length.compareTo(first.key.length),
        );
    return candidates.expand((entry) => entry.value).toList();
  }

  static List<FundSearchMatch> _searchCatalog(
    _FundCatalog catalog,
    String query,
  ) {
    final normalizedQuery = _normalizeFundName(query);
    final queryTokens = normalizedQuery
        .split(' ')
        .where((token) => token.length >= 3)
        .toSet();
    if (queryTokens.isEmpty) return [];

    final matches =
        catalog.isinsByName.entries.where((entry) {
          final catalogTokens = entry.key.split(' ').toSet();
          return queryTokens.every(catalogTokens.contains);
        }).toList()..sort(
          (first, second) => first.key.length.compareTo(second.key.length),
        );

    return matches
        .take(10)
        .expand(
          (entry) => entry.value.map(
            (isin) => FundSearchMatch(
              isin: isin,
              symbol: '',
              name: catalog.names[entry.key] ?? entry.key,
            ),
          ),
        )
        .toList();
  }

  static List<FundSearchMatch> searchCatalogMatches(
    Map<String, String> catalog,
    String query,
  ) {
    final internalCatalog = _FundCatalog(
      isinsByName: catalog.map((name, isin) => MapEntry(name, [isin])),
      names: _fundCatalogNames,
    );
    return _searchCatalog(internalCatalog, query);
  }

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

    final effectivePrice = history.isNotEmpty ? history.last.price : price!;
    final effectiveDate = history.isNotEmpty
        ? history.last.date
        : timestamp == null
        ? DateTime.now()
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

  static List<FundSearchMatch> parseSearchPayload(
    Map<String, dynamic> payload,
  ) {
    final quotes = payload['quotes'];
    if (quotes is! List) return [];

    final matches = <FundSearchMatch>[];
    final seen = <String>{};
    for (final quote in quotes) {
      if (quote is! Map<String, dynamic>) continue;
      final symbol = quote['symbol'];
      if (symbol is! String || symbol.isEmpty || !seen.add(symbol)) continue;
      final name = quote['longname'] ?? quote['shortname'];
      if (name is! String || name.isEmpty) continue;
      final isin =
          quote['isin'] is String && (quote['isin'] as String).isNotEmpty
          ? quote['isin'] as String
          : null;
      matches.add(FundSearchMatch(isin: isin, symbol: symbol, name: name));
    }
    return matches;
  }

  static Future<List<FundSearchMatch>> searchFunds(String query) async {
    final catalog = await _loadFundCatalog();
    var yahooMatches = <FundSearchMatch>[];
    try {
      final response = await _getWithRetry(
        Uri.parse(
          '$_searchUrl${Uri.encodeQueryComponent(query)}&quotesCount=10',
        ),
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body);
        if (payload is Map<String, dynamic>) {
          yahooMatches = await _addCatalogIsins(parseSearchPayload(payload));
        }
      }
    } catch (_) {
      // El catálogo local sigue permitiendo buscar sin conexión.
    }

    final localMatches = _searchCatalog(catalog, query);
    final seenIsins = yahooMatches
        .map((match) => match.isin)
        .whereType<String>()
        .toSet();
    return [
      ...yahooMatches,
      ...localMatches.where((match) => !seenIsins.contains(match.isin)),
    ];
  }

  static Future<ScrapeResult> getFundBySearchMatch(
    FundSearchMatch match, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (match.symbol.isEmpty && match.isin != null) {
      return getFundByIsin(match.isin!, startDate: startDate, endDate: endDate);
    }
    return _getFundBySymbol(
      isin: match.isin ?? match.symbol,
      symbol: match.symbol,
      name: match.name,
      startDate: startDate,
      endDate: endDate,
    );
  }

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

      return await _getFundBySymbol(
        isin: isin,
        symbol: symbol,
        name: name,
        startDate: startDate,
        endDate: endDate,
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

  static Future<ScrapeResult> _getFundBySymbol({
    required String isin,
    required String symbol,
    required String name,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
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
