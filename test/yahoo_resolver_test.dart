import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_providers/yahoo_provider.dart';
import 'package:investing/services/isin_resolver.dart';

class _TrackingForeignProvider implements ForeignIsinProvider {
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
  final String? shortname;
  final String exchange;
  final String quoteType;
  final String? isin;

  const _Quote({
    required this.symbol,
    this.longname = '',
    this.shortname,
    this.exchange = 'XPAR',
    required this.quoteType,
    this.isin,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'longname': longname,
    if (shortname != null) 'shortname': shortname,
    'exchange': exchange,
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
  required _FakeYahooClient client,
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

      print('[T1] ticker=1, nombre=1 -> OK');
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

      print('[T8] PIMCO ticker + nombre + Morningstar -> OK');
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

      print('[T9] ticker vacío + nombre válido -> OK');
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

      print('[T10] ticker válido + nombre vacío -> OK');
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

      print('[T11] mismo symbol + datos complementarios -> fusión OK');
    });

    test('T12 - error en ticker no impide consultar el nombre', () async {
      /* final client = _FailFirstYahooClient(
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
      ); */

      /* final client = _FakeYahooClient({
        'XYZ.PA': const [],
        'Alpha Growth Fund': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
      }); */

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

      print('[T12] error ticker + continuación con nombre -> OK');
    });
  });
}
