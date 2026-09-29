import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'yahoo_resolver/yahoo_identity_test.dart';
import 'yahoo_resolver/yahoo_merge_test.dart';
import 'yahoo_resolver/yahoo_ranking_test.dart';
import 'yahoo_resolver/yahoo_search_test.dart';
import 'yahoo_resolver/yahoo_selection_test.dart';
import 'yahoo_resolver/yahoo_test_support.dart';

import 'dart:convert';

import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  runYahooMergeTests();
  runYahooIdentityTests();
  runYahooSelectionTests();
  runYahooRankingTests();
  runYahooSearchTests();

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

    // ===========================================================================
    // S1-S10 — SELECCIÓN DEL SÍMBOLO REPRESENTATIVO DESPUÉS DE LA FUSIÓN
    // ===========================================================================

    test('S1 - Morningstar: si incoming es el ticker exacto, reemplaza la variante', () async {
      final seenSymbols = <String>[];

      final trackingProvider = TrackingForeignProvider(
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

        final trackingProvider = TrackingForeignProvider(
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

      final trackingProvider = TrackingForeignProvider(
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

      final trackingProvider = TrackingForeignProvider(
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

      final trackingProvider = TrackingForeignProvider(
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

      final trackingProvider = TrackingForeignProvider(
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

      final trackingProvider = TrackingForeignProvider(
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

        final trackingProvider = TrackingForeignProvider(
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

        final trackingProvider = TrackingForeignProvider(
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

      final trackingProvider = TrackingForeignProvider(
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

    /* test(
      'F3 - el ISIN aportado por cualquiera de las consultas se conserva',
      () async {
        final client = FakeYahooClient({
          'XYZ.PA': [
            const Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          'Alpha Growth Fund': [
            const Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
            ),
          ],
        });

        final provider = provider(client: client);

        final result = await provider.resolve(
          ticker: 'XYZ.PA',
          fundName: 'Alpha Growth Fund',
        );

        expectIsin(result, 'FR0000000010', 'F3');

        debugPrint('[F3] ISIN de una de las consultas conservado -> OK');
      },
    ); */

    /* test(
      'F4 - ISIN diferentes para el mismo mergeKey generan conflicto',
      () async {
        final client = FakeYahooClient({
          'XYZ.PA': [
            const Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          'Alpha Growth Fund': [
            const Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: 'LU0000000020',
            ),
          ],
        });

        final provider = provider(client: client);

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
