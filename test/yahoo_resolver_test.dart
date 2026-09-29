import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_providers/yahoo_provider.dart';
import 'package:investing/services/isin_resolver.dart';

/* class _TrackingForeignProvider implements ForeignIsinProvider {
  final List<String> seenSymbols;

  _TrackingForeignProvider({required this.seenSymbols});

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    seenSymbols.add(yahooSymbol);
    return null;
  }
} */

class _TrackingForeignProvider implements ForeignIsinProvider {
  final List<String> seenSymbols;
  final List<String> seenNames;

  _TrackingForeignProvider({required this.seenSymbols, List<String>? seenNames})
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

class _FakeYahooClient extends http.BaseClient {
  final Map<String, List<_Quote>> responses;
  final Map<String, int> queryCount = {};

  _FakeYahooClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final query = request.url.queryParameters['q'] ?? '';
    queryCount[query] = (queryCount[query] ?? 0) + 1;

    final body = jsonEncode({
      'quotes': (responses[query] ?? const <_Quote>[])
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

class _Quote {
  final String symbol;
  final String longname;
  //final String? shortname;
  //final String exchange;
  final String quoteType;
  final String? isin;

  const _Quote({
    required this.symbol,
    this.longname = '',
    //this.shortname,
    //this.exchange = 'XPAR',
    required this.quoteType,
    this.isin,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'longname': longname,
    //if (shortname != null) 'shortname': shortname,
    //'exchange': exchange,
    'quoteType': quoteType,
    if (isin != null) 'isin': isin,
  };
}

class _FailFirstYahooClient extends http.BaseClient {
  final String failingQuery;
  final Map<String, List<_Quote>> responses;
  final Map<String, int> queryCount = {};

  _FailFirstYahooClient({required this.failingQuery, required this.responses});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final query = request.url.queryParameters['q'] ?? '';
    queryCount[query] = (queryCount[query] ?? 0) + 1;

    if (query == failingQuery) {
      throw Exception('HTTP error for query: $query');
    }

    final body = jsonEncode({
      'quotes': (responses[query] ?? const <_Quote>[])
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

class _RawYahooClient extends http.BaseClient {
  final Map<String, dynamic> responses;
  final Map<String, int> queryCount = {};

  _RawYahooClient(this.responses);

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

class _FakeForeignProvider implements ForeignIsinProvider {
  final Map<String, String> bySymbol;
  final List<Map<String, String>> calls = [];

  _FakeForeignProvider({this.bySymbol = const {}});

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

class _NullForeignProvider implements ForeignIsinProvider {
  const _NullForeignProvider();

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async => null;
}

YahooProvider _provider({
  required http.Client client,
  List<ForeignIsinProvider>? foreign,
}) {
  return YahooProvider(
    client: client,
    foreignIsinProviders: foreign ?? const [_NullForeignProvider()],
  );
}

void _expectIsin(dynamic result, String expected, String label) {
  expect(result, isNotNull, reason: '$label: resultado null');
  expect(result.isin, expected, reason: '$label: ISIN inesperado');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Yahoo Resolver Tests', () {
    test('ISIN directo desde Yahoo', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": [{"symbol": "CANC.PA", "longname": "Carmignac Court Terme", "quoteType": "MUTUALFUND", "isin": "FR0000993172"}]}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(
        ticker: 'CANC.PA',
        fundName: 'Carmignac Court Terme',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test('ticker inexistente devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(
        ticker: 'FAKE.SYMBOL',
        fundName: 'Nonexistent Fund',
      );

      expect(result, isNull);
    });

    test('sin ISIN ni proveedor foreign devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": [{"symbol": "TEST.PA", "longname": "Test Fund", "quoteType": "MUTUALFUND"}]}',
          200,
        );
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );
      final result = await resolver.resolve(
        ticker: 'TEST.PA',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test(
      'múltiples candidatos y preferencia MUTUALFUND vs ETF y ticker exacto',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('''
          {
            "quotes": [
              {"symbol": "MYFUND.PA", "longname": "My Fund ETF", "quoteType": "ETF"},
              {"symbol": "MYFUND.PA", "longname": "My Fund", "quoteType": "MUTUALFUND", "isin": "FR0010135103"},
              {"symbol": "OTHER.PA", "longname": "Other Fund", "quoteType": "MUTUALFUND", "isin": "FR0000993172"}
            ]
          }
          ''', 200);
        });

        final resolver = IsinResolver(client: mockClient);
        final result = await resolver.resolve(
          ticker: 'MYFUND.PA',
          fundName: 'My Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0010135103');
      },
    );

    test('M1. Mismo symbol + mismo ISIN en ambas búsquedas', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        if (query == 'Test Fund') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test(
      'M2. Mismo symbol: búsqueda ticker con ISIN + nombre sin ISIN',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND"'
              '}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(client: mockClient);

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test(
      'M3. Mismo symbol: búsqueda ticker sin ISIN + nombre con ISIN',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND"'
              '}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(client: mockClient);

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test(
      'M4. Mismo symbol con dos ISIN diferentes: debe producir conflicto',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(client: mockClient);

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
      },
    );

    test(
      'M5. Mismo symbol con nombres diferentes: conserva el más similar',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Completely Different Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
        expect(result.officialName, 'Test Fund');
      },
    );

    test(
      'M6. Mismo symbol: MUTUALFUND prevalece sobre otro quoteType',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "ETF", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test(
      'M7. Mismo symbol: exchange vacío se completa con la segunda respuesta',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"exchange": "", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"exchange": "PAR", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test(
      'M8. Mismo symbol repetido con el mismo ISIN: no crea conflicto',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response('{"quotes": []}', 200);
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test(
      'M9. Symbol con distinta capitalización se fusiona y detecta conflicto',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "test", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
      },
    );
    test(
      'M10. Tres resultados con el mismo symbol se fusionan acumulativamente',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"exchange": "", '
              '"quoteType": "ETF"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"exchange": "PAR", '
              '"quoteType": "MUTUALFUND"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"exchange": "PAR", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response('{"quotes": []}', 200);
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test('M11. Tres resultados con el mismo symbol y el mismo ISIN', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"},'
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"},'
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        if (query == 'Test Fund') {
          return http.Response('{"quotes": []}', 200);
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test(
      'M12. Tres resultados con el mismo symbol y tres ISIN diferentes',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0129445192"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response('{"quotes": []}', 200);
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
      },
    );

    test(
      'M13. Nombre vacío seguido de nombre válido conserva el nombre válido',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "", '
              '"shortname": "", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response('{"quotes": []}', 200);
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.officialName, 'Test Fund');
      },
    );

    test(
      'M14. MUTUALFUND no se degrada al fusionar posteriormente un ETF',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "ETF", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response('{"quotes": []}', 200);
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test(
      'M15. ETF + EQUITY + MUTUALFUND: MUTUALFUND prevalece al final',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "ETF"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "EQUITY"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response('{"quotes": []}', 200);
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test(
      'M19. Mismo symbol: MUTUALFUND + MUTUALFUND con el mismo ISIN',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000993172',
            ),
          ],
          'Test Fund': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000993172',
            ),
          ],
        });

        final provider = _provider(client: client);

        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        _expectIsin(result, 'FR0000993172', 'M19');
        expect(result?.source, 'Yahoo');
        expect(result?.officialName, 'Test Fund');

        debugPrint('[M19] MUTUALFUND + MUTUALFUND + mismo ISIN -> OK');
      },
    );

    test(
      'M20. Mismo symbol: ETF aporta ISIN y MUTUALFUND no aporta ISIN',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'ETF',
              isin: 'FR0000993172',
            ),
          ],
          'Test Fund': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
        });

        final provider = _provider(client: client);

        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);

        debugPrint('[M20] ISIN solo del ETF ignorado -> OK');
      },
    );

    test(
      'M21. Mismo symbol: MUTUALFUND aporta ISIN y ETF no aporta ISIN',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'ETF',
              isin: null,
            ),
          ],
          'Test Fund': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000993172',
            ),
          ],
        });

        final provider = _provider(client: client);

        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        _expectIsin(result, 'FR0000993172', 'M21');
        expect(result?.source, 'Yahoo');
        expect(result?.officialName, 'Test Fund');

        debugPrint('[M21] ISIN solo del MUTUALFUND + ETF -> OK');
      },
    );

    test('M22. Mismo symbol: ETF y MUTUALFUND aportan el mismo ISIN', () async {
      final client = _FakeYahooClient({
        'TEST': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'ETF',
            isin: 'FR0000993172',
          ),
        ],
        'Test Fund': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
      });

      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      _expectIsin(result, 'FR0000993172', 'M22');
      expect(result?.source, 'Yahoo');
      expect(result?.officialName, 'Test Fund');

      debugPrint('[M22] ETF + MUTUALFUND + mismo ISIN -> OK');
    });

    test(
      'M23. Mismo symbol: dos MUTUALFUND con ISIN diferentes generan conflicto',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000993172',
            ),
          ],
          'Test Fund': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'IE00B4L5Y983',
            ),
          ],
        });

        final provider = _provider(client: client);

        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);

        debugPrint('[M23] dos ISIN válidos distintos -> conflicto -> null');
      },
    );

    test('M24. Mismo symbol: ISIN de ETF se ignora aunque MUTUALFUND aporte otro ISIN', () async {
      final client = _FakeYahooClient({
        'TEST': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'ETF',
            isin: 'LU0123456789',
          ),
        ],
        'Test Fund': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
      });

      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      _expectIsin(result, 'FR0000993172', 'M24');
      expect(result?.source, 'Yahoo');

      debugPrint('[M24] ISIN ETF ignorado + ISIN MF aceptado -> OK');
    });

    test(
      'M25. Conflicto de ISIN Yahoo permite continuar con proveedor extranjero',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000993172',
            ),
          ],
          'Test Fund': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'IE00B4L5Y983',
            ),
          ],
        });

        final seenSymbols = <String>[];

        final foreignProvider = _TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final provider = _provider(client: client, foreign: [foreignProvider]);

        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
        expect(seenSymbols, contains('TEST'));

        debugPrint(
          '[M25] conflicto Yahoo -> proveedor extranjero consultado -> OK',
        );
      },
    );

    test('M26. Mismo symbol: varias apariciones del mismo ISIN no generan conflicto', () async {
      final client = _FakeYahooClient({
        'TEST': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
          const _Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
        'Test Fund': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
      });

      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      _expectIsin(result, 'FR0000993172', 'M26');
      expect(result?.source, 'Yahoo');

      debugPrint('[M26] ISIN repetido -> una sola evidencia -> OK');
    });

    test(
      'M27. Mismo mergeKey: symbol exacto del ticker tiene prioridad',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'test',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'Test Fund': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
        });

        final seenSymbols = <String>[];

        final provider = _provider(
          client: client,
          foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
        );

        await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

        expect(seenSymbols, contains('TEST'));

        debugPrint('[M27] symbol exacto del ticker -> TEST -> OK');
      },
    );

    /* test(
      'M28. Mismo mergeKey: sin coincidencia exacta conserva existing',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'TEST.MC',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'Test Fund': [
            const _Quote(
              symbol: 'TEST.DE',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
        });

        final seenSymbols = <String>[];

        final provider = _provider(
          client: client,
          foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
        );

        await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

        expect(seenSymbols, contains('TEST.MC'));
        expect(seenSymbols, isNot(contains('TEST.DE')));

        debugPrint('[M28] ningún symbol exacto -> conserva existing -> OK');
      },
    ); */

    test('M28a. Mismo Morningstar ID sin sufijo se fusiona', () async {
      final client = _FakeYahooClient({
        '0P0000X83M': [
          const _Quote(
            symbol: '0P0000X83M',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'PIMCO GIS Income Fund': [
          const _Quote(
            symbol: '0P0000X83M',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final seenSymbols = <String>[];

      final provider = _provider(
        client: client,
        foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund',
      );

      expect(seenSymbols, ['0P0000X83M']);

      debugPrint(
        '[M28a] mismo Morningstar ID sin sufijo -> 1 resultado fusionado -> OK',
      );
    });

    test('M28b. Mismo Morningstar ID con .F se fusiona', () async {
      final client = _FakeYahooClient({
        '0P0000X83M': [
          const _Quote(
            symbol: '0P0000X83M',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'PIMCO GIS Income Fund': [
          const _Quote(
            symbol: '0P0000X83M.F',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final seenSymbols = <String>[];

      final provider = _provider(
        client: client,
        foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund',
      );

      expect(seenSymbols, ['0P0000X83M']);

      debugPrint('[M28b] 0P0000X83M + 0P0000X83M.F -> fusionado -> OK');
    });

    test(
      'M28c. Mismo Morningstar ID con sufijos diferentes se fusiona',
      () async {
        final client = _FakeYahooClient({
          '0P0000X83M': [
            const _Quote(
              symbol: '0P0000X83M.F',
              longname: 'PIMCO GIS Income Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'PIMCO GIS Income Fund': [
            const _Quote(
              symbol: '0P0000X83M.DE',
              longname: 'PIMCO GIS Income Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
        });

        final seenSymbols = <String>[];

        final provider = _provider(
          client: client,
          foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
        );

        await provider.resolve(
          ticker: '0P0000X83M',
          fundName: 'PIMCO GIS Income Fund',
        );

        expect(seenSymbols.length, 1);
        expect(seenSymbols.single, '0P0000X83M.F');

        debugPrint('[M28c] 0P0000X83M.F + 0P0000X83M.DE -> fusionado -> OK');
      },
    );

    test('M28d. Morningstar IDs diferentes no se fusionan', () async {
      final client = _FakeYahooClient({
        '0P0000X83M': [
          const _Quote(
            symbol: '0P0000X83M',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'PIMCO GIS Income Fund': [
          const _Quote(
            symbol: '0P0000X83N',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final seenSymbols = <String>[];

      final provider = _provider(
        client: client,
        foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund',
      );

      expect(seenSymbols.length, 2);
      expect(seenSymbols, containsAll(<String>['0P0000X83M', '0P0000X83N']));

      debugPrint('[M28d] Morningstar IDs diferentes -> 2 resultados -> OK');
    });

    test('M28e. Ticker normal con mercados diferentes no se fusiona', () async {
      final client = _FakeYahooClient({
        'TEST': [
          const _Quote(
            symbol: 'TEST.MC',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Test Fund': [
          const _Quote(
            symbol: 'TEST.DE',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final seenSymbols = <String>[];

      final provider = _provider(
        client: client,
        foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols.length, 2);
      expect(seenSymbols, containsAll(<String>['TEST.MC', 'TEST.DE']));

      debugPrint('[M28e] TEST.MC + TEST.DE -> no fusion -> OK');
    });

    test('M28f. Ticker normal y ticker base no se fusionan', () async {
      final client = _FakeYahooClient({
        'TEST': [
          const _Quote(
            symbol: 'TEST.MC',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Test Fund': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final seenSymbols = <String>[];

      final provider = _provider(
        client: client,
        foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols.length, 2);
      expect(seenSymbols, containsAll(<String>['TEST.MC', 'TEST']));

      debugPrint('[M28f] TEST.MC + TEST -> no fusion -> OK');
    });

    test(
      'M28g. Mismo ticker con diferente capitalización se fusiona',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'test',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'Test Fund': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
        });

        final seenSymbols = <String>[];

        final provider = _provider(
          client: client,
          foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
        );

        await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

        expect(seenSymbols, ['TEST']);

        debugPrint('[M28g] test + TEST -> mismo mergeKey -> fusionado -> OK');
      },
    );

    test(
      'M29. Mismo symbol: conserva el nombre más similar al fundName',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Alpha Income Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'Alpha Growth Fund': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
        });

        final seenNames = <String>[];

        final provider = _provider(
          client: client,
          foreign: [
            _TrackingForeignProvider(
              seenSymbols: <String>[],
              seenNames: seenNames,
            ),
          ],
        );

        await provider.resolve(ticker: 'TEST', fundName: 'Alpha Growth Fund');

        expect(seenNames, contains('Alpha Growth Fund'));
        expect(seenNames, isNot(contains('Alpha Income Fund')));

        debugPrint(
          '[M29] nombre más similar al fundName -> Alpha Growth Fund -> OK',
        );
      },
    );

    test('M30. Mismo symbol: empate de similitud conserva existing', () async {
      final client = _FakeYahooClient({
        'TEST': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Growth Alpha Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final seenNames = <String>[];

      final provider = _provider(
        client: client,
        foreign: [
          _TrackingForeignProvider(
            seenSymbols: <String>[],
            seenNames: seenNames,
          ),
        ],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Alpha Growth Fund');

      expect(seenNames, contains('Alpha Growth Fund'));
      expect(seenNames, isNot(contains('Growth Alpha Fund')));

      debugPrint('[M30] empate de similitud -> conserva existing -> OK');
    });

    test('M31. Mismo mergeKey: MUTUALFUND + ETF conserva MUTUALFUND', () async {
      final client = _FakeYahooClient({
        'TEST': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Test Fund': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'ETF',
            isin: null,
          ),
        ],
      });

      final seenSymbols = <String>[];

      final provider = _provider(
        client: client,
        foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols, ['TEST']);

      debugPrint('[M31] MUTUALFUND + ETF -> conserva MUTUALFUND -> OK');
    });

    test('M32. Mismo mergeKey: ETF + MUTUALFUND conserva MUTUALFUND', () async {
      final client = _FakeYahooClient({
        'TEST': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'ETF',
            isin: null,
          ),
        ],
        'Test Fund': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final seenSymbols = <String>[];

      final provider = _provider(
        client: client,
        foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols, ['TEST']);

      debugPrint('[M32] ETF + MUTUALFUND -> conserva MUTUALFUND -> OK');
    });

    test(
      'M33. Mismo mergeKey: nombres contradictorios conserva el más similar',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Alpha Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'Alpha Growth Fund': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
        });

        final seenSymbols = <String>[];
        final seenNames = <String>[];

        final provider = _provider(
          client: client,
          foreign: [
            _TrackingForeignProvider(
              seenSymbols: seenSymbols,
              seenNames: seenNames,
            ),
          ],
        );

        await provider.resolve(ticker: 'TEST', fundName: 'Alpha Growth Fund');

        expect(seenSymbols, ['TEST']);
        expect(seenNames, ['Alpha Growth Fund']);

        debugPrint(
          '[M33] nombres contradictorios -> conserva el más similar al fundName -> OK',
        );
      },
    );

    test('M34. Mismo mergeKey: ISIN real idéntico repetido no genera conflicto', () async {
      final client = _FakeYahooClient({
        'TEST': [
          const _Quote(
            symbol: 'TEST',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: 'IE00B8K7V925',
          ),
        ],
        'PIMCO GIS Income Fund': [
          const _Quote(
            symbol: 'TEST',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: 'IE00B8K7V925',
          ),
        ],
      });

      final seenSymbols = <String>[];

      final provider = _provider(
        client: client,
        foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      final result = await provider.resolve(
        ticker: 'TEST',
        fundName: 'PIMCO GIS Income Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'IE00B8K7V925');
      expect(seenSymbols, isEmpty);

      debugPrint(
        '[M34] ISIN real repetido -> una única evidencia -> Yahoo acepta -> OK',
      );
    });

    test(
      'M35. Mismo mergeKey: dos ISIN reales diferentes mantienen el conflicto',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'TEST',
              longname: 'PIMCO GIS Income Fund',
              quoteType: 'MUTUALFUND',
              isin: 'IE00B8K7V925',
            ),
          ],
          'PIMCO GIS Income Fund': [
            const _Quote(
              symbol: 'TEST',
              longname: 'PIMCO GIS Income Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0010135103',
            ),
          ],
        });

        final seenSymbols = <String>[];

        final provider = _provider(
          client: client,
          foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
        );

        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'PIMCO GIS Income Fund',
        );

        expect(result, isNull);
        expect(seenSymbols, ['TEST']);

        debugPrint(
          '[M35] dos ISIN reales diferentes -> conflicto -> proveedor extranjero -> OK',
        );
      },
    );

    test('N1. Symbol con distinta capitalización: TEST y test', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        if (query == 'Test Fund') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "test", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test('N2. Symbol con espacios: TEST y " TEST "', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        if (query == 'Test Fund') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": " TEST ", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test('N3. Morningstar ID base y con sufijo .F', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "IE00B8K7V925"}'
            ']}',
            200,
          );
        }

        if (query == 'PIMCO GIS Income Fund E Class USD Income') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M.F", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "IE00B8K7V925"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'IE00B8K7V925');
      expect(result.source, 'Yahoo');
    });

    test('N4. Morningstar ID con sufijo .F y base: orden inverso', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M.F') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M.F", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "IE00B8K7V925"}'
            ']}',
            200,
          );
        }

        if (query == 'PIMCO GIS Income Fund E Class USD Income') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "IE00B8K7V925"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M.F',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'IE00B8K7V925');
      expect(result.source, 'Yahoo');
    });

    test(
      'N5. Símbolos de mercados diferentes no se fusionan: TEST.PA y TEST.MC',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST.PA') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST.PA", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST.MC", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST.PA',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test('N6. Symbol con distinta capitalización y mismo mercado: TEST.PA y TEST.pa', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST.PA') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST.PA", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        if (query == 'Test Fund') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST.pa", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: 'TEST.PA',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test(
      'N7. Morningstar base y .F con ISIN diferentes: detecta si se fusionan',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == '0P0000X83M') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "0P0000X83M", '
              '"longname": "PIMCO GIS Income Fund E Class USD Income", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'PIMCO GIS Income Fund E Class USD Income') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "0P0000X83M.F", '
              '"longname": "PIMCO GIS Income Fund E Class USD Income", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: '0P0000X83M',
          fundName: 'PIMCO GIS Income Fund E Class USD Income',
        );

        // Si ambos symbols se normalizan al mismo identificador,
        // los dos ISIN entran en el mismo _YahooResult y hay conflicto.
        expect(result, isNull);
      },
    );

    test(
      'N8. TEST y test con ISIN diferentes: detecta si se fusionan',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "test", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        // Si TEST y test se consideran el mismo symbol,
        // los ISIN entran en conflicto.
        expect(result, isNull);
      },
    );

    test(
      'N9. TEST.PA y TEST.pa con ISIN diferentes: detecta si se fusionan',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST.PA') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST.PA", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST.pa", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST.PA',
          fundName: 'Test Fund',
        );

        // Si sólo cambia la capitalización, una normalización
        // case-insensitive debería detectar el conflicto.
        expect(result, isNull);
      },
    );

    test(
      'N10. TEST.PA y TEST.MC con ISIN diferentes: no deben fusionarse',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST.PA') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST.PA", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST.MC", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST.PA',
          fundName: 'Test Fund',
        );

        // PA y MC representan mercados diferentes y no deben
        // considerarse el mismo symbol durante la fusión.
        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test(
      'N11. Morningstar ID base y .F con el mismo ISIN deben fusionarse',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == '0P0000X83M') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "0P0000X83M", '
              '"longname": "PIMCO GIS Income Fund E Class USD Income", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "IE00B8K7V925"}'
              ']}',
              200,
            );
          }

          if (query == 'PIMCO GIS Income Fund E Class USD Income') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "0P0000X83M.F", '
              '"longname": "PIMCO GIS Income Fund E Class USD Income", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "IE00B8K7V925"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: '0P0000X83M',
          fundName: 'PIMCO GIS Income Fund E Class USD Income',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'IE00B8K7V925');
        expect(result.source, 'Yahoo');
      },
    );

    test('N12. Morningstar ID base y .F con ISIN diferentes deben generar conflicto', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        if (query == 'PIMCO GIS Income Fund E Class USD Income') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M.F", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "LU0261948904"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      expect(result, isNull);
    });

    test(
      'N13. Morningstar ID .F y .SG deben considerarse la misma identidad',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == '0P0000X83M.F') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "0P0000X83M.F", '
              '"longname": "PIMCO GIS Income Fund E Class USD Income", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "IE00B8K7V925"}'
              ']}',
              200,
            );
          }

          if (query == 'PIMCO GIS Income Fund E Class USD Income') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "0P0000X83M.SG", '
              '"longname": "PIMCO GIS Income Fund E Class USD Income", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: '0P0000X83M.F',
          fundName: 'PIMCO GIS Income Fund E Class USD Income',
        );

        expect(result, isNull);
      },
    );

    test('N14. Morningstar IDs diferentes no deben fusionarse', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "IE00B8K7V925"}'
            ']}',
            200,
          );
        }

        if (query == 'PIMCO GIS Income Fund E Class USD Income') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P00000FB4", '
            '"longname": "Carmignac Court Terme", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0010135103"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'IE00B8K7V925');
      expect(result.source, 'Yahoo');
    });

    // ===========================================================================
    // N15-N20 — NORMALIZACIÓN DE SYMBOL
    // ===========================================================================

    test('N15 - Morningstar ID con espacios y mayúsculas se fusiona', () async {
      final client = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': ' 0p0000x83m ',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'IE00B8K7V925',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(
          jsonEncode({
            'quotes': [
              {
                'symbol': '0P0000X83M.F',
                'longname': 'Test Fund',
                'exchange': 'FRA',
                'quoteType': 'MUTUALFUND',
                'isin': 'FR0010135103',
              },
            ],
          }),
          200,
        );
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: const [],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('N16 - dos suffixes Morningstar diferentes con ISIN distintos producen conflicto', () async {
      final client = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'IE00B8K7V925',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(
          jsonEncode({
            'quotes': [
              {
                'symbol': '0P0000X83M.SG',
                'longname': 'Test Fund',
                'exchange': 'SGX',
                'quoteType': 'MUTUALFUND',
                'isin': 'FR0010135103',
              },
            ],
          }),
          200,
        );
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: const [],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test(
      'N17 - symbol genérico con mayúsculas/minúsculas y espacios se fusiona',
      () async {
        final client = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': ' TEST ',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                    'isin': 'IE00B8K7V925',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'test',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'FR0010135103',
                },
              ],
            }),
            200,
          );
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: const [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
      },
    );

    test(
      'N18 - suffix de mercado se normaliza solo por mayúsculas/minúsculas',
      () async {
        final client = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST.PA') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': ' TEST.PA ',
                    'longname': 'Test Fund',
                    'exchange': 'PAR',
                    'quoteType': 'MUTUALFUND',
                    'isin': 'FR0010135103',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'test.pa',
                  'longname': 'Test Fund',
                  'exchange': 'PAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'IE00B8K7V925',
                },
              ],
            }),
            200,
          );
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: const [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST.PA',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
      },
    );

    test('N19 - diferentes mercados no se fusionan', () async {
      final client = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST.PA') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'TEST.PA',
                  'longname': 'Test Fund',
                  'exchange': 'PAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'FR0010135103',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(
          jsonEncode({
            'quotes': [
              {
                'symbol': 'TEST.MC',
                'longname': 'Test Fund',
                'exchange': 'MCE',
                'quoteType': 'MUTUALFUND',
                'isin': 'IE00B8K7V925',
              },
            ],
          }),
          200,
        );
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: const [],
      );

      final result = await resolver.resolve(
        ticker: 'TEST.PA',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0010135103');
    });

    test(
      'N20 - Morningstar ID con sufijo no alfabético no se fusiona',
      () async {
        final client = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == '0P0000X83M') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': '0P0000X83M.123',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                    'isin': 'IE00B8K7V925',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'FR0010135103',
                },
              ],
            }),
            200,
          );
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: const [],
        );

        final result = await resolver.resolve(
          ticker: '0P0000X83M',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0010135103');
      },
    );

    // ===========================================================================
    // O1-O6 — SYMBOL REPRESENTATIVO DESPUÉS DE LA FUSIÓN
    // ===========================================================================

    test(
      'O1 - Morningstar: el ticker exacto aparece después de una variante .F',
      () async {
        final seenSymbols = <String>[];

        final trackingProvider = _TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final client = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == '0P0000X83M') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': '0P0000X83M.F',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                  },
                  {
                    'symbol': '0P0000X83M',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [trackingProvider],
        );

        await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

        expect(seenSymbols, isNotEmpty);
        expect(seenSymbols.first, '0P0000X83M');
      },
    );

    test('O2 - Morningstar: el ticker exacto aparece primero y sigue siendo representativo', () async {
      final seenSymbols = <String>[];

      final trackingProvider = _TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, '0P0000X83M');
    });

    test(
      'O3 - Morningstar: con tres variantes se conserva el ticker exacto',
      () async {
        final seenSymbols = <String>[];

        final trackingProvider = _TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final client = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == '0P0000X83M') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': '0P0000X83M.SG',
                    'longname': 'Test Fund',
                    'exchange': 'SGX',
                    'quoteType': 'MUTUALFUND',
                  },
                  {
                    'symbol': '0P0000X83M.F',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                  },
                  {
                    'symbol': '0P0000X83M',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [trackingProvider],
        );

        await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

        expect(seenSymbols, isNotEmpty);
        expect(seenSymbols.first, '0P0000X83M');
      },
    );

    test('O4 - Morningstar: sin ticker exacto se conserva una variante de forma determinista', () async {
      final seenSymbols = <String>[];

      final trackingProvider = _TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.SG',
                  'longname': 'Test Fund',
                  'exchange': 'SGX',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, '0P0000X83M.SG');
    });

    test('O5 - symbol genérico: se conserva la variante que coincide exactamente con el ticker', () async {
      final seenSymbols = <String>[];

      final trackingProvider = _TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'test',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': 'TEST',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, 'TEST');
    });

    test(
      'O6 - mercado: TEST.PA y TEST.MC siguen siendo resultados independientes',
      () async {
        final seenSymbols = <String>[];

        final trackingProvider = _TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final client = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST.PA') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': 'TEST.MC',
                    'longname': 'Test Fund',
                    'exchange': 'MCE',
                    'quoteType': 'MUTUALFUND',
                  },
                  {
                    'symbol': 'TEST.PA',
                    'longname': 'Test Fund',
                    'exchange': 'PAR',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [trackingProvider],
        );

        await resolver.resolve(ticker: 'TEST.PA', fundName: 'Test Fund');

        expect(seenSymbols, isNotEmpty);
        expect(seenSymbols.first, 'TEST.PA');
      },
    );

    test(
      'R1. Identidad fuerte: ticker exacto permite similitud de nombre >= 0.20',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Alpha Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'Completely Different': const <_Quote>[],
        });

        final seenSymbols = <String>[];

        final provider = _provider(
          client: client,
          foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
        );

        await provider.resolve(ticker: 'TEST', fundName: 'Alpha Fund');

        expect(seenSymbols, ['TEST']);

        debugPrint(
          '[R1] ticker exacto + identidad fuerte + similitud suficiente -> OK',
        );
      },
    );

    test(
      'R2. Identidad fuerte: similitud de nombre cero descarta el candidato',
      () async {
        final client = _FakeYahooClient({
          'TEST': [
            const _Quote(
              symbol: 'TEST',
              longname: 'Completely Different',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'Unrelated Fund': const <_Quote>[],
        });
        final seenSymbols = <String>[];
        final provider = _provider(
          client: client,
          foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
        );
        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'Unrelated Fund',
        );
        expect(result, isNull);
        expect(seenSymbols, isEmpty);
        debugPrint(
          '[R2] ticker exacto pero nombre sin similitud -> descartado -> OK',
        );
      },
    );

    test('R3. Sin identidad fuerte: similitud inferior a 0.50 descarta el candidato', () async {
      final client = _FakeYahooClient({
        'OTHER': [
          const _Quote(
            symbol: 'OTHER',
            longname: 'Alpha Beta Gamma',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': const <_Quote>[],
      });

      final seenSymbols = <String>[];

      final provider = _provider(
        client: client,
        foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      final result = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);
      expect(seenSymbols, isEmpty);

      debugPrint(
        '[R3] sin identidad fuerte + similitud < 0.50 -> descartado -> OK',
      );
    });

    test('R4. Sin identidad fuerte: similitud >= 0.50 permite competir', () async {
      final client = _FakeYahooClient({
        'TEST': const <_Quote>[],
        'Alpha Growth Fund': [
          const _Quote(
            symbol: 'OTHER',
            longname: 'Alpha Growth',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });
      final seenSymbols = <String>[];
      final seenNames = <String>[];
      final provider = YahooProvider(
        client: client,
        foreignIsinProviders: [
          _TrackingForeignProvider(
            seenSymbols: seenSymbols,
            seenNames: seenNames,
          ),
        ],
      );
      final result = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Alpha Growth Fund',
      );
      expect(result, isNull);
      expect(seenSymbols, ['OTHER']);
      expect(seenNames, ['Alpha Growth']);
      debugPrint(
        '[R4] candidato sin identidad fuerte pero con similitud >= 0.50 -> OK',
      );
    });

    test('R5. Ticker exacto supera a candidato no exacto con nombre ligeramente mejor', () async {
      final client = _FakeYahooClient({
        'TEST': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
          const _Quote(
            symbol: 'OTHER',
            longname: 'Alpha Growth Fund International',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': const <_Quote>[],
      });

      final seenSymbols = <String>[];

      final provider = _provider(
        client: client,
        foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Alpha Growth Fund');

      expect(seenSymbols.first, 'TEST');

      debugPrint('[R5] ticker exacto obtiene prioridad en el ranking -> OK');
    });

    test('R6. Un nombre perfecto puede superar a un ticker exacto con similitud menor', () async {
      final client = _FakeYahooClient({
        'TEST': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Alpha Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
          const _Quote(
            symbol: 'OTHER',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': const <_Quote>[],
      });

      final seenSymbols = <String>[];

      final provider = _provider(
        client: client,
        foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Alpha Growth Fund');

      expect(seenSymbols.first, 'OTHER');

      debugPrint(
        '[R6] nombre perfecto puede superar ticker exacto con similitud baja -> OK',
      );
    });

    test('R7. ISIN aporta peso adicional al ranking', () async {
      final client = _FakeYahooClient({
        'TEST': [
          const _Quote(
            symbol: 'TEST',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
          const _Quote(
            symbol: 'OTHER',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
        'Alpha Growth Fund': const <_Quote>[],
      });

      final seenSymbols = <String>[];

      final provider = _provider(
        client: client,
        foreign: [_TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Alpha Growth Fund');

      expect(seenSymbols.first, 'OTHER');

      debugPrint('[R7] ISIN válido añade peso al ranking -> OK');
    });

    // ===========================================================================
    // S1-S10 — SELECCIÓN DEL SÍMBOLO REPRESENTATIVO DESPUÉS DE LA FUSIÓN
    // ===========================================================================

    test('S1 - Morningstar: si incoming es el ticker exacto, reemplaza la variante', () async {
      final seenSymbols = <String>[];

      final trackingProvider = _TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': '0P0000X83M',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, '0P0000X83M');
    });

    test(
      'S2 - Morningstar: si existing ya es el ticker exacto, se conserva',
      () async {
        final seenSymbols = <String>[];

        final trackingProvider = _TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == '0P0000X83M') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': '0P0000X83M',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                  },
                  {
                    'symbol': '0P0000X83M.F',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [trackingProvider],
        );

        await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

        expect(seenSymbols, isNotEmpty);
        expect(seenSymbols.first, '0P0000X83M');
      },
    );

    test('S3 - Morningstar: ticker exacto después de dos variantes', () async {
      final seenSymbols = <String>[];

      final trackingProvider = _TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.SG',
                  'longname': 'Test Fund',
                  'exchange': 'SGX',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': '0P0000X83M',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, '0P0000X83M');
    });

    test('S4 - Morningstar: la comparación del ticker ignora mayúsculas/minúsculas', () async {
      final seenSymbols = <String>[];

      final trackingProvider = _TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == 'TEST') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'test',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': 'TEST',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, 'TEST');
    });

    test('S5 - Morningstar: si ninguna variante coincide exactamente, se conserva existing', () async {
      final seenSymbols = <String>[];

      final trackingProvider = _TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.SG',
                  'longname': 'Test Fund',
                  'exchange': 'SGX',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, '0P0000X83M.SG');
    });

    test('S6 - Morningstar: entre variantes no exactas no se introduce una preferencia de mercado', () async {
      final seenSymbols = <String>[];

      final trackingProvider = _TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': '0P0000X83M.SG',
                  'longname': 'Test Fund',
                  'exchange': 'SGX',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, '0P0000X83M.F');
    });

    test('S7 - Mercado: ticker exacto TEST.PA gana frente a TEST.MC', () async {
      final seenSymbols = <String>[];

      final trackingProvider = _TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == 'TEST.PA') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'TEST.MC',
                  'longname': 'Test Fund',
                  'exchange': 'MCE',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': 'TEST.PA',
                  'longname': 'Test Fund',
                  'exchange': 'PAR',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: 'TEST.PA', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, 'TEST.PA');
    });

    test(
      'S8 - Mercado: TEST.PA gana aunque TEST.MC aparezca primero',
      () async {
        final seenSymbols = <String>[];

        final trackingProvider = _TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == 'TEST.PA') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': 'TEST.MC',
                    'longname': 'Test Fund',
                    'exchange': 'MCE',
                    'quoteType': 'MUTUALFUND',
                  },
                  {
                    'symbol': 'TEST.PA',
                    'longname': 'Test Fund',
                    'exchange': 'PAR',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [trackingProvider],
        );

        await resolver.resolve(ticker: 'TEST.PA', fundName: 'Test Fund');

        expect(seenSymbols, isNotEmpty);
        expect(seenSymbols.first, 'TEST.PA');
      },
    );

    test(
      'S9 - Sin coincidencia exacta: se conserva el primer símbolo recibido',
      () async {
        final seenSymbols = <String>[];

        final trackingProvider = _TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == 'TEST') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': 'ABC',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                  },
                  {
                    'symbol': 'XYZ',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [trackingProvider],
        );

        await resolver.resolve(ticker: 'TEST', fundName: 'Test Fund');

        expect(seenSymbols, isNotEmpty);
        expect(seenSymbols.first, 'ABC');
      },
    );

    test('S10 - Sin coincidencia exacta: el orden determina el representante de forma estable', () async {
      final seenSymbols = <String>[];

      final trackingProvider = _TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == 'TEST') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'XYZ',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': 'ABC',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, 'XYZ');
    });

    test('T1 - _searchYahoo ejecuta ticker y nombre', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': const [],
        'Alpha Growth Fund': const [],
      });

      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      expect(client.queryCount.length, 2);

      debugPrint('[T1] ticker=1, nombre=1 -> OK');
    });

    test('T8 - PIMCO ejecuta ticker y nombre y resuelve ISIN', () async {
      final client = _FakeYahooClient({
        '0P0000X83M': [
          const _Quote(
            symbol: '0P0000X83M.F',
            longname: 'PIMCO GIS Income Fund E Class USD Income',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'PIMCO GIS Income Fund E Class USD Income': [
          const _Quote(
            symbol: '0P0000X83M.F',
            longname: 'PIMCO GIS Income Fund E Class USD Income',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final foreign = _FakeForeignProvider(
        bySymbol: {
          '0P0000X83M': 'IE00B8K7V925',
          '0P0000X83M.F': 'IE00B8K7V925',
        },
      );

      final provider = _provider(client: client, foreign: [foreign]);

      final result = await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      _expectIsin(result, 'IE00B8K7V925', 'T8');

      expect(result?.source, 'Yahoo/Foreign');

      expect(client.queryCount['0P0000X83M'], 1);
      expect(client.queryCount['PIMCO GIS Income Fund E Class USD Income'], 1);

      expect(client.queryCount.length, 2);

      expect(foreign.calls, isNotEmpty);

      debugPrint('[T8] PIMCO ticker + nombre + Morningstar -> OK');
    });

    test('T9 - ticker sin resultados y nombre con resultado', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': const [],
        'Alpha Growth Fund': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
      });

      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'T9');

      expect(result?.source, 'Yahoo');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      expect(client.queryCount.length, 2);

      debugPrint('[T9] ticker vacío + nombre válido -> OK');
    });

    test('T10 - ticker con resultado y nombre sin resultados', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'T10');

      expect(result?.source, 'Yahoo');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      expect(client.queryCount.length, 2);

      debugPrint('[T10] ticker válido + nombre vacío -> OK');
    });

    test('T11 - ticker y nombre devuelven mismo fondo y se fusionan', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
      });

      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'T11');

      expect(result?.source, 'Yahoo');

      expect(result?.officialName, 'Alpha Growth Fund');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      expect(client.queryCount.length, 2);

      debugPrint('[T11] mismo symbol + datos complementarios -> fusión OK');
    });

    test('T12 - error en ticker no impide consultar el nombre', () async {
      final client = _FailFirstYahooClient(
        failingQuery: 'XYZ.PA',
        responses: {
          'Alpha Growth Fund': [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
        },
      );

      //final provider = _provider(client: client);
      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'T12');

      expect(result?.source, 'Yahoo');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      expect(client.queryCount.length, 2);

      debugPrint('[T12] error ticker + continuación con nombre -> OK');
    });

    test('T13 - quote con symbol vacío se ignora', () async {
      final client = _FakeYahooClient({
        'Alpha Growth Fund': [
          const _Quote(
            symbol: '',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        'XYZ.PA': const [],
      });

      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'T13');
      expect(result?.source, 'Yahoo');
      expect(result?.officialName, 'Alpha Growth Fund');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      debugPrint('[T13] symbol vacío ignorado -> OK');
    });

    test('T14 - elementos de quotes que no son Map se ignoran', () async {
      final client = _RawYahooClient({
        'XYZ.PA': {
          'quotes': [
            'basura',
            123,
            null,
            {
              'symbol': 'XYZ.PA',
              'longname': 'Alpha Growth Fund',
              'quoteType': 'MUTUALFUND',
              'isin': 'FR0000000010',
            },
          ],
        },
        'Alpha Growth Fund': {'quotes': []},
      });

      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'T14');
      expect(result?.source, 'Yahoo');
      expect(result?.officialName, 'Alpha Growth Fund');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      debugPrint('[T14] elementos no Map ignorados -> OK');
    });

    test(
      'T15 - ISIN válido con quoteType ETF no se acepta como ISIN Yahoo',
      () async {
        final client = _FakeYahooClient({
          'XYZ.PA': [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'ETF',
              isin: 'FR0000000010',
            ),
          ],
          'Alpha Growth Fund': const [],
        });

        final provider = _provider(client: client);

        final result = await provider.resolve(
          ticker: 'XYZ.PA',
          fundName: 'Alpha Growth Fund',
        );

        expect(result, isNull);

        expect(client.queryCount['XYZ.PA'], 1);
        expect(client.queryCount['Alpha Growth Fund'], 1);

        debugPrint('[T15] ISIN de ETF ignorado -> OK');
      },
    );

    test('T16 - ISIN inválido se descarta', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'NO-ES-UN-ISIN',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      debugPrint('[T16] ISIN inválido descartado -> OK');
    });

    test('T17 - si falta longname se utiliza shortname', () async {
      final client = _RawYahooClient({
        'XYZ.PA': {'quotes': []},
        'Alpha Growth Fund': {
          'quotes': [
            {
              'symbol': 'XYZ.PA',
              'shortname': 'Alpha Growth Fund',
              'quoteType': 'MUTUALFUND',
              'isin': 'FR0000000010',
            },
          ],
        },
      });

      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'T17');
      expect(result?.source, 'Yahoo');
      expect(result?.officialName, 'Alpha Growth Fund');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      debugPrint('[T17] fallback longname -> shortname -> OK');
    });

    test('T18 - quoteType ausente impide aceptar el ISIN', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: '',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final provider = _provider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      debugPrint('[T18] quoteType ausente/vacío -> ISIN ignorado -> OK');
    });

    test(
      'F1 - al fusionar el mismo mergeKey se conserva el symbol del ticker',
      () async {
        final client = _FakeYahooClient({
          '0P0000X83M.F': [
            const _Quote(
              symbol: '0P0000X83M',
              longname: 'PIMCO GIS Income Fund E Class USD Income',
              quoteType: 'MUTUALFUND',
            ),
          ],
          'PIMCO GIS Income Fund E Class USD Income': [
            const _Quote(
              symbol: '0P0000X83M.F',
              longname: 'PIMCO GIS Income Fund E Class USD Income',
              quoteType: 'MUTUALFUND',
            ),
          ],
        });

        final tracking = _TrackingForeignProvider(seenSymbols: []);

        final provider = _provider(client: client, foreign: [tracking]);

        final result = await provider.resolve(
          ticker: '0P0000X83M.F',
          fundName: 'PIMCO GIS Income Fund E Class USD Income',
        );

        expect(result, isNull);

        expect(tracking.seenSymbols, ['0P0000X83M.F']);

        debugPrint('[F1] symbol representativo del ticker -> OK');
      },
    );

    test('F2 - al fusionar el mismo mergeKey se conserva el nombre más similar al fundName', () async {
      final seenSymbols = <String>[];
      final seenNames = <String>[];

      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Completely Different Fund',
            quoteType: 'MUTUALFUND',
          ),
        ],
        'Alpha Growth Fund': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
          ),
        ],
      });

      final provider = _provider(
        client: client,
        foreign: [
          _TrackingForeignProvider(
            seenSymbols: seenSymbols,
            seenNames: seenNames,
          ),
        ],
      );

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);

      expect(seenSymbols, ['XYZ.PA']);
      expect(seenNames, ['Alpha Growth Fund']);

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      debugPrint(
        '[F2] nombre más similar seleccionado -> '
        '${seenNames.first} -> OK',
      );
    });

    /* test(
      'F3 - el ISIN aportado por cualquiera de las consultas se conserva',
      () async {
        final client = _FakeYahooClient({
          'XYZ.PA': [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          'Alpha Growth Fund': [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
            ),
          ],
        });

        final provider = _provider(client: client);

        final result = await provider.resolve(
          ticker: 'XYZ.PA',
          fundName: 'Alpha Growth Fund',
        );

        _expectIsin(result, 'FR0000000010', 'F3');

        debugPrint('[F3] ISIN de una de las consultas conservado -> OK');
      },
    ); */

    /* test(
      'F4 - ISIN diferentes para el mismo mergeKey generan conflicto',
      () async {
        final client = _FakeYahooClient({
          'XYZ.PA': [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          'Alpha Growth Fund': [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: 'LU0000000020',
            ),
          ],
        });

        final provider = _provider(client: client);

        final result = await provider.resolve(
          ticker: 'XYZ.PA',
          fundName: 'Alpha Growth Fund',
        );

        expect(result, isNull);

        debugPrint('[F4] conflicto de ISIN conservador -> OK');
      },
    ); */
  });
}
