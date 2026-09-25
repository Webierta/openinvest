import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:investing/utils/isin_validator.dart';

import '../../models/foreign_isin_provider.dart';
import '../isin_resolver.dart';
import '../../utils/http_config.dart';
//import '../../models/foreign_isin_provider.dart';
import '../local_isin_provider.dart';
import 'isin_source_provider.dart';

class YahooProvider implements IsinSourceProvider {
  final http.Client _client;
  final List<ForeignIsinProvider> _foreignIsinProviders;

  static const String _yahooSearchUrl =
      'https://query1.finance.yahoo.com/v1/finance/search?q=';

  YahooProvider({
    http.Client? client,
    List<ForeignIsinProvider>? foreignIsinProviders,
  }) : _client = client ?? http.Client(),
       _foreignIsinProviders =
           foreignIsinProviders ??
           [
             LocalIsinProvider(),
             MorningstarLtForeignIsinProvider(client: client ?? http.Client()),
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
      //if (yahooIsin != null && _isIsin(yahooIsin)) {
      if (yahooIsin != null && IsinValidator.isValid(yahooIsin)) {
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
          if (symbol == null || symbol.isEmpty) continue;

          final yahooIsin = item['isin']?.toString().trim().toUpperCase();

          final incoming = _YahooResult(
            symbol: symbol,
            name:
                item['longname']?.toString() ??
                item['shortname']?.toString() ??
                '',
            exchange: item['exchange']?.toString() ?? '',
            type: item['quoteType']?.toString() ?? '',
            isin: yahooIsin != null && IsinValidator.isValid(yahooIsin)
                ? yahooIsin
                : null,
          );

          final existing = results[symbol];

          if (existing == null) {
            results[symbol] = incoming;
          } else {
            results[symbol] = _mergeYahooResult(existing, incoming, fundName);
          }
        }
      } catch (_) {}
    }

    return results.values.toList();
  }

  _YahooResult _mergeYahooResult(
    _YahooResult existing,
    _YahooResult incoming,
    String fundName,
  ) {
    final name = _chooseBestName(existing.name, incoming.name, fundName);

    final exchange = existing.exchange.trim().isNotEmpty
        ? existing.exchange
        : incoming.exchange;

    final type = _chooseBestType(existing.type, incoming.type);

    final existingIsin = existing.isin;
    final incomingIsin = incoming.isin;

    String? isin;

    if (existingIsin == null) {
      isin = incomingIsin;
    } else if (incomingIsin == null) {
      isin = existingIsin;
    } else if (existingIsin == incomingIsin) {
      isin = existingIsin;
    } else {
      // Hay dos ISIN distintos para el mismo symbol.
      // No elegimos arbitrariamente ninguno.
      isin = null;
    }

    return _YahooResult(
      symbol: existing.symbol,
      name: name,
      exchange: exchange,
      type: type,
      isin: isin,
    );
  }

  String _chooseBestName(String existing, String incoming, String fundName) {
    if (existing.trim().isEmpty) return incoming;
    if (incoming.trim().isEmpty) return existing;

    final existingSimilarity = _nameSimilarity(fundName, existing);

    final incomingSimilarity = _nameSimilarity(fundName, incoming);

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

    final scored =
        results
            .map((result) {
              final symbol = result.symbol.toUpperCase();
              final type = result.type.toUpperCase();
              final nameSimilarity = _nameSimilarity(fundName, result.name);
              var score = nameSimilarity * 0.55;

              if (symbol == normalizedTicker) score += 0.20;
              if (symbol.startsWith(normalizedTicker)) score += 0.05;

              if (type == 'MUTUALFUND') {
                score += 0.30;
              } else if (type == 'ETF') {
                score -= 0.20;
              } else if (type == 'EQUITY' || type == 'INDEX') {
                score -= 0.30;
              }

              if (_sameMorningstarId(symbol, normalizedTicker)) score += 0.10;
              if (result.isin != null) score += 0.10;

              return (result: result, score: score);
            })
            .where((item) => item.score >= 0.50)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    return scored.map((item) => item.result).toList();
  }

  bool _sameMorningstarId(String a, String b) {
    String normalize(String value) {
      final match = RegExp(r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$')
          .firstMatch(value.trim().toUpperCase());
      return match?.group(1) ?? value.trim().toUpperCase();
    }

    return normalize(a) == normalize(b);
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

  /* bool _isIsin(String value) {
    final normalized = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}\d$').hasMatch(normalized)) {
      return false;
    }
    return _isValidIsinChecksum(normalized);
  } */

  /* bool _isValidIsinChecksum(String isin) {
    final value = isin.toUpperCase();
    final digits = <int>[];

    for (final char in value.split('')) {
      if (RegExp(r'[A-Z]').hasMatch(char)) {
        final n = char.codeUnitAt(0) - 55;
        digits.add(n ~/ 10);
        digits.add(n % 10);
      } else {
        digits.add(int.parse(char));
      }
    }

    var sum = 0;
    final parity = digits.length % 2;

    for (var i = 0; i < digits.length; i++) {
      var digit = digits[i];
      if (i % 2 == parity) {
        digit *= 2;
        if (digit > 9) digit = digit ~/ 10 + digit % 10;
      }
      sum += digit;
    }

    return sum % 10 == 0;
  } */

  double _nameSimilarity(String a, String b) {
    final aa = _normalizeName(a);
    final bb = _normalizeName(b);
    if (aa.isEmpty || bb.isEmpty) return 0.0;
    if (aa == bb) return 1.0;

    final ta = aa.split(' ').where((x) => x.isNotEmpty).toSet();
    final tb = bb.split(' ').where((x) => x.isNotEmpty).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0.0;

    return ta.intersection(tb).length / ta.union(tb).length;
  }

  String _normalizeName(String value) {
    var result = value.toUpperCase();
    const replacements = <String, String>{
      'Á': 'A',
      'À': 'A',
      'Ä': 'A',
      'Â': 'A',
      'É': 'E',
      'È': 'E',
      'Ë': 'E',
      'Ê': 'E',
      'Í': 'I',
      'Ì': 'I',
      'Ï': 'I',
      'Î': 'I',
      'Ó': 'O',
      'Ò': 'O',
      'Ö': 'O',
      'Ô': 'O',
      'Ú': 'U',
      'Ù': 'U',
      'Ü': 'U',
      'Û': 'U',
      'Ñ': 'N',
      '&': ' ',
      '-': ' ',
      '_': ' ',
      '/': ' ',
      ',': ' ',
      '.': ' ',
      ':': ' ',
      ';': ' ',
      '(': ' ',
      ')': ' ',
    };
    replacements.forEach((from, to) => result = result.replaceAll(from, to));
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _YahooResult {
  final String symbol;
  final String name;
  final String exchange;
  final String type;
  final String? isin;

  const _YahooResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
    this.isin,
  });
}
