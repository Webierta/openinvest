import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:investing/utils/isin_validator.dart';

import '../../models/foreign_isin_provider.dart';
import '../../utils/fund_name_matcher.dart';
import '../isin_resolver.dart';
import '../../utils/http_config.dart';
import '../local_isin_provider.dart';
import 'isin_source_provider.dart';

class YahooProvider implements IsinSourceProvider {
  final http.Client _client;
  final List<ForeignIsinProvider> _foreignIsinProviders;

  static const String _yahooSearchUrl =
      'https://query1.finance.yahoo.com/v1/finance/search?q=';

  factory YahooProvider({
    http.Client? client,
    List<ForeignIsinProvider>? foreignIsinProviders,
  }) {
    final sharedClient = client ?? http.Client();

    return YahooProvider._(
      client: sharedClient,
      foreignIsinProviders: foreignIsinProviders,
    );
  }

  YahooProvider._({
    required http.Client client,
    List<ForeignIsinProvider>? foreignIsinProviders,
  }) : _client = client,
       _foreignIsinProviders =
           foreignIsinProviders ??
           [
             LocalIsinProvider(),
             MorningstarLtForeignIsinProvider(client: client),
           ];

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    final results = await _searchYahoo(ticker: ticker, fundName: fundName);
    if (results.isEmpty) return null;

    final rankedResults = _rankYahooResults(results, ticker, fundName);

    for (final yahooMatch in rankedResults) {
      final yahooIsin = yahooMatch.isin;
      if (yahooIsin != null &&
          IsinValidator.isValid(yahooIsin) &&
          yahooMatch.type.toUpperCase() == 'MUTUALFUND') {
        return IsinResult(
          isin: yahooIsin,
          source: 'Yahoo',
          officialName: yahooMatch.name,
        );
      }

      final isin = await _resolveForeignIsin(
        yahooResult: yahooMatch,
        fundName: fundName,
        ticker: ticker,
      );

      if (isin != null) {
        return IsinResult(
          isin: isin,
          source: 'Yahoo/Foreign',
          officialName: yahooMatch.name,
        );
      }
    }

    return null;
  }

  String _normalizeYahooSymbol(String symbol) {
    var normalized = symbol.trim().toUpperCase();

    final morningstarMatch = RegExp(r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$')
        .firstMatch(normalized);

    if (morningstarMatch != null) {
      return morningstarMatch.group(1)!;
    }

    return normalized;
  }

  Future<List<_YahooResult>> _searchYahoo({
    required String ticker,
    required String fundName,
  }) async {
    final results = <String, _YahooResult>{};

    for (final query in <String>[ticker, fundName]) {
      try {
        final uri = Uri.parse(_yahooSearchUrl).replace(
          queryParameters: {
            'q': query,
            'quotesCount': '20',
            'newsCount': '0',
            'enableFuzzyQuery': 'false',
          },
        );

        final response = await _client
            .get(
              uri,
              headers: const {
                'Accept': 'application/json',
                'User-Agent': 'OpenInvest/1.0',
              },
            )
            .timeout(HttpConfig.timeout);

        if (response.statusCode != 200) continue;

        final json = jsonDecode(response.body);
        if (json is! Map<String, dynamic>) continue;

        final quotes = json['quotes'];
        if (quotes is! List) continue;

        for (final item in quotes) {
          if (item is! Map) continue;

          final symbol = item['symbol']?.toString();
          if (symbol == null || symbol.trim().isEmpty) continue;

          final mergeKey = _normalizeYahooSymbol(symbol);

          final type = item['quoteType']?.toString() ?? '';

          final yahooIsin = item['isin']?.toString().trim().toUpperCase();

          final validIsin =
              type.toUpperCase() == 'MUTUALFUND' &&
                  yahooIsin != null &&
                  IsinValidator.isValid(yahooIsin)
              ? yahooIsin
              : null;

          final incoming = _YahooResult(
            symbol: symbol,
            name:
                item['longname']?.toString() ??
                item['shortname']?.toString() ??
                '',
            exchange: item['exchange']?.toString() ?? '',
            type: type,
            isins: validIsin != null ? {validIsin} : const <String>{},
          );

          final existing = results[mergeKey];

          if (existing == null) {
            results[mergeKey] = incoming;
          } else {
            results[mergeKey] = _mergeYahooResult(
              existing,
              incoming,
              ticker,
              fundName,
            );
          }
        }
      } catch (_) {}
    }

    return results.values.toList();
  }

  String _chooseBestSymbol(String existing, String incoming, String ticker) {
    final normalizedTicker = ticker.trim();

    final existingTrimmed = existing.trim();
    final incomingTrimmed = incoming.trim();

    // 1. Coincidencia textual exacta con el ticker.
    if (existingTrimmed == normalizedTicker) {
      return existing;
    }

    if (incomingTrimmed == normalizedTicker) {
      return incoming;
    }

    // 2. Si no hay coincidencia textual exacta, respetamos el orden
    //    original incluso si coinciden ignorando mayúsculas/minúsculas.
    return existing;
  }

  _YahooResult _mergeYahooResult(
    _YahooResult existing,
    _YahooResult incoming,
    String ticker,
    String fundName,
  ) {
    final name = _chooseBestName(existing.name, incoming.name, fundName);

    final exchange = existing.exchange.trim().isNotEmpty
        ? existing.exchange
        : incoming.exchange;

    final type = _chooseBestType(existing.type, incoming.type);

    final isins = <String>{...existing.isins, ...incoming.isins};

    return _YahooResult(
      //symbol: existing.symbol,
      symbol: _chooseBestSymbol(existing.symbol, incoming.symbol, ticker),
      name: name,
      exchange: exchange,
      type: type,
      isins: isins,
    );
  }

  String _chooseBestName(String existing, String incoming, String fundName) {
    if (existing.trim().isEmpty) return incoming;
    if (incoming.trim().isEmpty) return existing;

    final existingSimilarity = FundNameMatcher.nameSimilarity(
      fundName,
      existing,
    );
    final incomingSimilarity = FundNameMatcher.nameSimilarity(
      fundName,
      incoming,
    );

    if (incomingSimilarity > existingSimilarity) {
      return incoming;
    }

    return existing;
  }

  String _chooseBestType(String existing, String incoming) {
    final existingType = existing.trim().toUpperCase();
    final incomingType = incoming.trim().toUpperCase();

    if (existingType.isEmpty) return incoming;
    if (incomingType.isEmpty) return existing;

    if (existingType == incomingType) {
      return existing;
    }

    if (existingType == 'MUTUALFUND') {
      return existing;
    }

    if (incomingType == 'MUTUALFUND') {
      return incoming;
    }

    return existing;
  }

  List<_YahooResult> _rankYahooResults(
    List<_YahooResult> results,
    String ticker,
    String fundName,
  ) {
    final normalizedTicker = ticker.toUpperCase();

    final scored = <({_YahooResult result, double score, double similarity})>[];

    for (final result in results) {
      final symbol = result.symbol.toUpperCase();
      final type = result.type.toUpperCase();

      final nameSimilarity = FundNameMatcher.nameSimilarity(
        fundName,
        result.name,
      );

      // ------------------------------------------------------------------
      // 1. BARRERA DE TIPO
      //
      // ETF, EQUITY e INDEX no son candidatos válidos para resolver
      // un fondo de inversión mediante este flujo.
      // ------------------------------------------------------------------
      if (type == 'ETF' || type == 'EQUITY' || type == 'INDEX') {
        continue;
      }

      // ------------------------------------------------------------------
      // 2. IDENTIDAD FUERTE
      //
      // Hay identidad fuerte cuando:
      //   - el symbol coincide exactamente con el ticker solicitado, o
      //   - ambos symbols corresponden al mismo Morningstar ID.
      // ------------------------------------------------------------------
      final exactTicker = symbol == normalizedTicker;
      final sameMorningstar = _sameMorningstarId(symbol, normalizedTicker);

      final strongIdentity = exactTicker || sameMorningstar;

      // ------------------------------------------------------------------
      // 3. BARRERA DE IDENTIDAD
      //
      // Sin similitud de nombre no aceptamos el candidato, aunque tenga
      // MUTUALFUND o ISIN.
      //
      // Con identidad fuerte permitimos una similitud mínima de 0.20.
      //
      // Sin identidad fuerte exigimos al menos 0.50.
      // ------------------------------------------------------------------
      if (nameSimilarity <= 0.0) {
        continue;
      }

      if (strongIdentity) {
        if (nameSimilarity < 0.20) {
          continue;
        }
      } else {
        if (nameSimilarity < 0.50) {
          continue;
        }
      }

      // ------------------------------------------------------------------
      // 4. RANKING
      //
      // A partir de aquí conservamos el sistema de puntuación existente.
      // La barrera anterior decide QUIÉN puede competir.
      // El score decide QUIÉN gana entre los candidatos elegibles.
      // ------------------------------------------------------------------
      var score = nameSimilarity * 0.55;

      if (symbol == normalizedTicker) {
        score += 0.20;
      }

      if (symbol.startsWith(normalizedTicker)) {
        score += 0.05;
      }

      if (type == 'MUTUALFUND') {
        score += 0.30;
      }

      if (sameMorningstar) {
        score += 0.10;
      }

      if (result.isin != null) {
        score += 0.10;
      }

      // ------------------------------------------------------------------
      // 5. UMBRAL FINAL DE SCORE
      //
      // Se mantiene el umbral existente de 0.50.
      // ------------------------------------------------------------------
      if (score < 0.50) {
        continue;
      }

      scored.add((result: result, score: score, similarity: nameSimilarity));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((item) => item.result).toList();
  }

  bool _sameMorningstarId(String a, String b) {
    String? extractMorningstarId(String value) {
      final match = RegExp(
        r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$',
        caseSensitive: false,
      ).firstMatch(value.trim());
      return match?.group(1)?.toUpperCase();
    }

    final idA = extractMorningstarId(a);
    final idB = extractMorningstarId(b);
    // Si alguno de los dos símbolos no es un ID Morningstar,
    // no existe coincidencia Morningstar.
    if (idA == null || idB == null) {
      return false;
    }
    return idA == idB;
  }

  Future<String?> _resolveForeignIsin({
    required _YahooResult yahooResult,
    required String fundName,
    required String ticker,
  }) async {
    for (final provider in _foreignIsinProviders) {
      try {
        final isin = await provider.resolve(
          ticker: ticker,
          fundName: fundName,
          yahooSymbol: yahooResult.symbol,
          yahooName: yahooResult.name,
        );

        if (isin == null) continue;
        final normalized = isin.trim().toUpperCase();
        if (IsinValidator.isValid(normalized)) return normalized;
      } catch (_) {}
    }

    return null;
  }
}

class _YahooResult {
  final String symbol;
  final String name;
  final String exchange;
  final String type;
  final Set<String> isins;

  _YahooResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
    Set<String>? isins,
  }) : isins = Set.unmodifiable(isins ?? const <String>{});

  /// ISIN usable únicamente cuando existe uno solo y no hay conflicto.
  String? get isin => isins.length == 1 ? isins.first : null;
}
