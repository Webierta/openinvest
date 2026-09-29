import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:investing/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_providers/yahoo_provider.dart';

class TrackingForeignProvider implements ForeignIsinProvider {
  final List<String> seenSymbols;
  final List<String> seenNames;

  TrackingForeignProvider({required this.seenSymbols, List<String>? seenNames})
    : seenNames = seenNames ?? <String>[];

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    seenSymbols.add(yahooSymbol);
    seenNames.add(yahooName);
    return null;
  }
}

class FakeYahooClient extends http.BaseClient {
  final Map<String, List<Quote>> responses;
  final Map<String, int> queryCount = {};

  FakeYahooClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final query = request.url.queryParameters['q'] ?? '';
    queryCount[query] = (queryCount[query] ?? 0) + 1;

    final body = jsonEncode({
      'quotes': (responses[query] ?? const <Quote>[])
          .map((q) => q.toJson())
          .toList(),
    });

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class Quote {
  final String symbol;
  final String longname;
  final String quoteType;
  final String? isin;

  const Quote({
    required this.symbol,
    this.longname = '',
    required this.quoteType,
    this.isin,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'longname': longname,
    'quoteType': quoteType,
    if (isin != null) 'isin': isin,
  };
}

class FailFirstYahooClient extends http.BaseClient {
  final String failingQuery;
  final Map<String, List<Quote>> responses;
  final Map<String, int> queryCount = {};

  FailFirstYahooClient({required this.failingQuery, required this.responses});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final query = request.url.queryParameters['q'] ?? '';
    queryCount[query] = (queryCount[query] ?? 0) + 1;

    if (query == failingQuery) {
      throw Exception('HTTP error for query: $query');
    }

    final body = jsonEncode({
      'quotes': (responses[query] ?? const <Quote>[])
          .map((q) => q.toJson())
          .toList(),
    });

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class RawYahooClient extends http.BaseClient {
  final Map<String, dynamic> responses;
  final Map<String, int> queryCount = {};

  RawYahooClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final query = request.url.queryParameters['q'] ?? '';
    queryCount[query] = (queryCount[query] ?? 0) + 1;

    final body = jsonEncode(responses[query] ?? {'quotes': []});

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class FakeForeignProvider implements ForeignIsinProvider {
  final Map<String, String> bySymbol;
  final List<Map<String, String>> calls = [];

  FakeForeignProvider({this.bySymbol = const {}});

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    calls.add({
      'ticker': ticker,
      'fundName': fundName,
      'yahooSymbol': yahooSymbol,
      'yahooName': yahooName,
    });

    return bySymbol[yahooSymbol];
  }
}

class NullForeignProvider implements ForeignIsinProvider {
  const NullForeignProvider();

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async => null;
}

/* YahooProvider provider({
  required http.Client client,
  List<ForeignIsinProvider>? foreign,
}) {
  return YahooProvider(
    client: client,
    foreignIsinProviders: foreign ?? const [NullForeignProvider()],
  );
} */

YahooProvider createYahooProvider({
  required http.Client client,
  List<ForeignIsinProvider>? foreign,
}) {
  return YahooProvider(
    client: client,
    foreignIsinProviders: foreign ?? const [NullForeignProvider()],
  );
}

void expectIsin(dynamic result, String expected, String label) {
  expect(result, isNotNull, reason: '$label: resultado null');
  expect(result.isin, expected, reason: '$label: ISIN inesperado');
}
