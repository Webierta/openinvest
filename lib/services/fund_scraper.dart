import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/fund_data.dart';
import '../models/fund_search_mode.dart';
import '../utils/app_error.dart';
import '../utils/fund_name_matcher.dart';
import '../utils/isin_search_query.dart';
import 'isin_providers/ecb_ifs_provider.dart';

class _FundCatalog {
  final Map<String, List<String>> isinsByName;
  final Map<String, String> names;
  final Set<String> allIsins;

  const _FundCatalog({
    required this.isinsByName,
    required this.names,
    required this.allIsins,
  });
}

class FundScraper {
  static const String _fundCatalogAsset =
      'assets/files/fondos_armonizados.json';

  // REVISAR EXPERIMENTAL
  //static const String _fundEcbIfs = 'assets/files/ECB_IFS_2024.json';

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

  static Future<_FundCatalog> _loadFundCatalog() {
    return _fundCatalog ??= _readFundCatalog();
  }

  static Future<_FundCatalog> _readFundCatalog() async {
    final content = await rootBundle.loadString(_fundCatalogAsset);
    final entries = json.decode(content);
    if (entries is! List) {
      return const _FundCatalog(isinsByName: {}, names: {}, allIsins: {});
    }

    final catalog = <String, List<String>>{};
    final names = <String, String>{};
    final allIsins = <String>{};
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      final name = entry['nombre'];
      final isins = entry['isins'];
      if (name is String && name.isNotEmpty && isins is List) {
        final normalizedName = FundNameMatcher.normalizeName(name);
        final catalogIsins = catalog.putIfAbsent(normalizedName, () => []);
        for (final isin in isins) {
          if (isin is String && isin.isNotEmpty) {
            allIsins.add(isin);
            if (!catalogIsins.contains(isin)) {
              catalogIsins.add(isin);
            }
          }
        }
        if (catalogIsins.isNotEmpty) {
          names.putIfAbsent(normalizedName, () => name);
        }
      }
    }
    _fundCatalogNames.addAll(names);
    return _FundCatalog(isinsByName: catalog, names: names, allIsins: allIsins);
  }

  static Future<List<FundSearchMatch>> _addCatalogIsins(
    List<FundSearchMatch> matches,
  ) async {
    final catalog = await _loadFundCatalog();
    return matches.expand((match) {
      if (match.isin != null) {
        final source = catalog.allIsins.contains(match.isin)
            ? FundSource.local
            : match.source;
        return [
          FundSearchMatch(
            isin: match.isin,
            symbol: match.symbol,
            name: match.name,
            source: source,
          ),
        ];
      }
      final isins = _findCatalogIsins(catalog, match.name);
      if (isins.isEmpty) {
        return [
          FundSearchMatch(
            isin: null,
            symbol: match.symbol,
            name: match.name,
            source: match.source,
          ),
        ];
      }
      return isins.map(
        (isin) => FundSearchMatch(
          isin: isin,
          symbol: match.symbol,
          name: match.name,
          source: FundSource.local,
        ),
      );
    }).toList();
  }

  static String? findCatalogIsin(Map<String, String> catalog, String fundName) {
    final normalizedName = FundNameMatcher.normalizeName(fundName);
    final normalizedCatalog = _catalogFromMap(catalog);
    final exact = normalizedCatalog.isinsByName[normalizedName];
    if (exact != null) return exact.first;

    final queryTokens = normalizedName
        .split(' ')
        .where((token) => token.length >= 3)
        .toList();
    if (queryTokens.isEmpty) return null;

    final candidates = normalizedCatalog.isinsByName.entries.where((entry) {
      return queryTokens.every((qt) => entry.key.contains(qt));
    }).toList()..sort((a, b) => a.key.length.compareTo(b.key.length));

    return candidates.isEmpty ? null : candidates.first.value.first;
  }

  static _FundCatalog _catalogFromMap(Map<String, String> catalog) {
    final isinsByName = <String, List<String>>{};
    final names = <String, String>{};
    final allIsins = <String>{};

    for (final entry in catalog.entries) {
      final normalizedName = FundNameMatcher.normalizeName(entry.key);
      final isins = isinsByName.putIfAbsent(normalizedName, () => []);
      if (!isins.contains(entry.value)) isins.add(entry.value);
      names.putIfAbsent(normalizedName, () => entry.key);
      allIsins.add(entry.value);
    }

    return _FundCatalog(
      isinsByName: isinsByName,
      names: names,
      allIsins: allIsins,
    );
  }

  static List<MapEntry<String, List<String>>> _findCatalogNameMatches(
    _FundCatalog catalog,
    String query,
  ) {
    final normalizedName = FundNameMatcher.normalizeName(query);

    final queryTokens = normalizedName
        .split(' ')
        .where((token) => token.length >= 2)
        .toList();

    if (queryTokens.isEmpty) return [];

    return catalog.isinsByName.entries
        .where((entry) => FundNameMatcher.matchesAllTokens(query, entry.key))
        .toList()
      ..sort((a, b) {
        final lengthComparison = a.key.length.compareTo(b.key.length);
        if (lengthComparison != 0) return lengthComparison;
        return a.key.compareTo(b.key);
      });
  }

  static List<String> _findCatalogIsins(_FundCatalog catalog, String fundName) {
    final normalizedName = FundNameMatcher.normalizeName(fundName);
    final exact = catalog.isinsByName[normalizedName];
    if (exact != null) return exact;

    return _findCatalogNameMatches(
      catalog,
      fundName,
    ).expand((entry) => entry.value).toList();
  }

  static List<FundSearchMatch> _searchCatalog(
    _FundCatalog catalog,
    String query, {
    required FundSearchMode mode,
  }) {
    if (mode == FundSearchMode.isin) {
      final isinPrefix = IsinSearchQuery.prefix(query);
      if (isinPrefix == null) return [];

      final seenIsins = <String>{};
      final isinMatches = <FundSearchMatch>[];

      for (final entry in catalog.isinsByName.entries) {
        for (final isin in entry.value) {
          final normalizedIsin = isin.toUpperCase();
          if (!normalizedIsin.startsWith(isinPrefix) ||
              !seenIsins.add(normalizedIsin)) {
            continue;
          }

          isinMatches.add(
            FundSearchMatch(
              isin: isin,
              symbol: '',
              name: catalog.names[entry.key] ?? entry.key,
              source: FundSource.local,
            ),
          );
        }
      }

      isinMatches.sort((a, b) => a.isin!.compareTo(b.isin!));
      return isinMatches;
    }

    final normalizedQuery = FundNameMatcher.normalizeName(query);
    final queryTokens = normalizedQuery
        .split(' ')
        .where((token) => token.length >= 2)
        .toList();
    if (queryTokens.isEmpty) return [];

    final matches =
        catalog.isinsByName.entries.where((entry) {
          // Búsqueda flexible: todos los trozos de la consulta deben estar en el nombre
          return queryTokens.every((qt) => entry.key.contains(qt));
        }).toList()..sort((a, b) {
          // Coincidencia más corta arriba (normalmente más relevante)
          return a.key.length.compareTo(b.key.length);
        });

    return matches
        .take(15)
        .expand(
          (entry) => entry.value.map(
            (isin) => FundSearchMatch(
              isin: isin,
              symbol: '',
              name: catalog.names[entry.key] ?? entry.key,
              source: FundSource.local,
            ),
          ),
        )
        .toList();
  }

  static List<FundSearchMatch> searchCatalogMatches(
    Map<String, String> catalog,
    String query, {
    required FundSearchMode mode,
  }) {
    final internalCatalog = _catalogFromMap(catalog);
    return _searchCatalog(internalCatalog, query, mode: mode);
  }

  static Future<List<FundSearchMatch>> _searchEcbIfs(
    String query, {
    required FundSearchMode mode,
  }) async {
    try {
      final provider = EcbIfsProvider();
      final results = mode == FundSearchMode.isin
          ? await provider.searchByIsin(query)
          : await provider.searchByName(query);

      return results
          .map(
            (result) => FundSearchMatch(
              isin: result.isin,
              symbol: '',
              name: result.officialName ?? '',
              source: FundSource.ecb,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
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

    // Intentar descubrir el ISIN real en los metadatos si el proporcionado es nulo o parece un símbolo
    String effectiveIsin = isin;
    if (metaMap['isin'] is String && (metaMap['isin'] as String).isNotEmpty) {
      effectiveIsin = metaMap['isin'] as String;
    }

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
        isin: effectiveIsin,
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
      FundSource source = FundSource.yahoo;
      if (symbol.toUpperCase().contains('0P') ||
          symbol.toUpperCase().endsWith('.F')) {
        source = FundSource.morningstar;
      }
      matches.add(
        FundSearchMatch(isin: isin, symbol: symbol, name: name, source: source),
      );
    }
    return matches;
  }

  /// Busca [query] en Yahoo Finance y enriquece los resultados con ISIN del
  /// catálogo local. Devuelve una lista vacía si la petición falla o no hay
  /// resultados válidos.
  static Future<List<FundSearchMatch>> _searchYahoo(String query) async {
    try {
      final response = await _getWithRetry(
        Uri.parse(
          '$_searchUrl${Uri.encodeQueryComponent(query)}&quotesCount=10',
        ),
      );
      if (response.statusCode != 200) return [];

      final payload = json.decode(response.body);
      if (payload is! Map<String, dynamic>) return [];
      return await _addCatalogIsins(parseSearchPayload(payload));
    } catch (_) {
      return [];
    }
  }

  static Future<List<FundSearchMatch>> _searchYahooByName(String query) async {
    var matches = await _searchYahoo(query.trim());
    if (matches.isNotEmpty) return matches;

    final queryTokens = FundNameMatcher.normalizeName(query)
        .split(' ')
        .where((token) => token.length >= 2)
        .toSet()
        .toList();
    if (queryTokens.length <= 1) return matches;

    final fallbackTokens = [...queryTokens]
      ..sort((a, b) => b.length.compareTo(a.length));
    final fallbackResponses = await Future.wait(
      fallbackTokens.take(3).map(_searchYahoo),
    );
    final seenSymbols = <String>{};
    matches = fallbackResponses.expand((response) => response).where((match) {
      return FundNameMatcher.matchesAllTokens(query, match.name) &&
          seenSymbols.add(match.symbol.toUpperCase());
    }).toList();
    return matches;
  }

  static Future<List<FundSearchMatch>> searchFunds(
    String query, {
    required FundSearchMode mode,
  }) async {
    final isinPrefix = mode == FundSearchMode.isin
        ? IsinSearchQuery.prefix(query)
        : null;
    if (mode == FundSearchMode.isin && isinPrefix == null) return [];

    final catalog = await _loadFundCatalog();
    final yahooMatches = mode == FundSearchMode.isin
        ? (await _searchYahoo(isinPrefix!)).where((match) {
            final isin = match.isin;
            return isin != null &&
                IsinSearchQuery.normalize(isin).startsWith(isinPrefix);
          }).toList()
        : await _searchYahooByName(query);

    final catalogQuery = isinPrefix ?? query;
    final localMatches = _searchCatalog(catalog, catalogQuery, mode: mode);
    final ecbMatches = await _searchEcbIfs(catalogQuery, mode: mode);

    final seenIsins = <String>{};
    final combined = <FundSearchMatch>[];

    // Revisar orden (por facilidad de obtener cotizaciones):
    // 1º local CNMV, 2º Yahoo - Morningstar 3º ECB
    //for (final match in [...yahooMatches, ...localMatches, ...ecbMatches]) {
    for (final match in [...localMatches, ...yahooMatches, ...ecbMatches]) {
      if (match.isin != null && match.isin!.isNotEmpty) {
        if (seenIsins.add(match.isin!)) {
          combined.add(match);
        }
      } else {
        combined.add(match);
      }
    }

    return combined;
  }

  static ScrapeResult _withSource(ScrapeResult result, FundSource source) {
    return ScrapeResult(
      data: result.data,
      error: result.error,
      isResolved: result.isResolved,
      source: source,
    );
  }

  static Future<ScrapeResult> getFundBySearchMatch(
    FundSearchMatch match, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Si la fuente es ECB, los datos ya están completos en el match local.
    // No necesitamos consultar Yahoo Finance porque son fondos no cotizados allí.
    if (match.source == FundSource.ecb) {
      return ScrapeResult(
        data: FundData(
          isin: match.isin ?? '',
          symbol: match.symbol,
          name: match.name,
          lastValue: 0.0, // Al no tener histórico online, parte de valor 0 hasta que se registren operaciones
          currency: 'EUR',
          date: DateTime.now(),
          history: const [],
        ),
        isResolved: true,
        source: FundSource.ecb,
      );
    }

    if (match.symbol.isEmpty && match.isin != null) {
      final result = await getFundByIsin(
        match.isin!,
        startDate: startDate,
        endDate: endDate,
      );
      return _withSource(result, match.source);
    }

    final result = await _getFundBySymbol(
      isin: match.isin ?? match.symbol,
      symbol: match.symbol,
      name: match.name,
      startDate: startDate,
      endDate: endDate,
    );

    return _withSource(result, match.source);
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

  static Future<ScrapeResult> getHistoryBySymbol(
    String symbol, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _getFundBySymbol(
      isin: symbol,
      symbol: symbol,
      name: symbol,
      startDate: startDate,
      endDate: endDate,
    );
  }

  static Future<ScrapeResult> _getFundBySymbol({
    required String isin,
    required String symbol,
    required String name,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // 1. Antes de descargar el gráfico, intentamos descubrir un ISIN real si el actual es corto (símbolo)
      String effectiveIsin = isin;
      if (effectiveIsin.length < 12) {
        final discovered = await _discoverRealIsin(symbol, name);
        if (discovered != null) effectiveIsin = discovered;
      }

      // Build chart URL
      String url = '$_chartUrl$symbol';
      if (startDate != null) {
        final start = startDate.millisecondsSinceEpoch ~/ 1000;
        final end = (endDate ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
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
        isin: effectiveIsin,
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

  static Future<String?> _discoverRealIsin(String symbol, String name) async {
    // 1. Intentar nivel 1: Búsqueda específica en Yahoo con el símbolo exacto
    try {
      final response = await _getWithRetry(Uri.parse('$_searchUrl$symbol'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List quotes = data['quotes'] ?? [];
        for (var quote in quotes) {
          if (quote['symbol'] == symbol && quote['isin'] != null) {
            final String foundIsin = (quote['isin'] as String).toUpperCase();
            if (RegExp(r'^[A-Z]{2}[A-Z0-9]{10}$').hasMatch(foundIsin)) {
              return foundIsin;
            }
          }
        }
      }
    } catch (_) {}

    // 2. Intentar nivel 2: Búsqueda Web simplificada para evitar bloqueos
    // Realizamos una única búsqueda muy amplia
    try {
      final query = Uri.encodeQueryComponent('"$symbol" ISIN');
      final response = await http
          .get(
            Uri.parse('https://html.duckduckgo.com/html/?q=$query'),
            headers: {
              'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.5',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = response.body;
        // Regex robusto para ISIN (12 caracteres: 2 letras + 10 alfanuméricos)
        final isinRegex = RegExp(r'\b[A-Za-z]{2}[A-Za-z0-9]{9}[0-9]\b');
        final matches = isinRegex.allMatches(body);

        if (matches.isNotEmpty) {
          // Extraemos todos los candidatos únicos
          final candidates = matches
              .map((m) => m.group(0)!.toUpperCase())
              .toSet()
              .toList();

          // Priorizamos prefijos de países conocidos para fondos/ETFs
          for (var prefix in ['LU', 'IE', 'ES', 'FR', 'DE', 'GB', 'US', 'CH']) {
            final best = candidates.where((c) => c.startsWith(prefix)).toList();
            if (best.isNotEmpty) return best.first;
          }

          // Si no hay de países prioritarios, devolvemos el primero que parezca válido
          return candidates.first;
        }
      }
    } catch (_) {}

    // 3. Intentar nivel 3: Emparejamiento por nombre en catálogo local (CNMV)
    try {
      final catalog = await _loadFundCatalog();
      final isins = _findCatalogIsins(catalog, name);
      if (isins.isNotEmpty) return isins.first;
    } catch (_) {}

    return null;
  }
}
